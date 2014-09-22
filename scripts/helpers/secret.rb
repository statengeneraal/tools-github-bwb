# Class containing secret stuff. Do not add to version control.
module Secret
  CLOUDANT_NAME = ENV['CLOUDANT_NAME']
  CLOUDANT_PASSWORD = ENV['CLOUDANT_PASSWORD']

  LAWLY_NAME = ENV['LAWLY_NAME']
  LAWLY_PASSWORD = ENV['LAWLY_PASSWORD']
end