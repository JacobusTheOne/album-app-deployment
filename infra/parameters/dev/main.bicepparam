using '../../main.bicep'

// These names are the ones that already exist in Azure. They predate the
// naming convention the other environments follow, and are kept verbatim
// because a changed name in Bicep creates a new resource rather than
// renaming the old one.
param location = 'brazilsouth'
param environmentType = 'development'
param environmentName = 'cae-album-private'
param vnetName = 'vnet-album-private'
param vnetAddressPrefix = '10.0.0.0/16'
param containerAppsSubnetPrefix = '10.0.0.0/23'
param privateEndpointSubnetPrefix = '10.0.2.0/24'
param workspaceName = 'law-album-dev-jj'
param logRetentionInDays = 30
param logDailyQuotaGb = 1
param sqlServerName = 'sql-album-dev-jj'
param keyVaultName = 'kv-album-dev-jj'
param readerIdentityName = 'id-album-api-acrpull'
