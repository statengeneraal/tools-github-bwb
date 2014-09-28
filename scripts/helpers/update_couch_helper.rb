require_relative 'secret'
require_relative 'json_constants'
require_relative 'couch'
require 'rest-client'
require 'cgi'
require 'json'
require 'open-uri'

module UpdateCouchHelper
  INFINITE_LOADING_DOCUMENTS=['BWBR0004581', 'BWBR0008587', 'BWBR0018715', 'BWBR0022061', 'BWBR0025132', 'BWBR0032324', 'BWBR0008023']

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

  def bulk_write_to_bwb_database(docs, max_post_size=15, couch=Couch::CLOUDANT_CONNECTION)
    bulk_write_to_database(docs, max_post_size, couch, 'bwb')
  end

  def bulk_write_to_database(docs, max_post_size=15, couch=Couch::CLOUDANT_CONNECTION, db)
    bytesize = 0
    bulk=[]
    docs.each do |doc|
      bulk<<doc
      bytesize += doc['xml'].bytesize if doc['xml']
      bytesize += doc['html'].bytesize if doc['html']
      if doc['_attachments']
        doc['_attachments'].each do |_, val|
          bytesize += val['data'].bytesize
        end
      end
      bytesize += doc['toc'].bytesize if doc['toc']
      if bytesize >= max_post_size*1024*1024 # Flush every n MB
        res = flush(bulk, couch, db)
        if res.code >= '200' and res.code < '300'
          puts "Flushed #{bulk.length}"
          resp = JSON.parse res.body
          error_count=0
          resp.each do |res_doc|
            if res_doc['error']
              error_count += 1
              puts "#{res_doc['id']}: #{res_doc['error']}"
              puts "#{res_doc['reason']}"
            end
          end
          if error_count>0
            puts "#{error_count} errors"
          end
        end
        bulk.clear
        bytesize = 0
      end
    end
    if bulk.length > 0
      res = flush(bulk, couch, db) # Flush remaining
      if res.code >= '200' and res.code < '300'
        puts "Flushed #{bulk.length}"
        resp = JSON.parse res.body
        resp.each do |doc|
          error_count = 0
          if doc['error']
            error_count += 1
            puts "#{doc['id']}: #{doc['error']}"
            puts doc['reason']
          end
          if error_count > 0
            puts "#{error_count} errors"
          end
        end
      end
    end
  end

  # Get metadata of documents currently in CouchDB, along with a mapping of BWBIDs to paths and a list of docs that have its path field set wrongly
  def get_cloudant_entries
    rows_cloudant = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'all') #all_non_metalex
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
  def process_changes(expressions, changed_metadata)
    today = Date.today.strftime('%Y-%m-%d')
    add_new_expressions(expressions, today)
    process_changed_metadata(changed_metadata, today)
    puts 'Done.'
  end

  # noinspection RubyStringKeysInHashInspection
  def add_new_expressions(expressions, today)
    bytesize = 0
    bulk = []

    i=0
    expressions.each_with_index do |doc, ind|
      expressions[ind] = nil # Pre-emptively save some memory

      url = "http://wetten.overheid.nl/xml.php?regelingID=#{doc[JsonConstants::BWB_ID]}"
      # Download (or skip) this document
      if INFINITE_LOADING_DOCUMENTS.include? doc[JsonConstants::BWB_ID]
        puts "Skipping #{doc[JsonConstants::BWB_ID]} because it took too long to download before (at #{url})"
      else
        begin
          xml = open(url, :read_timeout => 20*60).read
          doc['_id'] = "#{doc[JsonConstants::BWB_ID]}/#{doc[JsonConstants::DATE_LAST_MODIFIED]}"
          doc['couchDbModificationDate'] = today
          doc['addedToCouchDb'] = today
          doc['_attachments'] = {
              'data.xml' => {
                  'content_type' => 'text/xml',
                  'data' => Base64.encode64(xml)
              }
          }
          bulk << doc
          bytesize += xml.bytesize
          i+=1
          if i > 0 and i % 10 == 0
            puts "Downloaded #{i} new expressions."
          end
        rescue
          puts "Could not download #{url}"
        end
      end

      max_bulk_size = 15
      if ind < (expressions.length/2)
        # First half have a max bulk size of 7
        max_bulk_size = 7
      end
      if bytesize >= max_bulk_size*1024*1024 or bulk.size >= 20 # Flush after some MB or 20 items
        bulk_write_to_bwb_database(bulk)
        # puts "Flush #{bulk.size}"
        bulk.clear
        bytesize = 0
      end
    end

    #Flush remaining
    if bulk.size > 0
      bulk_write_to_bwb_database(bulk)
      bulk.clear
    end
  end

  def process_changed_metadata(metadata_changed, today)
    keyz=[]
    metadata_changed.each do |id, _|
      keyz << id
    end
    if keyz.length > 0
      set_new_metadata(metadata_changed, keyz, today)
    end
  end

  def set_new_metadata(new_metadata, keyz, today)
    bulk=[]
    docs = Couch::CLOUDANT_CONNECTION.get_all_docs('bwb', {keys: keyz})
    docs.each do |doc|
      doc['couchDbModificationDate'] = today
      # Copy over attributes
      new_metadata[doc['_id']].each do |key, value|
        if value == '_delete'
          doc[key] = nil
        else
          doc[key] = value
        end
      end

      bulk << doc
    end
    bulk_write_to_bwb_database(bulk)
  end

  # Flushes the given hashes to bwb database in CouchDB
  def flush(docs, connection, db='bwb')
    connection.flush_bulk(db, docs)

    # request = Net::HTTP::Post.new('/bwb/_bulk_docs')
    # request['Content-Type'] = 'application/json;charset=utf-8'
    # # noinspection RubyStringKeysInHashInspection
    # request.basic_auth(username, password)
    # request.body = body
    # response = Net::HTTP.start(CLOUDANT_URI.host, CLOUDANT_URI.port) do |http|
    #   http.request(request)
    # end
    # case response
    #   when Net::HTTPSuccess # Response code 2xx: success
    #     puts "Flushed #{docs.length} files"
    #   else
    #     puts body
    #     puts response.code
    #     puts response.body
    #     raise 'Error posting documents'
    # end
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
        m1 = metadata1.uniq
        m1 = m1.sort_by do |array_item|
          if array_item.is_a? Comparable
            array_item
          else
            array_item.hash
          end
        end

        m2 = metadata2.uniq
        m2 = m2.sort_by do |array_item|
          if array_item.is_a? Comparable
            array_item
          else
            array_item.hash
          end
        end

        same = (m1 == m2)
      else
        same = false
      end
    end
    same
  end

end