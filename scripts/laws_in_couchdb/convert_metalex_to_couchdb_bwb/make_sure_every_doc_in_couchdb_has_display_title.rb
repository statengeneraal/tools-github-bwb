# Script to find all converted documents in CouchDB that do not have 'displayTitle' set. Set them.

require 'sparql/client'
require 'json'
require 'open-uri'
require_relative '../../helpers/bwb_couch_helper'
require_relative '../../helpers/couch'
include BwbCouchHelper

SPARQL_ENDPOINT = URI('http://doc.metalex.eu:8000/sparql/')
SPARQL_CLIENT = SPARQL::Client.new(SPARQL_ENDPOINT)

def process_all_docs(titles, limit, offset)
  all_docs = Couch::CLOUDANT_CONNECTION.get_docs_for_view('bwb', 'RegelingInfo', 'all_from_metalex', {:skip => offset, :limit => limit})
  write_docs = []
  all_docs.each do |doc|
    unless doc['displayTitle'] or !titles[doc['metalexId']]
      doc['displayTitle'] = titles[doc['metalexId']]
      write_docs << doc
    end
  end
  bulk_write_to_bwb_database(write_docs)
  all_docs.length
end

def process_docs_by_metalex_id(titles, uris)
  if uris
    docs = Couch::CLOUDANT_CONNECTION.get_docs_for_view('bwb', 'RegelingInfo', 'byMetalexId', {:keys => uris.to_json})
  else
    docs = Couch::CLOUDANT_CONNECTION.get_docs_for_view('bwb', 'RegelingInfo', 'allFromMetalex')
  end
  docs.each do |doc|
    if doc['displayTitle']
      puts "WARNING: #{doc['_id']} already had a displayTitle"
    else
      doc['displayTitle'] = titles[doc['metalexId']]
    end
  end
  bulk_write_to_bwb_database(docs)
end

LIMIT = 150

def set_titles_by_metalex_id(titles)
  uris = []
  titles.each do |uri, _|
    uris << uri

    if uris.length >= 135
      process_docs_by_metalex_id(titles, uris)
      uris = []
    end
  end
  if uris.length > 0
    process_docs_by_metalex_id(titles, uris)
  end

  # offset = 0
  # loop do
  #   n_docs = process_all_docs(titles, LIMIT, offset)
  #   puts "handled #{n_docs} docs"
  #   offset += LIMIT
  #   if n_docs <= 0
  #     break
  #   end
  # end
end

def get_titles_for_uris(uris)
  query = get_sparql_query(uris)

  response = Net::HTTP.new(SPARQL_ENDPOINT.host, SPARQL_ENDPOINT.port).start do |http|
    request = Net::HTTP::Post.new(SPARQL_ENDPOINT)
    request.set_form_data({:query => query})
    request['Accept']='application/sparql-results+xml'
    http.request(request)
  end
  titles = {}
  case response
    when Net::HTTPSuccess # Response code 2xx: success
      results = SPARQL_CLIENT.parse_response(response)
      number = 0
      results.each do |result|
        number += 1
        titles[result['doc'].to_s] = result['title'].to_s
      end
    else
      puts query
      raise "Could not make sparql query"
  end

  titles
end

def get_sparql_query(uris)
  docs_filter = uris.map do |uri|
    "<#{uri}>"
  end
  filter = docs_filter.join ','
  "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  select distinct * {
      ?doc <http://purl.org/dc/terms/title> ?title .
      FILTER(?doc in (#{filter}))
  }"
end

def set_docs(bulk, titles)
  puts "Setting #{bulk.length} docs"
  docs = Couch::CLOUDANT_CONNECTION.get_all_docs('bwb', {keys: bulk.to_json}) # docs = Couch::CLOUDANT_CONNECTION.get_docs_for_view('bwb', 'RegelingInfo', 'noDisplayTitle', {keys: bulk.to_json})
  changed = []
  docs.each do |doc|
    if doc['displayTitle'] or !titles[doc[JsonConstants::BWB_ID]]
      puts "Could not update document #{doc['_id']}. #{titles[doc[JsonConstants::BWB_ID]]}: #{doc['displayTitle']}"
    else
      doc['displayTitle'] = titles[doc[JsonConstants::BWB_ID]]
      changed << doc
    end
  end
  if changed.length > 0
    flush(changed)
  end
end

def set_titles_by_couch_id(no_titles, titles)
  puts "about to set #{no_titles.length} docs..."
  bulk = []

  no_titles.each do |id|
    bulk << id
    if bulk.length >= 65
      set_docs(bulk, titles)
      bulk.clear
    end
  end
  if bulk.length > 0
    set_docs(bulk, titles)
  end
end

### Start script:
rows = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'doc_dates')
no_titles = []
rows.each do |row|
  if row['id'] == "BWBR0005324/2014-01-01"
    puts "BWBR0005324/2014-01-01"
  end
  no_titles << row['id']
end
puts "#{no_titles.length} docs without a title"

titles = {}
rows.each do |row|
  bwb_id = row['key']
  begin
    str_html = open("http://wetten.overheid.nl/#{bwb_id}/geldigheidsdatum_17-07-2014/informatie").read
    html= Nokogiri::HTML(str_html)
    el_title = html.css('#inhoud-titel h2')
    if el_title.length > 0
      titles[bwb_id] = el_title.first.text.force_encoding('utf-8')
    else
      puts "Could not find #{bwb_id} website"
    end
  rescue
    "could not open http://wetten.overheid.nl/#{bwb_id}/geldigheidsdatum_17-07-2014/informatie"
  end
  if titles.length % 10 == 0
    puts titles.length
  end
  # if titles.length >= 100
  #   break
  # end
end
set_titles_by_couch_id(no_titles, titles)

# no_title_metalex = {}
# rows.each do |row|
# metalex_id= row['value']
# if metalex_id
# no_title_metalex[metalex_id] = row['id']
# end
# end
# puts "Found #{no_title_metalex.length} documents we would like to query for the title"
#
# titles={}
# bulk = []
# no_title_metalex.each do |uri, _id|
#   bulk << uri
#   if bulk.length >= 3500
#     titles.merge!(get_titles_for_uris(bulk))
#     bulk.clear
#     puts "Found #{titles.length} titles"
#   end
# end
# if bulk.length > 0
#   titles.merge!(get_titles_for_uris(bulk))
#   puts "Found #{titles.length} titles"
# end
#
# set_titles_by_metalex_id(titles)

