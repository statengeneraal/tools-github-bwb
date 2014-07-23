# Parse XML for all BWBIDs
# http://www.e-overheidvoorburgers.nl/producten,wet-en-regelgeving/Documentatie.html

from xml.dom.minidom import parse
import os

lawsdir = os.path.join(os.path.dirname(os.getcwd()), 'laws')

lawfiles = os.listdir(lawsdir)

for filename in [f for f in lawfiles if f.index('.') != 0]:
    filepath = os.path.join(lawsdir, filename)
    lawdom = parse(filepath)

    wetgevingElements = lawdom.getElementsByTagName('wetgeving')
    soort = ''
    if wetgevingElements:
        soort = wetgevingElements[0].getAttribute('soort')

    tituleElements = lawdom.getElementsByTagName('intitule')
    titule = ''
    if tituleElements:
        titule = tituleElements[0].childNodes[0].data
        titule = titule.replace('\n', '')



        print filename, soort, titule.encode('utf-8')
