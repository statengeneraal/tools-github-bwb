require_relative '../helpers/update_couch_helper'
require_relative '../helpers/couch'
require_relative '../helpers/json_constants'
require_relative '../helpers/bwb_list_parser'
require 'nokogiri'
require 'open-uri'
require 'sparql/client'
include UpdateCouchHelper

docs = Couch::CLOUDANT_CONNECTION.get_docs_for_view('bwb', 'RegelingInfo', 'wrongKinds')

changed = []
docs.each do |doc|
  case doc[JsonConstants::KIND]
    when "Ministeriële Regeling"
      doc[JsonConstants::KIND] = "ministeriele-regeling"
      changed << doc
    when "Regeling PBO/OLBB"
      doc[JsonConstants::KIND] = "pbo"
      changed << doc
    when "Regeling ZBO"
      doc[JsonConstants::KIND] = "zbo"
      changed << doc
    when "Wet"
      doc[JsonConstants::KIND] = "wet"
      changed << doc
    when "Circulaire"
      doc[JsonConstants::KIND] = "circulaire"
      changed << doc
    when "Beleidsregel"
      doc[JsonConstants::KIND] = "beleidsregel"
      changed << doc
    else
      puts "unknown kind #{doc[JsonConstants::KIND]}"
  end
end

Couch::CLOUDANT_CONNECTION.bulk_write_to_bwb_database changed