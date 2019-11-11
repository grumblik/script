#!/bin/bash
############
### Script return number of days remaining until expiration
############

cert_domain=$1
raw_cert_date=$(echo | openssl s_client -showcerts -servername    $cert_domain -connect  $cert_domain:443 2>/dev/null | openssl x509 -inform pem -noout -text | grep "Not After" | awk -F' : ' '{print $2}')
cert_expire_ts=$(date -d "$raw_cert_date" +%s)
current_ts=$(date +%s)
seconds=$(($cert_expire_ts - $current_ts))
s=60
days=$(($seconds / $s))
days=$(($days / $s))
s=24
days=$(($days / $s))
echo "$days"
