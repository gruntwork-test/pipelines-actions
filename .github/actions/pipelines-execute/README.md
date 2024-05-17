# Pipelines Execute

This GitHub Action automates running Terragrunt (and eventually other) commands in a secure environment.
It is designed to be run in your `<company-name>/infrastructure-live-root` repository as part of Gruntwork Pipelines.

## Env

- `PIPELINES_CLI_VERSION` (required): The version of the Gruntwork Pipelines CLI to use.

## Inputs

- `working_directory` (required): The folder path to run the Terragrunt command in.
- `with_ssh_enabled` (optional): Set to `true` to enable debugging via SSH using [mxschmitt/action-tmate](https://github.com/marketplace/actions/debugging-with-tmate).
- `terragrunt_command` (required): The Terragrunt command to execute. Default is `"plan"`.
- `token` (required): The GitHub token used for the Terragrunt action.
- `tg_version` (required): The Terragrunt version to install. Default is `"0.48.1"`.
- `tf_version` (required): The Terraform version to install. Default is `"1.0.11"`.
- `tg_execution_parallelism_limit` (optional): "Maximum number of concurrently executed Terraform modules during Terragrunt execution". Default is `0`(no-limit).
- `infra_live_repo` (required): The name of the infrastructure-live repo to execute in.
- `infra_live_directory` (required): The name of the directory containing the infrastructure-live repo on disk.
- `infra_live_repo_branch` (required): The branch of the infrastructure-live repo to execute in.
- `gruntwork_config` (optional): Contents of the Gruntwork config file in the infrastructure-live-root repo. NOTE: One of gruntwork_config or gruntwork_config_file MUST be passed in.
- `gruntwork_config_file` (optional): Absolute path to the Gruntwork config file in the infrastructure-live-root. NOTE: One of gruntwork_config or gruntwork_config_file MUST be passed in.

## Outputs

- `plan`: The plan output from the Terragrunt execution.

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

- name: "Read in Gruntwork context"
  id: gruntwork_context
  uses: ./pipelines-actions/.github/actions/pipelines-bootstrap

- name: Authenticate to AWS
  id: aws_auth
  uses: aws-actions/configure-aws-credentials@v4
  with:
    # We can authenticate to any valid region, the IaC configured provider determines what region resources are created
    # in. As a result we can pass the default aws region.
    aws-region: ${{ steps.gruntwork_context.outputs.default_aws_region }}
    role-to-assume: "arn:aws:iam::${{ inputs.account_id }}:role/${{ inputs.account_role_name }}"
    role-duration-seconds: 3600
    role-session-name: ${{ inputs.role_session_name }}

- name: "[Terragrunt Execute] Run terragrunt ${{ inputs.terragrunt_command }} in ${{ inputs.working_directory }}"
  if: ${{ steps.aws_auth.outcome == 'success' }}
  id: execute
  uses: ./pipelines-actions/.github/actions/pipelines-execute
  with:
    token: ${{ inputs.PIPELINES_READ_TOKEN }}
    tf_binary: ${{ steps.gruntwork_context.outputs.tf_binary }}
    working_directory: ${{ inputs.working_directory }}
    terragrunt_command: ${{ steps.gruntwork_context.outputs.terragrunt_command }}
    infra_live_repo_branch: ${{ steps.gruntwork_context.outputs.branch }}
    gruntwork_config_file: ${{ steps.gruntwork_context.outputs.gruntwork_config_file }}
    infra_live_repo: "."
    infra_live_directory: "."
    deploy_branch_name: ${{ steps.gruntwork_context.outputs.deploy_branch_name }}
```

This example workflow snippet defines part of a job that runs Terragrunt with the specified parameters.
