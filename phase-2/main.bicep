@description('Username for the Virtual Machines')
param adminUsername string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

@description('Enter Public IP CIDR to allow for accessing the deployment. Enter in 0.0.0.0/0 format, you can always modify these later in NSG Settings')
param remoteAllowedCIDR string = '0.0.0.0/0'

var webTierVmName = 'web-tier-vm'
var appTierVmName = 'app-tier-vm'
var databaseTierVmName = 'database-tier-vm'
var jumpVmName = 'jump-vm'

var redHatTags = {
  type: 'object'
  provider: '9d2c71fc-96ba-4b4a-93b3-14def5bc96fc'
}

module networking 'modules/networking.bicep' = {
  name: 'networkingDeploy'
  params: {
    location: location
    redHatTags: redHatTags
    remoteAllowedCIDR: remoteAllowedCIDR
  }
}

resource diagStorage 'Microsoft.Storage/storageAccounts@2021-01-01' = {
  name: '${uniqueString(resourceGroup().id)}diagstorage'
  location: location
  tags: {
    displayName: 'Diagnostics Storage Account'
    provider: redHatTags.provider
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {}
}

resource availSets 'Microsoft.Compute/availabilitySets@2017-12-01' = [for i in range(0, 3): {
  name: 'avail-set-${(i + 1)}'
  location: location
  tags: {
    displayName: 'Availability Sets'
    provider: redHatTags.provider
  }
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 5
  }
}]

module webTier 'modules/generic-tier.bicep' = {
  name: 'web-tier-deploy'
  params: {
    location: location
    adminPasswordOrKey: adminPasswordOrKey
    adminUsername: adminUsername
    storageUri: diagStorage.properties.primaryEndpoints.blob
    vnetName: networking.outputs.vnetName
    availSetId: availSets[0].id
    loadBalancerBackendPoolId: networking.outputs.webBackendPoolId
    subnetName: networking.outputs.webTierSubnetName
    enableWebServer: true
    vmName: webTierVmName
  }
}

module appTier 'modules/generic-tier.bicep' = {
  name: 'app-tier-deploy'
  params: {
    location: location
    adminPasswordOrKey: adminPasswordOrKey
    adminUsername: adminUsername
    storageUri: diagStorage.properties.primaryEndpoints.blob
    vnetName: networking.outputs.vnetName
    availSetId: availSets[1].id
    loadBalancerBackendPoolId: networking.outputs.internalBackendPoolId
    subnetName: networking.outputs.appTierSubnetName
    vmName: appTierVmName
  }
}

module dbTier 'modules/generic-tier.bicep' = {
  name: 'db-tier-deploy'
  params: {
    location: location
    adminPasswordOrKey: adminPasswordOrKey
    adminUsername: adminUsername
    storageUri: diagStorage.properties.primaryEndpoints.blob
    vnetName: networking.outputs.vnetName
    availSetId: availSets[2].id 
    loadBalancerBackendPoolId: ''
    subnetName: networking.outputs.dbTierSubnetName
    vmName: databaseTierVmName
  }
}

module jumpVm 'modules/generic-tier.bicep' = {
  name: 'jump-vm-deploy'
  params: {
    location: location
    adminPasswordOrKey: adminPasswordOrKey
    adminUsername: adminUsername
    storageUri: diagStorage.properties.primaryEndpoints.blob
    vnetName: networking.outputs.vnetName
    availSetId: ''
    loadBalancerBackendPoolId: ''
    subnetName: networking.outputs.jumpSubnetName
    vmCount: 1
    vmName: jumpVmName
  }
}

output webLoadBalancerIP string = networking.outputs.webLoadBalancerIP
output webLoadBalancerFqdn string = networking.outputs.webLoadBalancerFqdn
output jumpVMIP string = networking.outputs.jumpVMIP
output jumpVMFqdn string = networking.outputs.jumpVMFqdn
