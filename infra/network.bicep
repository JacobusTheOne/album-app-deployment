@description('Azure region.')
param location string

@description('Virtual network name.')
param vnetName string

@description('Virtual network address range.')
param vnetAddressPrefix string

@description('Container Apps subnet address range.')
param containerAppsSubnetPrefix string

@description('Private endpoints subnet address range.')
param privateEndpointSubnetPrefix string

@description('Tags applied to every resource here. Passed in from main.bicep so one definition covers the whole stack.')
param tags object

// Fixed by Azure: private endpoint DNS for Azure SQL only resolves from this
// zone name. It is therefore not parameterisable, which also means two
// environments cannot share a resource group.
#disable-next-line no-hardcoded-env-urls
var sqlPrivateDnsZoneName = 'privatelink.database.windows.net'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
        name: 'snet-container-apps'
        properties: {
          addressPrefix: containerAppsSubnetPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.Sql'
            }
          ]
          delegations: [
            {
              name: 'container-apps-delegation'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
  tags: tags
}

resource sqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: sqlPrivateDnsZoneName
  location: 'global'
  tags: tags
}

resource sqlPrivateDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlPrivateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
  tags: tags
}

output vnetId string = vnet.id

output containerAppsSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnetName,
  'snet-container-apps'
)

output privateEndpointSubnetId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnetName,
  'snet-private-endpoints'
)

output privateDnsZoneId string = sqlPrivateDnsZone.id
