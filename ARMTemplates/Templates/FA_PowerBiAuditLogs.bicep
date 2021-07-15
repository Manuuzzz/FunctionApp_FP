@allowed([
  'West Europe'
  'North Europe'
])
param location string
param environment string
param umi string
param tenantId string
param kv object
param sta object
param fa object
param functionAppPlanName string
param subscriptionId string
param rg_functionAppPlan string
var resourceGroupName = resourceGroup().name

var envShort = {
  'Test': 'tin'
  'Acceptance': 'acc'
  'Production': 'in'
}

var locShort = {
  'West Europe': 'awe'
  'North Europe': 'ane'
}

var keyVaultName = '${locShort[location]}-${envShort[environment]}-kv-bi-02'
var storageAccountName = '${locShort[location]}${envShort[environment]}saazfcon02'
var stasid = resourceId('Microsoft.Storage/storageAccounts', storageAccountName)


resource r_userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: '${umi}-umi'
  location: location
  
}

resource r_keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  dependsOn: [
    r_userManagedIdentity
  ]
  name: keyVaultName
  location: location
  
  properties: {
    tenantId: tenantId
    sku: {
      family: kv.skuFamily
      name: kv.skuName
    }
      
    enabledForDeployment: kv.enabledForDeployment
    enabledForDiskEncryption: kv.enabledForDiskEncryption
    enabledForTemplateDeployment: kv.enabledForTemplateDeployment
    enableSoftDelete: kv.enableSoftDelete
    softDeleteRetentionInDays: kv.softDeleteRetentionInDays
    enableRbacAuthorization: kv.enableRbacAuthorization
  }
  
}

resource r_roleAssignmentKeyVault 'Microsoft.Authorization/roleAssignments@2020-08-01-preview'= {
  dependsOn: [
    r_keyVault
  ]
  name: guid(r_userManagedIdentity.id, '/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6', resourceGroup().id)
  scope: r_keyVault
  properties: {
    principalType: 'ServicePrincipal'
    principalId: r_userManagedIdentity.properties.principalId
    roleDefinitionId: '/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6'
  }
  
}

resource r_storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: sta.sku
  }
  kind: sta.kind
  
  properties: {
    encryption: {
      services: {
        blob: {
           enabled: true
           keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'      
    }
    supportsHttpsTrafficOnly: sta.httpsTrafficOnly
    accessTier: sta.accessTier
    minimumTlsVersion: sta.tlsVersion
    allowBlobPublicAccess: sta.blobPublicAccess
    allowSharedKeyAccess: sta.sharedKeyAccess
    networkAcls: {
    bypass: sta.byPass
    defaultAction: sta.defaultAction
    
     }
  }
}
resource r_blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-04-01' = {
    dependsOn: [
      r_storageAccount
  ]
  name: '${storageAccountName}/default'
  properties: {
    
    deleteRetentionPolicy: {
      enabled: sta.deleteRetentionPolicy
      days: sta.deleteRetentionPolicyDays
    }
     containerDeleteRetentionPolicy: {
       enabled: sta.containerDeleteRetentionPolicy
       days: sta.containerDeleteRetentionPolicyDays
     }
      
  }
}
  
resource r_blobContainer1 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  dependsOn: [
    r_blobService
  ]
  name: '${storageAccountName}/default/${sta.container1}'
  
  properties: {
    publicAccess: 'None'
  
  }
  
}

resource r_blobContainerr2 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  dependsOn: [
    r_blobService
  ]
  name: '${storageAccountName}/default/${sta.container2}'
  properties: {
    publicAccess: 'None'
  } 
  
}

resource r_roleAssignmentStorageAccount 'Microsoft.Authorization/roleAssignments@2020-08-01-preview'= {
  dependsOn: [
    r_storageAccount
  ]
  name: guid(r_userManagedIdentity.id, '/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe', resourceGroup().id)
  scope: r_storageAccount
  properties: {
    principalType: 'ServicePrincipal'
    principalId: r_userManagedIdentity.properties.principalId
    roleDefinitionId: '/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  }
  
}

resource r_functionAppPlan 'Microsoft.Web/serverfarms@2021-01-01' existing = {
  name: functionAppPlanName
}

resource r_functionApp 'Microsoft.Web/sites@2020-06-01' =  {
  dependsOn:[
    r_userManagedIdentity
  ]
  name: fa.functionAppName
  location: location
  kind: fa.kind

  identity: {
    type: 'UserAssigned'
    
    userAssignedIdentities: {
      '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${r_userManagedIdentity.name}': {}
    }

  }
    properties:{
    enabled: fa.enabled
    containerSize: fa.containerSize
    serverFarmId:resourceId(rg_functionAppPlan,'Microsoft.Web/serverFarms',functionAppPlanName)
   
    siteConfig:{
      appSettings: [
      {
        name: 'AzureWebJobsStorage'
        value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(stasid, '2021-04-01').keys[0].value}'
      }
      
      {
        name: 'FUNCTIONS_WORKER_RUNTIME'
        value: 'powershell'
      }
      {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '10.14.1'
      }
      {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
      }
              
      
      {
        name: 'StorageAccountName'
        value: storageAccountName
      }
    
     ]
    }
    
  }
  
  
}