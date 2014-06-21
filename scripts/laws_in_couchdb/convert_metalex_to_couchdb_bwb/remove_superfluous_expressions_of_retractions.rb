####
# This code is deprecated
####
#
# require 'sparql/client'
# require 'json'
# require 'open-uri'
# require 'set'
# require_relative '../../helpers/update_couch_helper'
# require_relative '../../helpers/couch'
# include UpdateCouchHelper
#
# suspicious_rows = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'expressionOfRetraction')
# puts "Found #{suspicious_rows.length} suspicious looking docs"
#
# date_map = {}
# rev_map = {}
# id_map = {}
# suspicious_rows.each do |row|
#   bwb_id = row['key']
#   rev_map[row['id']] = row['value']['_rev']
#   verval_datum = row['value'][JsonConstants::EXPIRATION_DATE]
#   if date_map[bwb_id] and date_map[bwb_id] != verval_datum
#     raise "Inconsistent expiration dates for #{bwb_id}"
#   end
#
#   ids = id_map[bwb_id]
#   if ids
#     puts "IDS EXISTED FOR #{bwb_id}"
#   end
#   ids ||= []
#   ids << row['id']
#   id_map[bwb_id] = ids
#
#   date_map[bwb_id] = verval_datum
# end
#
# delete_keys = Set.new
# all_rows = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'all')
# all_rows.each do |row|
#   bwb_id = row['key']
#   regeling_info = row['value']
#   unless id_map[bwb_id] and id_map[bwb_id].include? row['id']
#     if id_map[bwb_id]
#       puts row['id']
#     end
#     date = date_map[bwb_id]
#     if date
#       if date == regeling_info[JsonConstants::EXPIRATION_DATE] or #We have a document containing the same vervalDatum
#           !(regeling_info['fromMetalex'] or regeling_info[JsonConstants::EXPIRATION_DATE]) # We have a document from BWBIdLit that does not have a vervalDatum: we do not believe MDS
#         id_map[bwb_id].each do |id|
#           delete_keys << id
#         end
#       else
#         puts "#{bwb_id}: #{date} is different from #{regeling_info[JsonConstants::EXPIRATION_DATE]}"
#       end
#     end
#   end
# end
#
# puts "We could delete #{delete_keys.length} docs"
# delete_docs=[]
# delete_keys.each do |id|
#   delete_docs << {:_id => id, :_rev => rev_map[id], :_deleted => true}
# end
# Couch::CLOUDANT_CONNECTION.bulk_delete('bwb', delete_docs)