# require 'sparql/client'
require 'set'
require 'fileutils'
require_relative 'git_utils'
require_relative 'couch'
require_relative 'markdown_utils'
require_relative 'secret'
require_relative 'json_constants'
include GitUtils
include MarkdownUtils

class GitEventBuilder
  attr_reader :maintain_xml_repo

  def initialize
    #Skip xml repo, it's not interesting if we have the couch database
    @maintain_xml_repo = false
    @logger = Logger.new('logfile.log')

    @events = {}
    @all_laws = {}
    @today = Date.today.strftime('%Y-%m-%d')
    @index = {
        GENERATED_ON => @today,
        LAW_LIST => {}
    }
  end

  # Create git repo / folders to store files
  def initialize_markdown_repo
    # initialize folders and git repo
    FileUtils.mkdir_p MARKDOWN_FOLDER unless File.exists?(MARKDOWN_FOLDER) # Make sure that path exists
    Dir.chdir(MARKDOWN_FOLDER)
    system('git init')
    Dir.chdir('..')
  end

  # Create git repo / folders to store files
  def initialize_xml_repo
    # initialize folders and git repo
    FileUtils.mkdir_p XML_FOLDER unless File.exists?(XML_FOLDER) # Make sure that path exists
    Dir.chdir(XML_FOLDER)
    system('git init')
    Dir.chdir('..')
  end

  # Populate XML and Markdown repos (if 'previous' is nil, load everything)
  def update(previous)
    add_cloudant_events previous
    if @events.length > 0
      puts "About to process #{@events.length} dates"
      @logger.info "About to process #{@events.length} dates"
      process_events
      save_index
      push_markdown_repo
    else
      puts "Nothing to do."
      @logger.info "Nothing to do."
    end
    
  end

  # Save index.json: a file mapping BWBIDs to paths. This function also the markdown folder: delete paths that don't exist in the index and print an error message if vice versa
  def save_index
    # if validate_markdown_repo

    # Write full list to json file
    open(INDEX_PATH, 'w') do |f|
      f.puts JSON.pretty_generate @index
    end

    commit_markdown_repo(@today, ar_add=nil, message='index ')
    # end
  end

  # Validate if all files and only the files from BWB list are in our folders
  def validate_markdown_repo
    validated = true

    @logger.info 'Validating if markdown files correspond to BWB list'
    Dir.chdir(MARKDOWN_FOLDER)
    all_paths = Dir['**/BWB*/README.md']
    all_files = {}
    all_paths.each do |path|
      m=/(.*\/(BWB.*))\/README\.md/.match(path)
      if m
        all_files[m[2]] = m[1]
      else
        @logger.error "ERROR: #{path} was not a proper path"
      end
    end

    before_length = all_files.length
    puts "#{before_length} documents in repo."
    i=0
    @index[LAW_LIST].each do |bwb_id, regeling_info|
      if all_files[bwb_id]
        regeling_info[JsonConstants::PATH] = all_files[bwb_id]
      end
      if bwb_id == 'BWBV0005981'
        puts bwb_id
      end
      unless (regeling_info[EXPIRATION_DATE] and regeling_info[EXPIRATION_DATE] <= @today) or File.exists? "#{regeling_info[JsonConstants::PATH]}/README.md"
        @logger.error "ERROR: #{regeling_info[JsonConstants::PATH]} did not exist at #{regeling_info[JsonConstants::PATH]}/README.md, but should exist according to BwbIdList"
        validated = false
      end
      # Remove element from map; it exists
      doc_path = File.expand_path(regeling_info[JsonConstants::PATH])
      if File.exist? doc_path
        all_files[bwb_id] = nil
      end

      i+=1

      if i % 1000 == 0
        puts "Checked #{i} docs"
      end
    end
    pruned = []
    all_files.each do |bwb_id, doc_path|
      if doc_path
        pruned << doc_path
      end
    end

    puts "#{before_length - pruned.length} documents existed rightfully."

    if pruned.length > 0
      validated = false
      puts "But we are still left with #{pruned.length} documents that don't exist anymore in the BwbIdList, but do exist as files."
      pruned.each do |doc_path|
        puts doc_path
        # File.delete doc_path
      end
    end

    # delete_empty_folders
    Dir.chdir('..')

    validated
  end

  def delete_empty_folders
    puts 'Deleting empty folders'
    all_folders = Dir['**/*/']
    all_folders.each do |folder|
      if File.exists? folder and Dir.entries(folder).count <= 2
        puts "#{folder} was empty"

        # This loop is to check up to what directory it's safe to delete
        loop do
          delete_path = File.expand_path("#{folder}/..")
          count = (Dir.entries(delete_path).size) - 3 # -2 to ignore . and .. and -1 to ignore the source folder
          if count > 0
            break
          else
            folder = delete_path
          end
        end
        FileUtils.rm_rf(folder)
      end
    end
  end

  private
  # Get all events in Cloudant db (including Metalex docs converted back again) that are not in the bwb list
  def add_cloudant_events(previous_index=nil)
    puts 'Querying all expressions in CouchDB...'

    if previous_index
      add_events_based_on_index(previous_index)
    else
      #Get all expressions in cloudant
      add_events_initial_population
    end
  end

  def add_events_initial_population
    str_our_expressions = open("http://#{Secret::CLOUDANT_NAME}.cloudant.com/bwb/_design/RegelingInfo/_view/all").read
    rows = JSON.parse(str_our_expressions.force_encoding('utf-8'))['rows']

    puts "Found #{rows.length} documents"
    rows.each do |row|
      bwb_id = row['key']
      regeling_info = row['value']

      add_to_law_list(regeling_info)

      unless row['value'][JsonConstants::PATH]
        raise "#{row['id']} did not have a path set."
      end
      # Add to the events map if it's not already in it
      retraction_date = handle_retraction(@today, bwb_id, regeling_info)
      if !retraction_date or regeling_info[DATE_LAST_MODIFIED] < retraction_date
        handle_modification(bwb_id, regeling_info)
        # else
        # puts "NOTE: #{bwb_id} was retracted before it was last modified. Ignoring modification"
      end
    end
  end

  def add_events_based_on_index(previous_index)
    last_index_date = previous_index[GENERATED_ON]

    # Add previous index to law list
    previous_index[LAW_LIST].each do |bwb_id, regeling_info|
      add_to_law_list(regeling_info)
    end

    # Get recently modified docs (after last index)
    rows_modified = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'modifiedAfter', {:startkey => "\"#{last_index_date}-some_string_to_exclude_this_date\""})
    rows_modified.each do |row|
      regeling_info = row['value']
      bwb_id = regeling_info [JsonConstants::BWB_ID]

      # Add doc to law list if it contains new info
      add_to_law_list(regeling_info)

      # Get retraction date for this doc from previous index
      existing_retraction_date = nil
      if previous_index[LAW_LIST][bwb_id] and previous_index[LAW_LIST][bwb_id][JsonConstants::EXPIRATION_DATE]
        existing_retraction_date = previous_index[LAW_LIST][bwb_id][JsonConstants::EXPIRATION_DATE]
      end

      retraction_date = regeling_info[EXPIRATION_DATE]
      # If our retraction date is either different than the existing metadata, or later than the last index, process it
      if retraction_date and (retraction_date != existing_retraction_date or existing_retraction_date > last_index_date)
        handle_retraction(@today, bwb_id, regeling_info)
      end

      # If there are expressions that were added after our last index, make an add event (if it's not after retraction of the law)
      # Note: if !addedToCouchDb, then the expression is from *before* 2014-07-24
      if regeling_info['addedToCouchDb'] and regeling_info['addedToCouchDb'] >= last_index_date
        if !retraction_date or regeling_info[DATE_LAST_MODIFIED] < retraction_date
          handle_modification(bwb_id, regeling_info)
          # else
          # puts "NOTE: #{bwb_id} was retracted before it was last modified. Ignoring modification"
        end
      end
    end
  end

  def add_to_law_list(regeling_info)
    info = @index[LAW_LIST][regeling_info[BWB_ID]]
    if !info or
        info[DATE_LAST_MODIFIED] < regeling_info[DATE_LAST_MODIFIED] or
        (metadata_updated(info, regeling_info))
      @index[LAW_LIST][regeling_info[BWB_ID]] = regeling_info
    end
  end

  def metadata_updated(info, info2)
    if info['couchDbModificationDate'] and info2['couchDbModificationDate']
      earlier_modification_date = info['couchDbModificationDate'] < info2['couchDbModificationDate']
    elsif !info['couchDbModificationDate'] and info2['couchDbModificationDate']
      earlier_modification_date = true
    else
      earlier_modification_date = false
    end
    info[DATE_LAST_MODIFIED] == info2[DATE_LAST_MODIFIED] and earlier_modification_date
  end

  def handle_modification(bwb_id, regeling_info)
    expression_date = regeling_info[DATE_LAST_MODIFIED]
    events_for_date = @events[expression_date]
    events_for_date ||= [] # Initialize to empty array if it doesn't exist
    @events[expression_date] = events_for_date
    unless is_in_events(bwb_id, events_for_date, false)
      events_for_date << regeling_info
    end
  end

  def handle_retraction(today, bwb_id, regeling_info)
    retraction_date = regeling_info[EXPIRATION_DATE]
    if retraction_date and retraction_date.strip.length > 0
      if retraction_date <= today # If retraction date for #{bwb_id} is before or on today; process deletion
        # Add deletion event
        events_for_date = @events[retraction_date]
        events_for_date ||= [] # Initialize to empty array if it doesn't exist
        @events[retraction_date] = events_for_date
        unless is_in_events(bwb_id, events_for_date, true)
          regeling_info = regeling_info.clone
          regeling_info[:_delete] = true
          regeling_info[EXPIRATION_DATE] = retraction_date
          events_for_date << regeling_info
        end
        # else
        # puts "WARNING: deletion date would be in the future"
      end
    end

    retraction_date
  end

  def is_in_events(bwb_id, events_for_date, delete)
    events_for_date.each do |event|
      if event[BWB_ID] == bwb_id
        if delete != event[:_delete] # Delete doc if one of conflicting verbs is delete
          # puts "WARNING: We have information saying #{bwb_id} is _delete: #{event[:_delete]}) on #{date} instead of #{delete}. Deleting anyway."
          event[:_delete] = true
        end
        return true
      end
    end
    false
  end

  def update_entry(full_law_list, entry, second_try=false)
    begin
      md_folder = "#{MARKDOWN_FOLDER}/#{entry[JsonConstants::PATH]}"
      md_path = "#{md_folder}/README.md"
      if entry[:_delete]
        # Delete expression:
        # - XML
        if @maintain_xml_repo
          xml_file = "#{XML_FOLDER}/#{entry[JsonConstants::BWB_ID]}.xml"
          File.delete xml_file if File.exists? xml_file
        end
        # - Markdown
        MarkdownUtils::delete_markdown_file(entry, md_folder)
      else
        bwb_id = entry[BWB_ID]
        # Write new expression
        # - XML
        str_xml = get_xml(bwb_id, entry)
        if @maintain_xml_repo
          write_xml_to_file(bwb_id, str_xml)
        end
        markdown = MarkdownUtils::convert_to_markdown(bwb_id, entry, full_law_list, str_xml)
        entry[:empty] = markdown.length > 0

        # - Markdown
        MarkdownUtils::write_markdown_file(markdown, md_folder, md_path)
      end
      rescue => e
        @logger.error "ERROR while updating #{entry[BWB_ID]}: #{e}"
        # Try a second time after waiting 1 minute
        if second_try
          @logger.error 'Second try also failed. Ignoring entry'
        else
          @logger.error '       Retrying after 1 minute'
          sleep(60)
          return update_entry(law_list, entry, second_try=true)
        end
    end
  end

  def validate_events
    status_quo = {}
    bwb_list_date = @index[GENERATED_ON]

    #Simulate writes / deletes
    @events.keys.sort.each do |date|
      @events[date].each do |entry|
        if entry[:_delete]
          # if entry[PATH] == "ministeriele-regeling/instellingsbesluit/ncp/2011/BWBR0029781"
          #   puts "ministeriele-regeling/instellingsbesluit/ncp/2011/BWBR0029781"
          # end
          status_quo[entry[PATH]] = nil
        else
          status_quo[entry[PATH]] = entry[BWB_ID]
        end
      end
    end

    # Check that every file in bwb list has been written
    @index[LAW_LIST].each do |_, entry|
      if status_quo[entry[PATH]]
        status_quo[entry[PATH]] = nil
      elsif entry[EXPIRATION_DATE] and entry[EXPIRATION_DATE] <= bwb_list_date
        # Rightfully deleted
      else
        raise "did not process #{entry[PATH]}"
      end
    end
    # Check that every written file is in bwb list
    status_quo.each do |path, bwb_id|
      if bwb_id
        unless @index[LAW_LIST][bwb_id]
          raise "did not delete #{path}"
        end
      end
    end
  end

  def git_gc
    git_gc_md # Git garbage collect
    if @maintain_xml_repo
      git_gc_xml
    end
  end

  def process_events
    ## Make sure that the index will align with the result of all events
    # validate_events

    gc_counter = 0
    # TODO if ever re-populating, url-ify the paths in CouchDB: get rid of accents on letters, etc. This happens for new docs, but old docs still have ugly paths sometimes
    start_from = '0000-00-00'
    dates=[]
    # puts "Starting from #{start_from}"
    @events.keys.each do |date|
      if date >= start_from
        dates << date
      else
        @events[date] = nil
      end
    end
    # Start with earliest date, so sort keys
    dates.sort!
    @logger.info "First: #{dates.first}"
    @logger.info "Last:  #{dates.last}"
    @logger.info "Left with #{dates.length} dates"

    # git_gc # Git garbage collect
    dates.each do |author_date|
      puts "#{author_date} has #{@events[author_date].length} changes"
      @events[author_date].each do |entry|
        update_entry(@all_laws, entry)
      end
      # Create git commits for changes on this date
      commit_markdown_repo author_date
      if @maintain_xml_repo
        commit_xml_repo author_date
      end
      gc_counter += 1
      if gc_counter >= 100
        git_gc # Git garbage collect
        gc_counter = 0
      end
    end
    # git_gc # Git garbage collect
  end


end
