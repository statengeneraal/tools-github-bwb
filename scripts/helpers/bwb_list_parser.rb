require_relative 'json_constants'
require_relative 'xml_constants'
require_relative 'extend_string'
require 'nokogiri'
# Parses BwbIdList.xml and maps it to a Ruby object model
# noinspection RubyTooManyInstanceVariablesInspection
class BwbListParser < Nokogiri::XML::SAX::Document
  attr_reader :bwb_list

  def initialize(prev_paths={})
    @prev_paths = prev_paths
    @bwb_list = {} #'_id'=> previous['_id'], '_rev'=> previous['_rev']
    @law_list = {}
    @current_tag = nil
    @current_id = nil
    @current_law = nil
    @current_cite_titles = nil
    @current_cite_title = nil
    @current_abbreviations = nil
    @current_non_official_titles = nil
    @laws_parsed = 0
  end

  # Dates are strings, but because they're encoded YYYY-MM-DD, lexicographical comparisons will work
  # E.g, "2014-08-05" > "2011-01-01"
  def self.is_newer_than(a, b)
    a[JsonConstants::DATE_LAST_MODIFIED] >= b[JsonConstants::DATE_LAST_MODIFIED]
  end

  def start_element(name, _=[])
    @current_tag = name

    case name
      when XmlConstants::LAW_INFO
        @current_law = {}
      when XmlConstants::CITE_TITLE
        @current_cite_title = {}
      when XmlConstants::CITE_TITLE_LIST
        @current_cite_titles = []
      when XmlConstants::ABBREVIATION_LIST
        @current_abbreviations = []
      when XmlConstants::NON_OFFICIAL_TITLE_LIST
        @current_non_official_titles = []
      when XmlConstants::LAW_LIST,
          XmlConstants::OFFICIAL_TITLE,
          XmlConstants::TITLE,
          XmlConstants::STATUS,
          XmlConstants::ENTRY_DATE,
          XmlConstants::BWB_ID,
          XmlConstants::DATE_LAST_MODIFIED,
          XmlConstants::EXPIRATION_DATE,
          XmlConstants::BWB_RESULT,
          XmlConstants::KIND,
          XmlConstants::LAW_INFO,
          XmlConstants::ABBREVIATION,
          XmlConstants::NON_OFFICIAL_TITLE,
          XmlConstants::GENERATED_ON
        # Do nothing
      else
        raise "WARNING: could not handle #{name} opening"
    end
    # Start with new text buffer
    @content = nil
  end

  def end_element(name)
    @current_tag = nil

    case name
      when XmlConstants::LAW_INFO
        unless @current_law[JsonConstants::BWB_ID]
          raise 'RegelingInfo ended but no BWB ID was found'
        end
        # unless @current_law[JsonConstants::ENTRY_DATE]
        #   raise 'RegelingInfo ended but no entry date was found'
        # end
        unless @current_law[JsonConstants::KIND]
          raise 'RegelingInfo ended but no kind was found'
        end
        unless @current_law[JsonConstants::DATE_LAST_MODIFIED]
          raise 'RegelingInfo ended but no last modified date was found'
        end

        # Finished a law block; set a display title and add to dictionary
        @current_law[JsonConstants::DISPLAY_TITLE] = extract_display_title(@current_law)

        bwb_id = @current_law[JsonConstants::BWB_ID]
        already_processed = @law_list[bwb_id]
        if already_processed
          puts "WARNING: #{bwb_id} exists twice in list"
        end

        path = @prev_paths[bwb_id]
        unless path
          path = BwbListParser.create_path(@current_law)
        end

        @current_law[JsonConstants::PATH] = path
        @law_list[bwb_id] = @current_law
        # puts BwbListParser.create_path(@current_law)

        @laws_parsed += 1
        if @laws_parsed % 5000 == 0
          puts "Parsed #{@laws_parsed} laws."
        end

        @current_law = nil
      when XmlConstants::CITE_TITLE
        # Add cite title to cite title list
        @current_cite_titles << @current_cite_title
        @current_cite_title = nil
      when XmlConstants::CITE_TITLE_LIST
        # Add cite title list to law info
        @current_law[JsonConstants::CITE_TITLE_LIST] = @current_cite_titles
        @current_cite_titles = nil
      when XmlConstants::NON_OFFICIAL_TITLE_LIST
        if @current_non_official_titles.length > 0
          @current_law[JsonConstants::NON_OFFICIAL_TITLE_LIST] = @current_non_official_titles
        end
        @current_non_official_titles = nil
      when XmlConstants::ABBREVIATION_LIST
        if @current_abbreviations.length > 0
          @current_law[JsonConstants::ABBREVIATION_LIST] = @current_abbreviations
        end
        @current_abbreviations = nil
      when XmlConstants::LAW_LIST
        @bwb_list[JsonConstants::LAW_LIST] = @law_list
      when XmlConstants::KIND
        @current_law[JsonConstants::KIND] = @content
      when XmlConstants::BWB_ID
        @current_law[JsonConstants::BWB_ID] = @content
      when XmlConstants::DATE_LAST_MODIFIED
        @current_law[JsonConstants::DATE_LAST_MODIFIED] = @content
      when XmlConstants::EXPIRATION_DATE
        @current_law[JsonConstants::EXPIRATION_DATE] = @content
      when XmlConstants::OFFICIAL_TITLE
        @current_law[JsonConstants::OFFICIAL_TITLE] = @content
      when XmlConstants::ENTRY_DATE
        if @current_cite_title
          @current_cite_title[JsonConstants::ENTRY_DATE] = @content
        else
          @current_law[JsonConstants::ENTRY_DATE] = @content
        end
      when XmlConstants::ABBREVIATION
        @current_abbreviations << @content
      when XmlConstants::TITLE
        @current_cite_title[JsonConstants::TITLE] = @content
      when XmlConstants::STATUS
        @current_cite_title[JsonConstants::STATUS] = @content
      when XmlConstants::GENERATED_ON
        @bwb_list[JsonConstants::GENERATED_ON] = @content
      when XmlConstants::NON_OFFICIAL_TITLE
        @current_non_official_titles << @content
      when XmlConstants::LAW_INFO,
          XmlConstants::BWB_RESULT
        #Do nothing
      else
        raise "WARNING: could not handle #{name} closing"
    end
    # Delete buffered text content
    @content = nil
  end

  def extract_display_title(law)
    if law[JsonConstants::CITE_TITLE_LIST] and law[JsonConstants::CITE_TITLE_LIST][0]
      law[JsonConstants::CITE_TITLE_LIST][0][JsonConstants::TITLE]
    elsif law[JsonConstants::OFFICIAL_TITLE]
      law[JsonConstants::OFFICIAL_TITLE]
    elsif law[JsonConstants::NON_OFFICIAL_TITLE_LIST] and law[JsonConstants::NON_OFFICIAL_TITLE_LIST][0]
      law[JsonConstants::NON_OFFICIAL_TITLE_LIST][0]
    elsif law[JsonConstants::ABBREVIATION_LIST] and law[JsonConstants::ABBREVIATION_LIST][0]
      law[JsonConstants::ABBREVIATION_LIST][0]
    else
      law[JsonConstants::BWB_ID]
    end
  end


