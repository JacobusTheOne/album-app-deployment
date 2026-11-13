param keyVaultName string
param readerIdentityName string

@description('Azure region for every resource in this environment.')
param location string

@description('Which deployment environment this stack represents. Drives the environment tag only; resource names are passed in explicitly so a wrong tag can never silently retarget a resource.')
@allowed([
  'development'
  'staging'
  'production'
])
param environmentType string

@description('Container Apps managed environment name.')
param environmentName string

@description('Virtual network name.')
param vnetName string

@description('Virtual network address range. Keep environments non-overlapping so the VNets can be peered later.')
param vnetAddressPrefix string

@description('Container Apps infrastructure subnet range. Must be /23 or larger for the Consumption workload profile.')
param containerAppsSubnetPrefix string

@description('Private endpoint subnet range.')
param privateEndpointSubnetPrefix string

@description('Log Analytics workspace name.')
param workspaceName string

@description('Log Analytics retention in days.')
@minValue(30)
@maxValue(730)
param logRetentionInDays int

@description('Log Analytics daily ingestion cap in GB. A cap protects a learning subscription from a log storm; raise it for production, where dropped logs cost more than ingestion.')
param logDailyQuotaGb int

@description('Existing Azure SQL server name. The server is created out of band; this template only manages its VNet firewall rule.')
param sqlServerName string

var tags = {
  project: 'album-app'
  environment: environmentType
  managedBy: 'bicep'
}

module network './network.bicep' = {
  name: 'album-network'
  params: {
    location: location
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    containerAppsSubnetPrefix: containerAppsSubnetPrefix
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    tags: tags
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
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
  }
  tags: tags
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

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    sku: {
      family: 'A'
      name: 'standard'
    }
  }
}

resource secretsReaderIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: readerIdentityName
}

var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource keyVaultSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, secretsReaderIdentity.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      keyVaultSecretsUserRoleId
    )
    principalId: secretsReaderIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

module monitoring './monitoring.bicep' = {
  name: 'album-monitoring'
  params: {
    location: location
    environmentName: environmentName
    workspaceName: workspaceName
    retentionInDays: logRetentionInDays
    dailyQuotaGb: logDailyQuotaGb
    tags: tags
  }
  dependsOn: [
    containerAppsEnvironment
  ]
}

output containerAppsEnvironmentId string = containerAppsEnvironment.id
output containerAppsEnvironmentName string = containerAppsEnvironment.name
output containerAppsSubnetId string = network.outputs.containerAppsSubnetId
output privateEndpointSubnetId string = network.outputs.privateEndpointSubnetId
output privateDnsZoneId string = network.outputs.privateDnsZoneId
output workspaceId string = monitoring.outputs.workspaceId
