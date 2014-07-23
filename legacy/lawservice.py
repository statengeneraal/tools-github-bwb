from suds.client import Client
from suds.xsd.doctor import ImportDoctor, Import

#WSDL and XML from: https://data.overheid.nl/data/dataset/basis-wetten-bestand
wsdlURL = 'http://wetten.overheid.nl/BWBIdService/BWBIdService.wsdl'

# For now we don't use this information because it does not supply full text
# Some API calls may be useful when implementing updates

# Suds documentation
# https://fedorahosted.org/suds/wiki/Documentation#FIXINGBROKENSCHEMAs
imp = Import('http://schemas.xmlsoap.org/soap/encoding/')
doctor = ImportDoctor(imp)

client = Client(wsdlURL, doctor=doctor)


print client

result = client.service.searchByBWBId("BWBR0001824")

print result