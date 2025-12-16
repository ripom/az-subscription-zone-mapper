# Azure Subscription Zone Mapper

A comprehensive PowerShell toolkit for discovering and analyzing Azure availability zone mappings and VM distributions across subscriptions and tenants.

## Overview

This repository contains two powerful PowerShell scripts designed to help Azure administrators understand and analyze availability zone configurations:

### 🗺️ Get-AzZoneMappings.ps1
Discovers physical-to-logical availability zone mappings for Azure subscriptions. Essential for understanding how Azure's logical zones (1, 2, 3) map to physical datacenter zones (az1, az2, az3) in your subscriptions.

**Returns PowerShell objects by default** - Enables pipeline integration and flexible data manipulation. Optionally exports to CSV.

### 📊 Get-AzVMZoneDistribution.ps1
Analyzes VM distribution across availability zones in your Azure environment. Generates comprehensive reports (HTML or console) showing which VMs are deployed in which physical zones, helping identify imbalances and plan for high availability.

---

> **⚠️ Breaking Change in v2.1:** Get-AzZoneMappings.ps1 now requires **Azure PowerShell module** instead of Azure CLI. If upgrading from v1.0/v2.0, uninstall Azure CLI dependency and use `Connect-AzAccount` instead of `az login`.

## Key Features

- **Multi-tenant support** - Select from multiple Azure tenants
- **Flexible scope** - Scan all subscriptions or target specific ones
- **Physical zone mapping** - Understand actual datacenter zone assignments
- **VM distribution analysis** - Identify zone imbalances and HA gaps
- **Rich reporting** - HTML reports with charts or console output
- **Progress tracking** - Real-time progress bars for long-running operations

## Prerequisites

**Both scripts require:**
- **Azure PowerShell module** (`Az`) installed: `Install-Module -Name Az -Repository PSGallery -Force`
- **PowerShell** 5.1 or later (PowerShell 7+ recommended)  
- Active Azure authentication: `Connect-AzAccount`

## Quick Start

### 1️⃣ Get Zone Mappings

```powershell
# Authenticate with Azure PowerShell
Connect-AzAccount

# Get zone mappings for all subscriptions (returns PowerShell objects)
$zones = .\Get-AzZoneMappings.ps1

# Get zone mappings for specific subscription
$zones = .\Get-AzZoneMappings.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"

# Export to CSV
.\Get-AzZoneMappings.ps1 -OutputPath "zones.csv"
```

### 2️⃣ Analyze VM Distribution

```powershell
# Authenticate with Azure PowerShell
Connect-AzAccount

# Interactive tenant selection + console summary
.\Get-AzVMZoneDistribution.ps1

# Specific tenant + HTML report
.\Get-AzVMZoneDistribution.ps1 -TenantId "12345678-1234-1234-1234-123456789012" -OutputPath "report.html"

# Specific subscription only
.\Get-AzVMZoneDistribution.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"
```

## Understanding Zone Mappings

### Why Zone Mappings Matter

Azure uses **logical zones** (1, 2, 3) in each subscription, but these map to different **physical zones** (az1, az2, az3) in the datacenter. This means:

- Logical Zone 1 in Subscription A might be Physical Zone az1
- Logical Zone 1 in Subscription B might be Physical Zone az3

**This is critical for:**
- Cross-subscription high availability planning
- Disaster recovery strategies
- Understanding actual physical separation of resources
- Compliance and regulatory requirements

### Example Mapping

| Subscription | Logical Zone | Physical Zone |
|-------------|--------------|---------------|
| Production  | 1            | az3           |
| Production  | 2            | az1           |
| Production  | 3            | az2           |
| Development | 1            | az1           |
| Development | 2            | az2           |
| Development | 3            | az3           |

In this example, VMs in Logical Zone 1 are in **different physical zones** across subscriptions!

## Documentation

For detailed information about each script:

- 📖 **[Get-AzZoneMappings.md](README-Get-AzZoneMappings.md)** - Zone mapping discovery
- 📖 **[Get-AzVMZoneDistribution.md](README-Get-AzVMZoneDistribution.md)** - VM distribution analysis

## Use Cases

### High Availability Planning
- Verify VMs in different logical zones are actually in different physical zones
- Identify zone imbalances in VM distributions
- Plan Azure Site Recovery configurations

### Compliance & Auditing  
- Document physical zone assignments for compliance reports
- Verify infrastructure meets regulatory requirements for physical separation
- Generate audit trails of zone configurations

