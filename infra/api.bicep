// Defaults describe the development environment, so the publishing and
// rollback workflows keep working while passing only the image tag. Every
// other environment supplies all of these through its parameter file in
// infra/parameters/<environment>/api.bicepparam.
@description('Azure region.')
param location string = 'brazilsouth'

@description('Which deployment environment this app belongs to. Drives the environment tag.')
@allowed([
  'development'
  'staging'
  'production'
])
param environmentType string = 'development'

@description('Container Apps managed environment to deploy into. Must already exist.')
param environmentName string = 'cae-album-private'

@description('Container registry holding the API image. One registry is shared by all environments; image tags are commit SHAs, so they never collide.')
param acrName string = 'ca7e04894508acr'

@description('User-assigned identity that pulls from the registry. Created out of band per environment along with its AcrPull grant, so this name must match the target environment.')
param pullIdentityName string = 'id-album-api-acrpull'

@description('Minimum replicas. Zero lets the app and its serverless database scale to nothing; one keeps the readiness probe querying SQL continuously, which prevents the database from auto-pausing.')
@minValue(0)
param minReplicas int = 0

@description('Maximum replicas.')
@minValue(1)
param maxReplicas int = 1

@description('Image tag to deploy. Supplied by the publishing workflow; no default, so a missing argument fails the deployment instead of silently redeploying a stale image.')
param apiImageTag string

@secure()
param databaseUrl string
@description('Name of the existing Key Vault.')
param keyVaultName string = 'kv-album-dev-jj'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}
resource environment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: environmentName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

var tags = {
  project: 'album-app'
  environment: environmentType
  managedBy: 'bicep'
}

// Created out of band along with its AcrPull grant on the registry, so the
// deployment identity needs no role-assignment rights in CI. Because the
// identity outlives the app, the grant is already in place before a newly
// created app pulls its first image.
resource pullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: pullIdentityName
}

resource api 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'album-api'
  location: location
  identity: {
    // The user-assigned identity pulls from ACR. System-assigned is retained
    // because the app authenticates to Azure SQL with it: DefaultAzureCredential
    // resolves to the system-assigned identity as long as AZURE_CLIENT_ID is
    // left unset, so the existing SQL grant keeps working.
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${pullIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 8080
        transport: 'Auto'
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: pullIdentity.id
        }
      ]
      secrets: [
        {
          name: 'database-url'
          value: databaseUrl
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'album-api'
          image: '${acr.properties.loginServer}/album-api:${apiImageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'DATABASE_URL'
              secretRef: 'database-url'
            }
            {
              name: 'KEY_VAULT_URL'
              value: keyVault.properties.vaultUri
            }
            {
              name: 'KEY_VAULT_MANAGED_IDENTITY_CLIENT_ID'
              value: pullIdentity.properties.clientId
            }
          ]
          probes: [
            {
              // The container runs migrations before uvicorn listens, and the
              // database is serverless with auto-pause, so a resume can hold
              // startup for a couple of minutes. A startup probe suspends
              // liveness and readiness until the process is up, so slow
              // startup is not mistaken for a hung process and restarted.
              // failureThreshold x periodSeconds is the budget allowed.
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: 8080
              }
              periodSeconds: 10
              failureThreshold: 30
            }
            {
              // Liveness only checks the process is listening, so it must not
              // depend on SQL: a database blip should not restart the replica.
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
            {
              // Readiness runs a real query, keeping the replica out of
              // rotation until SQL answers. failureThreshold x periodSeconds
              // is the grace period allowed for a database resume.
              type: 'Readiness'
              httpGet: {
                path: '/ready'
                port: 8080
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              failureThreshold: 6
            }
          ]
        }

      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
  tags: tags
}

output apiId string = api.id
output apiName string = api.name
output apiPrincipalId string = api.identity.principalId
