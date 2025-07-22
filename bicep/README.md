# Azure Function App Bicep Template

This Bicep template deploys an Azure Function App with all required resources following Azure best practices.

## Resources Deployed

- **Azure Function App**: The main function app resource
- **App Service Plan**: Hosting plan for the function app (supports Consumption and Premium tiers)
- **Storage Account**: Required storage for function app runtime and content

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `functionAppName` | string | `func-{uniqueString}` | Name of the Function App |
| `location` | string | `resourceGroup().location` | Azure region for deployment |
| `appServicePlanName` | string | `plan-{uniqueString}` | Name of the App Service Plan |
| `appServicePlanSku` | string | `Y1` | App Service Plan SKU (Y1, EP1, EP2, EP3) |
| `storageAccountName` | string | `st{uniqueString}` | Name of the Storage Account |
| `storageAccountSku` | string | `Standard_LRS` | Storage Account SKU |
| `functionAppRuntime` | string | `dotnet` | Function app runtime (dotnet, node, python, etc.) |
| `functionAppRuntimeVersion` | string | `8` | Runtime version |

## App Service Plan SKUs

- **Y1**: Consumption plan (pay-per-execution)
- **EP1**: Premium plan (enhanced performance and features)
- **EP2**: Premium plan (higher tier)
- **EP3**: Premium plan (highest tier)

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `functionAppHostname` | string | Default hostname of the Function App |
| `functionAppId` | string | Resource ID of the Function App |
| `functionAppName_output` | string | Name of the Function App |
| `storageAccountId` | string | Resource ID of the Storage Account |
| `storageAccountName_output` | string | Name of the Storage Account |

## Usage

### Deploy with Azure CLI

```bash
az deployment group create \
  --resource-group myResourceGroup \
  --template-file main.bicep \
  --parameters functionAppName=myFunctionApp
```

### Deploy with Azure PowerShell

```powershell
New-AzResourceGroupDeployment `
  -ResourceGroupName "myResourceGroup" `
  -TemplateFile "main.bicep" `
  -functionAppName "myFunctionApp"
```

### Example Parameters

```bash
az deployment group create \
  --resource-group myResourceGroup \
  --template-file main.bicep \
  --parameters \
    functionAppName=myapp \
    appServicePlanSku=EP1 \
    functionAppRuntime=node \
    functionAppRuntimeVersion=18
```

## Security Features

- HTTPS only access enforced
- Minimum TLS version 1.2
- FTPS only for FTP access
- Storage account with HTTPS traffic only
- Storage encryption enabled

## Notes

- The template creates a Linux-based Function App by default
- Storage account connection strings are automatically configured
- The template follows Azure naming conventions and best practices
- Resource names use `uniqueString()` to ensure uniqueness when defaults are used