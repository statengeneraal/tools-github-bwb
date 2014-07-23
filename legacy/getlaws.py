

# Parse XML for all BWBIDs
# http://www.e-overheidvoorburgers.nl/producten,wet-en-regelgeving/Documentatie.html

from xml.dom.minidom import parse
import os
import urllib2

# dom = parse('webservice/short.xml')
print 'started'
dom = parse('webservice/BWBIdList.xml')
print 'parsed dom'

lawsdir = os.path.join(os.path.dirname(os.getcwd()), 'laws')

for node in dom.getElementsByTagName('__NS1:BWBId'):
    bwbid = node.childNodes[0].data

    writepath = os.path.join(lawsdir, bwbid + '.xml')

    # Documentation for content webservices
    # http://www.e-overheidvoorburgers.nl/producten,wet-en-regelgeving/Documentatie.html
    # URL for regelingen is: http://wetten.overheid.nl/xml.php?regelingID=BWBR0004757
    # URL for others?

    if not os.path.exists(writepath):
        # TODO rewrite using twisted with 5-25 simultaneous connections

        remoteConnection = urllib2.urlopen('http://wetten.overheid.nl/xml.php?regelingID=%s' % bwbid)
        content = remoteConnection.read()

        f = open(writepath, 'w')
        f.write(content)
        f.close()

        print 'Did bwbid', bwbid
