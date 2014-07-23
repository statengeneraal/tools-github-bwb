Convert MetaLex to BWB
======================
This folder contains scripts to convert documents from the [MetaLex document server](http://doc.metalex.eu/) (Dutch laws as linked open data) back to the official BWB XML format.

Why?
----
It may sound stupid to take MetaLex documents and convert them *back* to BWB, but I feel it is important to keep historical copies of source content. Because the government service doesn't give access to historic laws, I have made these scripts to convert files on the [MetaLex document server](http://doc.metalex.eu/) back to BWB XML.

The [Laws in CouchDB](https://github.com/statengeneraal/tools-laws-in-couchdb/) project started running in June 2014, so any Dutch law expression after that point should be covered by the code in that repository. 

Limitations 
-----------
Because the MetaLex document server contains some bugs, some information is lost in conversion. That is why documents should always be marked as being converted from MetaLex. This is currently done through the "fromMetalex" field, which is set to true.

I do not have a comprehensive list of limitations, but one thing I found out is that the MetaLex document server does not URI-encode correctly. As such, it is impossible to get the metadata from elements that need to have characters encoded, such as spaces and commas. 

Also, the scripts in this folder are meant to be one-off, and not very well-written.