# Get-AzZoneMappings.ps1

> **⚠️ Breaking Change in v2.1:** This script now uses **Azure PowerShell module** instead of Azure CLI. Previous versions (v1.0-v2.0) required `az login` and Azure CLI installation. Current version requires `Connect-AzAccount` and the Az PowerShell module.

## Overview

Discovers physical-to-logical availability zone mappings for Azure subscriptions. This script queries Azure's location metadata to determine how logical zones (1, 2, 3) map to physical datacenter zones (az1, az2, az3) in your subscriptions.

## Synopsis

```powershell
Get-AzZoneMappings.ps1 [-SubscriptionId <string>] [-OutputPath <string>]
```

## Description

Azure availability zones provide physical separation within a region, but the logical zone numbers (1, 2, 3) you specify when deploying resources map to different physical zones (az1, az2, az3) in each subscription. This script reveals these mappings, which is critical for:

- **Cross-subscription HA planning** - Ensuring VMs in different subscriptions are truly in different physical zones
- **Disaster recovery** - Understanding actual physical separation
- **Compliance** - Documenting physical infrastructure layout
- **Capacity planning** - Coordinating deployments across subscriptions

## Parameters

### -SubscriptionId

**Type:** String  
**Required:** No  
**Default:** All subscriptions in current tenant

Azure subscription ID to query. If not provided, processes all subscriptions in the current tenant.

```powershell
# Single subscription
.\Get-AzZoneMappings.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"
```

### -OutputPath

**Type:** String  
**Required:** No  
**Default:** Returns PowerShell objects

Path to export results as CSV. If not provided, returns results as PowerShell objects.

```powershell
# Export to CSV
.\Get-AzZoneMappings.ps1 -OutputPath "zones.csv"
```

## Prerequisites

- **Azure PowerShell module (Az)** - `Install-Module -Name Az -Scope CurrentUser`
- **PowerShell** 5.1 or later (PowerShell 7+ recommended)
- Authenticated with Azure: `Connect-AzAccount`
- Reader access to target subscriptions

## Output

### PowerShell Objects (Default)

Returns an array of custom objects with properties:

| Property | Type | Description |
|----------|------|-------------|
| Subscription | String | Subscription name |
| SubscriptionId | String | Subscription GUID |
| PhysicalZone | String | Physical zone identifier (az1, az2, az3) |
| LogicalZone | Integer | Logical zone number (1, 2, 3) |

```powershell
Subscription SubscriptionId                       PhysicalZone LogicalZone
------------ --------------                       ------------ -----------
Production   12345678-1234-1234-1234-123456789abc az1          1
Production   12345678-1234-1234-1234-123456789abc az3          2
Production   12345678-1234-1234-1234-123456789abc az2          3
```

### CSV Export (When -OutputPath specified)

Creates a CSV file with the same columns:

```csv
Subscription,SubscriptionId,PhysicalZone,LogicalZone
Production,12345678-1234-1234-1234-123456789abc,az1,1
Production,12345678-1234-1234-1234-123456789abc,az3,2
Production,12345678-1234-1234-1234-123456789abc,az2,3
```

## Usage Examples

### Example 1: Get All Subscriptions (PowerShell Objects)

```powershell
# Returns objects for all subscriptions in current tenant
$zones = .\Get-AzZoneMappings.ps1

# Display results
$zones | Format-Table -AutoSize

# Filter to specific physical zone
$zones | Where-Object { $_.PhysicalZone -eq 'az1' }

# Group by subscription
$zones | Group-Object Subscription
```

### Example 2: Export All to CSV

```powershell
# Export all subscriptions to CSV
.\Get-AzZoneMappings.ps1 -OutputPath "all-zones.csv"
```

### Example 3: Specific Subscription

