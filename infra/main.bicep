
param location string = 'brazilsouth'
param environmentName string = 'cae-album-private'
param sqlServerName string = 'sql-album-dev-jj'

module network './network.bicep' = {
  name: 'album-network'
  params: {
    location: location
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: network.outputs.containerAppsSubnetId
      internal: false
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    peerAuthentication: {
      mtls: {
        enabled: false
      }
    }
    peerTrafficConfiguration: {
      encryption: {
        enabled: false
      }
    }
  }
  tags: {
    project: 'album-app'
    environment: 'development'
    managedBy: 'bicep'
  }
}

// Reference the existing Azure SQL server.
resource sqlServer 'Microsoft.Sql/servers@2023-08-01' existing = {
  name: sqlServerName
}

// Manage the existing SQL VNet firewall rule.
resource sqlVnetRule 'Microsoft.Sql/servers/virtualNetworkRules@2025-01-01' = {
  parent: sqlServer
  name: 'allow-container-apps-subnet'
  properties: {
    ignoreMissingVnetServiceEndpoint: false
    virtualNetworkSubnetId: network.outputs.containerAppsSubnetId
  }
}

output containerAppsEnvironmentId string = containerAppsEnvironment.id
output containerAppsEnvironmentName string = containerAppsEnvironment.name
output containerAppsSubnetId string = network.outputs.containerAppsSubnetId
output privateEndpointSubnetId string = network.outputs.privateEndpointSubnetId
output privateDnsZoneId string = network.outputs.privateDnsZoneId
