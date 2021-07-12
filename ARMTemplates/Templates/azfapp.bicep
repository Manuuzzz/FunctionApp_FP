@allowed([
  'West Europe'
  'North Europe'
])
param location string
param sta object
param functionName string
param builtInRoleType string
param tenantId string
param kv object
param environment string
var envShort = {
  'Test': 'tin'
  'Acceptance': 'acc'
  'Production': 'in'
}

var locShort = {
  'West Europe': 'awe'
  'North Europe': 'ane'
}

var storageAccountName = 'mytest${locShort[location]}${envShort[environment]}saazfcon01'
var keyVaultName = 'mytest-${locShort[location]}-${envShort[environment]}-kv-bi-02'

resource str 'Microsoft.Storage/storageAccounts@2021-04-01' = {
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
resource stblobr 'Microsoft.Storage/storageAccounts/blobServices@2021-04-01' = {
    dependsOn: [
    str
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
  
resource stblobcontainerr1 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  dependsOn: [
    stblobr
  ]
  name: '${storageAccountName}/default/${sta.container1}'
  
  properties: {
    publicAccess: 'None'
  
  }
  
}

resource stblobconterr2 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  dependsOn: [
    stblobr
  ]
  name: '${storageAccountName}/default/${sta.container2}'
  properties: {
    publicAccess: 'None'
  } 
  
}

resource kvr 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
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

