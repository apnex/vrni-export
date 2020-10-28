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
echo ${LOCAL} | jq --tab .

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
if [[ -n ${TOKEN} ]]; then
	echo "Authentication SUCCESS"
read -r -d '' BODY <<-EOF
{
	"id": "",
	"name": "my-new-template",
	"entityType": "515",
	"scope":"GLOBAL",
	"templateProperties": [
		"Bytes Rate",
		"Bytes",
		"Global Destination Security Group",
		"Global Source Security Group",
		"Global Destination L2 Network",
		"Global Source L2 Network",
		"Port",
		"Destination IP Address",
		"Source IP Address",
		"Flow Type"
	]
}
EOF
	curl -sk -b "./vrni.cookies" -D "./vrni.headers" -X POST \
		-H "Content-Type: application/json" \
		-H "Origin: https://${ENDPOINT}" \
		-H "x-vrni-csrf-token: ${TOKEN}" \
		--data-raw "${BODY}" \
	"${URL}"
else
	echo "Authentication FAILED for some reason - aborting"
fi
