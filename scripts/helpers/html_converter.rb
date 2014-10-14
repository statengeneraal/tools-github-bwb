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
EXTRACT_TOC_XML = Nokogiri::XSLT(File.open('./xslt/bwb_extract_toc_xml.xslt'))
EXTRACT_POLYMER_TOC = Nokogiri::XSLT(File.open('./xslt/bwb_extract_polymer_toc.xslt'))
TEMPLATE = Tilt.new('./erb/show.html.erb', :default_encoding => 'utf-8')
WORK_TEMPLATE = Tilt.new('./erb/show_work.html.erb', :default_encoding => 'utf-8')

class HtmlConverter
  attr_reader :full_html
  attr_reader :inner_html
  attr_reader :toc
  attr_reader :toc_xml
  attr_reader :xml
  attr_reader :id_adder
  attr_reader :is_empty

  def initialize(xml, doc)
    # Add ids to xml
    @xml=xml
    bwbid=doc[JsonConstants::BWB_ID]
    title = doc[JsonConstants::DISPLAY_TITLE]
    @id_adder = IdAdder.new xml, bwbid
    @id_adder.add_ids '' #"#{bwbid}:#{doc['datumLaatsteWijziging']}"
    @id_adder.set_references


    #Convert xml to html
    make_html

    # Create toc
    @toc = EXTRACT_TOC.transform(xml)
    @toc_xml = EXTRACT_TOC_XML.transform(xml)

    last_modified_match = doc['datumLaatsteWijziging'].match(/([0-9]+)-([0-9]+)-([0-9]+)/)
    human_readable_date_last = nil
    if last_modified_match
      human_readable_date_last = "#{last_modified_match[3]}-#{last_modified_match[2]}-#{last_modified_match[1]}"
    end

    @full_html = TEMPLATE.render(Object.new, {
        :page_title => title,
        :date_last_modified => human_readable_date_last,
        :description => doc[JsonConstants::OFFICIAL_TITLE],
        :toc => @toc,
        :inner_html => @inner_html
    })
  end

  def make_work_html
    @full_html = WORK_TEMPLATE.render(Object.new, {
        :page_title => title,
        :date_last_modified => human_readable_date_last,
        :description => doc[JsonConstants::OFFICIAL_TITLE],
        :toc => @toc,
        :inner_html => @inner_html
    })
  end

  private
  def make_html
    @is_empty = (@xml.root.name == 'error' or id_adder.xml.root.inner_text.gsub(/\s*/, '').length < 1)
    if @is_empty
      @inner_html = Nokogiri::HTML '<h1>Dit document kan niet weergegeven worden</h1>'
    else
      @inner_html = BWB_TO_HTML.transform(@id_adder.xml)
    end
  end

end

