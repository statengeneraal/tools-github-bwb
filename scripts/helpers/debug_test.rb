require 'json'
require_relative '../helpers/couch'
require_relative '../helpers/update_couch_helper'

include UpdateCouchHelper

body = File.open("C:/Users/Maarten/test.json").read
docs = Couch::CLOUDANT_CONNECTION.get_docs_for_view('bwb', 'RegelingInfo', 'docsWithHtml')
puts "#{docs.length} docs with html"

deletes=[]
docs.each do |doc|
  if doc['_id'].match /\/|%2F/
    puts doc['_id']
  else
    deletes << {'_id' => doc['_id'], '_rev' => doc['_rev'], '_deleted' => true}
  end
end

res = flush deletes, Couch::CLOUDANT_CONNECTION
puts res.body