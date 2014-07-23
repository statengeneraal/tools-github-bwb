require_relative 'secret'
require 'rest-client'
module CouchHelper
  CLOUDANT_URI = URI.parse("http://#{Secret::CLOUDANT_NAME}.cloudant.com")

  # Flushes the given hashes to Cloudant
  def flush docs
    body = {:docs => docs}.to_json
    request = Net::HTTP::Post.new("/bwb/_bulk_docs")
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
end