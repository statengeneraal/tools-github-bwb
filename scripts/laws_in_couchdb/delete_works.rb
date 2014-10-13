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

work_revs = Couch::CLOUDANT_CONNECTION.get_docs_for_view('bwb', 'RegelingInfo', 'workRevs')
puts "Found #{work_revs.length} works"
work_revs.each do |doc|
  if doc['_id'].match(/(\/|:|%2F)/)
    raise 'lol'
  end
  doc['_deleted'] = true
end
bulk_write_to_bwb_database(work_revs)