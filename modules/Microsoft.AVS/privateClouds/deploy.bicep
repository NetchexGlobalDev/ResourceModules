// ============== //
//   Parameters   //
// ============== //

@description('Required. Name of the private cloud')
param name string

@description('Required. The resource model definition representing SKU')
param sku object

@description('Optional. The addons to create as part of the privateCloud.')
param addons array = []

@description('Optional. The authorizations to create as part of the privateCloud.')
param authorizations array = []

@description('Optional. The properties describing private cloud availability zone distribution')
param availability object = {}

@description('Optional. An ExpressRoute Circuit')
param circuit object = {}

@description('Optional. The cloudLinks to create as part of the privateCloud.')
param cloudLinks array = []

@description('Optional. The clusters to create as part of the privateCloud.')
param clusters array = []

@description('Optional. The dhcpConfigurations to create as part of the privateCloud.')
param dhcpConfigurations array = []

@description('Optional. Resource ID of the diagnostic event hub authorization rule for the Event Hubs namespace in which the event hub should be created or streamed to.')
param diagnosticEventHubAuthorizationRuleId string = ''

@description('Optional. Name of the diagnostic event hub within the namespace to which logs are streamed. Without this, an event hub is created for each log category. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.')
param diagnosticEventHubName string = ''

@description('Optional. The name of logs that will be streamed.')
@allowed([
  'CapacityLatest'
  'DiskUsedPercentage'
  'EffectiveCpuAverage'
  'EffectiveMemAverage'
  'OverheadAverage'
  'TotalMbAverage'
  'UsageAverage'
  'UsedLatest'
])
param diagnosticLogCategoriesToEnable array = [
  'CapacityLatest'
  'DiskUsedPercentage'
  'EffectiveCpuAverage'
  'EffectiveMemAverage'
  'OverheadAverage'
  'TotalMbAverage'
  'UsageAverage'
  'UsedLatest'
]

@description('Optional. Specifies the number of days that logs will be kept for; a value of 0 will retain data indefinitely.')
param diagnosticLogsRetentionInDays int = 365

@description('Optional. The name of metrics that will be streamed.')
@allowed([
  'AllMetrics'
])
param diagnosticMetricsToEnable array = [
  'AllMetrics'
]

@description('Optional. The name of the diagnostic setting, if deployed.')
param diagnosticSettingsName string = '${name}-diagnosticSettings'

@description('Optional. Resource ID of the diagnostic storage account. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of the diagnostic log analytics workspace. For security reasons, it is recommended to set diagnostic settings to send data to either storage account, log analytics workspace or event hub.')
param diagnosticWorkspaceId string = ''

@description('Optional. The dnsServices to create as part of the privateCloud.')
param dnsServices array = []

@description('Optional. The dnsZones to create as part of the privateCloud.')
param dnsZones array = []

@description('Optional. Enable telemetry via the Customer Usage Attribution ID (GUID).')
param enableDefaultTelemetry bool = true

@description('Optional. The properties of customer managed encryption key')
param encryption object = {}

@description('Optional. The globalReachConnections to create as part of the privateCloud.')
param globalReachConnections array = []

@description('Optional. The hcxEnterpriseSites to create as part of the privateCloud.')
param hcxEnterpriseSites array = []

@description('Optional. Identity for the virtual machine.')
param identity object = {}

@description('Optional. vCenter Single Sign On Identity Sources')
param identitySources array = []

@description('Optional. Connectivity to internet is enabled or disabled')
@allowed([
  'Enabled'
  'Disabled'
])
param internet string = 'Disabled'

@description('Optional. Location for all Resources.')
param location string = resourceGroup().location

@description('Optional. Specify the type of lock.')
@allowed([
  ''
  'CanNotDelete'
  'ReadOnly'
])
param lock string = ''

@description('Optional. The properties of a management cluster')
param managementCluster object = {}

@description('Optional. The block of addresses should be unique across VNet in your subscription as well as on-premise. Make sure the CIDR format is conformed to (A.B.C.D/X) where A,B,C,D are between 0 and 255, and X is between 0 and 22')
param networkBlock string = ''

