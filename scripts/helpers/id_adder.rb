require 'nokogiri'
require 'set'

# Adds a descriptive id to the 'about' attribute of every node in an xml document
class IdAdder
  attr_reader :xml
  attr_reader :references_bwbs

  # Expects a Nokogiri XML doc
  def initialize xml, bwbid
    @counter_for_element = {}
    @ids_used = {}
    @xml = xml
    @expressions = []
    @metadata = {}
    @bwbid=bwbid
    @references_bwbs = Set.new
  end

  def add_ids expression_name
    if @xml.root and @xml.root.name == 'wetgeving'
      encode_and_set_about(@xml.root, expression_name) #skip {BWB_EXPR}/wetgeving/1 and make it {BWB_EXPR}

      @xml.root.children.each do |child|
        add_id(child, expression_name)
      end
    else
      #Probably 'error' document. Don't add ids.
      puts "ERROR: #{@bwbid} doesn't have 'wetgeving' as a root node, but #{@xml.root}"
    end
  end

  def set_references
    if @xml and @xml.root
      @xml.root.xpath('//extref|//intref').each do |ref|
        str_juriconnect = ref['doc']
        if str_juriconnect
          /(.*):(.):([^&]*)&?(.*)/ =~ str_juriconnect
          # juriconnect_version = $1
          # juriconnect_type = $2 #'c' for single consolidation or 'v' for a collection
          bwb_id = $3
          str_params = $4 # example: boek=1&artikel=5

          if str_params and str_params.length > 0
            ref['href'] = "/bwb/#{bwb_id}?#{str_params}"
          else
            ref['href'] = "/bwb/#{bwb_id}"
          end

          if bwb_id #and ref.name == 'extref'
          @references_bwbs << bwb_id
          end
          # if ref.name == 'intref'
          #   params={}
          #   if str_params.length > 0
          #     str_params.split('&').each do |key_val|
          #       split = key_val.split('=')
          #       params[split[0]] = split[1]
          #     end
          #   end
          #
          #   params.each do |key, val|
          #     case key
          #       when 'g' #geldigheidsdatum
          #       when 'z' #zichtbaarheidsdatum
          #       else
          #         @xml.root.xpath("//#{key}").each do |el|
          #           nrs = el.xpath("nr")
          #           nrs.each do |nr|
          #             if nr.text.strip == val.strip
          #
          #             end
          #           end
          #           kop_nrs = el.xpath("kop/nr")
          #
          #           end
          #         end
          #     end
          #   end
          # end
        end
      end
    end
  end

  private

  def add_id el, parent_id
    # Only add ids to elements
    if el.class == Nokogiri::XML::Element
      # make id:
      counter = @counter_for_element[parent_id]
      if counter == nil
        counter = {}
        @counter_for_element[parent_id] = counter
      end
      element_count = counter[el.name]
      if element_count
        element_count = element_count+1
      else
        element_count=1
      end
      counter[el.name] = element_count

      nr = element_count
      nrs = el.xpath('./kop/nr')
      if nrs and nrs.length > 0
        nr = nrs.first.text
        # puts "number #{nr}"
        # puts "from #{nrs.first}"
      end
      label=el.name
      labels = el.xpath('./kop/label')
      if labels and labels.length > 0
        label = labels.first.text
      end

      # add id:
      if parent_id and parent_id.length > 0
        id = "#{parent_id}/#{label}/#{nr}"
      else
        id = "#{label}/#{nr}"
      end
      encode_and_set_about el, id

      el.children.each do |child|
        add_id(child, id) # recurse with children
      end
    end
  end

  def encode_and_set_about(el, id_path)
    if el['about']
      # Element already had an about element. Put it in another attribute
      # puts "WARNING: #{id_path} already had an 'about' element: #{el['about']}"
      el['original-about'] = el['about']
    end

    if id_path.match /^[^A-Za-z]/
      id_path = "BWB_#{id_path}" # id must start with [A-Za-z]
    end
    id_path.gsub! /[ ]/, '-' # replace spaces '-'
    id_path.gsub! /[:\.]/, '_' # replace colons and periods with '_'. JQuery may have problems with these chars

    # Make sure that the id is unique
    while @ids_used[id_path]
      # puts "WARNING: #{id_path} was already set. Trying #{id_path}-"
      id_path = "#{id_path}-"
    end
    @ids_used[id_path] = true
    el['about'] = id_path
    id_path
  end
end