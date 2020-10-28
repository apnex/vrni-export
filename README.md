# vRNI CSV Export
A collection of scripts to assist in exporting flow data from the vRealize Network Insight Platform Appliance.  

WARNING: This is for demonstration / lab purposes only, as this example script has the following limitations:  
- Error Checking
- API Rate Limiting
- Maximum export of `999999` flows per execution
- Restricted to `Now` in the vRNI query
- Minimal testing against large datasets

### Get started
You can clone this repo, and edit the `drv.export.csv.sh` script to include the desired endpoint and credentials

Note:
- This script requires to be executed in a linux BASH shell environment
- `JQ` is a required installation dependency

For `JQ` - most systems can install this from the distro package manager - ie for Ubuntu:  
```
apt install jq
```

Run with root priveleges.  
Can be scheduled via a cron job directly on the vRNI Platform appliance VM if desired.

### Example Script Execution
```
$ ./drv.export.csv.sh 
Authentication against [ 10.1.2.3 ]: Using LOCAL domain
Authentication SUCCESS - saving flows to [ flows-10-29-2020-09:46:10.csv ]
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 48647    0 48365  100   282  25780    150  0:00:01  0:00:01 --:--:-- 25917
```

### Script Details
Just a copy / paste of the body of `drv.export.csv.sh` for reference  
```
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
```
