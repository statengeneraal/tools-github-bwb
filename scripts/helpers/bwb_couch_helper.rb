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
      unless cloudant_docs["#{bwb_id}:#{regeling_info[JsonConstants::DATE_LAST_MODIFIED]}"]
        puts "#{bwb_id}:#{regeling_info[JsonConstants::DATE_LAST_MODIFIED]} was new "
        new_expressions << regeling_info
      end
    end
    return new_expressions, metadata_changed, disappeared
  end

  #TODO remove this method
  def bulk_write_to_bwb_database(docs, max_post_size=15)
    bytesize = 0
    bulk=[]
    docs.each do |doc|
      bulk<<doc
      bytesize += doc['xml'].bytesize if doc['xml']
      if doc['_attachments']
        doc['_attachments'].each do |_, val|
          bytesize += val['data'].bytesize
        end
      end
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


  # Flushes the given hashes to CouchDB
  def flush(docs)
    body = {:docs => docs}.to_json
    request = Net::HTTP::Post.new('/bwb/_bulk_docs')
    request['Content-Type'] = 'application/json;charset=utf-8'
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
        raise 'Error posting documents'
    end
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