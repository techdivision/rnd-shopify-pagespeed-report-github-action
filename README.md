# Pagespeed Report for Shopify GitHub Action

This action runs a Pagespeed report on a Shopify store and sends the report to a Google Cloud Function.

## To do

- Implement logic to preview other branches (temp theme)

## Inputs

- `store`: The Shopify store URL. (required)
- `access_token`: The Shopify access token. (required)
- `project`: The Google Cloud project ID. (required)
- `commit_hash`: The git commit hash. (required)
- `branch`: The git branch. (required)
- `cloud_function_url`: The URL of the Google Cloud Function. (required)
- `pagespeed_api_key`: The Google PageSpeed Insights API key. (required) This action fetches a comprehensive report
  including performance, SEO, accessibility, and best-practices scores.

## Local test

1. Configure `.env` file (copy from `.env.dist`)
2. Run PageSpeed Google Cloud Ingestor locally `npx functions-framework --target=ingestPageSpeed --port=8080`
3. Run `./run.sh`

## Example Usage

```yaml
name: Pagespeed Report

on:
  push:
    branches:
      - main

jobs:
  pagespeed:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2

      - name: Run Pagespeed Report
        uses: ./
        with:
          project: 'CHANGEME'
          store: 'changeme.myshopify.com'
          access_token: ${{ secrets.SHOPIFY_ACCESS_TOKEN }}
          commit_hash: ${{ github.sha }}
          branch: ${{ github.ref_name }}
          cloud_function_url: ${{ secrets.PAGESPEED_CLOUD_FUNCTION_URL }}
          pagespeed_api_key: ${{ secrets.PAGESPEED_API_KEY }}
```
