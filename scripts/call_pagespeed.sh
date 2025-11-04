#!/bin/bash

# exit on error
set -e

# check for required inputs
if [ -z "$URL" ] || [ -z "$PAGESPEED_API_KEY" ]; then
  echo "Error: URL and PAGESPEED_API_KEY environment variables are required." >&2
  exit 1
fi

# run PageSpeed Insights
PAGESPEED_API_URL="https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=$URL&key=$PAGESPEED_API_KEY&strategy=mobile&category=accessibility&category=best-practices&category=performance&category=pwa&category=seo"
PAGESPEED_RESPONSE=$(curl --silent --show-error "$PAGESPEED_API_URL")

# output the response
echo "$PAGESPEED_RESPONSE"
