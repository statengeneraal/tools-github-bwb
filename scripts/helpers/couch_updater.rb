require 'open-uri'
require 'uri'
require 'logger'
require 'nokogiri'
require 'zip'
require 'json'
require_relative 'bwb_list_parser'
require_relative 'html_converter'
require_relative 'update_couch_helper'
include UpdateCouchHelper

class CouchUpdater
  LAWLY_ROOT = 'http://wetten.lawly.nl/'
  INFINITE_LOADING_DOCUMENTS = %w(BWBR0004581 BWBR0008587 BWBR0018715 BWBR0022061 BWBR0025132 BWBR0032324 BWBR0008023)

  def initialize
    @logger = Logger.new('couch_update.log')

    @bytesize = 0
    @bulk=[]
    @expressions_added=0
    @new_expressions = []
    @metadata_changed = {}
    @disappeared = []
    @today = Date.today.strftime('%Y-%m-%d')
  end

  def get_realization_map(expressions)
    bwb_ids = Set.new
    expressions.each do |doc|
      bwb_ids << doc[JsonConstants::BWB_ID]
    end
    bwb_ids = bwb_ids.to_a

    expression_map = {}
    rows = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'expressionsForBwbId', {keys: bwb_ids})
    rows.each do |row|
      bwbid=row['key']
      set = expression_map[bwbid] || Set.new
      expression_id=row['id']
      set << expression_id
      expression_map[bwbid] = set
    end
    expressions.each do |doc|
      bwbid=doc[JsonConstants::BWB_ID]
      set = expression_map[bwbid] || Set.new
      set << doc['_id']
    end
    expression_map
  end

  def start
    xml_source = download_metadata_dump

    # Get what's in OUR database
    rows_cloudant, prev_paths, _ = get_cloudant_entries

    # Parse government XML
    sax_handler = BwbListParser.new(prev_paths)
    parser = Nokogiri::XML::SAX::Parser.new(sax_handler)
    puts 'Parsing XML...'
    parser.parse xml_source
    puts 'XML parsed.'

    bwb_list = sax_handler.bwb_list

    # Find new expressions
    get_differences(rows_cloudant, bwb_list)

    puts "Found #{bwb_list[JsonConstants::LAW_LIST].length} expressions, of which #{@new_expressions.length} new, #{@metadata_changed.length} had metadata changed, #{@disappeared.length} disappeared"
    @logger.info "Found #{bwb_list[JsonConstants::LAW_LIST].length} expressions, of which #{@new_expressions.length} new, #{@metadata_changed.length} had metadata changed, #{@disappeared.length} disappeared"

    # Download new expressions and upload to CouchDB
    process_changes
  end

  # noinspection RubyStringKeysInHashInspection
  def setup_doc_as_new_expression(doc, str_xml)
    expression_id = "#{doc[JsonConstants::BWB_ID]}:#{doc[JsonConstants::DATE_LAST_MODIFIED]}"
    doc['@context'] = 'http://assets.lawly.eu/ld/bwb_context.jsonld'
    doc['@type'] = 'frbr:Expression'
    doc['frbr:realizationOf'] = doc[JsonConstants::BWB_ID]
    doc['foaf:page'] = "#{LAWLY_ROOT}bwb:#{expression_id}"
    doc['_id'] = expression_id
    doc['couchDbModificationDate'] = @today
    doc['displayKind'] = get_display_kind(doc)
    doc['addedToCouchDb'] = @today
    doc.delete('xml')
    #TODO add dcterms:tableOfContents, dcterms:publisher='KOOP'
    # TODO dcterm:seealso/sameas metalex id

    html_converter = HtmlConverter.new(Nokogiri::XML(str_xml), doc)
    str_html =html_converter.full_html.to_s
    doc['empty'] = html_converter.is_empty
    doc['dcterms:references']=html_converter.id_adder.references_bwbs.to_a

    doc['_attachments'] = {
        'data.xml' => {
            'content_type' => 'text/xml',
            'data' => Base64.encode64(str_xml)
        },
        'show.html' => {
            'content_type' => 'text/html',
            'data' => Base64.encode64(str_html)
        }
    }
    if html_converter.toc_xml.root.element_children.length > 0
      doc['_attachments']['toc.xml'] = {
          'content_type' => 'text/xml',
          'data' => Base64.encode64(html_converter.toc_xml.to_s)
      }
    end
    str_xml.bytesize + html_converter.full_html.to_s.bytesize + html_converter.toc_xml.to_s.bytesize
  end

  def convert_new_expression_to_work(doc, realizations)
    #TODO handle case where work already exists...
    bwb_id = doc[JsonConstants::BWB_ID]
    realizations[bwb_id].each do |realization_id|
      if realization_id > doc['_id']
        puts "WARNING: we have a realization #{realization_id}, yet we make the work about an earlier expression #{doc['_id']}"
        @logger.warn "WARNING: we have a realization #{realization_id}, yet we make the work about an earlier expression #{doc['_id']}"
      end
    end
    doc['_id'] = bwb_id
    doc['@type'] = 'frbr:LegalWork'
    doc['foaf:page'] = "#{LAWLY_ROOT}bwb/#{bwb_id}"
    doc['frbr:realization'] = realizations[bwb_id].to_a
    doc.delete('frbr:realizationOf')
    doc.delete('xml')

    get_byte_size(doc)
  end

  private

  # Download XML of given documents and upload the expressions to CouchDB
  def process_changes
    add_new_expressions
    @realizations = get_realization_map(@new_expressions)
    update_works
    process_changed_metadata
    puts 'Done.'
  end

  # noinspection RubyStringKeysInHashInspection
  def add_new_expressions
    @bytesize = 0
    @bulk = []
    @new_expressions.each do |doc|
      # Download (or skip) this document
      str_xml = get_gov_xml(doc[JsonConstants::BWB_ID])
      if str_xml
        doc_bytesize = setup_doc_as_new_expression(doc, str_xml)
        @bulk << doc
        @expressions_added+=1
        @bytesize += doc_bytesize
        if @expressions_added > 0 and @expressions_added % 10 == 0
          puts "Downloaded #{@expressions_added} new expressions."
        end
        # Flush if array gets too big
        flush_if_too_big
      end
    end

    #Flush remaining
    if @bulk.size > 0
      bulk_write_to_bwb_database(@bulk)
      @bytesize = 0
      @bulk.clear
    end
  end

  def update_works
    @bytesize = 0
    @bulk = []

    works = {}
    @new_expressions.each do |doc|
      bwb_id = doc[JsonConstants::BWB_ID]
      unless works[bwb_id] and
          works[bwb_id][JsonConstants::DATE_LAST_MODIFIED] > doc[JsonConstants::DATE_LAST_MODIFIED]
        # Only use the latest expression for this work
        works[bwb_id] = doc
      end
    end

    works.each do |_, doc|
      doc_bytesize = convert_new_expression_to_work(doc, @realizations)
      @bulk << doc
      @expressions_added+=1
      @bytesize += doc_bytesize
      if @expressions_added > 0 and @expressions_added % 10 == 0
        puts "Downloaded #{@expressions_added} new expressions."
      end
      # Flush if array gets too big
      flush_if_too_big
    end

    #Flush remaining
    if @bulk.size > 0
      bulk_write_to_bwb_database(@bulk)
      @bytesize = 0
      @bulk.clear
    end
  end


  def get_gov_xml(bwb_id)
    url = "http://wetten.overheid.nl/xml.php?regelingID=#{bwb_id}"
    begin
      open(url, :read_timeout => 20*60).read
    rescue
      @logger.error "ERROR: Could not download #{url}"
      return
    end
  end

