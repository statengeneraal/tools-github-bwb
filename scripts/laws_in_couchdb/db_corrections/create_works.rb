require_relative '../../helpers/update_couch_helper'
require_relative '../../helpers/couch'
require_relative '../../helpers/json_constants'
require_relative '../../helpers/bwb_list_parser'
require 'nokogiri'
require 'base64'
require 'open-uri'
include UpdateCouchHelper

expressions = Couch::CLOUDANT_CONNECTION.get_docs_for_view('bwb', 'RegelingInfo', 'allExpressionsWithColon')

expressions.each do |expression|

end