
param location string = 'brazilsouth'
param environmentName string = 'cae-album-private'
param workspaceName string = 'law-album-dev-jj'

// Create the central Log Analytics workspace.
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: 1
    }
    features: {
      disableLocalAuth: false
    }
  }
  tags: {
    project: 'album-app'
    environment: 'development'
    managedBy: 'bicep'
  }
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
