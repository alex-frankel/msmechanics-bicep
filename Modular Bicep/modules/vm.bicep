param location string

param adminUsername string

@secure()
param adminPasswordOrKey string

param loadBalancerBackendPoolId string
param vnetName string
param subnetName string
param availSetId string
param storageUri string

param enableWebServer bool = false

param vmName string

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'sshPublicKey'

var vmSize = 'Standard_D2_v3'
var redHatsku = '7.3'
var Publisher = 'RedHat'
var Offer = 'RHEL'

var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = if(loadBalancerBackendPoolId != ''){
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
          loadBalancerBackendAddressPools: [
            {
              id: loadBalancerBackendPoolId
            }
          ]
        }
      }
    ]
  }
}

resource nicNoLb 'Microsoft.Network/networkInterfaces@2021-05-01' = if(loadBalancerBackendPoolId == ''){
  name: '${vmName}-nicNoLb'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: location
  properties: {
    availabilitySet: availSetId != '' ? {
      id: availSetId
    } : null
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxConfiguration)
    }
    storageProfile: {
      imageReference: {
        publisher: Publisher
        offer: Offer
        sku: redHatsku
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}_OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: loadBalancerBackendPoolId != '' ? nic.id : nicNoLb.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageUri // diagStorage.properties.primaryEndpoints.blob
      }
    }
  }
}

resource webServerConfig 'Microsoft.Compute/virtualMachines/extensions@2021-04-01' = if(enableWebServer){
  parent: vm

  name: 'enable-webServer'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'echo \'${loadFileAsBase64('../scripts/enable-nginx.sh')}\' | base64 -d > decodedScript.sh && chmod +x ./decodedScript.sh && ./decodedScript.sh'
    }
  }
}
