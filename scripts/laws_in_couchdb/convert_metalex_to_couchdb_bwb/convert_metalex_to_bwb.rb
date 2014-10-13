## This code is deprecated
#
# # Script to convert metalex files in '/xml_daily_dump' to BWB XML and write them to '/converted'
#
# require 'sparql/client'
# require 'set'
# require 'rdf'
# require 'rdf/n3'
# require 'json'
# require 'nokogiri'
# require 'open-uri'
# require 'fileutils'
# require_relative 'secret'
#
# BWB_ID = 'bwbId'
# KIND = 'regelingSoort'
# OFFICIAL_TITLE = 'officieleTitel'
# DATE_LAST_MODIFIED = 'datumLaatsteWijziging'
# EXPIRATION_DATE = 'vervalDatum'
# ENTRY_DATE = 'inwerkingtredingsDatum'
# TITLE = 'titel'
# STATUS = 'status'
# NON_OFFICIAL_TITLE_LIST = 'nietOfficieleTitels'
# ABBREVIATION_LIST = 'afkortingen'
# CITE_TITLE_LIST = 'citeertitels'
# GENERATED_ON = 'gegenereerdOp'
# LAW_LIST = 'regelingInfoLijst'
#
#
# QUERY_METALEX_EXPRESSIONS = "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
# PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
# PREFIX bwb: <http://doc.metalex.eu/bwb/ontology/>
# PREFIX metalex: <http://www.metalex.eu/schema/1.0#>
# SELECT DISTINCT ?sub ?bwbId ?time ?title ?page ?retractionDate ?kind {
# 	?sub <http://doc.metalex.eu/bwb/ontology/bwb-id> ?bwbId.
#   ?sub <http://www.w3.org/ns/prov#wasGeneratedAtTime> ?time.
#   ?sub <http://xmlns.com/foaf/0.1/page> ?page.
#   ?sub <http://doc.metalex.eu/bwb/ontology/soort> ?kind.
#
#   OPTIONAL {
#     ?sub <http://purl.org/dc/terms/title> ?title.
#     ?expression <http://www.metalex.eu/schema/1.0#resultOf> ?s.
#     ?s a <http://doc.metalex.eu/bwb/ontology/Intrekking_regeling>.
#     ?s metalex:date ?dateo.
#     ?dateo <http://www.w3.org/2006/time#inXSDDateTime> ?retractionDate.
#   }
#   FILTER(?time < \"2014-05-26\"^^xsd:date)
# }"
#
# # Convert Metalex BWB documents to an approximation of the original BWB XML and make a JSON file out of the data.
# # NOTE: this code assumes there a folder 'xml_daily_dump' containing Metalex XML files. Get the Metalex Document Server dump here: http://doc.metalex.eu/#data
# class DocumentConverter
#   def initialize
#     @today = Date.today.strftime("%Y-%m-%d")
#     @bwb_list = parse_bwb_list
#     @law_list = @bwb_list[LAW_LIST]
#     @cloudant_expressions = get_cloudant_expressions
#     puts "Found #{@cloudant_expressions.length} BWBs in cloudant"
#     handle_metalex_expressions
#   end
#
#   #Convert a MetaLex BWB XML string to a BWB XML (nokogiri document), including original attributes
#   def convert_metalex_to_bwb(str_metalex, path)
#     metalex = Nokogiri::XML(str_metalex)
#     bwb = Nokogiri::XSLT(File.open("xslt/metalex_to_bwb.xslt")).transform(metalex)
#
#     uris = []
#     triples = {}
#     # threads = []
#     # Set bwb attributes
#     abouts = bwb.xpath('//*[@about]')
#     abouts.each do |element|
#       unless element['about']
#         raise "No about found for #{element}"
#       end
#       unless triples[element['about']] # raise "#{element['about']} was about of multiple elements in the same document"
#         uri = URI.escape(element['about'])
#         if uri.length > 0
#           if uri == element['about'] # it's hopeless if we our encoded uri is different from non-encoded
#             uris << uri
#             if uris.length >= 1000
#               # Do batches of uris
#               uris_2 = uris
#               predicates = get_bwb_predicates(uris_2, path)
#               triples.merge!(predicates)
#               uris.clear
#             end
#           end
#         end
#       end
#     end
#
#     uris_2 = uris
#     predicates = get_bwb_predicates(uris_2, path)
#     triples.merge!(predicates)
#
#     abouts.each do |element|
#       predicate_value_pair = triples[element['about'].to_s]
#       if predicate_value_pair
#         predicate_value_pair.each do |predicate, value|
#           element[predicate] = value
#         end
#       end
#     end
#     bwb
#   end
#
#   # Make SPARQL query to get the original XML attributes for the given elements. Return a dictionary where keys are element uris and values are also dictionaries, containing the attribute name as keys and attribute value as values.
#   def get_bwb_predicates(uris, path)
#     attributes = {}
#     #Make filter for ?uri
#     uris = uris.reduce([]) do |sum, uri|
#       if uri.length > 0
#         # sum << "?uri=<#{uri}>"
#         sum << "<#{uri}>"
#       end
#       sum
#     end
#     # filter = uris.join('||')
#     filter = "(#{uris.join(', ')})"
#     if filter.length > 0
#       q = "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
# PREFIX bwb: <http://doc.metalex.eu/bwb/ontology/>
# PREFIX owl: <http://www.w3.org/2002/07/owl#>
#
# SELECT DISTINCT ?uri ?predicate ?object
# WHERE {
# {
#  ?uri ?predicate ?object.
# } UNION
# {
#  ?same owl:sameAs ?uri.
#  ?same ?predicate ?object.
# }
# FILTER(STRSTARTS(STR(?predicate), STR(bwb:)) && (?uri IN #{filter}))
# }"
# # FILTER(STRSTARTS(STR(?predicate), STR(bwb:)) && (#{filter}))
# # puts q
#       sparql_endpoint = URI('http://doc.metalex.eu:8000/sparql/')
#       sparql_client = SPARQL::Client.new(sparql_endpoint)
#       response = Net::HTTP.new(sparql_endpoint.host, sparql_endpoint.port).start do |http|
#         request = Net::HTTP::Post.new(sparql_endpoint)
#         request.set_form_data({:query => q})
#         request['Accept']='application/sparql-results+xml'
#         http.request(request)
#       end
# # puts q
#       case response
#         when Net::HTTPSuccess # Response code 2xx: success
#           results = sparql_client.parse_response(response)
#           # puts ''
#           l = 0
#           results.each do |result|
#             l += 1
#             if result['predicate'].value.length > 0 and result['object'].value.length > 0
#               existing = attributes[result['uri'].value]
#               existing ||= {}
#               existing[result['predicate'].value.gsub('http://doc.metalex.eu/bwb/ontology/', '')] = result['object'].value
#               attributes[result['uri'].value] = existing
#             end
#           end
#           if l > 0
#             puts "Found #{l} triples for #{uris.length} uris (#{path})"
#           end
#         else
#           puts q
#           raise "Could not make SPARQL request for #{uris}"
#       end
#     end
#     attributes
#   end
#
#   # Get all events in Cloudant db that are not in the bwb list
#   def get_cloudant_expressions
#     puts "Querying all expressions in CouchDB..."
#     str_our_expressions = open("http://#{Secret::CLOUDANT_NAME}.cloudant.com/bwb/_design/RegelingInfo/_view/all").read
#     rows_cloudant = JSON.parse(str_our_expressions.force_encoding('utf-8'))['rows']
#     puts "Found #{rows_cloudant.length} expressions in Cloudant"
#     rows_cloudant
#     cloudant_expressions = {}
#     rows_cloudant.each do |row|
#       regeling_info = row['value']
#       # unless @law_list[regeling_info[BWB_ID]]
#       #   @law_list[regeling_info[BWB_ID]] = regeling_info
#       # end
#
#       expressions = cloudant_expressions[regeling_info[BWB_ID]]
#       expressions ||= []
#       expressions << regeling_info
#       cloudant_expressions[regeling_info[BWB_ID]] = expressions
#     end
#     cloudant_expressions
#   end
#
#   def parse_bwb_list
#     puts 'Downloading JSON'
#     str_json = open("http://#{Secret::CLOUDANT_NAME}.cloudant.com/bwb/bwbIdList").read
#     bwb_id_list = JSON.parse str_json.force_encoding('utf-8')
#
#     law_dict ={}
#     bwb_id_list[LAW_LIST].each do |regeling_info|
#       unless regeling_info[BWB_ID]
#         raise 'No bwbId'
#       end
#       law_dict[regeling_info[BWB_ID]] = regeling_info
#     end
#     bwb_id_list[LAW_LIST] = law_dict
#     bwb_id_list
#   end
#
#
#   # Get all expressions from BEFORE May 26th that ARE NOT in our Cloudant db from MetaLex doc server
#   def handle_metalex_expressions
#     metalex_files = Dir['xml_daily_dump/*_*_ml.xml']
#     puts "#{metalex_files.length} xml files found"
#
#     i = 0
#     # threads = []
#     metalex_files.each do |path|
#       # Regex to parse XML dump file names (bwb id and expression date)
#       match_data = /xml_daily_dump\/(.*)_(.*)_ml.xml/.match path
#       bwb_id = match_data[1]
#       date_last_modified = match_data[2]
#
#       unless has_date_or_earlier(bwb_id, date_last_modified)
#         i+=1
#         converted_path = "converted/#{bwb_id}.#{date_last_modified}"
#         if File.exist? "#{converted_path}.xml"
#           # puts "Skipping #{converted_path}"
#         else
#           save_expression(bwb_id, converted_path, date_last_modified, path)
#         end
#       end
#     end
#     # threads.each do |thread|
#     #  thread.join
#     #end
#     #puts "#{threads.length} threads done"
#     puts "Found #{i} unique expressions."
#   end
#
#
#   def save_expression(bwb_id, converted_path, date_last_modified, path)
#     puts "Starting #{converted_path}\n"
#     str_metalex = File.open(path).read
#     is_empty = str_metalex.length <= 0
#     bwb_xml = nil
#     unless is_empty
#       # if bwb_id == 'BWBR0001824'
#       #   puts 'hello'
#       # end
#       bwb_xml = convert_metalex_to_bwb str_metalex, path
#       unless bwb_xml.xpath('/*').length > 0 and bwb_xml.xpath('/*').first.children.length > 0
#         is_empty = true
#       end
#     end
#     regeling_info = {
#         BWB_ID => bwb_id,
#         DATE_LAST_MODIFIED => date_last_modified,
#         :page => path,
#         :fromMetalex => true,
#         :schema => '26-06-2014',
#         :empty => is_empty
#     }
#     # noinspection RubyUnusedLocalVariable
#     str_metalex = nil
#     str_json = regeling_info.to_json
#     File.open("#{converted_path}.json", 'w') do |file|
#       file.write(str_json)
#     end
#     File.open("#{converted_path}.xml", 'w') do |file|
#       file.write bwb_xml.to_s
#     end
#     # noinspection RubyUnusedLocalVariable
#     bwb_xml = nil
#     puts "written file to #{converted_path}.json and #{converted_path}.xml"
#   end
#
#   # Returns whether the given expression is also in our map of of expressions in the Cloudant db
#   def has_date_or_earlier(bwb_id, date_last_modified)
#     found_in_cloudant_expressions = false
#
#     if @cloudant_expressions[bwb_id]
#       @cloudant_expressions[bwb_id].each do |expression|
#         if expression[DATE_LAST_MODIFIED] <= date_last_modified
#           # puts "#{expression[DATE_LAST_MODIFIED]} == #{date_last_modified}"
#           found_in_cloudant_expressions = true
#           break
#         end
#       end
#     end
#
#     # if (!found_in_cloudant_expressions) and (date_last_modified > "2014-05-26")
#     #   puts "WARNING: found a metalex expression of #{bwb_id} that was modified on #{date_last_modified} and not in cloudant"
#     # end
#     found_in_cloudant_expressions
#   end
# end
#
# #Run script. Just instantiating the object will have the side-effects we want. (Maybe not a good programming pattern?)
# DocumentConverter.new