# def find_keys_to_update
#   keys_to_update = []
#   rows_xml, _, _ = get_cloudant_entries
#
#   puts "Found #{rows_xml.length} XML docs"
#   xml_expressions = {}
#   rows_xml.each do |row|
#     doc=row['value']
#     last_modified = doc['datumLaatsteWijziging']
#     if last_modified
#       expressions = xml_expressions[doc['bwbId']] || []
#       expressions << last_modified
#       expressions.sort!
#       xml_expressions[doc['bwbId']]=expressions
#     else
#       puts "WARNING: #{doc['bwbId']} did not have a last modified date"
#     end
#   end
#   puts "Of which #{xml_expressions.length} BWBs"
#
#   rows_lawly = Couch::LAWLY_CONNECTION.get_rows_for_view('bwb', 'RegelingInfo', 'addedToLawly')
#
#   # Find new expressions
#   rows_lawly.each do |row|
#     lawly_date = row['value']['addedToLawly']
#     bwbid = row['id']
#     if (!lawly_date) or (lawly_date < xml_expressions[bwbid].last) or (row['value']['inlinedHtml'])
#       keys_to_update << "#{bwbid}:#{xml_expressions[bwbid].last}"
#       # puts "update"
#     end
#     xml_expressions[bwbid] = nil
#   end
#
#   xml_expressions.each do |key, value|
#     unless value == nil # marked nil in previous loop
#       keys_to_update << "#{key}:#{value.last}"
#       # puts "new"
#     end
#   end
#   keys_to_update
# end
#
# # noinspection RubyStringKeysInHashInspection
# def make_xml_doc_html(doc, xml, old_rev)
#   ok now crash
#
#
#   # Remove _rev and xml attributes from document
#   doc.tap do |hs|
#     hs.delete('_rev')
#     hs.delete('xml')
#   end
#
#   # Set _id, and if applicable _rev
#   doc['_id'] = doc['bwbId']
#   if old_rev
#     doc['_rev'] = old_rev
#   end
#
#   doc['displayKind']=get_display_kind(doc)
#   # Timestamp
#   doc['addedToLawly'] = Time.now.strftime('%Y-%m-%d')
#
#
#   # Encoding.default_external = Encoding::UTF_8
#   # Encoding.default_internal = Encoding::UTF_8
#
#   # puts full_html
#
#   attachments={
#       'show.html' =>
#           {
#               'content_type' => 'text/html',
#               'data' => Base64.encode64(full_html)
#           },
#       'inner.html' =>
#           {
#               'content_type' => 'text/html',
#               'data' => Base64.encode64(doc['html'])
#           },
#   }
#   if doc['toc']
#     attachments['toc.html'] = {
#         'content_type' => 'text/html',
#         'data' => Base64.encode64(doc['toc'])
#     }
#   end
#   doc['_attachments']=attachments
#   doc
# end
#
# def update_html(keys)
#   batch_size = 150
#
#   batches = []
#   batch = []
#   keys.each do |key|
#     batch << key
#     if batch.length >= batch_size
#       batches << batch
#       batch = []
#     end
#   end
#   if batch.length > 0
#     batches << batch
#   end
#   puts "#{batches.length} batches"
#
#   batches.each do |keyz|
#     xml_docs = Couch::CLOUDANT_CONNECTION.get_all_docs('bwb', {:keys => keyz.to_json})
#     bwbs=[]
#     xml_map = {}
#     xml_docs.each do |doc|
#       bwbid=doc['bwbId']
#       bwbs << bwbid
#       if xml_map[bwbid]
#         puts "WARNING: #{bwbid} already had a document set"
#       end
#       xml_map[bwbid] = doc
#     end
#
#     new_docs = Couch::LAWLY_CONNECTION.get_all_docs('bwb', {:keys => bwbs.to_json})
#
#     write_docs = []
#     # Update existing docs
#     new_docs.each do |old_doc|
#       if xml_map[old_doc['bwbId']]
#         str_xml = Nokogiri::XML(Couch::CLOUDANT_CONNECTION.get_attachment_str('bwb', old_doc['_id'], 'data.xml'))
#         doc = xml_map[old_doc['bwbId']]
#         doc = make_xml_doc_html(doc, str_xml, old_doc['_rev'])
#         xml_map[doc['bwbId']] = nil
#         write_docs << doc
#       else
#         puts "WARNING: #{old_doc['bwbId']} was not in xml map."
#       end
#     end
#     # Add new docs
#     xml_map.each do |bwbid, doc|
#       unless doc == nil
#         puts "New doc: #{bwbid}"
#         xml = Nokogiri::XML(Couch::CLOUDANT_CONNECTION.get_attachment_str('bwb', old_doc['_id'], 'data.xml'))
#         doc = make_xml_doc_html(doc, xml, nil)
#         write_docs << doc
#       end
#     end
#
#
#     new_docs = []
#     write_docs.each do |doc|
#       new_doc = {}
#       doc.each do |name, val|
#         unless name == 'toc' or name == 'html'
#           new_doc[name]=val
#         end
#       end
#       new_docs << new_doc
#     end
#     bulk_write_to_database(new_docs, 15, Couch::LAWLY_CONNECTION, 'bwb')
#   end
# end
#
# keys_to_update = find_keys_to_update
# puts "#{keys_to_update.length} keys to update"
# update_html(keys_to_update)