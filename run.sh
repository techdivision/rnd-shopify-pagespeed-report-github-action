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
export GITHUB_RUN_ID="${GITHUB_RUN_ID:-${GITHUB_RUN_ID:-$INPUT_GITHUB_RUN_ID}}"

for VAR_NAME in DRY_RUN STORE ACCESS_TOKEN PROJECT COMMIT_HASH BRANCH CLOUD_FUNCTION_URL SA_KEY GITHUB_RUN_ID; do
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

# run PageSpeed tests
run_test() {
  PAGE_TYPE=$1
  DEVICE_TYPE=$2
  URL=$3

  echo
  echo "Running PageSpeed test for $PAGE_TYPE [$DEVICE_TYPE] ($URL)..."

  for i in {1..3}
  do
    echo "  Run $i of 3..."

    export URL

    # The body of the request should be a JSON object with the following properties:
    # - url: the URL to test
    # - page_type: the type of page being tested (e.g. "home", "product", "collection")
    # - project: the JIRA project ID
    # - commit_hash: the git commit hash
    # - branch: the git branch
    BODY=$(jq -n \
      --arg url "$URL" \
      --arg type "$PAGE_TYPE" \
      --arg device_type "$DEVICE_TYPE" \
      --arg project "$PROJECT" \
      --arg commit_hash "$COMMIT_HASH" \
      --arg branch "$BRANCH" \
      --arg github_run_id "$GITHUB_RUN_ID" \
      '{url: $url, page_type: $type, device_type: $device_type, project: $project, commit_hash: $commit_hash, branch: $branch, github_run_id: $github_run_id}')

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

    PERFORMANCE_SCORE=$(echo "$RESPONSE_JSON" | jq -e '.data.lighthouseResult.categories.performance.score' 2>/dev/null || { echo "null"; echo "$RESPONSE_JSON" >&2; })
    echo "   Performance Score: $PERFORMANCE_SCORE"
  done
}

# home page
run_test "home" "desktop" "https://$STORE/"
run_test "home" "mobile" "https://$STORE/"

# product page
PRODUCT_URL="$(bash "$SCRIPT_DIR/scripts/get_product_url.sh")"
run_test "product" "mobile" "$PRODUCT_URL"
run_test "product" "desktop" "$PRODUCT_URL"

# collection page
COLLECTION_URL="$(bash "$SCRIPT_DIR/scripts/get_collection_url.sh")"
run_test "category" "mobile" "$COLLECTION_URL"
run_test "category" "desktop" "$COLLECTION_URL"

echo "All PageSpeed tests completed."
