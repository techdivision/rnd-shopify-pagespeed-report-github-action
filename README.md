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
- `sa_key`: The Google Cloud service account key. (required)

## Local test

1. Configure `.env` file (copy from `.env.dist`)
2. Run PageSpeed Google Cloud Ingestor locally `npx functions-framework --target=ingestPageSpeed --port=8080`
3. Run `./run.sh`

## Example Usage

See `dev/example_github_workflow.yml`.
