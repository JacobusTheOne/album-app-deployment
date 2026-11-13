# Environment parameters

One `.bicepparam` file per template per environment. A parameter file declares
its template with `using`, so it targets exactly one template — the three
templates here are deployed independently, which is why each environment
directory holds three files rather than one.

```
parameters/
├── dev/      main · api · ui   (deployed)
├── staging/  main · api · ui   (structure only, never deployed)
└── prod/     main · api · ui   (structure only, never deployed)
```

## What varies, and what does not

| Setting | dev | staging | prod |
| --- | --- | --- | --- |
| Environment tag | `development` | `staging` | `production` |
| Container Apps env | `cae-album-private` | `cae-album-staging` | `cae-album-prod` |
| VNet / address space | `vnet-album-private` · `10.0.0.0/16` | `vnet-album-staging` · `10.1.0.0/16` | `vnet-album-prod` · `10.2.0.0/16` |
| Log Analytics | `law-album-dev-jj` | `law-album-staging-jj` | `law-album-prod-jj` |
| Log retention / daily cap | 30 days · 1 GB | 30 days · 2 GB | 90 days · 5 GB |
| SQL server | `sql-album-dev-jj` | `sql-album-staging-jj` | `sql-album-prod-jj` |
| API replicas | 0–1 | 1–2 | 1–3 |
| UI replicas | 0–1 | 1–2 | 1–3 |
| Registry | `ca7e04894508acr` — shared by all environments |

Address spaces do not overlap, so the VNets can be peered later without
renumbering.

Deliberately **not** parameterised, because they are contract rather than
configuration: probe paths and ports, `targetPort`, container names, the
`snet-container-apps` subnet name and its `Microsoft.App/environments`
delegation, the `project` and `managedBy` tags, and the private DNS zone name
`privatelink.database.windows.net` — that last one is fixed by Azure, which
also means **two environments cannot share a resource group**.

Dev's resource names predate the convention the other two follow. They are kept
verbatim because a changed `name` in Bicep creates a *new* resource; ARM has no
rename. Renaming dev would mean rebuilding its container apps, private endpoint
and DNS records, so it is left as its own exercise.

## Deploying

`using` supplies the template, so `--template-file` is not passed — and passing
both is an error.

```sh
# Platform: network, Container Apps environment, SQL firewall rule, monitoring
az deployment group what-if \
  --resource-group rg-azure-container-apps-dev \
  --parameters infra/parameters/dev/main.bicepparam

az deployment group create \
  --resource-group rg-azure-container-apps-dev \
  --name main-$(date +%Y%m%d-%H%M%S) \
  --parameters infra/parameters/dev/main.bicepparam
```

Always run `what-if` against `main.bicep` first. It owns the networking, and a
mistyped resource name shows up there as a `Create` beside the resource it was
meant to replace.

`--name` matters: a deployment name is a record in the resource group's history,
and reusing one overwrites the previous entry.

The app templates read their image tag — and, for the API, the database URL —
from the environment at compile time via `readEnvironmentVariable`, so a deploy
needs no `--parameters key=value` arguments. An unset variable fails the build
rather than deploying a stale image or an empty connection string:

```sh
API_IMAGE_TAG=<40-char commit sha> DATABASE_URL=<connection string> \
az deployment group create \
  --resource-group rg-azure-container-apps-dev \
  --name api-<sha> \
  --parameters infra/parameters/dev/api.bicepparam
```

Validate every file without touching Azure:

```sh
az bicep build-params --file infra/parameters/dev/main.bicepparam --stdout
```

## Pending: point the workflows at these files

`api.bicep` and `ui.bicep` keep defaults describing **dev**, so the existing
workflows — which pass only an image tag — continue to work unchanged. The
switch has to happen in this order, because both workflows check out this
repository's *default branch* with no `ref:`, and so cannot see a parameter file
that has not merged yet:

1. Merge these parameter files to `main` here.
2. Then, in `containerapps-albumapi-python`, change the deploy step of
   `.github/workflows/publish-azure.yaml` and `rollback-azure.yaml` from
   `--template-file deployment/infra/api.bicep --parameters apiImageTag=…` to
   `--parameters deployment/infra/parameters/dev/api.bicepparam`, exporting
   `API_IMAGE_TAG` and `DATABASE_URL` as step `env:`. Same for `UI_IMAGE_TAG` in
   `code-to-cloud-ui`.

Until step 2 lands, the parameter files are the source of truth for staging and
prod only, and dev is still driven by the template defaults.

## Before a second environment can be deployed

`main.bicep` is not enough on its own. Each environment also needs, created out
of band:

- its **own resource group** (the private DNS zone name collides otherwise),
- the **Azure SQL server** named in its parameter file — `main.bicep` references
  it as `existing` and only manages its VNet firewall rule, and SQL server names
  are globally unique,
- the two **user-assigned identities** named in `api.bicepparam` and
  `ui.bicepparam`, each granted **AcrPull** on `ca7e04894508acr`,
- **Managed Identity Operator** for the deploy identity on each of those,
- the custom **ARM Deployment Operator** role assigned to the deploy identity at
  the new resource group's scope,
- a **federated credential** per environment if deploys are gated behind GitHub
  Environments, since the subject changes from
  `repo:…:ref:refs/heads/main` to `repo:…:environment:<name>`.

## One cost consequence of `minReplicas: 1`

The API's readiness probe runs a real SQL query every 10 seconds. At
`minReplicas: 0` that traffic stops when the app scales to zero and the
serverless database auto-pauses. At `minReplicas: 1` the probe becomes a
permanent keep-alive, so the database never pauses — which is the point for an
environment meant to catch cold-start problems, but it is a continuous cost per
environment, not a rounding error.
