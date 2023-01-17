#!/bin/bash

AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Source: https://docs.aws.amazon.com/general/latest/gr/sigv4-signed-request-examples.html

[[ -n "${AWS_ACCESS_KEY_ID}" ]]     || { echo "AWS_ACCESS_KEY_ID required" >&2; exit 1; }
[[ -n "${AWS_SECRET_ACCESS_KEY}" ]] || { echo "AWS_SECRET_ACCESS_KEY required" >&2; exit 1; }
[[ -n "${AWS_SECURITY_TOKEN}" ]]    || { echo "AWS_SECURITY_TOKEN required" >&2; exit 1; }
[[ -n "${OBJECT_LAMBDA_HOST}" ]]    || { echo "OBJECT_LAMBDA_HOST required" >&2; exit 1; }


readonly method="GET"
readonly service="s3-object-lambda"
readonly host="${OBJECT_LAMBDA_HOST}"
readonly region="us-east-1"
readonly emptyContentSha256="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" # This is the SHA256 of an empty string.

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

# After declaring the functions and the static values, we can start the read loop
# Apache will pass the Request-URI to stdin of the script, and it will respond with the corresponding authorization header
while read inputUri
do

# --- TASK 1: create canonical request ---

amazonDate="$(date -u +'%Y%m%dT%H%M%SZ')" # This has to match the x-amz-date header that apache generates
dateStamp="$(date -u +'%Y%m%d')"

canonicalUri=${inputUri}
canonicalQueryString=""
canonicalHeaders="host:${host}\nx-amz-content-sha256:${emptyContentSha256}\nx-amz-date:${amazonDate}\nx-amz-security-token:${AWS_SECURITY_TOKEN}\n" # \n Last newline is needed???
signedHeaders="host;x-amz-content-sha256;x-amz-date;x-amz-security-token"
payloadHash=${emptyContentSha256}

canonicalRequest="${method}\n${canonicalUri}\n${canonicalQueryString}\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}"

# --- TASK 2: create the string to sign ---

algorithm="AWS4-HMAC-SHA256"
credentialScope="${dateStamp}/${region}/${service}/aws4_request"

hashedCanonicalRequest="$(sha256 "${canonicalRequest}")"
# Hack for debian which appears to add a prefix of '(stdin)= ' to the output
hashedCanonicalRequest="${hashedCanonicalRequest#(stdin)= }"

stringToSign="${algorithm}\n${amazonDate}\n${credentialScope}\n${hashedCanonicalRequest}"

# --- TASK 3: calculate the signature ---

signingKey="$(getSignatureKey "${AWS_SECRET_ACCESS_KEY}" "${dateStamp}" "${region}" "${service}")"

signature="$(sign "${signingKey}" "${stringToSign}")"
# Hack for debian which appears to add a prefix of '(stdin)= ' to the output
signature="${signature#(stdin)= }"

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