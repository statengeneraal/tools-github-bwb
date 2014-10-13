require 'open-uri'
require 'uri'
require 'zip'
require_relative 'secret'
require_relative 'markdown_utils'

BWB_RESULT = 'regelingInfoLijst'

BWB_ID = 'bwbId'
KIND = 'regelingSoort'
OFFICIAL_TITLE = 'officieleTitel'
DATE_LAST_MODIFIED = 'datumLaatsteWijziging'
EXPIRATION_DATE = 'vervalDatum'
ENTRY_DATE = 'inwerkingtredingsDatum'
TITLE = 'titel'
STATUS = 'status'
NON_OFFICIAL_TITLE_LIST = 'nietOfficieleTitels'
ABBREVIATION_LIST = 'afkortingen'
CITE_TITLE_LIST = 'citeertitels'
GENERATED_ON = 'gegenereerdOp'
LAW_LIST = 'regelingInfoLijst'
PATH='path'

# Module containing methods for converting BWB XML to Markdown, commiting repos, parsing the BWB list, etc.
# TODO tear some stuff apart
module GitUtils
  MARKDOWN_FOLDER = 'md'
  XML_FOLDER = 'xml'
  BWB_JSON='bwb_list.json'
  INDEX_PATH = "#{MARKDOWN_FOLDER}/index.json"

  def get_xml(bwb_id, entry)
    cache_path = "cache/#{bwb_id}.#{entry[DATE_LAST_MODIFIED]}.xml"
    old_cache_path = "cache/#{bwb_id}%2F#{entry[DATE_LAST_MODIFIED]}.xml"
    if File.exist? cache_path
      str_xml = File.open(cache_path).read
    elsif File.exitst? old_cache_path
      str_xml = File.open(old_cache_path).read
    else
      str_xml = open("http://#{Secret::CLOUDANT_NAME}.cloudant.com/bwb/#{bwb_id}:#{entry[DATE_LAST_MODIFIED]}/data.xml").read.force_encoding('utf-8')

      #Write to cache
      File.open(cache_path, "w+") do |f|
        f.puts str_xml
      end
    end
    if str_xml == nil
      str_xml = ''
    end
    str_xml
  end

  def write_xml_to_file(bwb_id, str_xml)
    FileUtils.mkdir_p XML_FOLDER unless File.exists?(XML_FOLDER) # Make sure that path exists
    xml_path = "#{XML_FOLDER}/#{bwb_id}.xml"
    open(xml_path, 'w+') do |f|
      f.puts str_xml
    end
  end

  @deprecated
  def parse_bwb_list(existing=nil)
    str_today = Time.now.strftime('%Y-%m-%d')

    if (existing == nil) or (existing[GENERATED_ON] < str_today)
      # author_date = str_today

      puts 'Downloading JSON'
      str_json = open("http://#{Secret::CLOUDANT_NAME}.cloudant.com/bwb/bwbIdList").read
      bwb_id_list = JSON.parse str_json.force_encoding('utf-8')

      law_dict ={}
      bwb_id_list[LAW_LIST].each do |regeling_info|
        bwb_id = regeling_info[BWB_ID]
        unless bwb_id
          raise 'No bwbId'
        end
        if existing and bwb_id_list[LAW_LIST][bwb_id]
          # Use existing path
          regeling_info[PATH] = bwb_id_list[LAW_LIST][bwb_id][PATH]
        else
          #Generate new path
          regeling_info[PATH] = GitUtils.create_path(regeling_info)
        end

        law_dict[bwb_id] = regeling_info
      end
      bwb_id_list[LAW_LIST] = law_dict
    else
      raise "We have previously processed a bwb list from #{existing[GENERATED_ON]} which is after #{str_today}"
    end
    puts "BWB list: #{bwb_id_list[GENERATED_ON]}"
    bwb_id_list
  end

  def self.create_path(law)
    cite_titles = law[CITE_TITLE_LIST]
    shortest_title = law[OFFICIAL_TITLE]
    if cite_titles
      cite_titles.each do |cite_title|
        if shortest_title == nil or cite_title[TITLE].length < shortest_title.length
          shortest_title = cite_title[TITLE]
        end
      end
    end

    non_official_titles = law[NON_OFFICIAL_TITLE_LIST]
    if non_official_titles
      non_official_titles.each do |title|
        if shortest_title == nil or title.length < shortest_title.length
          shortest_title = title
        end
      end
    end

    if shortest_title
      words = shortest_title.split(/ /)

      words.map! do |word|
        case word.downcase
          when 'con', 'prn', 'aux', 'nul', /com[0-9]/, /lpt[0-9]/, /^\.+$/
            # Escape Windows-unfriendly folders, e.g., driver file or only periods
            # See http://support.microsoft.com/kb/74496/en-us
            word = "_#{word}_"
          else
        end
        word.gsub!(/^\.+/, '') # Replace leading periods with ''
        word.gsub!(/["\/\^\?<>:\*\|]/, '') # Replace any non-valid char with '', see http://support.grouplogic.com/?p=1607
        word.gsub!(/[,°]/, '') # Replace ugly chars with ''
        word.downcase! # For Windows /CONCERNANT/ and /ConCerNanT/ are the same folders, so just downcase it
        word
      end

      escaped = ''
      words.each do |word|
        if escaped.length + word.length < 50 #Don't exceed 50 chars (note that Windows has a 255 char limit for paths)
          escaped << "/#{word}"
        else
          escaped << '/etc'
          break
        end
      end
      unless escaped.start_with? '/'
        escaped = '/'+escaped
      end

      path = "#{law[KIND]}#{escaped}/#{law[BWB_ID]}"

      # if /[^A-Za-z0-9 ,]/ =~ shortest_title
      #shortest_title
      # end
    else
      path = "#{law[KIND]}/#{law[BWB_ID]}"
    end
    path.gsub!(/\/\/+/, '/') # Remove duplicate /'s
    path.gsub!(/\/+$/, '') # Remove trailing /'s # Although there are none b/c the path always ends with /[BWBID]
    # puts path

    path
  end

  def save_bwb_list_xml
    puts 'Downloading XML'
    zipped_file = open("http://wetten.overheid.nl/BWBIdService/BWBIdList.xml.zip")
    # zipped_file = open('C:\Users\Maarten\Desktop\BWBIdList.zip')

    xml_source = nil
    Zip::File.open(zipped_file) do |zip|
      xml_source = zip.read('BWBIdList.xml').force_encoding('UTF-8')
    end
    if xml_source == nil
      throw :could_not_read_xml
    end

    # Write xml to file
    FileUtils.mkdir_p(XML_FOLDER) unless File.exists?(XML_FOLDER) # Make sure that path exists
    xml_path = "#{XML_FOLDER}/bwbIdList/BWBIdList.xml"
    open(xml_path, 'w+') do |f|
      f.puts xml_source
    end

    commit_xml_repo Time.now.strftime('%Y-%m-%d'), add=['bwbIdList/BWBIdList.xml'], message='BWBIdList '
  end

  def parse_bwb_list_xml
    # See if JSON file already exists
    begin
      json_str = File.read(BWB_JSON_PATH)
      existing = JSON.parse(json_str.force_encoding('utf-8'))
    rescue
      puts 'Problem loading JSON file. Proceeding to download'
    end

    str_today = Time.now.strftime('%Y-%m-%d')
    if (existing == nil) or (existing[GENERATED_ON] < str_today)
      author_date = str_today

      puts 'Downloading XML'
      zipped_file = open("http://#{Secret::CLOUDANT_NAME}.overheid.nl/BWBIdService/BWBIdList.xml.zip")
      # zipped_file = open('C:\Users\Maarten\Desktop\BWBIdList.zip')

      xml_source = nil
      Zip::ZipFile.open(zipped_file) do |zip|
        xml_source = zip.read('BWBIdList.xml').force_encoding('UTF-8')
      end
      if xml_source == 'nil'
        throw :could_not_read_xml
      end

      # Write xml to file
      FileUtils.mkdir_p(XML_FOLDER) unless File.exists?(XML_FOLDER) # Make sure that path exists
      xml_path = "#{XML_FOLDER}/bwbIdList/BWBIdList.xml"
      open(xml_path, 'w+') do |f|
        f.puts xml_source
      end

      commit_xml_repo author_date, add=['bwbIdList/BWBIdList.xml'], message='BWBIdList '

      sax_handler = LegislationParser.new(existing)
      parser = Nokogiri::XML::SAX::Parser.new(sax_handler)
      # Parse XML file
      puts "Parsing XML..."
      parser.parse xml_source
      puts "XML parsed."

      bwb_list = sax_handler.bwb_list
      changes = sax_handler.changes
    else
      puts 'Already have bwb list for today'
      bwb_list = existing
      changes = nil # TODO we should save state in case the program crashes
    end
    return bwb_list, changes
  end

  # Change given string with given updates at the matches of the given regex
  def substitute!(regexp, string, updates)
    match = regexp.match(string)
    if match
      keys_in_order = updates.keys.sort_by { |k| match.offset(k) }.reverse
      keys_in_order.each do |k|
        offsets_for_group = match.offset(k)
        string[offsets_for_group.first...offsets_for_group.last] = updates[k]
      end
    end
  end

  # Get relative path from a document to a document
  def get_path_to(from, to)
    directories_back = from.count('/')+1
    ('../' * directories_back)+to+'/README.md' #/README.md
  end

  # Git commit the markdown repository in the /md folder
  def commit_markdown_repo(date, ar_add=nil, message='')
    Dir.chdir(MARKDOWN_FOLDER)
    if ar_add and ar_add.length > 0
      adds = ar_add.reduce('') do |sum, value|
        sum + "\"#{value}\" "
      end
      # puts "git add #{adds}"
      system("git add #{adds}")
    else
      # puts 'git add --all'
      system('git add --all')
    end
    # puts "git commit -am \"#{message+date}\" --quiet --date '#{get_author_date(date)}'"
    system("git commit -am \"#{message+date}\" --quiet --date '#{get_author_date(date)}'") #
    Dir.chdir('..')
  end

  # Return epoch time if our date is before that
  def get_author_date(str_date)
    /([0-9]{4})-([0-9]{2})-([0-9]{2})/ =~ str_date
    date = Time.new($1, $2, $3, 9, 0, 0, '+02:00') # Create time out of date string, 9 'o clock Amsterdam time

    if date < Time.at(0)
      # puts 'WARNING: Date was before epoch (1-1-1970)'
      Time.at(0).iso8601(0)
    else
      date.iso8601(0)
    end
  end

  # # Split the list into laws that are in effect and laws that have been retracted
  # def split_effective index
  #   today = Date.today.strftime("%Y-%m-%d")
  #
  #   effectives = {}
  #   retracted = {}
  #   index.each do |bwb_id, regeling_info|
  #     expiration = regeling_info[EXPIRATION_DATE].strip
  #     if expiration and expiration.length > 0 and expiration < today
  #       retracted[bwb_id] = regeling_info
  #     else
  #       effectives[bwb_id] = regeling_info
  #     end
  #   end
  #
  #   return effectives, retracted
  # end

  def git_gc_xml
    puts "Garbage collecting /xml/.git ..."
    Dir.chdir(XML_FOLDER)
    system("git gc")
    Dir.chdir('..')
  end
  def git_gc_md
    puts "Garbage collecting /md/.git ..."
    Dir.chdir(MARKDOWN_FOLDER)
    system("git gc")
    Dir.chdir('..')
  end

  # Git commit the XML repository in the /xml folder
  def commit_xml_repo(author_date, array_add=nil, message='')
    Dir.chdir(XML_FOLDER)
    if array_add and array_add.length > 0
      str_add = array_add.reduce('') do |sum, value|
        sum + "\"#{value}\" "
      end
      # puts "git add #{str_add}"
      system("git add #{str_add}")
    else
      # puts 'git add .'
      system('git add .')
    end
    # puts "git commit -am \"#{message+author_date}\" --quiet --date '#{get_author_date(author_date)}'"
    system("git commit -am \"#{message+author_date}\" --quiet --date '#{get_author_date(author_date)}'") #

    Dir.chdir('..')
  end
  def pull_markdown_repo
    Dir.chdir(MARKDOWN_FOLDER)
    system('git pull')
    Dir.chdir('..')
  end
  def push_markdown_repo
    Dir.chdir(MARKDOWN_FOLDER)
    system('git push')
    Dir.chdir('..')
  end
end

