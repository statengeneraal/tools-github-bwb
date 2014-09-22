# Delete xml files in /converted that are empty

xml_files = Dir['converted/*.xml']

  deleted = 0
xml_files.each do |path|
  if File.size(path) <= 64
    File.delete path
    deleted+=1
  end
end
puts "Deleted #{deleted} files."
