require 'open-uri'
require 'uri'
require 'erb'
require 'nokogiri'
require 'json'
require 'base64'
require 'erb'
require 'tilt'
require 'tilt/erb'
require_relative '../helpers/bwb_list_parser'
require_relative '../helpers/update_couch_helper'
require_relative '../helpers/id_adder'
require_relative '../helpers/secret'
require_relative '../helpers/json_constants'
include UpdateCouchHelper

# This script will sync our HTML laws against our CouchDB database. Run daily.
# Encoding.default_external = Encoding::UTF_8
# Encoding.default_internal = Encoding::UTF_8

BWB_TO_HTML = Nokogiri::XSLT(File.open('./xslt/bwb_to_html.xslt'))
EXTRACT_TOC = Nokogiri::XSLT(File.open('./xslt/bwb_extract_toc.xslt'))
EXTRACT_POLYMER_TOC = Nokogiri::XSLT(File.open('./xslt/bwb_extract_polymer_toc.xslt'))

def find_keys_to_update
  keys_to_update = []
  rows_xml, _, _ = get_cloudant_entries

  puts "Found #{rows_xml.length} XML docs"
  xml_expressions = {}
  rows_xml.each do |row|
    doc=row['value']
    last_modified = doc['datumLaatsteWijziging']
    if last_modified
      expressions = xml_expressions[doc['bwbId']] || []
      expressions << last_modified
      expressions.sort!
      xml_expressions[doc['bwbId']]=expressions
    else
      puts "WARNING: #{doc['bwbId']} did not have a last modified date"
    end
  end
  puts "Of which #{xml_expressions.length} BWBs"

  rows_lawly = Couch::LAWLY_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'addedToLawly')

  # Find new expressions
  rows_lawly.each do |row|
    lawly_date = row['value']['addedToLawly']
    bwbid = row['id']
    if (!lawly_date) or (lawly_date < xml_expressions[bwbid].last) or (row['value']['inlinedHtml'])
      keys_to_update << "#{bwbid}/#{xml_expressions[bwbid].last}"
      # puts "update"
    end
    xml_expressions[bwbid] = nil
  end

  xml_expressions.each do |key, value|
    unless value == nil # marked nil in previous loop
      keys_to_update << "#{key}/#{value.last}"
      # puts "new"
    end
  end
  keys_to_update
end

def get_display_kind(doc)
  display_kind = nil
  if                          doc[JsonConstants::KIND]
    case doc[JsonConstants::KIND]
      when 'AMvB',
          'AMvB-BES',
          'beleidsregel',
          'circulaire',
          'circulaire-BES',
          'KB',
          'rijksKB',
          'rijkswet',
          'reglement',
          'verdrag',
          'wet',
          'wet-BES',
          'beleidsregel-BES',
          'ministeriele-regeling',
          'ministeriele-regeling-archiefselectielijst',
          'ministeriele-regeling-BES'
        display_kind = doc[JsonConstants::KIND].gsub('inisteriele', 'inisteriële').gsub('-', ' ').capitalize
      when 'pbo',
          'zbo'
        display_kind = doc[JsonConstants::KIND]
      else
        display_kind = doc[JsonConstants::KIND]
    end
  end
  display_kind
end

