@description('Required. Name for the container group.')
param name string

@description('Required. Name for the container.')
param containername string

@description('Required. Name of the image.')
param image string

@description('Optional. Port to open on the container and the public IP address.')
param ports array = [
  {
    protocol: 'Tcp'
    port: '443'
  }
]

@description('Optional. The number of CPU cores to allocate to the container.')
param cpuCores int = 2

@description('Optional. The amount of memory to allocate to the container in gigabytes.')
param memoryInGB int = 2

@description('Optional. The operating system type required by the containers in the container group. - Windows or Linux.')
param osType string = 'Linux'

@description('Optional. Restart policy for all containers within the container group. - Always: Always restart. OnFailure: Restart on failure. Never: Never restart. - Always, OnFailure, Never.')
param restartPolicy string = 'Always'

@description('Optional. Specifies if the IP is exposed to the public internet or private VNET. - Public or Private.')
param ipAddressType string = 'Public'

@description('Optional. The image registry credentials by which the container group is created from.')
param imageRegistryCredentials array = []

@description('Optional. Environment variables of the container group.')
param environmentVariables array = []

@description('Optional. Location for all Resources.')
param location string = resourceGroup().location

@allowed([
  ''
  'CanNotDelete'
  'ReadOnly'
])
@description('Optional. Specify the type of lock.')
param lock string = ''

@description('Optional. Enables system assigned managed identity on the resource.')
param systemAssignedIdentity bool = false

@description('Optional. The ID(s) to assign to the resource.')
param userAssignedIdentities object = {}

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Optional. Enable telemetry via the Customer Usage Attribution ID (GUID).')
param enableDefaultTelemetry bool = true

@description('Optional. The container group SKU.')
@allowed([
  'Dedicated'
  'Standard'
])
param sku string = 'Standard'

@description('Optional. The resource ID of a key vault to reference a customer managed key for encryption from.')
param cMKKeyVaultResourceId string = ''

@description('Optional. The name of the customer managed key to use for encryption.')
param cMKKeyName string = ''

@description('Optional. The version of the customer managed key to reference for encryption. If not provided, the latest key version is used.')
param cMKKeyVersion string = ''

var identityType = systemAssignedIdentity ? (!empty(userAssignedIdentities) ? 'SystemAssigned,UserAssigned' : 'SystemAssigned') : (!empty(userAssignedIdentities) ? 'UserAssigned' : 'None')

var identity = identityType != 'None' ? {
  type: identityType
  userAssignedIdentities: !empty(userAssignedIdentities) ? userAssignedIdentities : null
} : null

resource defaultTelemetry 'Microsoft.Resources/deployments@2021-04-01' = if (enableDefaultTelemetry) {
  name: 'pid-47ed15a6-730a-4827-bcb4-0fd963ffbd82-${uniqueString(deployment().name, location)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}

resource cmkKeyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = if (!empty(cMKKeyVaultResourceId)) {
  name: last(split(cMKKeyVaultResourceId, '/'))
  scope: resourceGroup(split(cMKKeyVaultResourceId, '/')[2], split(cMKKeyVaultResourceId, '/')[4])
}

resource cMKKeyVaultKey 'Microsoft.KeyVault/vaults/keys@2021-10-01' existing = if (!empty(cMKKeyVaultResourceId) && !empty(cMKKeyName)) {
  name: '${last(split(cMKKeyVaultResourceId, '/'))}/${cMKKeyName}'
  scope: resourceGroup(split(cMKKeyVaultResourceId, '/')[2], split(cMKKeyVaultResourceId, '/')[4])
}

resource containergroup 'Microsoft.ContainerInstance/containerGroups@2021-03-01' = {
  name: name
  location: location
  identity: identity
  tags: tags
  properties: {
    sku: sku
    containers: [
      {
        name: containername
        properties: {
          command: []
          image: image
          ports: ports
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGB
            }
          }
          environmentVariables: environmentVariables
        }
      }
    ]
    encryptionProperties: !empty(cMKKeyName) ? {
      keyName: cMKKeyName
      keyVersion: !empty(cMKKeyVersion) ? '${cMKKeyVaultKey.properties.keyUri}/${cMKKeyVersion}' : cMKKeyVaultKey.properties.keyUriWithVersion
      vaultBaseUrl: cmkKeyVault.properties.vaultUri
    } : null
    imageRegistryCredentials: imageRegistryCredentials
    restartPolicy: restartPolicy
    osType: osType
    ipAddress: {
      type: ipAddressType
      ports: ports
    }
  }
}

resource containergroup_lock 'Microsoft.Authorization/locks@2017-04-01' = if (!empty(lock)) {
  name: '${containergroup.name}-${lock}-lock'
  properties: {
    level: any(lock)
    notes: lock == 'CanNotDelete' ? 'Cannot delete resource or child resources.' : 'Cannot modify the resource or child resources.'
  }
  scope: containergroup
}

@description('The name of the container group.')
output name string = containergroup.name

@description('The resource ID of the container group.')
output resourceId string = containergroup.id

@description('The resource group the container group was deployed into.')
output resourceGroupName string = resourceGroup().name

@description('The IPv4 address of the container group.')
output iPv4Address string = containergroup.properties.ipAddress.ip

@description('The principal ID of the system assigned identity.')
output systemAssignedPrincipalId string = systemAssignedIdentity && contains(containergroup.identity, 'principalId') ? containergroup.identity.principalId : ''

@description('The location the resource was deployed into.')
output location string = containergroup.location
