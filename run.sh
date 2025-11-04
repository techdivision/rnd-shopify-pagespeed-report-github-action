#!/bin/bash

# load environment variables if .env file exists
if [ -f "$(dirname "$0")/.env" ]; then
  set -a
  source "$(dirname "$0")/.env"
  set +a
fi

# exit on error
set -e

# check if jq is installed
if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed.' >&2
  exit 1
fi

# get inputs
export STORE="$INPUT_STORE"
export ACCESS_TOKEN="$INPUT_ACCESS_TOKEN"
export PROJECT="$INPUT_PROJECT"
export COMMIT_HASH="$INPUT_COMMIT_HASH"
export BRANCH="$INPUT_BRANCH"
export CLOUD_FUNCTION_URL="$INPUT_CLOUD_FUNCTION_URL"
export PAGESPEED_API_KEY="$INPUT_PAGESPEED_API_KEY"

# run Pagespeed tests

run_test() {
  PAGE_TYPE=$1
  URL=$2

  echo "Running Pagespeed test for $PAGE_TYPE ($URL)..."

  for i in {1..3}
  do
    echo "  Run $i of 3..."

    export URL

    DRY_RUN=false
    TEMP_FILE=$(mktemp)
    if [ "$DRY_RUN" = true ]; then
        cp tmp/last_response.json "$TEMP_FILE"
    else
        bash "scripts/call_pagespeed.sh" > "$TEMP_FILE"
        cp "$TEMP_FILE" tmp/last_response.json
    fi

    export PAGE_TYPE
    bash "scripts/send_report.sh" < "$TEMP_FILE"

    rm "$TEMP_FILE"
  done
}

# home page
run_test "home" "https://$STORE/"

# product page
PRODUCT_URL=$(bash "scripts/get_product_url.sh")
run_test "product" "$PRODUCT_URL"

# collection page
COLLECTION_URL=$(bash "scripts/get_collection_url.sh")
run_test "collection" "$COLLECTION_URL"

echo "All Pagespeed tests completed."