# noinspection RubyStringKeysInHashInspection
def make_xml_doc_html(doc, old_rev)
  bwbid=doc['bwbId']
  xml = Nokogiri::XML doc['xml']

  id_adder = IdAdder.new xml, bwbid
  id_adder.add_ids '' #"#{bwbid}/#{doc['datumLaatsteWijziging']}"
  id_adder.set_hrefs

  # Remove _rev and xml attributes from document
  doc.tap do |hs|
    hs.delete('_rev')
    hs.delete('xml')
  end

  # Set _id, and if applicable _rev
  doc['_id'] = doc['bwbId']
  if old_rev
    doc['_rev'] = old_rev
  end

  doc['displayKind']=get_display_kind(doc)
  # Timestamp
  doc['addedToLawly'] = Time.now.strftime('%Y-%m-%d')

  #Convert xml to html
  is_empty = (id_adder.xml.root.name == 'error' or id_adder.xml.root.inner_text.gsub(/\s*/, '').length < 1)
  doc['is_empty'] = is_empty
  if is_empty
    doc['html'] = '<h1>Dit document kan niet weergegeven worden</h1>'
  else
    html = BWB_TO_HTML.transform(id_adder.xml)
    doc['html'] = html.to_s
  end

  # Create toc
  toc = EXTRACT_TOC.transform(id_adder.xml)
  if toc.root and toc.root.children.length > 0
    doc['toc'] = toc.to_s
  end
  # toc = EXTRACT_POLYMER_TOC.transform(id_adder.xml)
  # if toc.root and toc.root.children.length > 0
  #   doc['polymer_toc'] = toc.to_s
  # end


  m = doc['datumLaatsteWijziging'].match(/([0-9]+)-([0-9]+)-([0-9]+)/)
  date_last = nil
  if m
    date_last = "#{m[3]}-#{m[2]}-#{m[1]}"
  end

  template = Tilt.new('xslt/show.html.erb', :default_encoding => 'utf-8')
  full_html = template.render(Object.new, {:doc => doc, :date_last_modified => date_last})

  # Encoding.default_external = Encoding::UTF_8
  # Encoding.default_internal = Encoding::UTF_8

  # puts full_html

  attachments={
      'show.html' =>
          {
              'content_type' => 'text/html',
              'data' => Base64.encode64(full_html)
          },
      'inner.html' =>
          {
              'content_type' => 'text/html',
              'data' => Base64.encode64(doc['html'])
          },
  }
  if doc['toc']
    attachments['toc.html'] = {
        'content_type' => 'text/html',
        'data' => Base64.encode64(doc['toc'])
    }
  end
  doc['_attachments']=attachments
  doc
end

def update_html keys
  batch_size = 150

  batches = []
  batch = []
  keys.each do |key|
    batch << key
    if batch.length >= batch_size
      batches << batch
      batch = []
    end
  end
  if batch.length > 0
    batches << batch
  end
  puts "#{batches.length} batches"

  batches.each do |keyz|
    xml_docs = Couch::CLOUDANT_CONNECTION.get_all_docs('bwb', {:keys => keyz.to_json})
    bwbs=[]
    xml_map = {}
    xml_docs.each do |doc|
      bwbid=doc['bwbId']
      bwbs << bwbid
      if xml_map[bwbid]
        puts "WARNING: #{bwbid} already had a document set"
      end
      xml_map[bwbid] = doc
    end

    new_docs = Couch::LAWLY_CONNECTION.get_all_docs('bwb', {:keys => bwbs.to_json})

    write_docs = []
    # Update existing docs
    new_docs.each do |old_doc|
      if xml_map[old_doc['bwbId']]
        doc = xml_map[old_doc['bwbId']]
        doc = make_xml_doc_html(doc, old_doc['_rev'])
        xml_map[doc['bwbId']] = nil
        write_docs << doc
      else
        puts "WARNING: #{old_doc['bwbId']} was not in xml map."
      end
    end
    # Add new docs
    xml_map.each do |bwbid, doc|
      unless doc == nil
        puts "New doc: #{bwbid}"
        doc = make_xml_doc_html(doc, nil)
        write_docs << doc
      end
    end


    new_docs = []
    write_docs.each do |doc|
      new_doc = {}
      doc.each do |name, val|
        unless name == 'toc' or name == 'html'
          new_doc[name]=val
        end
      end
      new_docs << new_doc
    end
    bulk_write_to_database(new_docs, 15, Couch::LAWLY_CONNECTION, 'bwb')
  end
end

keys_to_update = find_keys_to_update
puts "#{keys_to_update.length} keys to update"
update_html(keys_to_update)