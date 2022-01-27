@description('Username for the Virtual Machines')
param adminUsername string

@description('Number of Web servers to be deployed')
param webTierVmCount int = 2

@description('Number of App servers to be deployed')
param appTierVmCount int = 2

@description('Number of Database servers to be deployed')
param databaseTierVmCount int = 2

@description('Enter Public IP CIDR to allow for accessing the deployment.Enter in 0.0.0.0/0 format, you can always modify these later in NSG Settings')
@minLength(7)
param remoteAllowedCIDR string = '0.0.0.0/0'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'sshPublicKey'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

@description('Default VM Size')
param vmSize string = 'Standard_D2_v3'

var diagStorageAccountName_var = '${uniqueString(resourceGroup().id)}diagstorage'
var virtualNetworkName_var = 'RedHat3Tier-vnet'
var webTierSubnetName = 'web-tier-subnet'
var appTierSubnetName = 'app-tier-subnet'
var databaseTierSubnetName = 'database-tier-subnet'
var jumpSubnetName = 'jump-subnet'
var webNSGName_var = 'web-tier-nsg'
var appNSGName_var = 'app-tier-nsg'
var databaseNSGName_var = 'database-tier-nsg'
var jumpNSGName_var = 'jump-nsg'
var webLoadBalancerName = 'web-lb'
var weblbIPAddressName_var = 'web-lb-pip'
var weblbDnsLabel = 'weblb${uniqueString(resourceGroup().id)}'
//var webLoadBalancerIPID = webLbPip.id

// constructed IDs to avoid circular reference
var webFrontEndIPConfigID = resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', webLoadBalancerName, 'loadBalancerFrontEnd')
var weblbBackendPoolID = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', webLoadBalancerName, 'loadBalancerBackend')
var weblbProbeHttpID = resourceId('Microsoft.Network/loadBalancers/probes', webLoadBalancerName, 'weblbProbeHttp')
var weblbProbeHttpsID = resourceId('Microsoft.Network/loadBalancers/probes', webLoadBalancerName, 'weblbProbeHttps')

var internalLoadBalancerName_var = 'internal-lb'
var internalFrontEndIPConfigID = resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', internalLoadBalancerName_var, 'loadBalancerFrontEnd')
var internallbBackendPoolID = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', internalLoadBalancerName_var, 'loadBalancerBackend')
var internallbProbeSSHID = resourceId('Microsoft.Network/loadBalancers/probes', internalLoadBalancerName_var, 'internallbProbeSSH')
var jumpIPAddressName_var = 'jump-pip'
var jumpDnsLabel = 'jump${uniqueString(resourceGroup().id)}'
var availSetName = 'avail-set-'
var webTierVmNicName = '${webTierVmName}-nic-'
var appTierVmNicName = '${appTierVmName}-nic-'
var databaseTierVmNicName = '${databaseTierVmName}-nic-'
var jumpVmNicName_var = '${jumpVmName_var}-nic'
var redHatsku = '7.3'
var Publisher = 'RedHat'
var Offer = 'RHEL'
var webTierVmName = 'web-tier-vm'
var appTierVmName = 'app-tier-vm'
var databaseTierVmName = 'database-tier-vm'
var jumpVmName_var = 'jump-vm'
var redHatTags = {
  type: 'object'
  provider: '9d2c71fc-96ba-4b4a-93b3-14def5bc96fc'
}
var quickstartTags = {
  type: 'object'
  name: 'rhel-3tier-iaas'
}
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

