require_relative '../../../helpers/update_couch_helper'
require_relative '../../../helpers/couch'
require_relative '../../../helpers/json_constants'
require_relative '../../../helpers/bwb_list_parser'
require 'nokogiri'
require 'base64'
require 'open-uri'
require 'sparql/client'

doc = JSON.parse(Couch::LAWLY_CONNECTION.get('/assets/ld').body)
# noinspection RubyStringKeysInHashInspection
doc['_attachments']['bwb_context.jsonld'] = {
    'content_type' => 'application/ld+json',
    'data' => Base64.encode64(File.read('bwb_context.jsonld'))
}

Couch::LAWLY_CONNECTION.flush_bulk('assets',[doc])