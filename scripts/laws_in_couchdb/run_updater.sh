#!/bin/sh
echo "Starting git_updater!"
cd /home/maarten/laws-in-git/scripts/laws_in_couchdb/
ruby /home/maarten/laws-in-git/scripts/laws_in_couchdb/update_couch_db.rb
echo "Updated Laws CouchDB!"

echo "Starting git_updater!"
cd /home/maarten/laws-in-git/scripts/laws_in_couchdb/
ruby /home/maarten/laws-in-git/scripts/laws_in_couchdb/git_update.rb
echo "Done!"