require 'net/http'
require 'cgi'
require_relative 'secret'

module Couch
  class Server
    def initialize(host, port, options = nil)
      @host = host
      @port = port
      @options = options
    end

    def delete(uri)
      req=Net::HTTP::Delete.new(uri)
      req.basic_auth @options[:name], @options[:password]
      request(req)
    end

    def get(uri)
      req = Net::HTTP::Get.new(uri)
      req.basic_auth @options[:name], @options[:password]
      request(req)
    end

    def put(uri, json)
      req = Net::HTTP::Put.new(uri)
      req.basic_auth @options[:name], @options[:password]
      req["Content-Type"] = "text/plain;charset=utf-8"
      req.body = json
      request(req)
    end

    def post(uri, json)
      req = Net::HTTP::Post.new(uri)
      req.basic_auth @options[:name], @options[:password]
      req["Content-Type"] = "application/json;charset=UTF-8"
      req.body = json
      request(req)
    end

    def request(req)
      res = Net::HTTP.start(@host, @port) do |http|
        http.request(req)
      end
      unless res.kind_of?(Net::HTTPSuccess)
        puts "CouchDb responsed with error code #{res.code}"
        handle_error(req, res)
      end
      res
    end

    def get_rows_for_view(database, design_doc, view, query_params=nil)
      postfix = create_postfix(query_params)

      uri = URI::encode "/#{database}/_design/#{design_doc}/_view/#{view}#{postfix}"
      res = get(uri)
      JSON.parse(res.body.force_encoding('utf-8'))['rows']
    end

    # Returns an array of the full documents for given database, possibly filtered with given parameters. Note that the 'include_docs' parameter must be set to true for this.
    def get_all_docs(database, params)
      if params.include? 'include_docs'
        params['include_docs'] = true
      else
        params.merge!({:include_docs => true})
      end
      postfix = create_postfix(params)

      uri = URI::encode "/#{database}/_all_docs#{postfix}"
      res = get(uri)
      result = JSON.parse(res.body)
      docs = []
      result['rows'].each do |row|
        docs << row['doc']
      end
      docs
    end

    # Returns an array of the full documents for given view, possibly filtered with given parameters. Note that the 'include_docs' parameter must be set to true for this.
    def get_docs_for_view(db, design_doc, view, params={})
      params.merge!({:include_docs => true})
      rows = get_rows_for_view(db, design_doc, view, params)
      docs = []
      rows.each do |row|
        docs << row['doc']
      end
      docs
    end

    def bulk_delete(database, docs)
      json = {:docs => docs}.to_json
      post("/#{database}/_bulk_docs", json)
    end

    #Returns parsed doc from database
    def get_doc(database, id)
      res = get("/#{database}/#{CGI.escape(id)}")
      JSON.parse(res.body)
    end

    private
    def handle_error(req, res)
      e = RuntimeError.new("#{res.code}:#{res.message}\nMETHOD:#{req.method}\nURI:#{req.path}\n#{res.body}")
      raise e
    end

    def create_postfix(query_params, default='')
      if query_params
        params_a = []
        query_params.each do |key, value|
          params_a << "#{key}=#{value}"
        end
        postfix = "?#{params_a.join('&')}"
      else
        postfix = default
      end
      postfix
    end
  end

  CLOUDANT_CONNECTION = Server.new(
      "#{Secret::CLOUDANT_NAME}.cloudant.com", "80",
      {name:
           Secret::CLOUDANT_NAME,
       password:
           Secret::CLOUDANT_PASSWORD
      }
  )
end
