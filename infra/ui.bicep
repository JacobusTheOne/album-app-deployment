param location string = 'brazilsouth'
param environmentName string = 'cae-album-private'
param acrName string = 'ca7e04894508acr'

@description('Image tag to deploy. Supplied by the publishing workflow; no default, so a missing argument fails the deployment instead of silently redeploying a stale image.')
param uiImageTag string

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: environmentName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

var tags = {
  project: 'album-app'
  environment: 'development'
  managedBy: 'bicep'
}

// Derived from the environment rather than passed in, so this template stays
// independent of api.bicep. The internal FQDN only resolves inside the
// environment, which is fine: the frontend calls it server side.
var apiBaseUrl = 'http://album-api.internal.${environment.properties.defaultDomain}'

// See api.bicep: created out of band with its AcrPull grant, so CI needs no
// role-assignment rights.
resource pullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: 'id-album-ui-acrpull'
}

resource ui 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'album-ui'
  location: location
  identity: {
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
        external: true
        targetPort: 3000
        transport: 'Auto'
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: pullIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'album-ui'
          image: '${acr.properties.loginServer}/albumapp-ui:${uiImageTag}'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'API_BASE_URL'
              value: apiBaseUrl
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
}

output uiId string = ui.id
output uiName string = ui.name
output uiPrincipalId string = ui.identity.principalId
output uiFqdn string = ui.properties.configuration.ingress.fqdn
