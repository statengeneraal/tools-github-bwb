require 'nokogiri'
module MarkdownUtils
  XSLT_METALEX = Nokogiri::XSLT(File.open('../../xslt/metalex_to_bwb.xslt'))
  XSLT_MARKDOWN = Nokogiri::XSLT(File.open('../../xslt/xml_to_markdown.xslt'))

  # Deletes a markdown/txt file and its empty parent folders
  def delete_file(entry, md_folder)
    md_path = "#{md_folder}/README.md"
    # puts "deleting #{File.expand_path(md_path)}, exists: #{File.exists?(File.expand_path(md_path))}"
    if File.exists?(File.expand_path(md_path))
      File.delete File.expand_path(md_path)
    end
    txt_path = "#{md_folder}/README.txt"
    if File.exists?(File.expand_path(txt_path))
      File.delete File.expand_path(txt_path)
    end

    folder = File.expand_path(md_folder)
    # This loop is to check up to what directory it's safe to delete (so we don't end up with empty directories)
    loop do
      count = Dir["#{folder}/*"].length
      if count > 0
        # puts "#{folder} had some children"
        break
      else
        if File.exists? folder
          if Dir["#{folder}/.git"].length > 0
            # puts "#{folder} contained .git: getting outta here"
            break
          else
            # If folder is empty and exists, delete
            # puts "Also deleted #{folder}"
            FileUtils.rm_rf folder
          end
        end
        folder = File.expand_path("#{folder}/..") # Go to parent folder
      end
    end
    # else
    # puts "Warning: #{entry[BWB_ID]} did not exist on #{md_path}"
    md_folder
  end

  def write_file(text, folder, path)
    FileUtils.mkdir_p folder unless File.exists?(folder) # Make sure that path exists
    # if path.length < 25
    #   puts path
    # end
    open(path, 'w+') do |f|
      f.puts text
    end
  end

  def get_plain_text(bwbid, date_last_modified, logger=nil)
    text = nil
    begin
      puts "Getting txt for #{bwbid}/#{date_last_modified}"
      zipped_file = open("http://wetten.overheid.nl/#{bwbid}/geldigheidsdatum_#{date_last_modified}/opslaan_in_ascii", :read_timeout => 20*60)
      Zip::File.open(zipped_file) do |zip|
        # Strip first 3 lines which contain '(Tekst geldend op: DD-MM-YYYY)'
        text = zip.read(zip.first).force_encoding('utf-8').lines.to_a[3..-1].join
      end
    rescue
      if logger
        logger.error "Could not open #{"http://wetten.overheid.nl/#{bwbid}/geldigheidsdatum_#{date_last_modified}/opslaan_in_ascii"}"
      end
      puts "ERROR: Could not open #{"http://wetten.overheid.nl/#{bwbid}/geldigheidsdatum_#{date_last_modified}/opslaan_in_ascii"}"
    end
    text
  end

  # Convert the given entry XML to markdown, for the given BWB law list.
  def convert_to_markdown(bwb_id, entry, law_list, str_xml)
    cache_path = "cache/#{bwb_id}.#{entry[DATE_LAST_MODIFIED]}.md"
    old_cache_path = "cache/#{bwb_id}%2F#{entry[DATE_LAST_MODIFIED]}.md"
    if File.exist? cache_path
      markdown = File.open(cache_path).read
    elsif File.exitst? old_cache_path
      markdown = File.open(old_cache_path).read
    else
      # Else convert XML to markdown
      xml_base = Nokogiri::XML(str_xml)
      set_hrefs(bwb_id, law_list, xml_base)
      markdown = XSLT_MARKDOWN.apply_to(xml_base)
      # kramdown escapes tables :(
      # kramdown = Kramdown::Document.new(markdown, :input => 'markdown') # Pretty print markdown
      markdown = format_markdown(markdown)
      File.open(cache_path, 'w+') do |f|
        f.puts markdown
      end
      puts "written #{cache_path} to cache"
    end
    markdown
  end

  def format_markdown(markdown)
    markdown.gsub!(/^[ ]+/, '') # Remove starting spaces
    markdown.gsub!(/^[#]+\s*$/, '') # Remove empty headers
    markdown.gsub!(/(\n\s*){3,}/, "\n\n") # Remove more than two newlines
    substitute!(/^[0-9]+\.(?<spaces>\s*)[^\s]*$/, markdown, {:spaces => ' '}) # pretty print lists, e.g., '1. bla bla' instead of '1.     bla bla'

    if markdown.gsub(/\s+/, '').length > 0 # If it's not just whitespaces
      markdown.prepend("<meta http-equiv='Content-Type' content='text/html; charset=utf-8' />\n")
    else
      markdown = ''
    end
    markdown
  end

  private
  def set_hrefs(bwb_id, law_list, xml_base)
    external_references = xml_base.xpath('.//extref[@doc]')
    if external_references and external_references.respond_to?('[]')
      external_references.each do |el|
        #1.0:v:BWBR0001834&artikel=15
        if el and el.respond_to?('[]')
          juriconnect = el['doc']
          /.\..:.*:(BWB[^&]*)/ =~ juriconnect

          to_bwb = $1
          if to_bwb and law_list[bwb_id]
            # Don't handle things like:
            # <extref doc="" label="verordening" reeks="Celex" compleet="nee">Verordening (EG) nr. 2201/2003</extref>
            from = law_list[bwb_id]['path']

            external_document = law_list[to_bwb]

            if external_document
              to = external_document['path']
              path = get_path_to(from, to)

              el['ref'] = path
            else
              case to_bwb
                when 'BWBR0003018', 'BWBR0002530', 'BWBR0002664', 'BWBR0003011', 'BWBR0006064', 'BWBR0026755', 'BWBR0002147' # Do nothing for 'known unknowns'

                else
                  puts "WARNING: handling extref; link to #{to_bwb} is not resolvable with our BWB ID list"
              end
            end
          else
            el['ref'] = ''
          end
        end
      end
    else
      puts "WARNING: #{external_references} did not respond to []"
    end
  end
end