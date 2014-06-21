####
# This code is deprecated
####
# # This script tries to give docs that do not have a 'regelingSoort' field set a 'regelingSoort'
#
# require_relative '../helpers/update_couch_helper'
# require_relative '../helpers/couch'
# require_relative '../helpers/bwb_list_parser'
# require 'nokogiri'
# require 'open-uri'
# require 'sparql/client'
# include UpdateCouchHelper
#
# SPARQL_ENDPOINT = URI('http://doc.metalex.eu:8000/sparql/')
# SPARQL_CLIENT = SPARQL::Client.new(SPARQL_ENDPOINT)
#
# wrongs = JSON.parse(open("http://#{Secret::CLOUDANT_NAME}.cloudant.com/bwb/_design/RegelingInfo/_view/noRegelingSoort").read.force_encoding('utf-8'))['rows']
# puts "#{wrongs.length} missing fields"
#
# def get_kinds(uris)
#   query = get_sparql_query(uris)
#   response = Net::HTTP.new(SPARQL_ENDPOINT.host, SPARQL_ENDPOINT.port).start do |http|
#     request = Net::HTTP::Post.new(SPARQL_ENDPOINT)
#     request.set_form_data({:query => query})
#     request['Accept']='application/sparql-results+xml'
#     http.request(request)
#   end
#   expiration_dates = {}
#   case response
#     when Net::HTTPSuccess # Response code 2xx: success
#       results = SPARQL_CLIENT.parse_response(response)
#       number = 0
#       results.each do |result|
#         number += 1
#         expiration_dates[result['doc'].to_s] = result['kind'].to_s
#       end
#     else
#       puts query
#       raise "Could not make sparql query"
#   end
#
#   expiration_dates
# end
#
# def get_sparql_query(uris)
#   docs_filter = uris.map do |uri|
#     "<#{uri}>"
#   end
#   filter = docs_filter.join ','
#   "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
#   PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
#   select distinct * {
#       ?doc <http://doc.metalex.eu/bwb/ontology/soort> ?kind .
#       FILTER(?doc in (#{filter}))
#   }"
# end
#
# def find_regeling_soort_in_name keys
#   docs = Couch::CLOUDANT_CONNECTION.get_all_docs('bwb', {:keys => keys.to_json})
#   kinds = {}
#   docs.each do |doc|
#     if doc[JsonConstants::BWB_ID].start_with? 'BWBV' # BWBV are always treaties
#       kinds[JsonConstants::BWB_ID] = 'verdrag'
#     else
#       # Scrape answer from Maxius website
#       slug = doc[JsonConstants::DISPLAY_TITLE].downcase.to_s.gsub(/[ëéè]/,'e').gsub(/[^A-Za-z0-9\- ]/, '').gsub(/[^A-Za-z0-9-]/, '-').gsub(/-$/,'')
#       url = "http://maxius.nl/wetsgeschiedenis/#{slug}"
#       begin
#         str_html = open(url).read
#         html = Nokogiri::HTML(str_html)
#         soorts = html.xpath("//div[text()='Soort regeling:']")
#         if soorts.length > 0
#           soort_node = soorts.first.next_element
#           soort = soort_node.text
#           if soort.length > 0
#             puts "#{doc[JsonConstants::BWB_ID]}: #{soort}"
#             kinds[doc[JsonConstants::BWB_ID]] = soort
#           end
#         end
#       rescue
#         puts "#{doc[JsonConstants::BWB_ID]}: Could not open #{url}"
#       end
#     end
#   end
#   changed=[]
#   docs.each do |doc|
#     if kinds[doc[JsonConstants::BWB_ID]]
#       if doc[JsonConstants::KIND]
#         puts "WARNING: #{doc['_id']} already had a kind set"
#       else
#         doc[JsonConstants::KIND]= kinds[doc[JsonConstants::BWB_ID]]
#         changed << doc
#       end
#     end
#   end
#
#   bulk_write_to_bwb_database(changed)
# end
#
# def find_regeling_soort_in_other_docs(keys, kinds)
#   puts "correcting #{keys.length} docs"
#
#   work_with_keys = []
#   keys.each do |key, _|
#     bwb_id = /([^\/]*)\/.*/.match(key)[1]
#     if kinds[bwb_id]
#       work_with_keys << key
#     end
#   end
#
#   docs = Couch::CLOUDANT_CONNECTION.get_all_docs('bwb', {:keys => work_with_keys.to_json})
#   puts "We can fix #{docs.length} documents"
#
#   # set regeling soort
#   docs.each do |doc|
#     if doc['regelingSoort']
#       puts "WARNING: #{doc['_id']} already had a regelingSoort set"
#       unless doc['regelingSoort'] == kinds[doc['bwbId']]
#         raise "#{doc['_id']} already had a regelingSoort set that was different from #{kinds[doc['bwbId']]}"
#       end
#     end
#     doc['regelingSoort'] = kinds[doc['bwbId']]
#   end
#
#   # Write documents to database
#   bulk_write_to_bwb_database(docs, 15)
# end
#
# def find_regeling_soort_in_mds(keys)
#   puts "correcting #{keys.length} docs"
#   str_json = open("http://#{Secret::CLOUDANT_NAME}.cloudant.com/bwb/_all_docs?include_docs=true&keys=#{CGI.escape(keys.to_json)}").read
#   result = JSON.parse(str_json)
#   docs = []
#   puts "parsed #{result['rows'].length} docs"
#   uris = []
#   result['rows'].each do |row|
#     dowc = row['doc']
#     uris << dowc['metalexId'] if dowc['metalexId']
#   end
#   uri_to_kind = get_kinds(uris)
#   result['rows'].each do |row|
#     doc = row['doc']
#     if doc['metalexId'] and uri_to_kind[doc['metalexId']]
#       doc['regelingSoort'] = uri_to_kind[doc['metalexId']]
#       docs << doc
#     end
#   end
#
#   puts "Writing #{docs.length} docs to Cloudant"
#   couch = Couch::CLOUDANT_CONNECTION
#
#   # Write documents to database
#   bytesize = 0
#   bulk=[]
#   docs.each do |doc|
#     bulk<<doc
#     bytesize += doc['xml'].bytesize if doc['xml']
#     if doc['_attachments']
#       doc['_attachments'].each do |_,val|
#         bytesize += val['data'].bytesize if val['data']
#       end
#     end
#     if bytesize >= 15*1024*1024 # Flush every 15 MB
#       flush(bulk, couch)
#       bulk.clear
#       bytesize = 0
#     end
#   end
#   if bulk.length > 0
#     flush(bulk, couch) # Flush remaining
#   end
# end
#
# # str_json = open("http://#{Secret::CLOUDANT_NAME}.cloudant.com/bwb/_design/RegelingInfo/_view/all_non_metalex?include_docs=false").read
# #
# # result = JSON.parse(str_json)
# #
# # puts "parsed #{result['rows'].length} docs"
# # kinds = {}
# # result['rows'].each do |row|
# #   metadata=row['value']
# #   kind = metadata['regelingSoort']
# #   bwb_id = row['key']
# #   if kind
# #     if kinds[bwb_id] and kind != kinds[bwb_id]
# #       puts "WARNING: #{row['value']} is both a #{kinds[bwb_id]} and a #{kind}. Leaving this to manual editing."
# #       kinds[bwb_id]=nil
# #     else
# #       kinds[bwb_id] = kind
# #     end
# #   end
# # end
# # puts "Found #{kinds.length} BWBs with a kind"
#
# # Corrects docs in batches
# wrongs_ids = []
# wrongs.each do |row|
#   wrongs_ids << row['id']
#   if wrongs_ids.length >= 150
#     # find_regeling_soort_in_other_docs(wrongs_ids, kinds)
#     # find_regeling_soort_in_mds(wrongs_ids)
#     wrongs_ids.clear
#   end
# end
# if wrongs_ids.length > 0
#   # find_regeling_soort_in_other_docs(wrongs_ids, kinds)
#   # find_regeling_soort_in_mds(wrongs_ids)
#   find_regeling_soort_in_name(wrongs_ids)
#   wrongs_ids.clear
# end