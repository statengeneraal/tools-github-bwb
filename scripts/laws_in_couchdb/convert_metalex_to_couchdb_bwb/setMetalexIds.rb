# Script to link the docs converted from metalex in CouchDB to the Metalex Document Server, by settings the 'metalexId' field


require 'open-uri'
require 'json'
require 'sparql/client'
require_relative 'couch_helper'
require_relative 'secret'
include CouchHelper

FIELD_METALEX_ID = 'metalexId'
LIMIT = 70

SPARQL_ENDPOINT = URI('http://doc.metalex.eu:8000/sparql/')
SPARQL_CLIENT = SPARQL::Client.new(SPARQL_ENDPOINT)


def url_exists(uri)
  begin
    open(uri)
    # puts "opened #{uri}"
    true
  rescue
    # puts "Could not open #{uri}"
    false
  end
end

def set_metalex_id(docs)
  query = get_sparql_query docs
  ids = query_for_ids query

  changed = []
  docs.each do |doc|
    if ids[doc['bwbId']] and ids[doc['bwbId']][doc['datumLaatsteWijziging']]
      doc[FIELD_METALEX_ID] = ids[doc['bwbId']][doc['datumLaatsteWijziging']]
      changed << doc
    else
      if url_exists("http://doc.metalex.eu:8080/data/id/#{doc['bwbId']}/#{doc['datumLaatsteWijziging']}")
        doc[FIELD_METALEX_ID] = "http://doc.metalex.eu/id/#{doc['bwbId']}/#{doc['datumLaatsteWijziging']}"
        changed << doc
      else
        if url_exists("http://doc.metalex.eu:8080/data/id/#{doc['bwbId']}/nl/#{doc['datumLaatsteWijziging']}")
          doc[FIELD_METALEX_ID] = "http://doc.metalex.eu/id/#{doc['bwbId']}/nl/#{doc['datumLaatsteWijziging']}"
          changed << doc
        end
      end
    end
  end

  if changed.length>0
    puts "Updating #{changed.length} docs"
    bytesize = 0
    bulk = []
    changed.each do |doc|
      bulk << doc
      bytesize += doc['xml'].bytesize
      if bytesize >= 5*1024*1024 #5MB
        flush(bulk)
        bulk=[]
        bytesize=0
      end
    end
    if bulk.length>0
      flush(bulk)
    end
  end
end

def query_for_ids(q)
  response = Net::HTTP.new(SPARQL_ENDPOINT.host, SPARQL_ENDPOINT.port).start do |http|
    request = Net::HTTP::Post.new(SPARQL_ENDPOINT)
    request.set_form_data({:query => q})
    request['Accept']='application/sparql-results+xml'
    http.request(request)
  end
  ids = {}
  case response
    when Net::HTTPSuccess # Response code 2xx: success
      results = SPARQL_CLIENT.parse_response(response)
      number = 0
      results.each do |result|
        number += 1
        for_bwb_id = ids[result['bwb_id'].to_s]
        for_bwb_id ||= {}
        ids[result['bwb_id'].to_s] = for_bwb_id
        for_bwb_id[result['date'].to_s] = result['doc'].to_s
      end
      # puts "found #{number} results."
    else
      puts q
      raise 'Could not make sparql query'
  end
  ids
end

def get_sparql_query(docs)
  filters = docs.map do |doc|
    "(?bwb_id = \"#{doc['bwbId']}\"^^xsd:string && bif:datediff('day', ?date, \"#{doc['datumLaatsteWijziging']}\"^^xsd:dateTime) = 0)"
  end
  filter = filters.join '||'

  "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  SELECT distinct ?doc ?bwb_id ?date {
    ?event <http://www.metalex.eu/schema/1.0#date> ?date_uri.
    ?date_uri <http://www.w3.org/1999/02/22-rdf-syntax-ns#value> ?date .
    ?doc <http://www.metalex.eu/schema/1.0#resultOf> ?event .
    ?doc <http://doc.metalex.eu/bwb/ontology/bwb-id> ?bwb_id .
    FILTER(#{filter})
  }"
end

### Start script
offset = 0
loop do
  puts offset
  url = "http://#{Secret::CLOUDANT_NAME}.cloudant.com/bwb/_design/RegelingInfo/_view/metalex_id_not_set?limit=#{LIMIT}&skip=#{offset}&include_docs=true"
  results = JSON.parse(open(url).read)
  if results['rows'].length <= 0
    break
  else
    docs = []
    results['rows'].each do |row|
      docs << row['doc']
    end
    set_metalex_id(docs)
    offset += LIMIT
  end
end
