param location string = 'brazilsouth'
param environmentName string = 'cae-album-private'
param acrName string = 'ca7e04894508acr'

@description('Image tag to deploy. Supplied by the publishing workflow; no default, so a missing argument fails the deployment instead of silently redeploying a stale image.')
param apiImageTag string

@secure()
param databaseUrl string

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: environmentName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

var acrPullRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

var tags = {
  project: 'album-app'
  environment: 'development'
  managedBy: 'bicep'
}

// A user-assigned identity can be granted AcrPull before the container app
// exists. A system-assigned identity cannot: the grant can only follow the app
// that owns it, so the first revision fails to pull its image.
resource pullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-album-api-acrpull'
  location: location
  tags: tags
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, pullIdentity.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: pullIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
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
          ]
          probes: [
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
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
  tags: tags
  // Nothing in this resource references acrPull, so the ordering has to be
  // stated outright or the first revision may pull before the grant lands.
  dependsOn: [
    acrPull
  ]
}

output apiId string = api.id
output apiName string = api.name
output apiPrincipalId string = api.identity.principalId
