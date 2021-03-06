require 'nokogiri'
require 'json'
require 'logger'
require 'open-uri'
require 'net/http'
require 'fileutils'
require_relative './git_event_builder'
require_relative './git_utils'
include GitUtils

# Script to update /md and /xml git folders. Run every once in a while.

# save_bwb_list_xml
###################

# Object used for creating and handling git events
event_builder = GitEventBuilder.new


unless File.exist? MARKDOWN_GIT_FOLDER
  system("git clone #{ENV['HTTPS_REPO']} md/")
end

if File.exist? INDEX_PATH
  # Read previous index; work from there
  json_str = File.read(INDEX_PATH)
  document_index = JSON.parse(json_str.force_encoding('utf-8'))
  event_builder.update(document_index)
else
  # There was no previous index. Do initial population.
  puts 'Problem loading JSON file. Assuming this is the first run.'

  event_builder.initialize_markdown_repo
  if event_builder.maintain_xml_repo
    event_builder.initialize_xml_repo
  end
  event_builder.update(nil)
end