# Flush documents in @bulk array if its size exceeds a certain size
  def flush_if_too_big(max_bulk_size=15)
    if @bytesize >= max_bulk_size*1024*1024 or @bulk.size >= 20 # Flush after some MB or 20 items
      bulk_write_to_bwb_database(@bulk)
      # puts "Flush #{bulk.size}"
      @bulk.clear
      @bytesize = 0
    end
  end

  def get_display_kind(doc)
    display_kind = nil
    if                          doc[JsonConstants::KIND]
      case doc[JsonConstants::KIND]
        when 'AMvB',
            'AMvB-BES',
            'beleidsregel',
            'circulaire',
            'circulaire-BES',
            'KB',
            'rijksKB',
            'rijkswet',
            'reglement',
            'verdrag',
            'wet',
            'wet-BES',
            'beleidsregel-BES',
            'ministeriele-regeling',
            'ministeriele-regeling-archiefselectielijst',
            'ministeriele-regeling-BES'
          display_kind = doc[JsonConstants::KIND].gsub('inisteriele', 'inisteriële').gsub('-', ' ').capitalize
        when 'pbo',
            'zbo'
          display_kind = doc[JsonConstants::KIND]
        else
          display_kind = doc[JsonConstants::KIND]
      end
    end
    display_kind
  end


