# Pagespeed Report for Shopify GitHub Action

This action runs a Pagespeed report on a Shopify store and sends the report to a Google Cloud Function.

## To do

- Implement logic to preview other branches (temp theme)

## Inputs

- `store`: The Shopify store URL. (required)
- `access_token`: The Shopify access token. (required)
- `project`: The JIRA project key, used as the `project` dimension in reporting. (required)
- `commit_hash`: The git commit hash. (required)
- `branch`: The git branch. (required)
- `runs`: How many times to repeat each PageSpeed test, 1 to 5. (optional, default 3)

## Authentication

The action authenticates through **Workload Identity Federation**. There is no service
account key any more — the `sa_key` input was removed. GitHub's OIDC token is exchanged for
a short-lived identity token inside the action.

Two consequences for the calling workflow:

1. The job must grant `id-token: write`. A composite action cannot grant this to itself.
   Only use it in `schedule`, `push` or `workflow_dispatch` workflows, never in
   `pull_request`.
2. The calling repository must be on the WIF allowlist of `td-pagespeed-metrics`. The OIDC
   token identifies the repository that *calls* the action, not this repository. To add a
   shop, ask the data team (see DATASUP-334).

Measurements go to
`https://europe-west3-td-pagespeed-metrics.cloudfunctions.net/td-gcf-pagespeed-metrics-collector`
and land in `td-pagespeed-metrics.pagespeed_raw.pagespeed_data`.

## Local test

1. Configure the local env file (copy the `.dist` template in this repo)
2. Run PageSpeed Google Cloud Ingestor locally `npx functions-framework --target=ingestPageSpeed --port=8080`
3. Run `./run.sh`

Note: the env template still carries the removed `INPUT_SA_KEY` variable. Local runs now
need `ID_TOKEN` instead — either a token obtained with
`gcloud auth print-identity-token`, or any value when pointing `CLOUD_FUNCTION_URL` at a
local functions-framework instance that does not verify it.

## Example Usage

See `dev/example_github_workflow.yml`.