resource diagStorageAccountName 'Microsoft.Storage/storageAccounts@2021-01-01' = {
  name: diagStorageAccountName_var
  location: location
  tags: {
    displayName: 'Diagnostics Storage Account'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {}
}

// NSGs
resource webNSGName 'Microsoft.Network/networkSecurityGroups@2016-03-30' = {
  name: webNSGName_var
  location: location
  tags: {
    displayName: 'Web NSG'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    securityRules: [
      {
        name: 'HTTP-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: remoteAllowedCIDR
          destinationAddressPrefix: '10.0.1.0/24'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'HTTPS-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: remoteAllowedCIDR
          destinationAddressPrefix: '10.0.1.0/24'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource appNSGName 'Microsoft.Network/networkSecurityGroups@2016-03-30' = {
  name: appNSGName_var
  location: location
  tags: {
    displayName: 'App NSG'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {}
}

resource databaseNSGName 'Microsoft.Network/networkSecurityGroups@2016-03-30' = {
  name: databaseNSGName_var
  location: location
  tags: {
    displayName: 'Database NSG'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {}
}

resource jumpNSGName 'Microsoft.Network/networkSecurityGroups@2016-03-30' = {
  name: jumpNSGName_var
  location: location
  tags: {
    displayName: 'Jump NSG'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    securityRules: [
      {
        name: 'SSH-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: remoteAllowedCIDR
          destinationAddressPrefix: '10.0.0.128/25'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

// IP Addresses
resource jumpIPAddressName 'Microsoft.Network/publicIPAddresses@2016-03-30' = {
  name: jumpIPAddressName_var
  location: location
  tags: {
    displayName: 'Jump VM Public IP'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: jumpDnsLabel
    }
    idleTimeoutInMinutes: 4
  }
}

resource webLbPip 'Microsoft.Network/publicIPAddresses@2016-03-30' = {
  name: weblbIPAddressName_var
  location: location
  tags: {
    displayName: 'Web LB Public IP'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: weblbDnsLabel
    }
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2016-03-30' = {
  name: virtualNetworkName_var
  location: location
  tags: {
    displayName: 'Virtual Network'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: webTierSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: webNSGName.id
          }
        }
      }
      {
        name: appTierSubnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: {
            id: appNSGName.id
          }
        }
      }
      {
        name: databaseTierSubnetName
        properties: {
          addressPrefix: '10.0.3.0/24'
          networkSecurityGroup: {
            id: databaseNSGName.id
          }
        }
      }
      {
        name: jumpSubnetName
        properties: {
          addressPrefix: '10.0.0.128/25'
          networkSecurityGroup: {
            id: jumpNSGName.id
          }
        }
      }
    ]
  }
}

resource availSets 'Microsoft.Compute/availabilitySets@2017-12-01' = [for i in range(0, 3): {
  name: '${availSetName}${(i + 1)}'
  location: location
  tags: {
    displayName: 'Availability Sets'
    quickstartName: quickstartTags.name
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

resource webLoadBalancer 'Microsoft.Network/loadBalancers@2015-06-15' = {
  name: webLoadBalancerName
  location: location
  tags: {
    displayName: 'External Load Balancer'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'loadBalancerFrontEnd'
        properties: {
          publicIPAddress: {
            id: webLbPip.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'loadBalancerBackend'
      }
    ]
    loadBalancingRules: [
      {
        name: 'LBRuleForlb80IP'
        properties: {
          frontendIPConfiguration: {
            id: webFrontEndIPConfigID
          }
          backendAddressPool: {
            id: weblbBackendPoolID
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 5
          enableFloatingIP: false
          probe: {
            id: weblbProbeHttpID
          }
        }
      }
      {
        name: 'LBRuleForlb443IP'
        properties: {
          frontendIPConfiguration: {
            id: webFrontEndIPConfigID
          }
          backendAddressPool: {
            id: weblbBackendPoolID
          }
          protocol: 'Tcp'
          frontendPort: 443
          backendPort: 443
          idleTimeoutInMinutes: 5
          enableFloatingIP: false
          probe: {
            id: weblbProbeHttpsID
          }
        }
      }
    ]
    probes: [
      {
        name: 'weblbProbeHttp'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
      {
        name: 'weblbProbeHttps'
        properties: {
          protocol: 'Tcp'
          port: 443
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
  }
}

resource internalLoadBalancer 'Microsoft.Network/loadBalancers@2015-06-15' = {
  name: internalLoadBalancerName_var
  location: location
  tags: {
    displayName: 'Internal Load Balancer'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'loadBalancerFrontEnd'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, webTierSubnetName)
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'loadBalancerBackEnd'
      }
    ]
    loadBalancingRules: [
      {
        name: 'internallbruleSSH'
        properties: {
          frontendIPConfiguration: {
            id: internalFrontEndIPConfigID
          }
          backendAddressPool: {
            id: internallbBackendPoolID
          }
          probe: {
            id: internallbProbeSSHID
          }
          protocol: 'Tcp'
          frontendPort: 22
          backendPort: 22
          idleTimeoutInMinutes: 15
        }
      }
    ]
    probes: [
      {
        name: 'internallbProbeSSH'
        properties: {
          protocol: 'Tcp'
          port: 22
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
  }
}

resource webTierNics 'Microsoft.Network/networkInterfaces@2016-03-30' = [for i in range(0, webTierVmCount): {
  name: '${webTierVmNicName}${(i + 1)}'
  location: location
  tags: {
    displayName: 'Web Tier VM NICs'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, webTierSubnetName)
          }
          loadBalancerBackendAddressPools: [
            {
              id: weblbBackendPoolID
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    webLoadBalancer
  ]
}]

resource appTierNics 'Microsoft.Network/networkInterfaces@2016-03-30' = [for i in range(0, appTierVmCount): {
  name: '${appTierVmNicName}${(i + 1)}'
  location: location
  tags: {
    displayName: 'App Tier VM NICs'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName_var, appTierSubnetName)
          }
          loadBalancerBackendAddressPools: [
            {
              id: internallbBackendPoolID
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    vnet
    internalLoadBalancer
  ]
}]

resource dbTierNics 'Microsoft.Network/networkInterfaces@2016-03-30' = [for i in range(0, databaseTierVmCount): {
  name: '${databaseTierVmNicName}${(i + 1)}'
  location: location
  tags: {
    displayName: 'Database Tier VM NICs'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName_var, databaseTierSubnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}]

resource jumpVmNicName 'Microsoft.Network/networkInterfaces@2016-03-30' = {
  name: jumpVmNicName_var
  location: location
  tags: {
    displayName: 'Jump VM NIC'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: jumpIPAddressName.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName_var, jumpSubnetName)
          }
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource webTierVMs 'Microsoft.Compute/virtualMachines@2017-03-30' = [for i in range(0, webTierVmCount): {
  name: '${webTierVmName}-${(i + 1)}'
  location: location
  tags: {
    displayName: 'Web Tier VMs'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    availabilitySet: {
      id: availSets[0].id
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'webserver${(i + 1)}'
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
        name: '${webTierVmName}-${(i + 1)}_OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: webTierNics[i].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagStorageAccountName.properties.primaryEndpoints.blob
      }
    }
  }
}]

resource webServerSetup 'Microsoft.Compute/virtualMachines/extensions@2021-04-01' = [for i in range(0, webTierVmCount): {
  parent: webTierVMs[i]

  name: 'enable-nginx'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'echo \'${loadFileAsBase64('./scripts/enable-nginx.sh')}\' | base64 -d > decodedScript.sh && chmod +x ./decodedScript.sh && ./decodedScript.sh'
    }
  }
}]

resource appTierVMs 'Microsoft.Compute/virtualMachines@2017-03-30' = [for i in range(0, appTierVmCount): {
  name: '${appTierVmName}-${(i + 1)}'
  location: location
  tags: {
    displayName: 'App Tier VMs'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    availabilitySet: {
      id: availSets[1].id
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'appserver${(i + 1)}'
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
        name: '${appTierVmName}-${(i + 1)}_OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: appTierNics[i].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagStorageAccountName.properties.primaryEndpoints.blob
      }
    }
  }
}]

resource dbTierVMs 'Microsoft.Compute/virtualMachines@2017-03-30' = [for i in range(0, databaseTierVmCount): {
  name: '${databaseTierVmName}-${(i + 1)}'
  location: location
  tags: {
    displayName: 'Database Tier VMs'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    availabilitySet: {
      id: availSets[2].id
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'databaseserver${(i + 1)}'
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
        name: '${databaseTierVmName}-${(i + 1)}_OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: dbTierNics[i].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagStorageAccountName.properties.primaryEndpoints.blob
      }
    }
  }
}]

resource jumpVmName 'Microsoft.Compute/virtualMachines@2017-03-30' = {
  name: jumpVmName_var
  location: location
  tags: {
    displayName: 'Jump VM'
    quickstartName: quickstartTags.name
    provider: redHatTags.provider
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'jumpvm'
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
        name: '${jumpVmName_var}_OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: jumpVmNicName.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagStorageAccountName.properties.primaryEndpoints.blob
      }
    }
  }
}

output webLoadBalancerIP string = webLbPip.properties.ipAddress
output webLoadBalancerFqdn string = webLbPip.properties.dnsSettings.fqdn
output jumpVMIP string = jumpIPAddressName.properties.ipAddress
output jumpVMFqdn string = jumpIPAddressName.properties.dnsSettings.fqdn
