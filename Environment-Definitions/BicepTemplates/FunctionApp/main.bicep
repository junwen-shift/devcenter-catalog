@description('The name of the function app.')
param functionAppName string = 'fnapp${uniqueString(resourceGroup().id)}'

@description('The location into which your Azure resources should be deployed.')
param location string = resourceGroup().location

@description('The language worker runtime to load in the function app.')
@allowed([
  'node'
  'dotnet'
  'java'
  'python'
])
param runtime string = 'dotnet'

@description('The pricing tier for the hosting plan.')
@allowed([
  'Y1'
  'EP1'
  'EP2'
  'EP3'
])
param sku string = 'Y1'

@description('The version of the runtime to use.')
param runtimeVersion string = '8'

var hostingPlanName = '${functionAppName}-plan'
var applicationInsightsName = '${functionAppName}-ai'
var storageAccountName = '${toLower(take(replace(functionAppName, '-', ''), 11))}${uniqueString(resourceGroup().id)}'
var functionWorkerRuntime = runtime
var deploymentLocation = location != '' ? location : resourceGroup().location

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: deploymentLocation
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
  }
}

// Hosting Plan
resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: hostingPlanName
  location: deploymentLocation
  kind: 'linux'
  sku: {
    name: sku
    tier: sku == 'Y1' ? 'Dynamic' : 'ElasticPremium'
  }
  properties: {
    reserved: true
    zoneRedundant: false
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: deploymentLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: deploymentLocation
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    reserved: true
    clientAffinityEnabled: false
    publicNetworkAccess: 'Enabled'
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: 'https://${storageAccountName}.blob.core.windows.net'
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: 'https://${storageAccountName}.queue.core.windows.net'
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: 'https://${storageAccountName}.table.core.windows.net'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
      ]
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
      }
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      linuxFxVersion: runtime == 'dotnet' ? 'DOTNET-ISOLATED|${runtimeVersion}.0' : runtime == 'node' ? 'NODE|${runtimeVersion}' : runtime == 'python' ? 'PYTHON|${runtimeVersion}' : 'JAVA|${runtimeVersion}'
    }
  }
}

// Disable SCM basic auth
resource functionAppScmBasicAuth 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-09-01' = {
  name: 'scm'
  parent: functionApp
  properties: {
    allow: false
  }
}

// Disable FTP basic auth
resource functionAppFtpBasicAuth 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-09-01' = {
  name: 'ftp'
  parent: functionApp
  properties: {
    allow: false
  }
}

// Storage Blob Data Owner role assignment for Function App
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
@description('The name of the function app.')
output functionAppName string = functionApp.name

@description('The default hostname of the function app.')
output functionAppHostName string = functionApp.properties.defaultHostName

@description('The resource ID of the function app.')
output functionAppResourceId string = functionApp.id

@description('The name of the storage account.')
output storageAccountName string = storageAccount.name

@description('The name of the Application Insights component.')
output applicationInsightsName string = applicationInsights.name
