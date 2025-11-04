#!/bin/bash

# exit on error
set -e

# check for required inputs
if [ -z "$STORE" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Error: STORE and ACCESS_TOKEN environment variables are required." >&2
  exit 1
fi

# shopify GraphQL Query
SHOPIFY_GRAPHQL_URL="https://$STORE/admin/api/2025-10/graphql.json"
QUERY='{collections(first: 1){edges{node{handle}}}}'

# get collection URL
SHOPIFY_RESPONSE=$(curl -s -X POST "$SHOPIFY_GRAPHQL_URL" \
  -H "X-Shopify-Access-Token: $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"$QUERY\"}")

COLLECTION_HANDLE=$(echo "$SHOPIFY_RESPONSE" | jq -r '.data.collections.edges[0].node.handle')

if [ -z "$COLLECTION_HANDLE" ]; then
  echo "Error: Could not get collection handle from Shopify." >&2
  exit 1
fi

echo "https://$STORE/collections/$COLLECTION_HANDLE"