```powershell
# Get mappings for one subscription
$prodZones = .\Get-AzZoneMappings.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"

# Create lookup table
$lookup = @{}
foreach ($zone in $prodZones) {
    $lookup[$zone.LogicalZone] = $zone.PhysicalZone
}

# Use in code
$physicalZone = $lookup["1"]  # Returns "az1" or similar
```

### Example 4: Pipeline Integration

```powershell
# Get zones and export to Excel
$zones = .\Get-AzZoneMappings.ps1
$zones | Export-Excel -Path "ZoneMappings.xlsx" -AutoSize -TableName "Zones"

# Filter and export specific subscriptions
$zones | Where-Object { $_.Subscription -like "*Prod*" } | 
    Export-Csv "ProductionZones.csv" -NoTypeInformation
```

### Example 5: Compare Subscriptions

```powershell
# Get all zones
$allZones = .\Get-AzZoneMappings.ps1

# Group by logical zone to see physical zone variations
$allZones | Group-Object LogicalZone | ForEach-Object {
    Write-Host "`nLogical Zone $($_.Name):"
    $_.Group | Format-Table Subscription, PhysicalZone -AutoSize
}
```

## Use Cases

### 1. Cross-Subscription HA Verification

**Scenario:** You have a multi-tier application split across two subscriptions (web in Subscription A, database in Subscription B). Both are deployed to Logical Zone 1 for high availability.

**Problem:** Without knowing the physical zones, you can't verify they're actually separated.

**Solution:**
```powershell
$zones = .\Get-AzZoneMappings.ps1

# Check if both subscriptions use same physical zone for logical zone 1
$webPhysical = ($zones | Where-Object { 
    $_.Subscription -eq "Web-Subscription" -and $_.LogicalZone -eq 1 
}).PhysicalZone

$dbPhysical = ($zones | Where-Object { 
    $_.Subscription -eq "DB-Subscription" -and $_.LogicalZone -eq 1 
}).PhysicalZone

if ($webPhysical -eq $dbPhysical) {
    Write-Warning "Both tiers are in same physical zone! ($webPhysical)"
} else {
    Write-Host "Tiers are properly separated: Web=$webPhysical, DB=$dbPhysical" -ForegroundColor Green
}
```

### 2. Audit Report Generation

**Scenario:** Generate compliance report showing zone mappings for all subscriptions.

```powershell
# Get all mappings
$zones = .\Get-AzZoneMappings.ps1

# Create audit report
$report = $zones | Select-Object `
    Subscription,
    SubscriptionId,
    @{N='Zone Assignment'; E={"Logical $($_.LogicalZone) → Physical $($_.PhysicalZone)"}},
    @{N='Audit Date'; E={Get-Date -Format "yyyy-MM-dd HH:mm:ss"}}

# Export with timestamp
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$report | Export-Csv "Zone-Audit-$timestamp.csv" -NoTypeInformation
```

### 3. Disaster Recovery Planning

**Scenario:** Plan Azure Site Recovery configuration to ensure proper zone separation.

```powershell
# Get zone mappings for DR subscription
$drZones = .\Get-AzZoneMappings.ps1 -SubscriptionId $drSubscriptionId

# Create zone mapping guide
Write-Host "DR Zone Mapping Guide:"
Write-Host "====================="
foreach ($zone in $drZones) {
    Write-Host "Deploy to Logical Zone $($zone.LogicalZone) for Physical Zone $($zone.PhysicalZone)"
}
```

### 4. Capacity Planning Across Subscriptions

**Scenario:** You're planning to deploy resources and want to balance across physical zones considering multiple subscriptions.

```powershell
# Get all zones
$zones = .\Get-AzZoneMappings.ps1

# Calculate physical zone distribution
$distribution = $zones | Group-Object PhysicalZone | Select-Object `
    Name,
    @{N='Subscriptions Using This Zone'; E={$_.Count / 3}}  # 3 logical zones per subscription

