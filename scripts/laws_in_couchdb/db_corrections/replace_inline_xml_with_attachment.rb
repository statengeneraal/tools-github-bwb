require_relative '../../helpers/update_couch_helper'
require_relative '../../helpers/couch'
require_relative '../../helpers/bwb_list_parser'
require 'nokogiri'
require 'base64'
require 'open-uri'
require 'json'
include UpdateCouchHelper

# noinspection RubyStringKeysInHashInspection
def update_keys keys
  docs = Couch::CLOUDANT_CONNECTION.get_all_docs('bwb', {:keys => keys.to_json})
  updated_docs = []
  docs.each do |doc|
    xml = doc['xml']
    if xml
      doc['_attachments']={
          'data.xml' =>
              {
                  'content_type' => 'application/xml',
                  'data' => Base64.encode64(xml)
              }
      }
      doc['xml'] = nil
    end
    updated_docs << doc
  end
  # puts keys
  Couch::CLOUDANT_CONNECTION.bulk_write_to_bwb_database(updated_docs)
  puts "updated #{keys.length} docs"
end

#Start script:
rows = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'hasInlineXml')#, {:limit => 3})
puts "Found #{rows.length} documents with inlined XML"

batch = []
rows.each do |row|
  id = row['id']
  batch << id
  if batch.length > 150
    update_keys(batch)
    batch.clear
  end
end
if batch.length > 0
  update_keys(batch)
  batch.clear
end
