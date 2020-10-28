#!/bin/bash

### CREDENTIALS
## LOCAL Example
#USERNAME='admin@local'
#PASSWORD='mypassword'
#ENDPOINT='10.1.1.1' # IP or FQDN

## LDAP Example
#USERNAME='myuser@example.com'
#PASSWORD='mypassword'
#ENDPOINT='vrni-platform.demo.local'
#DOMAIN='example.com' # using LDAP - comment or remove this line to use LOCAL auth

NOW=$(date +"%m-%d-%Y-%T")
OUTPUT="flows-${NOW}.csv"

### LDAP body
read -r -d '' LDAP <<-EOF
{
	"username": "${USERNAME}",
	"password": "${PASSWORD}",
	"tenantName": "${ENDPOINT}",
	"vIDMURL":"",
	"redirectURL":"",
	"authenticationDomains":{
		"0":{
			"domainType": "LDAP",
			"domain": "${DOMAIN}",
			"redirectUrl": ""
		}
	},
	"currentDomain": 0,
	"domain": "${DOMAIN}",
	"nDomains": 1,
	"serverTimestamp": false,
	"loginFieldPlaceHolder": "Username"
}
EOF

### LOCAL body
read -r -d '' LOCAL <<-EOF
{
	"username": "${USERNAME}",
	"password": "${PASSWORD}",
	"tenantName": "${ENDPOINT}",
	"vIDMURL":"",
	"redirectURL":"",
	"authenticationDomains": {
		"0": {
			"domainType": "LOCAL_DOMAIN",
			"domain": "localdomain",
			"redirectUrl": ""
		}
	},
	"currentDomain": 0,
	"domain": "localdomain",
	"nDomains": 1,
	"serverTimestamp": false,
	"loginFieldPlaceHolder": "Username"
}
EOF
#echo ${LOCAL} | jq --tab .

### Check if DOMAIN is set
if [[ -n ${DOMAIN} ]]; then
	echo "Authentication against [ ${ENDPOINT} ]: Using LDAP domain [ ${DOMAIN} ]"
	AUTHBODY="${LDAP}"
else
	echo "Authentication against [ ${ENDPOINT} ]: Using LOCAL domain"
	AUTHBODY="${LOCAL}"
fi

### Create AUTH Token
URL="https://${ENDPOINT}/api/auth/login"
MYAUTH=$(curl -s -k --location -c "./vrni.cookies" -D "./vrni.headers" -X POST \
	-H 'Content-Type: application/json' \
	--data-raw "${LDAP}" \
"${URL}")
TOKEN=$(echo ${MYAUTH} | jq -r '.csrfToken' 2>/dev/null)

### Check TOKEN is valid
#		--data-urlencode "x-vrni-csrf-token=${TOKEN}" \
if [[ -n ${TOKEN} ]]; then
	echo "Authentication SUCCESS - saving flows to [ ${OUTPUT} ]"

	### Call CSV export method
	URL="https://${ENDPOINT}/api/search/csv"
	curl -k -b "./vrni.cookies" -D "./vrni.headers" -X POST \
		-H "Origin: https://${ENDPOINT}" \
		-H "x-vrni-csrf-token: ${TOKEN}" \
		-H "Content-Type: application/x-www-form-urlencoded" \
		--data-urlencode 'csvFields=name,port.display,port.ianaName,flow.totalBytes.delta.summation.bytes,protocol,srcVm,srcCluster,srcHost,srcIP.ipAddress,dstVm,dstCluster,dstHost,dstIP.ipAddress' \
		--data-urlencode 'maxItemCount=999999' \
		--data-urlencode 'searchString=flows' \
		--data-urlencode 'sourceString=USER' \
		--data-urlencode 'timeRangeString= at Now ' \
	"${URL}" >"${OUTPUT}"
else
	echo "Authentication FAILED for some reason - aborting"
fi
