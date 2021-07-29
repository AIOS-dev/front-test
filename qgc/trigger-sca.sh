#!/bin/sh

# This script use the following env variable (default github env or secrets):
for env in QGC_URL QGC_CREDENTIALS QGC_COMPONENT_ID QGC_ORGANIZATION_ID QGC_SCA_QG_NAME \
           GITHUB_SERVER_URL GITHUB_REPOSITORY GITHUB_REF; do
  eval "value=\$${env}"
  if [ -z "${value}" ]; then
    echo "Missing variable ${env}. Please set it and rerun this script (export ${env}=VALUE)"
    exit 1
  fi
done

curl --user "${QGC_CREDENTIALS}" \
  "${QGC_URL}/api/applications/${QGC_ORGANIZATION_ID}/componentqg/SOURCE_CODE_ANALYSIS/components/${QGC_COMPONENT_ID}/execution" \
  -H "Content-Type: application/json" \
  -d "{\"branchName\":\"${GITHUB_REF}\",\"gitUrl\":\"${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}.git\",\"qualityGateName\":\"${QGC_SCA_QG_NAME}\"}"
