# Federated credentials

Workload identity federation lets the GitHub Actions workflows sign in to Azure
with no stored secret: Entra trusts a token GitHub issues for a specific
repository and branch. These files record that trust so it can be recreated.

They are a record, not something a deployment applies — Bicep cannot manage
Entra app registrations. Nothing reads them automatically.

## Which app registration

Both credentials below belong to **`github-actions-api-deployer`**
(appId `baee0352-43dd-43ec-a4b9-5eaf0d2c5ee4`), the identity the deploy jobs
use via the `AZURE_DEPLOY_CLIENT_ID` repository variable. It needs one
credential per repository that deploys, because the subject names the repo:

| File | Repository |
| --- | --- |
| `api-main.json` | `containerapps-albumapi-python`, `main` |
| `frontend-main.json` | `containerapps-albumui`, `main` |

A second app registration (`e52d9b2f-3ccd-4a13-a5af-a2d067659a87`) holds
AcrPush and only pushes images. It has its own equivalent pair of credentials,
not recorded here.

## Re-applying one

```bash
az ad app federated-credential create \
  --id baee0352-43dd-43ec-a4b9-5eaf0d2c5ee4 \
  --parameters @infra/federated-credentials/api-main.json
```

On Windows, pass a native path (`@C:/...`) rather than a Git Bash path, and
set `MSYS_NO_PATHCONV=1` so the shell does not rewrite arguments beginning
with `/`.

## About the subject format

The `@47494589` and `@1439957998` suffixes are the owner and repository IDs.
They are not a mistake: GitHub switched to an immutable `sub` claim carrying
these IDs for repositories created after 2026-07-15, which these were. The
older format was `repo:OWNER/REPO:ref:refs/heads/BRANCH`.

Because the IDs are immutable, a repository rename does not break the trust —
but these files then no longer show the current repository name, so update the
table above if a repo is renamed.

A mismatch between the token's `sub` and the credential's subject fails the
login with `AADSTS70021`, naming no detail — compare the two strings exactly,
including case.

## Not recorded here

These credentials are only part of the out-of-band setup the pipeline depends
on. The rest — the ACR pull identities, their AcrPull grants, the deployer's
Managed Identity Operator grants, and the custom `ARM Deployment Operator`
role — is also absent from every template.