# path: /[LAW]/SHORTEST/TITLE/FINDABLE/[BWBID]
  def self.create_path(law)
    if law[JsonConstants::DISPLAY_TITLE]
      shortest_title = law[JsonConstants::DISPLAY_TITLE]
    else
      shortest_title = law[JsonConstants::OFFICIAL_TITLE]
      cite_titles = law[JsonConstants::CITE_TITLE_LIST]
      if cite_titles
        cite_titles.each do |cite_title|
          if shortest_title == nil or cite_title[JsonConstants::TITLE].length < shortest_title.length
            shortest_title = cite_title[JsonConstants::TITLE]
          end
        end
      end

      non_official_titles = law[JsonConstants::NON_OFFICIAL_TITLE_LIST]
      if non_official_titles
        non_official_titles.each do |title|
          if shortest_title == nil or title.length < shortest_title.length
            shortest_title = title
          end
        end
      end
    end

    if shortest_title
      words = shortest_title.split(/ /)

      words.map! do |word|
        word = word.urlize({:downcase => true})
        case word
          when 'con', 'prn', 'aux', 'nul', /com[0-9]/, /lpt[0-9]/, /^\.+$/
            # Escape Windows-unfriendly folders, e.g., driver file or only periods
            # See http://support.microsoft.com/kb/74496/en-us
            word = "_#{word}_"
          else
        end
        word.gsub!(/^\.+/, '') # Replace leading periods with ''
        word.gsub!(/["\/\^\?<>:\*\|]/, '') # Replace any non-valid char with '', see http://support.grouplogic.com/?p=1607
        word.gsub!(/[,°]/, '') # Replace ugly chars with ''
        word
      end

      escaped = ''
      words.each do |word|
        if escaped.length + word.length < 75 #Don't exceed 75 chars (note that Windows has a 255 char limit for paths)
          escaped << "/#{word}"
        else
          escaped << '/etc'
          break
        end
      end
      unless escaped.start_with? '/'
        escaped = '/'+escaped
      end
      path = "#{escaped}/#{law[JsonConstants::BWB_ID]}"

      # if /[^A-Za-z0-9 ,]/ =~ shortest_title
      #shortest_title
      # end
    else
      path = law[JsonConstants::BWB_ID]
    end
    path = "#{law[JsonConstants::KIND]}/#{path}"

    path.gsub!(/\/\/+/, '/') # Remove duplicate /'s
    path.gsub!(/\/+$/, '') # Remove trailing /'s # Although there are none b/c the path always ends with /[BWBID]
    path
  end

  def characters(chars)
    if @content
      @content += chars
    else
      @content = chars
    end
    # if @content.start_with? 'Convention'
    # end
  end

end