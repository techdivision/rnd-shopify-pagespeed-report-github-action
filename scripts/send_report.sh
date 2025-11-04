#!/bin/bash

# exit on error
set -e

# check for required inputs
if [ -z "$CLOUD_FUNCTION_URL" ] || [ -z "$PROJECT" ] || [ -z "$COMMIT_HASH" ] || [ -z "$BRANCH" ] || [ -z "$PAGE_TYPE" ] || [ -z "$URL" ]; then
  echo "Error: CLOUD_FUNCTION_URL, PROJECT, COMMIT_HASH, BRANCH, PAGE_TYPE, and URL environment variables are required." >&2
  exit 1
fi

# read pagespeed response from stdin
PAGESPEED_RESPONSE=$(cat)

if [ -z "$PAGESPEED_RESPONSE" ]; then
    echo "Error: PAGESPEED_RESPONSE was not provided via stdin" >&2
    exit 1
fi

# send to Cloud Function
JSON_PAYLOAD=$(jq -n \
  --arg project "$PROJECT" \
  --arg commit_hash "$COMMIT_HASH" \
  --arg branch "$BRANCH" \
  --arg page_type "$PAGE_TYPE" \
  --arg url "$URL" \
  --slurpfile pagespeed_response <(echo "$PAGESPEED_RESPONSE") \
  '{
    project: $project,
    commit_hash: $commit_hash,
    branch: $branch,
    page_type: $page_type,
    url: $url,
    pagespeed_response: ($pagespeed_response[0] | @json)
  }'
)

set +x
echo "$JSON_PAYLOAD" | curl -s -X POST "$CLOUD_FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -d @-

echo ""
echo "Pagespeed report for $URL ($PAGE_TYPE) sent to Cloud Function."
