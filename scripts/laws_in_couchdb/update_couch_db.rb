require_relative '../helpers/update_couch_helper'

# This script will sync our CouchDB database against the government BWBIdList. Run daily.
CouchUpdater.new.start