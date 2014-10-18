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

docs_with_slash = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'all_expressions_with_slash')
docs_with_colon = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'allExpressionsWithColon')


already_converted = {}
docs_with_colon.each do |row|
  #puts row['id'].gsub(':','/')
  already_converted[row['id'].gsub(':', '/')]=true
end
docs_with_colon.clear
puts "Already converted #{already_converted.length}"

to_convert = []
docs_with_slash.each do |d|
  unless already_converted[d['id']]
    to_convert << d['id']
  end
end
puts "Still #{to_convert.length} left"
