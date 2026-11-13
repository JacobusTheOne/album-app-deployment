@description('Azure region.')
param location string

@description('Container Apps managed environment whose logs are collected.')
param environmentName string

@description('Log Analytics workspace name.')
param workspaceName string

@description('Retention in days.')
@minValue(30)
@maxValue(730)
param retentionInDays int

@description('Daily ingestion cap in GB.')
param dailyQuotaGb int

@description('Tags applied to the workspace. Passed in from main.bicep.')
param tags object

// Create the central Log Analytics workspace.
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
    features: {
      disableLocalAuth: false
    }
  }
  tags: tags
}

// Reference the existing Container Apps environment.
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: environmentName
}

// Route application and platform logs into the workspace.
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'album-container-apps-logs'
  scope: containerAppsEnvironment
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'ContainerAppConsoleLogs'
        enabled: true
      }
      {
        category: 'ContainerAppSystemLogs'
        enabled: true
      }
    ]
  }
}

output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