@description('Optional. Optionally, set the NSX-T Manager password when the private cloud is created')
@secure()
param nsxtPassword string = ''

@description('Optional. The portMirroringProfiles to create as part of the privateCloud.')
param portMirroringProfiles array = []

@description('Optional. The publicIPs to create as part of the privateCloud.')
param publicIPs array = []

@description('Optional. The scriptExecutions to create as part of the privateCloud.')
param scriptExecutions array = []

@description('Optional. An ExpressRoute Circuit')
param secondaryCircuit object = {}

@description('Optional. The segments to create as part of the privateCloud.')
param segments array = []

@description('Optional. Resource tags')
param tags object = {}

@description('Optional. Optionally, set the vCenter admin password when the private cloud is created')
@secure()
param vcenterPassword string = ''

@description('Optional. The vmGroups to create as part of the privateCloud.')
param vmGroups array = []

var diagnosticsMetrics = [for metric in diagnosticMetricsToEnable: {
  category: metric
  timeGrain: null
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

var diagnosticsLogs = [for category in diagnosticLogCategoriesToEnable: {
  category: category
  enabled: true
  retentionPolicy: {
    enabled: true
    days: diagnosticLogsRetentionInDays
  }
}]

var enableReferencedModulesTelemetry = false


// =============== //
//   Deployments   //
// =============== //

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


resource privateCloud 'Microsoft.AVS/privateClouds@2022-05-01' = {
  name: name
  identity: identity
  sku: sku
  location: location
  tags: tags
  properties: {
    secondaryCircuit: secondaryCircuit
    nsxtPassword: nsxtPassword
    vcenterPassword: vcenterPassword
    networkBlock: networkBlock
    circuit: circuit
    identitySources: identitySources
    internet: internet
    encryption: encryption
    availability: availability
    managementCluster: managementCluster
  }
}

resource privateCloud_diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2021-05-01-preview' = if ((!empty(diagnosticStorageAccountId)) || (!empty(diagnosticWorkspaceId)) || (!empty(diagnosticEventHubAuthorizationRuleId)) || (!empty(diagnosticEventHubName))) {
  name: diagnosticSettingsName
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    workspaceId: !empty(diagnosticWorkspaceId) ? diagnosticWorkspaceId : null
    eventHubAuthorizationRuleId: !empty(diagnosticEventHubAuthorizationRuleId) ? diagnosticEventHubAuthorizationRuleId : null
    eventHubName: !empty(diagnosticEventHubName) ? diagnosticEventHubName : null
    metrics: diagnosticsMetrics
    logs: diagnosticsLogs
  }
  scope: privateCloud
}

resource keyVault_lock 'Microsoft.Authorization/locks@2017-04-01' = if (!empty(lock)) {
  name: '${privateCloud.name}-${lock}-lock'
  properties: {
    level: any(lock)
    notes: lock == 'CanNotDelete' ? 'Cannot delete resource or child resources.' : 'Cannot modify the resource or child resources.'
  }
  scope: privateCloud
}

