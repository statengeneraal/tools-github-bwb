require_relative 'secret'
require_relative 'json_constants'
require_relative 'couch'
require 'rest-client'
require 'cgi'
require 'open-uri'

module BwbCouchHelper
  CLOUDANT_URI = URI.parse("http://#{Secret::CLOUDANT_NAME}.cloudant.com")

  # Find gaps between database and BwbIdList.xml
  def get_new_expressions(rows_cloudant, bwb_list)
    new_expressions = []
    disappeared = []
    metadata_changed = {}
    # reappeared = []

    cloudant_docs={}
    # i = 0
    rows_cloudant.each do |row|
      # i += 1
      # if i % 15000 == 0
      # puts i
      # end
      id = row['id']
      cloudant_docs[id] = true

      evaluate_row_against_bwbidlist(bwb_list, metadata_changed, disappeared, row)
    end

    bwb_list[JsonConstants::LAW_LIST].each do |bwb_id, regeling_info|
      unless cloudant_docs["#{bwb_id}/#{regeling_info[JsonConstants::DATE_LAST_MODIFIED]}"]
        puts "#{bwb_id}/#{regeling_info[JsonConstants::DATE_LAST_MODIFIED]} was new "
        new_expressions << regeling_info
      end
    end
    return new_expressions, metadata_changed, disappeared
  end

  def bulk_write_to_bwb_database(docs, max_post_size=15)
    bytesize = 0
    bulk=[]
    docs.each do |doc|
      bulk<<doc
      bytesize += doc['xml'].bytesize if doc['xml']
      if bytesize >= max_post_size*1024*1024 # Flush every n MB
        flush(bulk)
        bulk.clear
        bytesize = 0
      end
    end
    if bulk.length > 0
      flush(bulk) # Flush remaining
    end
  end

  # Get metadata of documents currently in CouchDB, along with a mapping of BWBIDs to paths and a list of docs that have its path field set wrongly
  def get_cloudant_entries
    rows_cloudant = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'all')#all_non_metalex
    puts "Found #{rows_cloudant.length} expressions in our own database"

    paths = {}
    wrong_paths = []
    rows_cloudant.each do |row|
      bwb_id = row['key']
      if row['value']['path']
        if paths[bwb_id]
          unless paths[bwb_id] == row['value']['path']
            puts "WARNING: #{row['id']} had a different path than #{paths[bwb_id]} (namely #{row['value']['path']})"
            wrong_paths << row
          end
        else
          paths[bwb_id] = row['value']['path']
        end
      else
        # puts "WARNING: #{row['id']} did not have a path set"
        wrong_paths << row
      end
    end
    return rows_cloudant, paths, wrong_paths
  end

  # Download XML of given documents and upload the expressions to CouchDB
  def process_changes expressions, metadata_changed
    today = Date.today.strftime("%Y-%m-%d")
    bytesize = 0
    bulk = []
    expressions.each do |doc|
      xml = open("http://wetten.overheid.nl/xml.php?regelingID=#{doc[JsonConstants::BWB_ID]}", :read_timeout => 20*60).read
      doc['_id'] = "#{doc[JsonConstants::BWB_ID]}/#{doc[JsonConstants::DATE_LAST_MODIFIED]}"
      doc['couchDbModificationDate'] = today
      doc[JsonConstants::XML] = xml
      bulk << doc
      bytesize += xml.bytesize
      puts "#{doc['_id']} (Y)"
      if bytesize >= 70*1024*1024 #Flush after 70MB
        bulk_write_to_bwb_database(bulk)
        # puts "Flush #{bulk.size}"
        bulk.clear
        bytesize = 0
      end
    end

    # Set metadata
    keyz=[]
    metadata_changed.each do |id, diff|
      keyz << id

      if keyz.length >= 50
        set_new_metadata(bulk, bytesize, metadata_changed, keyz, today)
        keyz.clear
      end
    end
    if keyz.length > 0
      set_new_metadata(bulk, bytesize, metadata_changed, keyz, today)
    end

    #Flush remaining
    if bulk.size > 0
      bulk_write_to_bwb_database(bulk)
    end

    puts "Done."
  end

  def set_new_metadata(bulk, bytesize, metadata, keyz, today)
    docs = Couch::CLOUDANT_CONNECTION.get_all_docs('bwb', {keys: keyz})
    docs.each do |doc|
      doc['couchDbModificationDate'] = today
      metadata[doc['_id']].each do |key, value|
        if value == '_delete'
          doc[key] = nil
        else
          doc[key] = value
        end
      end

      bulk << doc
      bytesize += doc['xml'].bytesize
      puts "#{doc['_id']} (Y)"
      if bytesize >= 70*1024*1024 #Flush after 70MB
        bulk_write_to_bwb_database(bulk)
        # puts "Flush #{bulk.size}"
        bulk.clear
        bytesize = 0
      end
    end
  end

  # Flushes the given hashes to CouchDB
  def flush(docs)
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

  # Correct path fields for documents with given given
  def correct_paths(keys, paths)
    puts "Checking #{keys.length} docs"
    correct = {}
    rows = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'paths', {keys: keys})
    rows.each do |row|
      bwb_id = row['value']['bwbId']
      if paths[bwb_id]
        path = paths[bwb_id]
      else
        path = BwbListParser::create_path(row['value'])
        puts "Created #{path}"
        paths[bwb_id] = path
      end
      if row['value']['path'] != path
        correct[row['key']] = path
      end
    end

    puts "Corrected #{correct.length} extra"
    correct
  end


  private
  def evaluate_row_against_bwbidlist(bwb_list, metadata_changed, disappeared, row)
    id = row['id']
    bwb_id = row['key']
    doc = row['value']
    if bwb_list[JsonConstants::LAW_LIST][bwb_id]
      regeling_info = bwb_list[JsonConstants::LAW_LIST][bwb_id]

      date_last_modified=regeling_info[JsonConstants::DATE_LAST_MODIFIED]
      if date_last_modified == row['value'][JsonConstants::DATE_LAST_MODIFIED]
        #Check if metadata is the same, still
        regeling_info.each do |key, value|
          unless key == 'displayTitle' or key == 'path'
            unless is_same(doc[key], value)
              changes = metadata_changed[id]
              changes ||= {}
              changes[key] = value
              metadata_changed[id] = changes
              break
            end
          end
        end
      end
      metadata_changed
    else
      disappeared << id
    end
  end

  def is_same(metadata1, metadata2)
    if metadata1 == metadata2
      same = true
    else
      if metadata1.is_a? Array # Order doesn't matter
        same = (metadata1.uniq.sort == metadata2.uniq.sort)
      else
        same = false
      end
    end
    same
  end

end