# Pipelines Orchestrator GitHub Action

This GitHub Action, named "Pipelines Orchestrate," is designed to automate the orchestration of Terragrunt plan/apply/destroy jobs using the Gruntwork Pipelines infrastructure-as-code (IaC) deployment framework. This action helps determine which actions need to take place based on changes to a repository's Terraform or Terragrunt folders.

## Inputs

### `token`

GitHub Personal Access Token (PAT) required for retrieving the pipelines binary. This input is required.

## Outputs

### `jobs`

An array of jobs to be dispatched to the Pipelines Execute step.

## Usage

```yaml
- name: Checkout infra-live repository
  uses: actions/checkout@v4
  with:
    path: infra-live-repo
    fetch-depth: 0

- name: Checkout Pipelines Actions
  uses: actions/checkout@v4
  with:
    path: pipelines-actions
    repository: gruntwork-io/pipelines-actions

- name: Pipelines Orchestrate
  id: orchestrate
  uses: ./pipelines-actions/.github/actions/pipelines-orchestrate
  with:
    token: ${{ secrets.PIPELINES_READ_TOKEN }}
```