### Capacity Planning
- Understand zone distribution before adding new workloads
- Identify zones with capacity constraints
- Plan migrations with zone considerations

### Multi-Subscription Environments
- Map zone relationships across subscription boundaries
- Coordinate deployments across multiple subscriptions
- Understand tenant-wide zone utilization

## Repository Structure

```
az-subscription-zone-mapper/
├── Get-AzZoneMappings.ps1           # Zone mapping discovery script
├── Get-AzVMZoneDistribution.ps1     # VM distribution analysis script
├── README.md                         # This file
├── README-Get-AzZoneMappings.md     # Detailed docs for zone mapping
└── README-Get-AzVMZoneDistribution.md # Detailed docs for VM analysis
```

## Integration Examples

### Pipeline Integration

```powershell
# Get zone mappings and filter by physical zone
$zones = .\Get-AzZoneMappings.ps1 | Where-Object { $_.PhysicalZone -eq 'az1' }

# Group by subscription to see zone distribution
$allZones = .\Get-AzZoneMappings.ps1
$allZones | Group-Object Subscription | Format-Table Name, Count -AutoSize

# Create lookup hashtable for automation
$zoneLookup = @{}
foreach ($zone in $allZones) {
    $key = "$($zone.SubscriptionId)-$($zone.LogicalZone)"
    $zoneLookup[$key] = $zone.PhysicalZone
}
```

### Scheduled Reporting

```powershell
# Weekly VM distribution report
$date = Get-Date -Format "yyyy-MM-dd"
.\Get-AzVMZoneDistribution.ps1 -TenantId $tenantId -OutputPath "VM-Report-$date.html"
```

## Troubleshooting

### Get-AzZoneMappings.ps1

**"Error: Subscription ID 'xxx' not found in the current tenant"**
- Run `Get-AzSubscription` to see available subscriptions
- Verify you're authenticated: `Connect-AzAccount`
- Check tenant context: `Get-AzContext`

### Get-AzVMZoneDistribution.ps1

**"Not connected to Azure. Please run 'Connect-AzAccount' first"**
- Authenticate with Azure PowerShell: `Connect-AzAccount`
- Verify connection: `Get-AzContext`

**"No VMs found" but VMs exist**
- Ensure you have Reader permissions on subscriptions
- Check if VMs are in the selected subscription: `Get-AzVM`

**"Warning: Get-AzZoneMappings.ps1 not found"**
- Ensure both scripts are in the same directory
- Get-AzVMZoneDistribution.ps1 depends on Get-AzZoneMappings.ps1

### General Issues

**Slow performance**
- Zone mapping queries can take time for subscriptions with many regions
- VM scanning is slower with many VMs and subscriptions
- Consider using `-SubscriptionId` to target specific subscriptions

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Changelog

### Version 2.1 (Current)
- **BREAKING CHANGE**: Get-AzZoneMappings.ps1 now uses Azure PowerShell module instead of Azure CLI
  - Replaced `az` commands with `Az` PowerShell cmdlets (`Invoke-AzRestMethod`, `Get-AzSubscription`, etc.)
  - Authentication changed from `az login` to `Connect-AzAccount`
  - Unified authentication across both scripts - only Azure PowerShell module required
  - No more dependency on Azure CLI installation
- Updated all documentation to reflect PowerShell module usage
- Improved error handling with Azure connection validation

### Version 2.0
- Added Get-AzVMZoneDistribution.ps1 for VM analysis
- HTML report generation with interactive charts
- Multi-tenant support with interactive selection
- PowerShell Az module integration for VM script
- Color-coded console output and HTML reports
- Optional parameters for flexible execution

### Version 1.0
- Initial Get-AzZoneMappings.ps1 release (using Azure CLI)
- Basic zone mapping discovery
- CSV export functionality

## License

MIT License - feel free to use and modify as needed.

## Support

For issues, questions, or contributions:
- 📝 [Open an issue](https://github.com/ripom/az-subscription-zone-mapper/issues)
- 💬 [Start a discussion](https://github.com/ripom/az-subscription-zone-mapper/discussions)

## Related Resources

- [Azure Availability Zones Documentation](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview)
- [Azure PowerShell Documentation](https://learn.microsoft.com/en-us/powershell/azure/)
- [Azure CLI Documentation](https://learn.microsoft.com/en-us/cli/azure/)