Write-Host "Physical Zone Distribution:"
$distribution | Format-Table -AutoSize
```

## Technical Details

### API Endpoints

The script uses Azure PowerShell's `Invoke-AzRestMethod` to query location metadata:

```powershell
Invoke-AzRestMethod -Method GET -Path "/subscriptions/{subscriptionId}/locations?api-version=2022-12-01"
```

### Zone Mapping Logic

1. Queries all locations for a subscription
2. Finds first region with `availabilityZoneMappings` property
3. Extracts physical zone identifiers (e.g., "uksouth-az1")
4. Parses to get zone suffix (az1, az2, az3)
5. Maps to corresponding logical zones (1, 2, 3)

### Caching

The script does not cache results between executions. For frequent queries, consider:

```powershell
# Cache results in session variable
if (-not $global:ZoneCache) {
    $global:ZoneCache = .\Get-AzZoneMappings.ps1
}

# Use cached data
$zones = $global:ZoneCache
```

## Error Handling

The script handles common errors:

- **No Azure authentication** - Exits with error message
- **Subscription not found** - Exits with specific error
- **No zone mappings available** - Returns empty array
- **API errors** - Continues to next subscription

## Performance Considerations

- **Single subscription:** ~2-5 seconds
- **10 subscriptions:** ~20-50 seconds  
- **100+ subscriptions:** Several minutes

Use `-SubscriptionId` to target specific subscriptions for faster execution.

## Integration with Get-AzVMZoneDistribution.ps1

This script is used internally by `Get-AzVMZoneDistribution.ps1`:

```powershell
# Get-AzVMZoneDistribution.ps1 calls this script
$zoneMappings = .\Get-AzZoneMappings.ps1 -SubscriptionId $subId

# Converts to hashtable for lookups
$lookup = @{}
foreach ($m in $zoneMappings) {
    $lookup[$m.LogicalZone.ToString()] = $m.PhysicalZone
}
```

## Troubleshooting

### Issue: "Error: Subscription ID not found in the current tenant"

**Cause:** Subscription doesn't exist or is in a different tenant

**Solution:**
```powershell
# List available subscriptions
Get-AzSubscription | Format-Table Name, Id, TenantId -AutoSize

# Switch tenant if needed
Connect-AzAccount -TenantId <tenant-id>
```

### Issue: No mappings returned but subscriptions exist

**Cause:** Region doesn't support availability zones

**Solution:** Most Azure regions now support zones, but some don't. The script returns mappings only for regions that support them.

### Issue: Script runs slowly

**Cause:** Querying many subscriptions

**Solution:**
```powershell
# Query specific subscriptions in parallel
$subscriptions = @("sub1-guid", "sub2-guid", "sub3-guid")
$results = $subscriptions | ForEach-Object -Parallel {
    & ".\Get-AzZoneMappings.ps1" -SubscriptionId $_
} -ThrottleLimit 5
```

## Best Practices

1. **Cache results** - Zone mappings rarely change, cache for session
2. **Filter early** - Use `-SubscriptionId` when possible
3. **Validate before deployment** - Always check mappings before zone-aware deployments
4. **Document mappings** - Export to CSV and version control
5. **Automate audits** - Schedule regular mapping checks

## Related Scripts

- **Get-AzVMZoneDistribution.ps1** - Analyzes VM distribution using these mappings
- See [README-Get-AzVMZoneDistribution.md](README-Get-AzVMZoneDistribution.md)

## See Also

- [Main README](README.md) - Repository overview
- [Azure Availability Zones](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview)
- [Azure PowerShell Reference](https://learn.microsoft.com/en-us/powershell/azure/)

---

## Version History

**v2.1 (Current)** - Migrated from Azure CLI to Azure PowerShell module
- Uses `Invoke-AzRestMethod` instead of `az rest`
- Authentication via `Connect-AzAccount` instead of `az login`
- Better error handling and Azure connection validation
- No Azure CLI installation required

**v1.0-v2.0** - Used Azure CLI (`az` commands)
