This repository contains some scripts used to maintain the Git repository and law database. 

About `git-updater.rb`
===========
This repository contains Ruby scripts to update the [`laws-markdown`](https://github.com/statengeneraal/laws-markdown) repository. See the documentation of the [`laws-markdown` repository](https://github.com/statengeneraal/laws-markdown) for a detailed description of the philosophy behind this.

How does it work?
-----------------
The script `git_update.rb` is run daily, checking the [CouchDB database](https://github.com/statengeneraal/tools-scripts/tree/master/scripts/laws_in_couchdb) for any modification to law. It then fetches the XML manifestation of this new expression,/ converts it to Markdown and saves the Markdown manifestation in the [`laws-markdown`](https://github.com/statengeneraal/laws-markdown) repository.
