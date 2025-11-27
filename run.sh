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

# check if gcloud is installed
if ! [ -x "$(command -v gcloud)" ]; then
  echo 'Error: gcloud is not installed. Please add a step to install gcloud in your workflow.' >&2
  exit 1
fi

# set script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# get inputs
export STORE="$INPUT_STORE"
export ACCESS_TOKEN="$INPUT_ACCESS_TOKEN"
export PROJECT="$INPUT_PROJECT"
export COMMIT_HASH="$INPUT_COMMIT_HASH"
export BRANCH="$INPUT_BRANCH"
export CLOUD_FUNCTION_URL="https://europe-west3-td-data-warehouse.cloudfunctions.net/td-gcf-pagespeed-metrics-collector"
export SA_KEY="$INPUT_SA_KEY"

for VAR_NAME in STORE ACCESS_TOKEN PROJECT COMMIT_HASH BRANCH CLOUD_FUNCTION_URL SA_KEY DRY_RUN; do
  printf "[DEBUG] %s=%s\n" "$VAR_NAME" "${!VAR_NAME}"
done

# a tmp file for the service account key is needed to authenticate with the cloud function
SA_KEY_FILE=$(mktemp)
echo "$SA_KEY" > "$SA_KEY_FILE"
echo
gcloud auth activate-service-account --key-file="$SA_KEY_FILE"

# get the gcloud auth token
GCLOUD_AUTH_TOKEN=$(gcloud auth print-identity-token)
rm "$SA_KEY_FILE"

# run Pagespeed tests
run_test() {
  PAGE_TYPE=$1
  URL=$2

  echo
  echo "Running Pagespeed test for $PAGE_TYPE ($URL)..."

  for i in {1..3}
  do
    echo "  Run $i of 3..."

    export URL

    # The body of the request should be a JSON object with the following properties:
    # - url: the URL to test
    # - type: the type of page being tested (e.g. "home", "product", "collection")
    # - project: the JIRA project ID
    # - commit_hash: the git commit hash
    # - branch: the git branch
    # - store: the Shopify store URL
    BODY=$(jq -n \
      --arg url "$URL" \
      --arg type "$PAGE_TYPE" \
      --arg project "$PROJECT" \
      --arg commit_hash "$COMMIT_HASH" \
      --arg branch "$BRANCH" \
      --arg store "$STORE" \
      '{url: $url, type: $type, project: $project, commit_hash: $commit_hash, branch: $branch, store: $store}')

    RESPONSE_JSON=""
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "   [DRY_RUN enabled]"
      RESPONSE_JSON=$(cat "$SCRIPT_DIR"/dev/example_response.json)
    else
      RESPONSE_JSON=$(curl -sS -X POST "$CLOUD_FUNCTION_URL" \
        -H "Authorization: bearer $GCLOUD_AUTH_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$BODY")
    fi

    PERFORMANCE_SCORE=$(echo "$RESPONSE_JSON" | jq '.data.lighthouseResult.categories.performance.score')
    echo "   Performance Score: $PERFORMANCE_SCORE"
  done
}

# home page
run_test "home" "https://$STORE/"

# product page
PRODUCT_URL="$(bash "$SCRIPT_DIR/scripts/get_product_url.sh")"
run_test "product" "$PRODUCT_URL"

# collection page
COLLECTION_URL="$(bash "$SCRIPT_DIR/scripts/get_collection_url.sh")"
run_test "collection" "$COLLECTION_URL"

echo "All Pagespeed tests completed."
