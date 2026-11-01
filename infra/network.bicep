
param location string = 'brazilsouth'
param vnetName string = 'vnet-album-private'

param vnetAddressPrefix string = '10.0.0.0/16'
param containerAppsSubnetPrefix string = '10.0.0.0/23'
param privateEndpointSubnetPrefix string = '10.0.2.0/24'

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
}

resource sqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: sqlPrivateDnsZoneName
  location: 'global'
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
