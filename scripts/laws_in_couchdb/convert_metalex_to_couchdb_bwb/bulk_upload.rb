# Script to upload all files in '/converted' folder to CochDB

require 'json'
require 'open-uri'
require 'net/http'
require_relative 'secret'

CLOUDANT_URI = URI.parse("http://#{Secret::CLOUDANT_NAME}.cloudant.com")

# Flushes the given JSON objects to Cloudant
def flush non_metalex, files
  docs = []
  files.each do |path|
    # puts "parsing #{path}"
    doc = JSON.parse File.open(path).read.force_encoding('utf-8')
    doc['_id'] = "#{doc['bwbId']}/#{doc['datumLaatsteWijziging']}"
    if non_metalex[doc['bwbId']] and (non_metalex[doc['bwbId']]['datumLaatsteWijziging'] <= doc['datumLaatsteWijziging'])
      # We have a non-converted expression from before this one... So it doesn't make sense to have newer expressions converted from Metalex
      puts "WARNING: #{doc['_id']} was later than our source from #{non_metalex[doc['bwbId']]['datumLaatsteWijziging']}. Ignoring document."
    else
      # Add doc to queue
      doc['fromMetalex'] = true
      # Add XML string
      str_xml = File.open("converted/#{doc['bwbId']}%2F#{doc['datumLaatsteWijziging']}.xml").read.force_encoding('utf-8').strip
      if str_xml.length > 0
        doc['xml'] = str_xml
      else
        doc['xml'] = nil
      end
      docs << doc
    end
  end

  body = {:docs => docs}.to_json

  request = Net::HTTP::Post.new("/bwb/_bulk_docs")
# request["Content-Type"] = "application/json;charset=UTF-8"
  request["Content-Type"] = "application/json;charset=utf-8"
# noinspection RubyStringKeysInHashInspection
  request.basic_auth(Secret::CLOUDANT_NAME, Secret::CLOUDANT_PASSWORD)
  request.body = body
  response = Net::HTTP.start(CLOUDANT_URI.host, CLOUDANT_URI.port) do |http|
    http.request(request)
  end
  case response
    when Net::HTTPSuccess # Response code 2xx: success
      puts "Flushed #{docs.length} files"
    else
      puts body
      puts response.code
      puts response.body
      raise "Error posting documents"
  end
end

def get_docs_already_in_cloudant
  already_in_cloudant={}
  str = open("http://#{Secret::CLOUDANT_NAME}.cloudant.com/bwb/_design/RegelingInfo/_view/all_from_metalex").read
  JSON.parse(str.force_encoding('utf-8'))['rows'].each do |row|
    already_in_cloudant[row['id']] = true
  end
  already_in_cloudant
end

def get_first_non_metalex_docs
  docs = {}
  str_json = open('http://wetten.cloudant.com/bwb/_design/RegelingInfo/_view/all_non_metalex').read
  result = JSON.parse(str_json.force_encoding('utf-8'))
  result['rows'].each do |row|
    doc = row['value']
    if docs[doc['bwbId']]
      if docs[doc['bwbId']]['datumLaatsteWijziging'] > doc['datumLaatsteWijziging']
        docs[doc['bwbId']] = doc
      end
    else
      docs[doc['bwbId']] = doc
    end
  end
  puts "#{docs.length} non-metalex firsts"
  docs
end

# Get all json files from the 'converted' folder
json_files = Dir['converted/*.json']
puts "#{json_files.length} files found"

already_in_cloudant = get_docs_already_in_cloudant
puts "Found #{already_in_cloudant.length} docs already in Cloudant."

paths = []
size = 0
ignored = 0
non_metalex_in_cloudant = get_first_non_metalex_docs

json_files.each do |path|
  /converted\/(.*)%2F(.*)\.json/ =~ path
  bwbid = $1
  date = $2
  if already_in_cloudant["#{bwbid}/#{date}"] # Reconstruct id with non-encoded slash
    ignored += 1
  else
    if ignored > 0
      puts "Ignored #{ignored} files already in Cloudant."
    end
    ignored = 0
    xml_path = "converted/#{bwbid}%2F#{date}.xml"
    size += File.size(xml_path) # in bytes
    # If aggregated size exceeds limit, flush our array
    if size > 25*1024*1024
      puts "Size reached #{size/1024.0/1024.0} MB"
      # begin
      flush(non_metalex_in_cloudant, paths)
      # rescue
      #   puts " Could not upload #{bulk.length} items"
      # ensure
      paths.clear
      size = File.size(path)
      # end
    end
    paths << path
  end
end
flush(non_metalex_in_cloudant, paths)