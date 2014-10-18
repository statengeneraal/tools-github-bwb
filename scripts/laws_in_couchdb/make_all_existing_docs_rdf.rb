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

