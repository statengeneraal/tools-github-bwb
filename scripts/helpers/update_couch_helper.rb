require_relative 'secret'
require_relative 'json_constants'
require_relative 'couch'
require 'rest-client'
require 'cgi'
require 'json'
require 'base64'
require 'open-uri'

module UpdateCouchHelper
  CLOUDANT_URI = URI.parse("http://#{Secret::CLOUDANT_NAME}.cloudant.com")


  def bulk_write_to_bwb_database(docs, max_post_size=15, couch=Couch::CLOUDANT_CONNECTION)
    bulk_write_to_database(docs, max_post_size, couch, 'bwb')
  end

  def bulk_write_to_database(docs, max_post_size=15, couch=Couch::CLOUDANT_CONNECTION, db)
    bytesize = 0
    bulk=[]
    docs.each do |doc|
      bulk<<doc
      bytesize += get_byte_size(doc)
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

  def get_byte_size(doc)
    bytesize=0
    bytesize += doc['xml'].bytesize if doc['xml']
    bytesize += doc['html'].bytesize if doc['html']
    if doc['_attachments']
      doc['_attachments'].each do |_, val|
        if val['data']
          bytesize += val['data'].bytesize
        end
      end
    end
    bytesize += doc['toc'].bytesize if doc['toc']
    bytesize
  end

  # Get metadata of documents currently in CouchDB, along with a mapping of BWBIDs to paths and a list of docs that have its path field set wrongly
  def get_cloudant_entries
    rows_cloudant = Couch::CLOUDANT_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'allExpressions') #all_non_metalex
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


  def process_changed_metadata
    changes_keys=[]
    @metadata_changed.each do |id, _|
      changes_keys << id
    end
    if changes_keys.length > 0
      set_new_metadata(changes_keys)
    end
  end

  def set_new_metadata(changes_keys)
    bulk=[]
    docs = Couch::CLOUDANT_CONNECTION.get_all_docs('bwb', {keys: changes_keys})
    docs.each do |doc|
      doc['couchDbModificationDate'] = @today
      # Copy over attributes
      @metadata_changed[doc['_id']].each do |key, value|
        if value == '_delete'
          doc.delete(key)
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
  end

  private


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