module privateCloud_hcxEnterpriseSites 'hcxEnterpriseSites/deploy.bicep' = [for (hcxEnterpriseSite, index) in hcxEnterpriseSites: {
name: '${uniqueString(deployment().name, location)}-privateCloud-hcxEnterpriseSite-${index}'
params: {
    privateCloudName: name
    name: hcxEnterpriseSite.name
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module privateCloud_globalReachConnections 'globalReachConnections/deploy.bicep' = [for (globalReachConnection, index) in globalReachConnections: {
name: '${uniqueString(deployment().name, location)}-privateCloud-globalReachConnection-${index}'
params: {
    privateCloudName: name
    name: globalReachConnection.name
    authorizationKey: contains(globalReachConnection, 'authorizationKey') ? globalReachConnection.authorizationKey : ''
    expressRouteId: contains(globalReachConnection, 'expressRouteId') ? globalReachConnection.expressRouteId : ''
    peerExpressRouteCircuit: contains(globalReachConnection, 'peerExpressRouteCircuit') ? globalReachConnection.peerExpressRouteCircuit : ''
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module privateCloud_clusters 'clusters/deploy.bicep' = [for (cluster, index) in clusters: {
name: '${uniqueString(deployment().name, location)}-privateCloud-cluster-${index}'
params: {
    privateCloudName: name
    name: cluster.name
    sku: cluster.sku
    hosts: contains(cluster, 'hosts') ? cluster.hosts : []
    clusterSize: contains(cluster, 'clusterSize') ? cluster.clusterSize : 
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module privateCloud_authorizations 'authorizations/deploy.bicep' = [for (authorization, index) in authorizations: {
name: '${uniqueString(deployment().name, location)}-privateCloud-authorization-${index}'
params: {
    privateCloudName: name
    name: authorization.name
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module privateCloud_cloudLinks 'cloudLinks/deploy.bicep' = [for (cloudLink, index) in cloudLinks: {
name: '${uniqueString(deployment().name, location)}-privateCloud-cloudLink-${index}'
params: {
    privateCloudName: name
    name: cloudLink.name
    linkedCloud: contains(cloudLink, 'linkedCloud') ? cloudLink.linkedCloud : ''
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module privateCloud_addons 'addons/deploy.bicep' = [for (addon, index) in addons: {
name: '${uniqueString(deployment().name, location)}-privateCloud-addon-${index}'
params: {
    privateCloudName: name
    name: addon.name
    addonType: contains(addon, 'addonType') ? addon.addonType : ''
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module privateCloud_scriptExecutions 'scriptExecutions/deploy.bicep' = [for (scriptExecution, index) in scriptExecutions: {
name: '${uniqueString(deployment().name, location)}-privateCloud-scriptExecution-${index}'
params: {
    privateCloudName: name
    name: scriptExecution.name
    scriptCmdletId: contains(scriptExecution, 'scriptCmdletId') ? scriptExecution.scriptCmdletId : ''
    failureReason: contains(scriptExecution, 'failureReason') ? scriptExecution.failureReason : ''
    output: contains(scriptExecution, 'output') ? scriptExecution.output : []
    namedOutputs: contains(scriptExecution, 'namedOutputs') ? scriptExecution.namedOutputs : {}
    timeout: contains(scriptExecution, 'timeout') ? scriptExecution.timeout : ''
    retention: contains(scriptExecution, 'retention') ? scriptExecution.retention : ''
    parameters: contains(scriptExecution, 'parameters') ? scriptExecution.parameters : []
    hiddenParameters: contains(scriptExecution, 'hiddenParameters') ? scriptExecution.hiddenParameters : []
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module workloadNetworks_privateCloud_publicIPs 'workloadNetworks/publicIPs/deploy.bicep' = [for (publicIP, index) in publicIPs: {
name: '${uniqueString(deployment().name, location)}-privateCloud-publicIP-${index}'
params: {
    privateCloudName: name
    workloadNetworkName: 'default'
    name: publicIP.name
    displayName: contains(publicIP, 'displayName') ? publicIP.displayName : ''
    numberOfPublicIPs: contains(publicIP, 'numberOfPublicIPs') ? publicIP.numberOfPublicIPs : 
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module workloadNetworks_privateCloud_dhcpConfigurations 'workloadNetworks/dhcpConfigurations/deploy.bicep' = [for (dhcpConfiguration, index) in dhcpConfigurations: {
name: '${uniqueString(deployment().name, location)}-privateCloud-dhcpConfiguration-${index}'
params: {
    privateCloudName: name
    workloadNetworkName: 'default'
    name: dhcpConfiguration.name
    displayName: contains(dhcpConfiguration, 'displayName') ? dhcpConfiguration.displayName : ''
    dhcpType: contains(dhcpConfiguration, 'dhcpType') ? dhcpConfiguration.dhcpType : ''
    revision: contains(dhcpConfiguration, 'revision') ? dhcpConfiguration.revision : 
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module workloadNetworks_privateCloud_dnsZones 'workloadNetworks/dnsZones/deploy.bicep' = [for (dnsZone, index) in dnsZones: {
name: '${uniqueString(deployment().name, location)}-privateCloud-dnsZone-${index}'
params: {
    privateCloudName: name
    workloadNetworkName: 'default'
    name: dnsZone.name
    revision: contains(dnsZone, 'revision') ? dnsZone.revision : 
    displayName: contains(dnsZone, 'displayName') ? dnsZone.displayName : ''
    dnsServices: contains(dnsZone, 'dnsServices') ? dnsZone.dnsServices : 
    dnsServerIps: contains(dnsZone, 'dnsServerIps') ? dnsZone.dnsServerIps : []
    sourceIp: contains(dnsZone, 'sourceIp') ? dnsZone.sourceIp : ''
    domain: contains(dnsZone, 'domain') ? dnsZone.domain : []
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module workloadNetworks_privateCloud_dnsServices 'workloadNetworks/dnsServices/deploy.bicep' = [for (dnsService, index) in dnsServices: {
name: '${uniqueString(deployment().name, location)}-privateCloud-dnsService-${index}'
params: {
    privateCloudName: name
    workloadNetworkName: 'default'
    name: dnsService.name
    logLevel: contains(dnsService, 'logLevel') ? dnsService.logLevel : ''
    fqdnZones: contains(dnsService, 'fqdnZones') ? dnsService.fqdnZones : []
    defaultDnsZone: contains(dnsService, 'defaultDnsZone') ? dnsService.defaultDnsZone : ''
    dnsServiceIp: contains(dnsService, 'dnsServiceIp') ? dnsService.dnsServiceIp : ''
    revision: contains(dnsService, 'revision') ? dnsService.revision : 
    displayName: contains(dnsService, 'displayName') ? dnsService.displayName : ''
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module workloadNetworks_privateCloud_vmGroups 'workloadNetworks/vmGroups/deploy.bicep' = [for (vmGroup, index) in vmGroups: {
name: '${uniqueString(deployment().name, location)}-privateCloud-vmGroup-${index}'
params: {
    privateCloudName: name
    workloadNetworkName: 'default'
    name: vmGroup.name
    displayName: contains(vmGroup, 'displayName') ? vmGroup.displayName : ''
    members: contains(vmGroup, 'members') ? vmGroup.members : []
    revision: contains(vmGroup, 'revision') ? vmGroup.revision : 
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module workloadNetworks_privateCloud_portMirroringProfiles 'workloadNetworks/portMirroringProfiles/deploy.bicep' = [for (portMirroringProfile, index) in portMirroringProfiles: {
name: '${uniqueString(deployment().name, location)}-privateCloud-portMirroringProfile-${index}'
params: {
    privateCloudName: name
    workloadNetworkName: 'default'
    name: portMirroringProfile.name
    destination: contains(portMirroringProfile, 'destination') ? portMirroringProfile.destination : ''
    displayName: contains(portMirroringProfile, 'displayName') ? portMirroringProfile.displayName : ''
    revision: contains(portMirroringProfile, 'revision') ? portMirroringProfile.revision : 
    direction: contains(portMirroringProfile, 'direction') ? portMirroringProfile.direction : ''
    source: contains(portMirroringProfile, 'source') ? portMirroringProfile.source : ''
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

module workloadNetworks_privateCloud_segments 'workloadNetworks/segments/deploy.bicep' = [for (segment, index) in segments: {
name: '${uniqueString(deployment().name, location)}-privateCloud-segment-${index}'
params: {
    privateCloudName: name
    workloadNetworkName: 'default'
    name: segment.name
    subnet: contains(segment, 'subnet') ? segment.subnet : {}
    displayName: contains(segment, 'displayName') ? segment.displayName : ''
    revision: contains(segment, 'revision') ? segment.revision : 
    connectedGateway: contains(segment, 'connectedGateway') ? segment.connectedGateway : ''
    enableDefaultTelemetry: enableReferencedModulesTelemetry
  }
}]

// =========== //
//   Outputs   //
// =========== //

@description('The name of the privateCloud.')
output name string = privateCloud.name

@description('The resource ID of the privateCloud.')
output resourceId string = privateCloud.id

@description('The name of the resource group the privateCloud was created in.')
output resourceGroupName string = resourceGroup().name