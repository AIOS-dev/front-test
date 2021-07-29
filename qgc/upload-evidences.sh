#!/bin/sh -x
# Script to upload evidences to QGC

set -e
X_MS_DATE_H="x-ms-date:$(TZ=GMT LC_ALL=C date "+%a, %d %h %Y %H:%M:%S %Z")"

# This script use the following env variable (default github env or secrets):
for env in QGC_URL QGC_CREDENTIALS QGC_COMPONENT_ID QGC_ORGANIZATION_ID QGC_EVIDENCES_PATH \
           GITHUB_SERVER_URL GITHUB_REPOSITORY GITHUB_REF; do
  eval "value=\$${env}"
  if [ -z "${value}" ]; then
    echo "Missing variable ${env}. Please set it and rerun this script (export ${env}=VALUE)"
    exit 1
  fi
done

cat <<EOF >/tmp/request.json
{
  "componentId": "$QGC_COMPONENT_ID",
  "url": "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}.git",
  "branchName": "$GITHUB_REF"
}
EOF

json_to_values() {
  sed 's/":"/="/g' "$1" | sed -E 's/"?,"/"'"\n"'/g' | sed 's/"}/"/' | grep "="
}

curl -s -X POST --user "${QGC_CREDENTIALS}" -d @/tmp/request.json \
  -H "accept: application/json" -H "Content-Type: application/json" \
  "${QGC_URL}/api/applications/$QGC_ORGANIZATION_ID/componentqg/UNIT_TESTS/upload" >/tmp/response.json
json_to_values /tmp/response.json >/tmp/info.sh

. /tmp/info.sh

if [ -z "${blobContainerUrl}" ]; then
  echo "Something went wrong: ${message}"
  exit 1
fi

cd "${QGC_EVIDENCES_PATH}"

for file in $(find . -type f -name "*.txt" -o -name "*.xml"); do
  echo "Uploading $file"
  curl -sf -X "PUT" -T "$file" \
    -H "${X_MS_DATE_H}" -H "x-ms-blob-type: BlockBlob" \
    "${blobContainerUrl}/${file}?${sasSignature}"
done

echo "Launch UT analyzer"
curl -s -X POST --user "${QGC_CREDENTIALS}" -H "accept: application/json" \
  "${QGC_URL}/api/applications/${QGC_ORGANIZATION_ID}/componentqg/UNIT_TESTS/process/${containerName}"

echo
echo "Waiting for completion"
for i in 10 5 5 5 5 5 5 5 5 10 10 10 10; do
  URL="${QGC_URL}/api/applications/${QGC_ORGANIZATION_ID}/componentqg/UNIT_TESTS/executions?containerName=${containerName}"
  # Retrieve analyse status
  curl -s --user "${QGC_CREDENTIALS}" -H "accept: application/json" "${URL}" >/tmp/response.json
  json_to_values /tmp/response.json >/tmp/info.sh
  . /tmp/info.sh
  if [ -z "${status}" ]; then
    echo "Something is wrong: status is empty ($message/$details)"
    exit 1
  fi
  if [ "${status}" = "SUCCESS" ]; then
    echo "XUnit files are valid"
    exit
  fi
  if [ "${status}" = "FAILED" ]; then
    echo "XUnit files are invalid"
    exit 1
  fi
  sleep "${i}"
done

echo "Timeout while waiting for end of analyzing completion"
exit 2
