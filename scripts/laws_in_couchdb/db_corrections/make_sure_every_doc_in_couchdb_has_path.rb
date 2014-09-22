# This script makes sure that docs that do not have have a 'path' field set, do get one

require_relative '../helpers/update_couch_helper'
require_relative '../helpers/bwb_list_parser'
require 'nokogiri'
include UpdateCouchHelper

# Get what paths are already used in our database, and which docs should have a path (re)set
rows_cloudant, prev_paths, wrong_paths = get_cloudant_entries
rows_cloudant.clear
# wrong_paths = JSON.parse(open("http://#{Secret::CLOUDANT_NAME}.cloudant.com/bwb/_design/RegelingInfo/_view/pathsThatShouldBeFixed").read.force_encoding('utf-8'))['rows']
puts "#{wrong_paths.length} wrong or missing paths and #{prev_paths.length} previously set paths"

# Corrects docs in batches
wrong_path_ids = []
paths = {}
wrong_paths.each do |row|
  wrong_path_ids << row['id']
  if wrong_path_ids.length >= 165
    paths.merge! correct_paths(wrong_path_ids, prev_paths)
    wrong_path_ids.clear
  end
end
if wrong_path_ids.length > 0
  paths.merge! correct_paths(wrong_path_ids, prev_paths)
  wrong_path_ids.clear
end

docs = Couch::CLOUDANT_CONNECTION.get_all_docs('bwb', {keys: paths.keys})
changed = []
docs.each do |doc|
  if paths[doc['_id']]
    doc['path'] = paths[doc['_id']]
    changed << doc
  end
end

# Write documents to database
bulk_write_to_bwb_database(changed)