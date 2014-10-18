require_relative '../../helpers/update_couch_helper'
require_relative '../../helpers/couch'
require_relative '../../helpers/json_constants'
require_relative '../../helpers/bwb_list_parser'
require 'nokogiri'
require 'base64'
require 'open-uri'
include UpdateCouchHelper

docs_with_slash = Couch::CLOUDANT_CONNECTION.get_docs_for_view('bwb', 'RegelingInfo', 'all_expressions_with_slash', {'stale'=>'ok'})

docs_with_slash.each do |doc|
  doc['_deleted'] = true
end

docs_with_slash.each_slice(500) do |docz|
  Couch::CLOUDANT_CONNECTION.bulk_write_to_bwb_database(docz)
end