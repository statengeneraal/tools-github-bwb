require 'json'
#splits json files with xml embedded into json (without embedded xml) and separate xml files

json_files = Dir['converted/*.json']

json_files.each do |path|
  doc = JSON.parse File.open(path).read.force_encoding('utf-8')
  if doc['xml']
    /(.*)\.json/ =~ path
    File.open("#{$1}.xml", 'w') do |file|
      file.write doc['xml']
    end
    doc['xml'] = nil
    File.open(path, 'w') do |file|
      file.write doc.to_json
    end
  end
end