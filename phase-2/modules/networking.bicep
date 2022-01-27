param location string
param redHatTags object

var webTierSubnetName = 'web-tier-subnet'
var appTierSubnetName = 'app-tier-subnet'
var databaseTierSubnetName = 'database-tier-subnet'
var jumpSubnetName = 'jump-subnet'

var webNSGName_var = 'web-tier-nsg'
var appNSGName_var = 'app-tier-nsg'
var jumpNSGName_var = 'jump-nsg'

var webLoadBalancerName = 'web-lb'
var weblbIPAddressName_var = 'web-lb-pip'
var weblbDnsLabel = 'weblb${uniqueString(resourceGroup().id)}'

// constructed IDs to avoid circular reference
var webFrontEndIPConfigID = resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', webLoadBalancerName, 'loadBalancerFrontEnd')
var weblbBackendPoolID = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', webLoadBalancerName, 'loadBalancerBackend')
var weblbProbeHttpID = resourceId('Microsoft.Network/loadBalancers/probes', webLoadBalancerName, 'weblbProbeHttp')
var weblbProbeHttpsID = resourceId('Microsoft.Network/loadBalancers/probes', webLoadBalancerName, 'weblbProbeHttps')

var internalLoadBalancerName = 'internal-lb'
var internalFrontEndIPConfigID = resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', internalLoadBalancerName, 'loadBalancerFrontEnd')
var internallbBackendPoolID = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', internalLoadBalancerName, 'loadBalancerBackend')
var internallbProbeSSHID = resourceId('Microsoft.Network/loadBalancers/probes', internalLoadBalancerName, 'internallbProbeSSH')

@description('Enter Public IP CIDR to allow for accessing the deployment. Enter in 0.0.0.0/0 format, you can always modify these later in NSG Settings')
//@minLength(7)
param remoteAllowedCIDR string = '0.0.0.0/0'

// NSGs
resource webNSGName 'Microsoft.Network/networkSecurityGroups@2016-03-30' = {
  name: webNSGName_var
  location: location
  tags: {
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
    provider: redHatTags.provider
  }
  properties: {}
}

resource databaseNSGName 'Microsoft.Network/networkSecurityGroups@2016-03-30' = {
  name: 'database-tier-nsg'
  location: location
  tags: {
    displayName: 'Database NSG'
    provider: redHatTags.provider
  }
  properties: {}
}

resource jumpNSGName 'Microsoft.Network/networkSecurityGroups@2016-03-30' = {
  name: jumpNSGName_var
  location: location
  tags: {
    displayName: 'Jump NSG'
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
resource jumpIPAddress 'Microsoft.Network/publicIPAddresses@2016-03-30' = {
  name: 'jump-pip'
  location: location
  tags: {
    displayName: 'Jump VM Public IP'
    provider: redHatTags.provider
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: 'jump${uniqueString(resourceGroup().id)}'
    }
    idleTimeoutInMinutes: 4
  }
}

resource webLbPip 'Microsoft.Network/publicIPAddresses@2016-03-30' = {
  name: weblbIPAddressName_var
  location: location
  tags: {
    displayName: 'Web LB Public IP'
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
  name: 'RedHat3Tier-vnet'
  location: location
  tags: {
    displayName: 'Virtual Network'
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

resource webLoadBalancer 'Microsoft.Network/loadBalancers@2015-06-15' = {
  name: webLoadBalancerName
  location: location
  tags: {
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
  name: internalLoadBalancerName
  location: location
  tags: {
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

output vnetName string = vnet.name

output webTierSubnetName string = webTierSubnetName
output appTierSubnetName string = appTierSubnetName
output dbTierSubnetName string = databaseTierSubnetName
output jumpSubnetName string = jumpSubnetName

output webLoadBalancerId string = webLoadBalancer.id
output webBackendPoolId string = weblbBackendPoolID

output internalLoadBalancerId string = internalLoadBalancer.id
output internalBackendPoolId string = internallbBackendPoolID

output jumpIpAddressId string = jumpIPAddress.id

output webLoadBalancerIP string = webLbPip.properties.ipAddress
output webLoadBalancerFqdn string = webLbPip.properties.dnsSettings.fqdn
output jumpVMIP string = jumpIPAddress.properties.ipAddress
output jumpVMFqdn string = jumpIPAddress.properties.dnsSettings.fqdn
