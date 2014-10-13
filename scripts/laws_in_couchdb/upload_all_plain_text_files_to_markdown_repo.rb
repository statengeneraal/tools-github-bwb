## This code is deprecated
#
# require 'open-uri'
# require_relative '../helpers/git_event_builder'
# require_relative '../helpers/git_utils'
# include GitUtils
#
# i=0
# json_str = File.read(INDEX_PATH)
# document_index = JSON.parse(json_str.force_encoding('utf-8'))
# document_index[LAW_LIST].each do |bwb_id, doc|
#   md_folder = "#{MARKDOWN_FOLDER}/#{doc[JsonConstants::PATH]}"
#   txt_path = "#{md_folder}/README.txt"
#   txt = MarkdownUtils::get_plain_text(bwb_id, doc[DATE_LAST_MODIFIED])
#   MarkdownUtils.write_file(txt, md_folder, txt_path)
#   i+=1
#   if i%100 == 0
#     puts i
#   end
# end