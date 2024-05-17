# Gruntwork Pipeline Actions

This monorepo houses all the GitHub Actions used as part of Gruntwork Pipelines.

They are intended to be used in the context of [Pipelines Workflows](https://github.com/gruntwork-io/pipelines-workflows), and as such, have logic that is tightly coupled with it and the Pipelines CLI.

Each of the folders located within `.github/actions` are individual GitHub Actions that are used within the Pipelines Workflows, and oftentimes within other actions found here.

## Actions

- [pipelines-aws-execute]: Executes Terragrunt commands in the context of a specific AWS account, using OIDC to assume an appropriate role.
- [pipelines-baseline-account-action]: Baselines an AWS account within the same repository as the one calling the action.
- [pipelines-baseline-child-account-action]: Baselines a child AWS account in a different repository than the one calling the action.
- [pipelines-bootstrap]: Bootstraps Pipelines by extracting all the requisite data needed to execute actions.
- [pipelines-execute]: Executes Terragrunt commands as instructed by `pipelines-orchestrate`.
- [pipelines-orchestrate]: Orchestrates the execution of Terragrunt commands based on changes to a repository.
- [pipelines-preflight-action]: Checks if certain necessary conditions are met before executing a Pipelines workflow.
- [pipelines-provision-access-control-action]: Provisions access control resources for a newly vended AWS account.
- [pipelines-provision-account-action]: Provisions a new AWS account.
- [pipelines-provision-repo-action]: Provisions a new repository integrated with Gruntwork Pipelines.
- [pipelines-status-update]: Updates the status of a Pipelines workflow as a sticky comment on a pull request.

## Monorepo Considerations

Due to the fact that GitHub Actions lack certain flexibility when organized in a monorepo, there are some considerations to keep in mind as to how these actions work:

1. The top level directory of a runner is kept as clean as possible, with work being done within a subdirectory.
2. Actions are used by checking out the monorepo using `actions/checkout` at a specified revision, then referenced in a `uses` field with a relative path.
3. `infrastructure-live` repositories are checked out into a subdirectory of the runner (typically `infra-repo`), and actions are configured to expect the repository to be in that location.

The advantage of accepting these limitations is that it allows for a single source of truth for all actions, and allows for easier management of dependencies between actions. Over time, the objective is to move more and more of the logic into the Pipelines CLI, which will allow for certain actions to be deprecated and reorganized.
