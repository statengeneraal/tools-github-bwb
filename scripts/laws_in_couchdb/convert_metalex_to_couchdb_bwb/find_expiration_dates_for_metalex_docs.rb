# Script to find all converted documents in CouchDB that do not have 'vervalDatum' set, but *may* have one. Find them and set them.

require 'sparql/client'
require 'json'
require 'open-uri'
require_relative 'couch_helper'
                                  include CouchHelper

SPARQL_ENDPOINT = URI('http://doc.metalex.eu:8000/sparql/')
SPARQL_CLIENT = SPARQL::Client.new(SPARQL_ENDPOINT)

def process_docs(expiration_dates, uris)
  url = "http://wetten.cloudant.com/bwb/_design/RegelingInfo/_view/byMetalexId?include_docs=true&keys=#{CGI.escape(uris.to_json)}"
  puts url
  result = JSON.parse(open(url).read)
  docs = []
  result['rows'].each do |row|
    doc = row['doc']
    doc['vervalDatum'] = expiration_dates[doc['metalexId']]
    docs << doc
  end
  flush(docs)
end

def set_dates(expiration_dates)
  uris = []
  expiration_dates.each do |uri, _|
    uris << uri

    # Flush
    if uris.length >= 50
      process_docs(expiration_dates, uris)
      uris = []
    end
  end
  if uris.length > 0
    process_docs(expiration_dates, uris)
  end
end

def get_dates_for_uris(uris)
  query = get_sparql_query(uris)

  response = Net::HTTP.new(SPARQL_ENDPOINT.host, SPARQL_ENDPOINT.port).start do |http|
    request = Net::HTTP::Post.new(SPARQL_ENDPOINT)
    request.set_form_data({:query => query})
    request['Accept']='application/sparql-results+xml'
    http.request(request)
  end
# puts query
  expiration_dates = {}
  case response
    when Net::HTTPSuccess # Response code 2xx: success
      results = SPARQL_CLIENT.parse_response(response)
      number = 0
      results.each do |result|
        number += 1
        expiration_dates[result['doc'].to_s] = result['datetime'].to_s
      end
    else
      puts query
      raise "Could not make sparql query"
  end

  expiration_dates
end

def get_sparql_query(uris)
  docs_filter = uris.map do |uri|
    "<#{uri}>"
  end
  filter = docs_filter.join ','
  "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  select distinct * {
      ?event a <http://doc.metalex.eu/bwb/ontology/Intrekking_regeling> .
      ?event <http://www.metalex.eu/schema/1.0#date> ?date.
      ?date <http://www.w3.org/1999/02/22-rdf-syntax-ns#value> ?datetime .
      ?doc <http://www.metalex.eu/schema/1.0#resultOf> ?event .
      FILTER(?doc in (#{filter}))
  }"
end

### Start script:
response = JSON.parse(open('http://wetten.cloudant.com/bwb/_design/RegelingInfo/_view/metalexIdSetButNoExpirationDate').read)

no_expiration_date = {}
response['rows'].each do |row|
  no_expiration_date[row['value']] = row['key'] # no_expiration_date[metalexId] = _id
end

puts "Found #{no_expiration_date.length} documents we would like to query for the expiration date"

dates={}
bulk = []
no_expiration_date.each do |uri, _id|
  bulk << uri
  if bulk.length >= 50
    dates.merge!(get_dates_for_uris(bulk))
    bulk.clear
    puts "Found #{dates.length} dates"
  end
end
if bulk.length > 0
  dates.merge!(get_dates_for_uris(bulk))
  puts "Found #{dates.length} dates"
end

set_dates(dates)