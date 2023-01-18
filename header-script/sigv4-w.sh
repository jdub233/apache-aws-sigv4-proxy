#!/bin/bash

# This script creates a signed AWS API s3 getObject request.
# Related AWS documentation:
#   - https://docs.aws.amazon.com/general/latest/gr/create-signed-request.html#create-canonical-request
#   - https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html
#   - https://czak.pl/2015/09/15/s3-rest-api-with-curl.html

# EXAMPLES:

  # ----------------------------------------------------------------
  #    Get creds from profile and pass an explicit timestamp
  # ----------------------------------------------------------------
  # sh signer.sh \
  #   profile=infnprd \
  #   task=curl \
  #   object_key=2.jpg \
  #   time_stamp=$(date --utc +'%Y%m%dT%H%M000000Z')
  # 
  # ----------------------------------------------------------------
  #    Export the credentials and invoke default of current timestamp
  # ----------------------------------------------------------------
  # set -a
  # aws_access_key_id=[id]
  # aws_secret_access_key=[key]
  # aws_session_token=[token]
  # sh signer.sh \
  #   task=curl \
  #   object_key=2.jpg

# These are just example values, not real credentials. These should be set in the environment.
AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
AWS_SECURITY_TOKEN="AQoEXAMPLEH4aoAH0gNCAPyJxz4BlCFFxWNE1OPTgk5TthT+FvwqnKwRcOIfrRh3c/LTo6UDdyJwOOvEVPvLXCrrrUtdnniCEXAMPLE/IvU1dYUg2RVAJBanLiHb4IgRmpRV3zrkuWJOgQs8IZZaIv2BXIa2R4OlgkBN9bkUDNCJiBeb/AXlzBBko7b15fjrBs2+cTQtpZ3CYWFXG8C5zqx37wnOE49mRl/+OtkIKGO7fAE"
OBJECT_LAMBDA_HOST="example.s3-object-lambda.us-east-1.amazonaws.com"

AWS_SESSION_TOKEN="${AWS_SECURITY_TOKEN}"

[[ -n "${AWS_ACCESS_KEY_ID}" ]]     || { echo "AWS_ACCESS_KEY_ID required" >&2; exit 1; }
[[ -n "${AWS_SECRET_ACCESS_KEY}" ]] || { echo "AWS_SECRET_ACCESS_KEY required" >&2; exit 1; }
[[ -n "${AWS_SECURITY_TOKEN}" ]]    || { echo "AWS_SECURITY_TOKEN required" >&2; exit 1; }
[[ -n "${OBJECT_LAMBDA_HOST}" ]]    || { echo "OBJECT_LAMBDA_HOST required" >&2; exit 1; }


setGlobals() {  
  #[ -z "$TIME_STAMP" ] && TIME_STAMP="$(date --utc +'%Y%m%dT%H%M%SZ')"
  #DATE_STAMP="${TIME_STAMP:0:8}"
  SERVICE="s3-object-lambda"
  HASH_ALG='AWS4-HMAC-SHA256'
  REQUEST_TYPE='aws4_request'
  SIGNED_HEADERS="host;x-amz-content-sha256;x-amz-date"
  EMPTY_STRING="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  [ -n "$AWS_SESSION_TOKEN" ] && SIGNED_HEADERS="$SIGNED_HEADERS;x-amz-security-token"
  [ -z "$REGION" ] && REGION="us-east-1"
  [ -z "$HOST" ] && HOST=${OBJECT_LAMBDA_HOST}
  [ -z "$OBJECT_KEY" ] && OBJECT_KEY="2.jpg"
}

hmac_sha256() {
  key="$1"
  data="$2"
  echo -ne "$data" | openssl dgst -sha256 -mac HMAC -macopt "$key" | sed 's/^.* //' | tr -d '\n'
}

getCanonicalRequest() {
  local httpmethod="GET"
  local canonicalURI="/${OBJECT_KEY}"
  local canonicalQueryString=""
  local canonicalHeader1="host:$HOST"
  local canonicalHeader2="x-amz-content-sha256:$EMPTY_STRING"
  local canonicalHeader3="x-amz-date:${TIME_STAMP}"
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
  local scope="${DATE_STAMP}/${REGION}/${SERVICE}/${REQUEST_TYPE}"
  local canonicalRequest="$(getCanonicalRequest)"
  local canonicalRequestHash="$(sha256 "$canonicalRequest")"
  printf "${HASH_ALG}\n${TIME_STAMP}\n${scope}\n${canonicalRequestHash}"
}

getSigningKey() {
  local dateKey=$(hmac_sha256 key:"AWS4$AWS_SECRET_ACCESS_KEY" $DATE_STAMP)
  local dateRegionKey=$(hmac_sha256 "hexkey:$dateKey" $REGION)
  local dateRegionServiceKey=$(hmac_sha256 "hexkey:$dateRegionKey" $SERVICE)
  local signingKey=$(hmac_sha256 "hexkey:$dateRegionServiceKey" "aws4_request")
  printf "$signingKey"
}

getSignature() {
  echo -ne $(hmac_sha256 "hexkey:$(getSigningKey)" "$(getStringToSign)")
}

getAuthHeader() {
  echo -ne \
    "$HASH_ALG \
    Credential=${AWS_ACCESS_KEY_ID}/${DATE_STAMP}/${REGION}/${SERVICE}/${REQUEST_TYPE}, \
    SignedHeaders=$SIGNED_HEADERS, \
    Signature=$(getSignature)"
}

setGlobals

while read inputUri
do

  TIME_STAMP="$(date --utc +'%Y%m%dT%H%M%SZ')"
  DATE_STAMP="${TIME_STAMP:0:8}"

  [ -z "$OBJECT_KEY" ] && OBJECT_KEY="2.jpg"

#echo "Date: ${TIME_STAMP}"
#echo "\n"

  echo ${inputUri}
  echo ${TIME_STAMP}
  echo ${DATE_STAMP}

#echo $(getAuthHeader)

done