require 'sparql/client'
require 'json'
require 'open-uri'
require 'set'
require_relative '../helpers/bwb_couch_helper'
require_relative '../helpers/couch'
include BwbCouchHelper

def update_docs(key_doc_pair)
  docs = Couch::CLOUDANT_CONNECTION.get_all_docs('bwb', {:keys => key_doc_pair.keys.to_json})
  puts "updating #{docs.length} docs"
  changed = []
  docs.each do |doc|
    path = key_doc_pair[doc['_id']][JsonConstants::PATH]
    if path == doc[JsonConstants::PATH]
      puts "WARNING: #{doc['_id']} already had path #{path}"
    else
      # puts "#{doc[JsonConstants::PATH]} becomes #{path}"
      doc[JsonConstants::PATH]=path
      changed << doc
    end
  end

  BwbCouchHelper.bulk_write_to_bwb_database(changed)
end

index = JSON.parse open('C:\Users\Maarten\wetten-tools\wetten-tools\scripts_heroku\laws_in_couchdb\md\index.json').read.force_encoding('utf-8')
rows = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'all')

different_paths=[]
rows.each do |row|
  doc =row['value']
  path = doc[JsonConstants::PATH]
  index_path = index[JsonConstants::LAW_LIST][doc[JsonConstants::BWB_ID]][JsonConstants::PATH]
  unless index_path==path
    # puts "#{index_path} != #{path}"
    doc[JsonConstants::PATH] = index_path
    doc['_id'] = row['id']
    different_paths << doc
  end
end
puts "found #{different_paths.length} different paths"

different_docs={}
different_paths.each do |doc|
  different_docs[doc['_id']] = doc
  if different_docs.length >= 100
    update_docs(different_docs)
    different_docs.clear
  end
end
if different_docs.length > 0
  update_docs(different_docs)
end

