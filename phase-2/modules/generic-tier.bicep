param location string
param loadBalancerBackendPoolId string
param vnetName string
param subnetName string
param vmCount int = 2
param availSetId string
param storageUri string

param adminUsername string
@secure()
param adminPasswordOrKey string

param enableWebServer bool = false

param vmName string

module vm 'vm.bicep' = [for i in range(0, vmCount): {
  name: 'deploy-${vmName}-tier${i}'
  params: {
    adminPasswordOrKey: adminPasswordOrKey
    adminUsername: adminUsername  
    availSetId: availSetId
    loadBalancerBackendPoolId: loadBalancerBackendPoolId
    location: location
    storageUri: storageUri
    subnetName: subnetName
    vmName: '${vmName}-${i+1}'
    vnetName: vnetName

    enableWebServer: enableWebServer
  }
}]
