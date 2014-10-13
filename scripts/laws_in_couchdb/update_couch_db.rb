require_relative '../helpers/update_couch_helper'
require_relative '../helpers/couch_updater'

# This script will sync our CouchDB database against the government BWBIdList. Run daily.
CouchUpdater.new.start