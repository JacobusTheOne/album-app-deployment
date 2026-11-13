using '../../main.bicep'

// Not deployed yet. The SQL server named here must be created out of band
// first: main.bicep references it as existing and only manages its VNet
// firewall rule. SQL server names are globally unique.
param location = 'brazilsouth'
param environmentType = 'staging'
param environmentName = 'cae-album-staging'
param vnetName = 'vnet-album-staging'
param vnetAddressPrefix = '10.1.0.0/16'
param containerAppsSubnetPrefix = '10.1.0.0/23'
param privateEndpointSubnetPrefix = '10.1.2.0/24'
param workspaceName = 'law-album-staging-jj'
param logRetentionInDays = 30
param logDailyQuotaGb = 2
param sqlServerName = 'sql-album-staging-jj'
param keyVaultName = 'kv-album-staging-jj'
param readerIdentityName = 'id-album-api-acrpull-staging'
