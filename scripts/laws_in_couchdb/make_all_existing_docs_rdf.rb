require_relative '../helpers/update_couch_helper'
require_relative '../helpers/couch'
require_relative '../helpers/json_constants'
require_relative '../helpers/bwb_list_parser'
require_relative '../helpers/couch_updater'
require 'nokogiri'
require 'base64'
require 'open-uri'
require 'sparql/client'
include UpdateCouchHelper

docs_without_context = Couch::CLOUDANT_CONNECTION.get_docs_for_view('bwb', 'RegelingInfo', 'docWithoutContext')

puts "Found #{docs_without_context.length} docs without context"

bytesize = 0
bulk=[]

updater = CouchUpdater.new
realization_map = {}
docs_without_context.each_slice(250) do |lol|
  new_ralizations = updater.get_realization_map(lol)
  new_ralizations.each do |bwbid, rz|
    exmap = realization_map[bwbid]||[]
    realization_map[bwbid] = exmap.push(rz).flatten
  end
end
puts "#{realization_map.length} works"
latest_expression_map = {}
realization_map.each do |key, val|
  latest_expression_map[key] = val.sort.last
end

docs_without_context.each do |_doc|
  doc = _doc.clone
  _doc.clear
  str_xml = Couch::CLOUDANT_CONNECTION.get_attachment_str('bwb', doc['_id'], 'data.xml')
  if str_xml
    bytesize += updater.setup_doc_as_new_expression(doc, str_xml)
    bulk<<doc
    if doc['_id'] == latest_expression_map[doc['bwbId']]
      work = doc.clone
      work.delete '_rev'
      bytesize += updater.convert_new_expression_to_work(work, realization_map)
      bulk<<work
    end

    # Flush if bulk too big
    if bytesize >= 20*1024*1024
      bulk_write_to_bwb_database(bulk)
      puts "Flushed #{bulk.length}"
      bulk.clear
      bytesize = 0
    end
  else
    puts "ERROR: COULD NOT READ ATTACHMENT FOR #{doc['_id']}"
  end
end
if bulk.length>0
  Couch::CLOUDANT_CONNECTION.flush_bulk('bwb', bulk)
  bulk.clear
  bytesize = 0
end