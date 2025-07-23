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
  'FC1'
  'Y1'
  'EP1'
  'EP2'
  'EP3'
])
param sku string = 'FC1'

@description('The version of the runtime to use.')
param runtimeVersion string = '9.0'

var hostingPlanName = '${functionAppName}-plan'
var applicationInsightsName = '${functionAppName}-ai'
var storageAccountName = '${toLower(take(replace(functionAppName, '-', ''), 11))}${uniqueString(resourceGroup().id)}'
var functionWorkerRuntime = runtime == 'dotnet' ? 'dotnet-isolated' : runtime
var deploymentLocation = location != '' ? location : resourceGroup().location

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  location: deploymentLocation
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    allowCrossTenantReplication: false
    allowedCopyScope: 'AAD'
    defaultToOAuthAuthentication: true
    routingPreference: {
      routingChoice: 'MicrosoftRouting'
      publishMicrosoftEndpoints: true
      publishInternetEndpoints: false
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    publicNetworkAccess: 'Enabled'
  }
}

// Blob Service for Storage Account
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  name: 'default'
  parent: storageAccount
}

// Deployments Container
resource deploymentsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  name: 'deployments'
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}

// Hosting Plan
resource hostingPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: hostingPlanName
  location: deploymentLocation
  kind: 'functionapp'
  sku: {
    name: sku
  }
  properties: {
    reserved: true // Linux Service Plan
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
resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: deploymentLocation
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: union({
    serverFarmId: hostingPlan.id
    reserved: true
    clientAffinityEnabled: false
    publicNetworkAccess: 'Enabled'
    httpsOnly: true
    siteConfig: {
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
        supportCredentials: true
      }
      appSettings: [
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccountName
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
      ]
    }
  }, sku == 'FC1' ? {
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}deployments'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: functionWorkerRuntime
        version: runtimeVersion
      }
    }
  } : {})

  resource webConfig 'config' = {
    name: 'web'
    properties: {
      minTlsVersion: '1.3'
      scmMinTlsVersion: '1.3'
      minTlsCipherSuite: 'TLS_AES_128_GCM_SHA256'
      http20Enabled: true
      ftpsState: 'Disabled'
      use32BitWorkerProcess: false
      localMySqlEnabled: false
      netFrameworkVersion: 'v9.0'
    }
  }

  resource basicPublishingCredentialsPoliciesFtp 'basicPublishingCredentialsPolicies' = {
    name: 'ftp'
    properties: {
      allow: false
    }
  }
  resource basicPublishingCredentialsPoliciesScm 'basicPublishingCredentialsPolicies' = {
    name: 'scm'
    properties: {
      allow: false
    }
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
