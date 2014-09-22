require 'open-uri'
require 'uri'
require 'nokogiri'
require 'zip'
require 'json'
require_relative '../helpers/bwb_list_parser'
require_relative '../helpers/update_couch_helper'
include UpdateCouchHelper

# This script will sync our CouchDB database against the government BWBIdList. Run daily. # TODO implement as Clockwork app; Heroku scheduler runs *best-effort*; not guaranteed.
def run_script
  # Get government XML
  puts 'Downloading XML'
  zipped_file = open('http://wetten.overheid.nl/BWBIdService/BWBIdList.xml.zip')
  xml_source = nil
  Zip::ZipFile.open(zipped_file) do |zip|
    xml_source = zip.read('BWBIdList.xml').force_encoding('UTF-8')
  end
  if xml_source == nil
    raise 'could not read xml'
  end
  # noinspection RubyUnusedLocalVariable
  zipped_file = nil

# Get what's in our database
  rows_cloudant, prev_paths, _ = get_cloudant_entries

# Parse government XML
  sax_handler = BwbListParser.new(prev_paths)
  parser = Nokogiri::XML::SAX::Parser.new(sax_handler)
  puts 'Parsing XML...'
  parser.parse xml_source
  puts 'XML parsed.'

  bwb_list = sax_handler.bwb_list

# Only use bwb_list and rows_cloudant
# noinspection RubyUnusedLocalVariable
  sax_handler = nil
# noinspection RubyUnusedLocalVariable
  xml_source = nil
# noinspection RubyUnusedLocalVariable
  parser = nil
# noinspection RubyUnusedLocalVariable
  prev_paths = nil
  _ = nil
#####################################

# Find new expressions
  new_expressions, metadata_changed, disappeared = get_new_expressions(rows_cloudant, bwb_list)
  puts "Found #{bwb_list[JsonConstants::LAW_LIST].length} expressions, of which #{new_expressions.length} new, #{metadata_changed.length} had metadata changed, #{disappeared.length} disappeared"

# noinspection RubyUnusedLocalVariable
  bwb_list = nil
# noinspection RubyUnusedLocalVariable
  rows_cloudant = nil
# noinspection RubyUnusedLocalVariable
  disappeared = nil


# Download new expressions and upload to CouchDB
#   GC.start
  process_changes(new_expressions, metadata_changed)
  # GC.start

# noinspection RubyUnusedLocalVariable
  new_expressions = nil
# noinspection RubyUnusedLocalVariable
  metadata_changed = nil
end

run_script