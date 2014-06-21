require_relative '../../helpers/update_couch_helper'
require_relative '../../helpers/couch'
require_relative '../../helpers/json_constants'
require_relative '../../helpers/bwb_list_parser'
require 'nokogiri'
require 'base64'
require 'open-uri'
require 'sparql/client'
include UpdateCouchHelper

doc = JSON.parse '{
    "_id": "BWBR0001827/2014-05-19",
    "datumLaatsteWijziging": "2014-05-19",
    "schema": "2014-01-05",
    "officieleTitel": "Wetboek van Burgerlijke Rechtsvordering",
    "bwbId": "BWBR0001827",
    "citeertitels": [
    {
        "titel": "Wetboek van Burgerlijke Rechtsvordering",
    "status": "officieel",
    "inwerkingtredingsDatum": "1838-10-01"
}
],
    "afkortingen": [
    "Rv"
],
    "regelingSoort": "wet",
"displayTitle": "Wetboek van Burgerlijke Rechtsvordering",
    "error": false,
"path": "wet/wetboek/van/burgerlijke/rechtsvordering/BWBR0001827",
    "_rev": "10-6b041a6f173870f005266f9cb8b8d0e3"
}'

# noinspection RubyStringKeysInHashInspection
doc['_attachments']={
    'data.xml' => {
        'content_type' => 'text/xml',
        'data' => Base64.encode64(File.read('data.xml'))
    }
}

Couch::CLOUDANT_CONNECTION.bulk_write_to_bwb_database([doc])