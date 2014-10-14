require_relative '../helpers/update_couch_helper'
require_relative '../helpers/couch'
require_relative '../helpers/json_constants'
require_relative '../helpers/bwb_list_parser'
require_relative '../helpers/couch_updater'
require 'nokogiri'
require 'base64'
require 'gc'
require 'open-uri'
require 'sparql/client'
include UpdateCouchHelper

docs_without_context = Couch::CLOUDANT_CONNECTION.get_docs_for_view('bwb', 'RegelingInfo', 'all_expressions_with_slash')
docs_with_colon = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'allExpressionsWithColon')

already_converted = {}
docs_with_colon.each do |row|
  #puts row['id'].gsub(':','/')
  already_converted[row['id'].gsub(':', '/')]=true
end
docs_with_colon.clear
puts "Already converted #{already_converted.length}"

puts "Found #{docs_without_context.length} docs without context"

#61895 ; 61876
# 13 new on 14-10

bytesize = 0
bulk=[]

updater = CouchUpdater.new
docs_without_context.each do |_doc|
  if already_converted[_doc['_id']]
    #puts "Skipping already converted #{_doc['_id']}"
    _doc.clear
  end
end
# realization_map = {}
# docs_without_context.each_slice(250) do |lol|
#   new_ralizations = updater.get_realization_map(lol)
#   new_ralizations.each do |bwbid, rz|
#     exmap = realization_map[bwbid]||[]
#     realization_map[bwbid] = exmap.push(rz).flatten
#   end
# end
#
# File.open('realizations.json', 'w+') do |f|
#   f.puts relation_map.to_json
# end
#
# puts "#{realization_map.length} works"
# latest_expression_map = {}
# realization_map.each do |key, val|
#   latest_expression_map[key] = val.sort.last
# end

docs_without_context.each do |_doc|
  if _doc.length>0
    doc = _doc.clone
    _doc.clear
    # _doc['_deleted']=true

    unless doc[JsonConstants::DATE_LAST_MODIFIED]
      # raise 'lol'
    end
    str_xml = Couch::CLOUDANT_CONNECTION.get_attachment_str('bwb', doc['_id'], 'data.xml')
    if str_xml
      puts "#{doc['_id']} becomes #{doc['_id'].sub('/', ':')}"
      doc['_id']=doc['_id'].sub('/', ':')

      doc.delete '_rev'
      bytesize += updater.setup_doc_as_new_expression(doc, str_xml)
      bulk << doc
      # bulk << _doc
      # if doc['_id'] == latest_expression_map[doc['bwbId']]
      # work = doc.clone
      # work.delete '_rev'
      # bytesize += updater.convert_new_expression_to_work(work, realization_map)
      # bulk<<work
      # end

      # Flush if bulk too big
      if bytesize >= 10*1024*1024
        bulk_write_to_bwb_database(bulk)
        # puts "Flushed #{bulk.length}"
        bulk.each do |doc_|
          doc_.clear
        end
        bulk.clear
        GC.start
        bytesize = 0
      end
    else
      puts "ERROR: COULD NOT READ ATTACHMENT FOR #{doc['_id']}"
    end
  end
end
if bulk.length>0
  Couch::CLOUDANT_CONNECTION.flush_bulk('bwb', bulk)
  bulk.clear
end