# Find gaps between database and BwbIdList.xml
  def get_differences(rows_cloudant, bwb_list)
    existing_couch_ids={}

    # See if metadata has changed
    rows_cloudant.each do |row|
      evaluate_row_against_bwbidlist(bwb_list, row)
    end

    # Find new expressions
    rows_cloudant.each do |row|
      id = row['id']
      # if(id.start_with? 'BWBR0001827')
      #   puts 'uuuuh'
      # end
      existing_couch_ids[id] = true
      existing_couch_ids[id.gsub('/', ':')] = true
    end
    bwb_list[JsonConstants::LAW_LIST].each do |bwb_id, regeling_info|
      expression_id="#{bwb_id}:#{regeling_info[JsonConstants::DATE_LAST_MODIFIED]}"
      unless existing_couch_ids[expression_id] or is_blacklisted?(bwb_id)
        @logger.info "#{expression_id} was new."
        @new_expressions << regeling_info
      end
    end
  end

  def is_blacklisted?(bwb_id)
    if INFINITE_LOADING_DOCUMENTS.include? bwb_id
      url = "http://wetten.overheid.nl/xml.php?regelingID=#{bwb_id}"
      puts "Skipping #{bwb_id} because it took too long to download before (at #{url})"
      true
    else
      false
    end
  end

  def evaluate_row_against_bwbidlist(bwb_list, couch_row)
    id = couch_row['id']
    # if(id.start_with? 'BWBR0001827')
    #   puts 'uuuuh'
    # end
    bwb_id = couch_row['key']
    doc = couch_row['value']
    if bwb_list[JsonConstants::LAW_LIST][bwb_id]
      regeling_info = bwb_list[JsonConstants::LAW_LIST][bwb_id]

      date_last_modified=regeling_info[JsonConstants::DATE_LAST_MODIFIED]
      if date_last_modified == couch_row['value'][JsonConstants::DATE_LAST_MODIFIED]
        #Check if metadata is the same, still
        regeling_info.each do |key, value|
          unless key == 'displayTitle' or key == 'path'
            unless is_same(doc[key], value)
              changes = @metadata_changed[id]
              changes ||= {}
              changes[key] = value
              @metadata_changed[id] = changes
              break
            end
          end
        end
      end
      @metadata_changed
    else
      @disappeared << id
    end
  end

# Get government XML; BwbIdList. This list contains metadata for all laws currently in the government CMS.
  def download_metadata_dump
    puts 'Downloading XML'
    zipped_file = open('http://wetten.overheid.nl/BWBIdService/BWBIdList.xml.zip')
    xml_source = nil
    Zip::File.open(zipped_file) do |zip|
      xml_source = zip.read('BWBIdList.xml').force_encoding('UTF-8')
    end
    if xml_source == nil
      err = 'Could not read metadata XML dump'
      @logger.error err
      raise err
    end

    xml_source
  end

end