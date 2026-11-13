using '../../main.bicep'

// Not deployed yet. See the staging notes: the SQL server is a prerequisite,
// and this environment needs its own resource group.
param location = 'brazilsouth'
param environmentType = 'production'
param environmentName = 'cae-album-prod'
param vnetName = 'vnet-album-prod'
param vnetAddressPrefix = '10.2.0.0/16'
param containerAppsSubnetPrefix = '10.2.0.0/23'
param privateEndpointSubnetPrefix = '10.2.2.0/24'
param workspaceName = 'law-album-prod-jj'
param logRetentionInDays = 90
param logDailyQuotaGb = 5
param sqlServerName = 'sql-album-prod-jj'
param keyVaultName = 'kv-album-prod-jj'
param readerIdentityName = 'id-album-api-acrpull-prod'
