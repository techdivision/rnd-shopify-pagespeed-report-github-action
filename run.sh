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

# determine number of runs (default 3). Enforce 1..5
RAW_RUNS="${RUNS:-${INPUT_RUNS:-3}}"
if ! [[ "$RAW_RUNS" =~ ^[0-9]+$ ]]; then
  RAW_RUNS=3
fi
if [ "$RAW_RUNS" -lt 1 ]; then
  RAW_RUNS=1
elif [ "$RAW_RUNS" -gt 5 ]; then
  RAW_RUNS=5
fi
export RUNS="$RAW_RUNS"

for VAR_NAME in DRY_RUN STORE ACCESS_TOKEN PROJECT COMMIT_HASH BRANCH CLOUD_FUNCTION_URL SA_KEY GITHUB_RUN_ID RUNS; do
  printf "[DEBUG] %s=%s\n" "$VAR_NAME" "${!VAR_NAME}"
done

# track if any request failed (non-200 or curl error) to set final exit code
ERROR_OCCURRED=0

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

  for i in $(seq 1 "$RUNS")
  do
    echo "  Run $i of $RUNS at $(date '+%Y-%m-%d %H:%M:%S')..."

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
      TMP_BODY_FILE=$(mktemp)
      # allow curl to fail without stopping the script, we'll handle status/exit
      set +e
      HTTP_STATUS=$(curl -sS -X POST "$CLOUD_FUNCTION_URL" \
        -H "Authorization: bearer $GCLOUD_AUTH_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$BODY" \
        -o "$TMP_BODY_FILE" -w "%{http_code}")
      CURL_EXIT=$?
      set -e
      RESPONSE_JSON=$(cat "$TMP_BODY_FILE" 2>/dev/null || echo "")
      rm -f "$TMP_BODY_FILE"

      if [ "$CURL_EXIT" -ne 0 ] || [ "$HTTP_STATUS" != "200" ]; then
        echo "   [WARN] Request failed (curl_exit=$CURL_EXIT http_status=$HTTP_STATUS)" >&2
        ERROR_OCCURRED=1
      fi
    fi

    PERFORMANCE_SCORE=$(echo "$RESPONSE_JSON" | jq -e '.data.lighthouseResult.categories.performance.score' 2>/dev/null || { echo "null"; echo "$RESPONSE_JSON" >&2; })
    echo "   Performance Score: $PERFORMANCE_SCORE"

    # wait 3 seconds between runs
    sleep 3
  done
}

# home page
run_test "home" "mobile" "https://$STORE/"
run_test "home" "desktop" "https://$STORE/"

# product page
PRODUCT_URL="$(bash "$SCRIPT_DIR/scripts/get_product_url.sh")"
run_test "product" "mobile" "$PRODUCT_URL"
run_test "product" "desktop" "$PRODUCT_URL"

# collection page
COLLECTION_URL="$(bash "$SCRIPT_DIR/scripts/get_collection_url.sh")"
run_test "category" "mobile" "$COLLECTION_URL"
run_test "category" "desktop" "$COLLECTION_URL"

echo "All PageSpeed tests ran."

# if any request did not return HTTP 200 or curl errored, fail the script at the end
if [ "$ERROR_OCCURRED" -ne 0 ]; then
  echo "One or more requests failed (non-200 or curl error). Failing the job." >&2
  exit 1
fi
