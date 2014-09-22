require 'open-uri'
require 'uri'
require 'nokogiri'
require 'zip'
require 'json'
require_relative '../helpers/bwb_list_parser'
require_relative '../helpers/bwb_couch_helper'
include BwbCouchHelper

# This script will sync our CouchDB database against the government BWBIdList. Run daily.

# TODO implement as Clockwork app; Heroku scheduler runs *best-effort*; not guaranteed.

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

# Get what's in our database
rows_cloudant, prev_paths, _ = get_cloudant_entries

# Parse government XML
sax_handler = BwbListParser.new(prev_paths)
parser = Nokogiri::XML::SAX::Parser.new(sax_handler)
puts 'Parsing XML...'
parser.parse xml_source
puts 'XML parsed.'

bwb_list = sax_handler.bwb_list

# Find new expressions
new_expressions, metadata_changed, disappeared = get_new_expressions(rows_cloudant, bwb_list)
puts "Found #{bwb_list[JsonConstants::LAW_LIST].length} expressions, of which #{new_expressions.length} new, #{metadata_changed.length} had metadata changed, #{disappeared.length} disappeared"

# Download new expressions and upload to CouchDB
process_changes(new_expressions, metadata_changed)