#!/bin/bash

# This script creates a signed authorization header for an S3 REST API getObject request.
# It is designed to be used by Apache's RewriteMap feature, which can start an external program
# and comminicate with it via stdin and stdout. The script listens for Apache to pass it the
# request URI, and returns a signed authorization header for that URI.  It uses a bash 'while' loop
# to run forever, listening for input from Apache (as specified in the RewriteMap configuration).

# Related AWS documentation:
#   - https://docs.aws.amazon.com/general/latest/gr/create-signed-request.html#create-canonical-request
#   - https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html
#   - https://czak.pl/2015/09/15/s3-rest-api-with-curl.html

# Related Apache documentation:
#   - https://httpd.apache.org/docs/2.4/rewrite/rewritemap.html#prg

# These are just example values, not real credentials. These should be set in the environment.
AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
AWS_SECURITY_TOKEN="AQoEXAMPLEH4aoAH0gNCAPyJxz4BlCFFxWNE1OPTgk5TthT+FvwqnKwRcOIfrRh3c/LTo6UDdyJwOOvEVPvLXCrrrUtdnniCEXAMPLE/IvU1dYUg2RVAJBanLiHb4IgRmpRV3zrkuWJOgQs8IZZaIv2BXIa2R4OlgkBN9bkUDNCJiBeb/AXlzBBko7b15fjrBs2+cTQtpZ3CYWFXG8C5zqx37wnOE49mRl/+OtkIKGO7fAE"
OBJECT_LAMBDA_HOST="example.s3-object-lambda.us-east-1.amazonaws.com"

# This line just renames a thing for convenience.
AWS_SESSION_TOKEN="${AWS_SECURITY_TOKEN}"

# Validates that the required environment variables are set.
[[ -n "${AWS_ACCESS_KEY_ID}" ]]     || { echo "AWS_ACCESS_KEY_ID required" >&2; exit 1; }
[[ -n "${AWS_SECRET_ACCESS_KEY}" ]] || { echo "AWS_SECRET_ACCESS_KEY required" >&2; exit 1; }
[[ -n "${AWS_SECURITY_TOKEN}" ]]    || { echo "AWS_SECURITY_TOKEN required" >&2; exit 1; }
[[ -n "${OBJECT_LAMBDA_HOST}" ]]    || { echo "OBJECT_LAMBDA_HOST required" >&2; exit 1; }

# Function definitions
setGlobals() {  
  SERVICE="s3-object-lambda"
  HASH_ALG='AWS4-HMAC-SHA256'
  REQUEST_TYPE='aws4_request'
  SIGNED_HEADERS="host;x-amz-content-sha256;x-amz-date"
  EMPTY_STRING="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  [ -n "$AWS_SESSION_TOKEN" ] && SIGNED_HEADERS="$SIGNED_HEADERS;x-amz-security-token"
  [ -z "$REGION" ] && REGION="us-east-1"
  [ -z "$HOST" ] && HOST=${OBJECT_LAMBDA_HOST}
}

hmac_sha256() {
  key="$1"
  data="$2"
  echo -ne "$data" | openssl dgst -sha256 -mac HMAC -macopt "$key" | sed 's/^.* //' | tr -d '\n'
}

getCanonicalRequest() {
  local httpmethod="GET"
  local canonicalURI="$1"
  local thisTimeStamp="$2"
  local canonicalQueryString=""
  local canonicalHeader1="host:$HOST"
  local canonicalHeader2="x-amz-content-sha256:$EMPTY_STRING"
  local canonicalHeader3="x-amz-date:${thisTimeStamp}"
  local canonicalHeaders="${canonicalHeader1}\n${canonicalHeader2}\n${canonicalHeader3}\n"
  if [ -n "$AWS_SESSION_TOKEN" ] ; then
    canonicalHeaders="${canonicalHeaders}x-amz-security-token:$AWS_SESSION_TOKEN\n"
  fi
  local hashedPayload=$EMPTY_STRING
  printf "${httpmethod}\n${canonicalURI}\n${canonicalQueryString}\n${canonicalHeaders}\n${SIGNED_HEADERS}\n${hashedPayload}"
}

getStringToSign() {
  sha256() {
    echo -ne "$1" | openssl dgst -sha256 -hex | sed 's/^.* //'
  }

  local canonicalRequest="$1"
  local thisDateStamp="$2"
  local scope="${DATE_STAMP}/${REGION}/${SERVICE}/${REQUEST_TYPE}"
  local canonicalRequestHash="$(sha256 "$canonicalRequest")"
  printf "${HASH_ALG}\n${thisDateStamp}\n${scope}\n${canonicalRequestHash}"
}

getSigningKey() {
  local thisDateStamp=$1
  local dateKey=$(hmac_sha256 key:"AWS4$AWS_SECRET_ACCESS_KEY" "${thisDateStamp}")
  local dateRegionKey=$(hmac_sha256 "hexkey:$dateKey" $REGION)
  local dateRegionServiceKey=$(hmac_sha256 "hexkey:$dateRegionKey" $SERVICE)
  local signingKey=$(hmac_sha256 "hexkey:$dateRegionServiceKey" "aws4_request")
  printf "$signingKey"
}

getSignature() {
  local thisKey=$1
  local thisString=$2
  echo -ne $(hmac_sha256 "hexkey:${thisKey}" "${thisString}")
}

getAuthHeader() {
  local sig=$1
  echo -ne \
    "$HASH_ALG \
    Credential=${AWS_ACCESS_KEY_ID}/${DATE_STAMP}/${REGION}/${SERVICE}/${REQUEST_TYPE}, \
    SignedHeaders=$SIGNED_HEADERS, \
    Signature=${sig}"
}

# When started, setup the static variables
setGlobals

# This is the main loop.  It reads the URI from stdin and outputs the corresponding signed auth header to stdout.
while read inputUri
do

  # Calculate the date and time stamps
  TIME_STAMP="$(date --utc +'%Y%m%dT%H%M%SZ')"
  DATE_STAMP="${TIME_STAMP:0:8}"

  # Parameterized functions to calculate the signature
  thisCanonicalRequest=$(getCanonicalRequest "${inputUri}" "${TIME_STAMP}")

  thisStringToSign=$(getStringToSign "${thisCanonicalRequest}" "${TIME_STAMP}")

  thisSigningKey=$(getSigningKey "${DATE_STAMP}")

  thisSignature=$(getSignature "${thisSigningKey}" "${thisStringToSign}")

  echo $(getAuthHeader "${thisSignature}")

done
