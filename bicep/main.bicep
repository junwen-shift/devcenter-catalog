@description('Specifies the name of the Function App.')
param functionAppName string = 'func-${uniqueString(resourceGroup().id)}'

@description('Specifies the Azure location where all resources should be created.')
param location string = resourceGroup().location

@description('Specifies the name of the App Service Plan.')
param appServicePlanName string = 'plan-${uniqueString(resourceGroup().id)}'

@description('Specifies the App Service Plan SKU.')
@allowed([
  'Y1'        // Consumption plan
  'EP1'       // Premium plan
  'EP2'       // Premium plan
  'EP3'       // Premium plan
])
param appServicePlanSku string = 'Y1'

@description('Specifies the name of the Storage Account.')
param storageAccountName string = 'st${uniqueString(resourceGroup().id)}'

@description('Specifies the Storage Account SKU.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param storageAccountSku string = 'Standard_LRS'

@description('Specifies the runtime stack for the Function App.')
@allowed([
  'dotnet'
  'dotnet-isolated'
  'java'
  'node'
  'python'
  'powershell'
])
param functionAppRuntime string = 'dotnet'

@description('Specifies the runtime version for the Function App.')
param functionAppRuntimeVersion string = '8'

// Storage Account (required for Function Apps)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSku
  }
  properties: {
    reserved: true // Required for Linux Function Apps
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: '${toUpper(functionAppRuntime)}|${functionAppRuntimeVersion}'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionAppRuntime
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

// Outputs
@description('The hostname of the Function App.')
output functionAppHostname string = functionApp.properties.defaultHostName

@description('The resource ID of the Function App.')
output functionAppId string = functionApp.id

@description('The name of the Function App.')
output functionAppName_output string = functionApp.name

@description('The resource ID of the Storage Account.')
output storageAccountId string = storageAccount.id

@description('The name of the Storage Account.')
output storageAccountName_output string = storageAccount.name