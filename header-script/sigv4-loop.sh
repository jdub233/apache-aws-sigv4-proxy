#!/bin/bash

AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Source: https://docs.aws.amazon.com/general/latest/gr/sigv4-signed-request-examples.html

[[ -n "${AWS_ACCESS_KEY_ID}" ]]     || { echo "AWS_ACCESS_KEY_ID required" >&2; exit 1; }
[[ -n "${AWS_SECRET_ACCESS_KEY}" ]] || { echo "AWS_SECRET_ACCESS_KEY required" >&2; exit 1; }

readonly parameterName="SlawekTestParam"

readonly method="POST"
readonly service="ssm"
readonly host="ssm.us-west-2.amazonaws.com"
readonly region="us-west-2"
readonly endpoint="https://${host}/"
readonly contentType="application/x-amz-json-1.1"
readonly amazonTarget="AmazonSSM.GetParameter"
readonly requestParameters="$(printf '{"Name":"%s","WithDecryption":true}' "${parameterName}")"
#readonly amazonDate="$(date -u +'%Y%m%dT%H%M%SZ')"
#readonly dateStamp="$(date -u +'%Y%m%d')"
# readonly amazonDate="20200429T093445Z"
# readonly dateStamp="20200429"

function sha256 {
    echo -ne "$1" | openssl dgst -sha256 -hex
}

function hex {
    echo -ne "$1" | hexdump | sed -e 's/^[0-9a-f]*//' -e 's/ //g' | tr -d '\n'
}

function sign {
    local hexKey="$1"
    local msg="$2"

    # Hack for debian which appears to add a prefix of '(stdin)= ' to the output.
    # This just removes that prefix.
    hexKey="${hexKey#(stdin)= }"

    echo -ne "${msg}" | openssl dgst -sha256 -mac hmac -macopt "hexkey:${hexKey}"
}

function getSignatureKey {
    local key="$1"
    local dateStamp1="$2"
    local regionName="$3"
    local serviceName="$4"
    local kDate kRegion kService kSigning

    kDate="$(sign "$(hex "AWS4${key}")" "${dateStamp1}")"
    kRegion="$(sign "${kDate}" "${regionName}")"
    kService="$(sign "${kRegion}" "${serviceName}")"
    kSigning="$(sign "${kService}" "aws4_request")"

    # Hack for debian which appears to add a prefix of '(stdin)= ' to the output
    kSigning="${kSigning#(stdin)= }"

    echo -ne "${kSigning}"
}

while read inputUri
do

# --- TASK 1: create canonical request ---

amazonDate="$(date -u +'%Y%m%dT%H%M%SZ')"
dateStamp="$(date -u +'%Y%m%d')"

canonicalUri=${inputUri}
canonicalQueryString=""
canonicalHeaders="content-type:${contentType}\nhost:${host}\nx-amz-date:${amazonDate}\nx-amz-target:${amazonTarget}\n"
signedHeaders="content-type;host;x-amz-date;x-amz-target"
payloadHash="$(sha256 "${requestParameters}")"

canonicalRequest="${method}\n${canonicalUri}\n${canonicalQueryString}\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}"

# --- TASK 2: create the string to sign ---

algorithm="AWS4-HMAC-SHA256"
credentialScope="${dateStamp}/${region}/${service}/aws4_request"

stringToSign="${algorithm}\n${amazonDate}\n${credentialScope}\n$(sha256 "${canonicalRequest}")"

# --- TASK 3: calculate the signature ---

signingKey="$(getSignatureKey "${AWS_SECRET_ACCESS_KEY}" "${dateStamp}" "${region}" "${service}")"

signature="$(sign "${signingKey}" "${stringToSign}")"

# --- TASK 4: add signing information to the request ---

authorizationHeader="${algorithm} Credential=${AWS_ACCESS_KEY_ID}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature#(stdin)= }"

# --- SEND REQUEST ---

echo $authorizationHeader

done

#curl --fail --silent \
#    "${endpoint}" \
#    --data "${requestParameters}" \
#    --header "Accept-Encoding: identity" \
#    --header "Content-Type: ${contentType}" \
#    --header "X-Amz-Date: ${amazonDate}" \
#    --header "X-Amz-Target: ${amazonTarget}" \
#    --header "Authorization: ${authorizationHeader}"