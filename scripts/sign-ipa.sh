#!/bin/bash

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <ipa> <p12> <password> <mobileprovision>"
    exit 1
fi

IPA_FILE="$1"
P12_FILE="$2"
PASSWORD="$3"
MOBILEPROVISION_FILE="$4"
OUTPUT_FILE="$5"

UPLOAD_URL="https://ipa.ipasign.cc:2052/uploadipa"
SIGNCHECK_URL="https://ipa.ipasign.cc:2052/signcheck"

echo "Signing .ipa with ipasign.cc"
echo "Upload in progress..."

# Upload the .ipa, .p12, and .mobileprovision files
RESPONSE=$(curl $UPLOAD_URL \
    -H 'accept: application/json, text/plain, */*' \
    -H 'accept-language: en-AU,en;q=0.9' \
    -H 'cache-control: no-cache' \
    -H 'dnt: 1' \
    -H 'origin: https://sign.ipasign.cc' \
    -H 'pragma: no-cache' \
    -H 'priority: u=1, i' \
    -H 'referer: https://sign.ipasign.cc/' \
    -H 'sec-ch-ua: "Not(A:Brand";v="99", "Google Chrome";v="133", "Chromium";v="133"' \
    -H 'sec-ch-ua-mobile: ?0' \
    -H 'sec-ch-ua-platform: "macOS"' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: same-site' \
    -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36' \
    -F "ipa=@$IPA_FILE" \
    -F "p12=@$P12_FILE" \
    -F "name=" \
    -F "password=$PASSWORD" \
    -F "unlock=0" \
    -F "identifier=" \
    -F "mobileprovision=@$MOBILEPROVISION_FILE")

# Extract UUID and time from response (used to construct the download link)
UUID=$(echo "$RESPONSE" | jq -r '.data.uuid')
TIME=$(echo "$RESPONSE" | jq -r '.data.time')

# Validate response
if [[ "$UUID" == "null" || "$TIME" == "null" ]]; then
    echo "Error: Failed to retrieve UUID or time from response."
    echo "Response: $RESPONSE"
    exit 1
fi

# Poll signcheck endpoint every 20 seconds, up to 10 times
ATTEMPTS=0
MAX_ATTEMPTS=10
SLEEP_DURATION=20

while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
    SIGNCHECK_RESPONSE=$(curl -s -X POST "$SIGNCHECK_URL" \
        -H "accept: application/json, text/plain, */*" \
        -H "content-type: multipart/form-data" \
        -F "uuid=$UUID" \
        -F "time=$TIME")
    
    SIGN_STATUS=$(echo "$SIGNCHECK_RESPONSE" | jq -r '.code')
    
    if [[ "$SIGN_STATUS" == "0" ]]; then
        echo "Signing successful. Proceeding to download."
        break
    fi
    
    ((ATTEMPTS++))
    echo "Signing in progress... attempt $ATTEMPTS of $MAX_ATTEMPTS. Checking again in $SLEEP_DURATION seconds."
    sleep $SLEEP_DURATION

done

if [[ $ATTEMPTS -eq $MAX_ATTEMPTS ]]; then
    echo "Error: Signing process timed out after $MAX_ATTEMPTS attempts."
    exit 1
fi

# Construct the download URL
DOWNLOAD_URL="https://ipa.ipasign.cc:2052/sign/$TIME/$UUID/resign_$TIME.ipa"

# Download the signed IPA file
curl -o $OUTPUT_FILE "$DOWNLOAD_URL"

echo "Download complete: $OUTPUT_FILE"
