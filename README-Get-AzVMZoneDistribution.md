# Get-AzVMZoneDistribution.ps1

## Overview

Analyzes virtual machine distribution across Azure availability zones with tenant selection, multi-subscription scanning, and interactive HTML reporting. This script provides comprehensive visibility into your VM zone topology, infrastructure protection configuration, power states, and physical zone mappings.

**Now includes Infrastructure Protection analysis** - automatically detects and assesses availability zones, availability sets, and identifies VMs without infrastructure-level protection.

## Synopsis

```powershell
Get-AzVMZoneDistribution.ps1 [-TenantId <string>] [-SubscriptionId <string>] [-OutputPath <string>]
```

## Description

This script scans Azure subscriptions to analyze how VMs are distributed across availability zones and evaluates their infrastructure protection configuration. It provides:

- **Tenant selection** - Interactive picker for multi-tenant environments
- **Zone mapping** - Shows physical datacenter zones (az1, az2, az3) not just logical zones (1, 2, 3)
- **Protection assessment** - Identifies VMs with zone isolation, availability sets, or lacking protection
- **Availability set tracking** - Shows which VMs are in availability sets
- **Power state tracking** - Identifies running, stopped, and deallocated VMs
- **Visual reporting** - HTML reports with interactive charts and color-coded tables
- **Progress tracking** - Real-time progress bars during VM scanning

## Parameters

### -TenantId

**Type:** String  
**Required:** No  
**Default:** Interactive tenant selection or inferred from SubscriptionId

Azure tenant (directory) ID to connect to. If not provided:
- Shows interactive tenant selection if multiple tenants available
- Auto-detects tenant from SubscriptionId if provided
- Uses current Azure context if only one tenant

```powershell
# Explicit tenant
.\Get-AzVMZoneDistribution.ps1 -TenantId "12345678-1234-1234-1234-123456789012"
```

### -SubscriptionId

**Type:** String  
**Required:** No  
**Default:** All subscriptions in tenant

Azure subscription ID to analyze. If not provided, scans all subscriptions in the tenant.

```powershell
# Single subscription
.\Get-AzVMZoneDistribution.ps1 -SubscriptionId "abcd1234-1234-1234-1234-123456789012"

# Specific tenant and subscription
.\Get-AzVMZoneDistribution.ps1 -TenantId "tenant-guid" -SubscriptionId "sub-guid"
```

### -OutputPath

**Type:** String  
**Required:** No  
**Default:** Console summary

Path to save HTML report. If not provided, displays summary in console.

```powershell
# HTML report
.\Get-AzVMZoneDistribution.ps1 -OutputPath "vm-report.html"

# Console summary only
.\Get-AzVMZoneDistribution.ps1
```

### -ExportCSV

**Type:** String  
**Required:** No  
**Default:** None

Path to export VM details table to CSV file. When specified, exports all VM data to the provided file path. Works with or without `-OutputPath` parameter.

```powershell
# Export to CSV with HTML report
.\Get-AzVMZoneDistribution.ps1 -OutputPath "report.html" -ExportCSV "vm-details.csv"
# Creates: report.html and vm-details.csv

# Export to CSV without HTML report
.\Get-AzVMZoneDistribution.ps1 -ExportCSV "vm-zone-distribution.csv"
# Creates: vm-zone-distribution.csv

# Specific subscription with CSV export
.\Get-AzVMZoneDistribution.ps1 -SubscriptionId "sub-guid" -OutputPath "prod-vms.html" -ExportCSV "prod-vms.csv"
# Creates: prod-vms.html and prod-vms.csv
```

**CSV Columns:**
- VMName
- SubscriptionName
- ResourceGroup
- Location
- LogicalZone
- PhysicalZone
- AvailabilitySet
- ProtectionLevel
- VMSize
- PowerState

## Prerequisites

- **Azure PowerShell Module (Az)** - `Install-Module -Name Az -Scope CurrentUser`
- **PowerShell** 5.1 or later
- **Get-AzZoneMappings.ps1** - Must be in same directory
- Authenticated with Azure: `Connect-AzAccount`
- Reader access to target subscriptions

## Output

### Console Summary (Default)

Displays text-based summary with zone distribution:

```
=== Azure VM Zone Distribution Report ===

Connected to: admin@contoso.com

Processing subscription: Production (12345678-1234-1234-1234-123456789012)
Processing VMs: [####################] 100% (25/25)

=== Summary ===
Total VMs: 25
VMs with Zones: 20
VMs without Zones: 5

=== Zone Distribution ===
Zone    VM Count    Percentage    Physical Zone
----    --------    ----------    -------------
az1     12          48.00%        az1
az2     5           20.00%        az2
az3     3           12.00%        az3
No Zone 5           20.00%        -
```

### HTML Report (When -OutputPath specified)

Generates interactive HTML report with:

- **Summary cards** - Total VMs, subscriptions scanned, VMs with zones, VMs in availability sets, VMs without protection
- **Info box** - Explains protection levels and clarifies HA requires multiple instances
- **Zone Distribution by Region table** - Shows VM counts per zone, grouped by Azure region with percentages
- **Interactive horizontal bar chart** - Visual distribution across zones grouped by region (Chart.js)
  - Regions displayed on Y-axis for better readability
  - Stacked bars showing zone distribution (az1, az2, az3, No Zone)
  - Color-coded by zone for easy identification
- **Detailed VM table** - All VMs with columns:
  - VM Name
  - Resource Group
  - Location
  - Logical Zone
  - Physical Zone
  - Availability Set
  - Protection Level
  - Power State
- **Color coding**:
  - 🟢 Green cells - Zone-Isolated VMs (datacenter-level protection)
  - 🔵 Blue cells - Availability Set VMs (rack-level protection)
  - 🔴 Red cells - VMs without infrastructure protection
  - 🟡 Yellow rows - VMs without zones
- **Visual legend** - Explains all color codes
- **Responsive design** - Works on desktop and mobile

**HTML Report Preview:**

```html
<!-- Opens in browser showing styled report -->
VM Distribution Report
======================
[Summary Cards: 468 Total | 56 Subscriptions | 203 Zones | 2 Avail Sets | 263 No Protection]
[Info Box: Protection Level Explanations]
[Region Table: Zone distribution grouped by region]
[Horizontal Bar Chart: Visual distribution by region]
[VM Details Table: All VM Details with Color Coding]
```

## Usage Examples

### Example 1: Quick Console Summary

```powershell
# Scan all subscriptions, display in console
.\Get-AzVMZoneDistribution.ps1

# Output shown above in "Console Summary" section
```

### Example 2: Generate HTML Report

```powershell
# Create HTML report for all subscriptions
.\Get-AzVMZoneDistribution.ps1 -OutputPath "reports\vm-zones.html"

# Open in browser
Start-Process "reports\vm-zones.html"
```

### Example 3: Specific Subscription Analysis

```powershell
# Analyze single subscription
$subId = "12345678-1234-1234-1234-123456789012"
.\Get-AzVMZoneDistribution.ps1 -SubscriptionId $subId -OutputPath "prod-vms.html"
```

### Example 4: Export to CSV

```powershell
# Generate HTML report and export to CSV
.\Get-AzVMZoneDistribution.ps1 -OutputPath "vm-report.html" -ExportCSV "vm-details.csv"
# Creates: vm-report.html and vm-details.csv

# Export to CSV only (no HTML)
.\Get-AzVMZoneDistribution.ps1 -ExportCSV "vm-zone-distribution.csv"
# Creates: vm-zone-distribution.csv

# Import CSV for further analysis
$vmData = Import-Csv "vm-details.csv"
$vmData | Where-Object { $_.ProtectionLevel -eq "No Protection" } | Format-Table
```

### Example 5: Multi-Tenant Analysis

```powershell
# Interactive tenant selection (when you have access to multiple tenants)
.\Get-AzVMZoneDistribution.ps1

# Output:
# Available Azure Tenants:
# 1. Contoso (12345678-1234-1234-1234-123456789012)
# 2. Fabrikam (87654321-4321-4321-4321-210987654321)
# Select tenant (1-2): 1
# [Scans selected tenant...]
```

### Example 6: Automated Reporting with CSV Export

```powershell
# Daily report script
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = "reports\vm-zones-$timestamp.html"
$csvPath = "reports\vm-zones-$timestamp.csv"

.\Get-AzVMZoneDistribution.ps1 -OutputPath $reportPath -ExportCSV $csvPath

# Email both HTML and CSV reports
Send-MailMessage -To "team@contoso.com" -Subject "Daily VM Zone Report" `
    -Body "See attached reports" -Attachments $reportPath, $csvPath `
    -SmtpServer "smtp.contoso.com"
```

### Example 7: Filter Running VMs Only

```powershell
# Generate report, then filter HTML table manually
# Or parse console output programmatically

$output = .\Get-AzVMZoneDistribution.ps1 | Out-String

# Extract running VM count from output
if ($output -match "Running:\s+(\d+)") {
    $runningCount = $Matches[1]
    Write-Host "Found $runningCount running VMs"
}
```

## Use Cases

### 1. Infrastructure Protection Assessment

**Scenario:** Assess protection compliance across your Azure environment to identify at-risk VMs.

**Solution:**
```powershell
# Generate comprehensive protection report
.\Get-AzVMZoneDistribution.ps1 -OutputPath "protection-assessment.html"

# Review HTML report to identify:
# - VMs with zone isolation (green) ✅
# - VMs with availability sets (blue) 🔵
# - VMs without protection (red) ⚠️

# Action items based on findings:
# 1. Red VMs → Move to zones or add to availability sets
# 2. Blue VMs → Consider upgrading to zone-redundant architecture
# 3. Yellow rows → Legacy VMs without zone assignment

# Note: For true HA, deploy multiple instances with load balancing
```

### 2. Disaster Recovery Planning

**Scenario:** Assess current VM distribution to identify single points of failure.

**Solution:**
```powershell
# Generate comprehensive report
.\Get-AzVMZoneDistribution.ps1 -OutputPath "dr-assessment.html"

# Review HTML report to identify:
# - VMs without zone assignments (at risk)
# - VMs in availability sets (partial protection)
# - Unbalanced zone distribution per region
# - Critical workloads in single zones
# - Regional resilience gaps

# Action items:
# - Move unzoned VMs to availability zones
# - Rebalance VMs across zones within each region
# - Configure zone-redundant load balancers
# - Document protection level for each workload
# - For critical workloads, ensure multiple instances across zones
# - Review region-specific zone distribution for capacity planning
```

### 3. Compliance Audit

**Scenario:** Document VM zone placement for SOC2/ISO compliance.

**Solution:**
```powershell
# Generate timestamped audit report
$auditDate = Get-Date -Format "yyyy-MM-dd"
$reportPath = "compliance\VM-Zone-Audit-$auditDate.html"

.\Get-AzVMZoneDistribution.ps1 -OutputPath $reportPath

# Report includes:
# - Complete VM inventory with zones
# - Physical datacenter mappings
# - Availability set assignments
# - Protection level for each VM
# - Power state verification
# - Visual distribution analysis

# Save to compliance documentation repository
Copy-Item $reportPath -Destination "\\compliance-share\audits\$auditDate\"
```

### 4. Capacity Planning

**Scenario:** Plan capacity expansion across zones to maintain balance.

**Solution:**
```powershell
# Get current distribution
.\Get-AzVMZoneDistribution.ps1 -OutputPath "current-capacity.html"

# Review region-based zone distribution chart
# Example: northeurope region shows:
# - az1: 89 VMs (20%)
# - az2: 111 VMs (23.78%)
# - az3: 98 VMs (22.16%)
# - No Zone: 151 VMs (34.05%)

# Create deployment plan
$analysis = @"
Current Distribution (North Europe):
- az1: 20% (Balanced)
- az2: 24% (Slightly high)
- az3: 22% (Balanced)
- No Zone: 34% (High - needs migration)

Recommendation:
- Migrate No Zone VMs to zones
- Deploy new workloads evenly across az1, az2, az3
- Target: 33% / 33% / 33% distribution, 0% unzoned
"@

$analysis | Out-File "capacity-plan.txt"
```

### 5. Cost Optimization

**Scenario:** Identify deallocated VMs and assess infrastructure overhead.

**Solution:**
```powershell
# Generate report showing power states and protection config
.\Get-AzVMZoneDistribution.ps1 -OutputPath "vm-power-states.html"

# Review HTML report:
# - Green cells = Running (incurring compute costs)
# - Deallocated VMs = Storage costs only
# - Red cells = No protection (single VM costs)
# - Blue cells = Availability sets (infrastructure overhead)

# Identify candidates:
# - VMs deallocated > 30 days → Delete?
# - Dev/Test VMs with protection → Evaluate if needed
# - Orphaned unzoned VMs → Cleanup targets
```

### 6. Multi-Subscription Governance

**Scenario:** Enterprise with 50+ subscriptions needs zone and protection governance.

**Solution:**
```powershell
# Option 1: Full tenant scan
.\Get-AzVMZoneDistribution.ps1 -OutputPath "enterprise-zones.html"

# Option 2: Per-subscription reports
$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq 'Enabled' }

foreach ($sub in $subscriptions) {
    $fileName = "reports\$($sub.Name)-zones.html"
    .\Get-AzVMZoneDistribution.ps1 -SubscriptionId $sub.Id -OutputPath $fileName
    Write-Host "Created report: $fileName"
}

# Aggregate findings
# - Count subscriptions with VMs lacking protection
# - Identify subscriptions with poor zone balance
# - Find availability set usage patterns
# - Generate executive summary
```

### 7. Migration Validation
    $fileName = "reports\$($sub.Name)-zones.html"
    .\Get-AzVMZoneDistribution.ps1 -SubscriptionId $sub.Id -OutputPath $fileName
    Write-Host "Created report: $fileName"
}

# Aggregate findings
# - Count subscriptions with unzoned VMs
# - Identify subscriptions with poor zone balance
# - Generate executive summary
```

### 7. Migration Validation

**Scenario:** Verify VMs were correctly migrated to availability zones or sets.

**Solution:**
```powershell
# Pre-migration baseline
.\Get-AzVMZoneDistribution.ps1 -OutputPath "pre-migration.html"

# [Perform migration...]

# Post-migration validation
.\Get-AzVMZoneDistribution.ps1 -OutputPath "post-migration.html"

# Compare reports:
# - Verify protection level changed from "No Protection" to "Zone-Isolated" or "Availability Set"
# - Confirm zone distribution matches plan
# - Validate all VMs show correct physical zones
# - Check power states (all VMs should be running)
# - Confirm no VMs lost infrastructure protection during migration
```

### 8. Incident Response

**Scenario:** Azure announces maintenance on physical zone az2, identify impacted VMs.

**Solution:**
```powershell
# Generate current state report
.\Get-AzVMZoneDistribution.ps1 -OutputPath "zone-impact-analysis.html"

# Open HTML report and filter table by Physical Zone = "az2"
# Export impacted VM list

# Assess impact:
# - VMs in az2 only → High risk
# - VMs in availability sets → Check if other instances in different zones
# - VMs without protection → Single instance, no redundancy

# Create communication plan:
# - Notify owners of VMs in az2
# - Schedule failover testing (for multi-instance workloads)
# - Prepare rollback procedures
# - Monitor during maintenance window
```

## Technical Details

### Architecture

```
Get-AzVMZoneDistribution.ps1
│
├── Test-AzureConnection()
│   └── Handles tenant selection and authentication
│
├── Select-AzureTenant()
│   └── Interactive tenant picker
│
├── Get-ZoneMappings()
│   └── Calls Get-AzZoneMappings.ps1
│   └── Returns hashtable: {1→"az1", 2→"az2", 3→"az3"}
│
├── Main Processing
│   ├── Get-AzSubscription (list subscriptions)
│   ├── ForEach subscription:
│   │   ├── Set-AzContext
│   │   ├── Get-AzVM -Status
│   │   └── Extract zone and power state
│   └── Aggregate results
│
└── Output Generation
    ├── Console: Write-Host with colors
    └── HTML: Get-HTMLTemplate() with Chart.js
```

### Zone Mapping Integration

The script calls `Get-AzZoneMappings.ps1` internally:

```powershell
# Executed for each subscription
$mappingsPath = Join-Path $PSScriptRoot "Get-AzZoneMappings.ps1"
$zoneMappingResults = & $mappingsPath -SubscriptionId $subscriptionId

# Converted to hashtable for fast lookups
$zoneMappings = @{}
foreach ($mapping in $zoneMappingResults) {
    $zoneMappings[$mapping.LogicalZone.ToString()] = $mapping.PhysicalZone
}

# Used when processing VMs
$physicalZone = $zoneMappings[$vm.Zones[0]]
```

### Power State Detection

Multi-method approach for compatibility:

```powershell
# Method 1: PowerState property (Az 6.0+)
$powerState = $vm.PowerState

# Method 2: Statuses collection (Az 5.x)
if ([string]::IsNullOrWhiteSpace($powerState)) {
    $statusCode = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" }).Code
    $powerState = $statusCode -replace "^PowerState/", ""
}

# Method 3: InstanceView fallback (older versions)
if ([string]::IsNullOrWhiteSpace($powerState)) {
    $statusCode = ($vm.InstanceView.Statuses | Where-Object { $_.Code -like "PowerState/*" }).Code
    $powerState = $statusCode -replace "^PowerState/", ""
}

# Default if all fail
if ([string]::IsNullOrWhiteSpace($powerState)) {
    $powerState = "Unknown"
}
```

### HTML Report Structure

```html
<!DOCTYPE html>
<html>
<head>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0"></script>
    <style>
        /* Gradient header, responsive design */
        .vm-running { background-color: #d4edda; } /* Green */
        .no-zone { background-color: #fff3cd; }    /* Yellow */
    </style>
</head>
<body>
    <h1>VM Distribution Report</h1>
    
    <!-- Summary Cards -->
    <div class="summary">
        <div class="card">Total VMs: 25</div>
        <div class="card">Zones Used: 3</div>
        <div class="card">Unzoned VMs: 5</div>
    </div>
    
    <!-- Bar Chart -->
    <canvas id="chart"></canvas>
    <script>
        new Chart(ctx, {
            type: 'bar',
            data: { /* zone distribution */ }
        });
    </script>
    
    <!-- VM Table -->
    <table>
        <thead>
            <tr><th>VM Name</th><th>Zone</th><th>Power State</th></tr>
        </thead>
        <tbody>
            <tr class="vm-running">
                <td>web-vm-01</td><td>az1</td><td>VM running</td>
            </tr>
            <tr class="no-zone">
                <td>legacy-vm</td><td>-</td><td>VM deallocated</td>
            </tr>
        </tbody>
    </table>
</body>
</html>
```

## Performance Considerations

| Subscriptions | VMs per Sub | Estimated Time |
|---------------|-------------|----------------|
| 1 | 10 | 15-30 seconds |
| 1 | 100 | 1-2 minutes |
| 5 | 50 each | 5-10 minutes |
| 20 | 50 each | 20-40 minutes |

**Optimization tips:**
- Use `-SubscriptionId` to target specific subscriptions
- Run during off-hours for large scans
- Progress bars show real-time status
- Script uses hybrid approach:
  - Subscriptions with ≤100 VMs: Fast scan (1 API call)
  - Subscriptions with >100 VMs: Detailed scan with progress tracking

**Note on Report Variance:**
In dynamic environments with active workloads (auto-scaling, CI/CD deployments), VM counts may vary between consecutive runs. This is expected behavior - variations of 1-2% typically indicate normal infrastructure changes (VMs being created/deleted, Databricks clusters scaling, etc.). For audit purposes, use the `-ExportCSV` parameter to capture point-in-time snapshots.

## Error Handling

The script handles common errors:

- **Not authenticated** - Prompts to run `Connect-AzAccount`
- **Insufficient permissions** - Continues with subscriptions you can access
- **Get-AzZoneMappings.ps1 not found** - Exits with clear error message
- **No VMs found** - Returns empty report with zero counts
- **Network timeouts** - Retries subscription switch

## Troubleshooting

### Issue: "Get-AzZoneMappings.ps1 not found"

**Cause:** Scripts must be in same directory

**Solution:**
```powershell
# Verify both files exist
Get-ChildItem *.ps1

# Should show:
# Get-AzZoneMappings.ps1
# Get-AzVMZoneDistribution.ps1

# If missing, download both files to same folder
```

### Issue: Tenant selection shows wrong tenants

**Cause:** Cached Azure credentials

**Solution:**
```powershell
# Clear Azure context
Clear-AzContext -Force

# Re-authenticate
Connect-AzAccount

# Run script again
.\Get-AzVMZoneDistribution.ps1
```

### Issue: Power State shows "Unknown" for all VMs

**Cause:** Not using `Get-AzVM -Status`

**Solution:**
The script already uses `-Status` flag. If still seeing Unknown:

```powershell
# Verify Az module version
Get-Module -Name Az.Compute -ListAvailable

# Update if < 5.0
Update-Module -Name Az -Force
```

### Issue: HTML report doesn't show charts

**Cause:** No internet connection (Chart.js loads from CDN)

**Solution:**
Chart.js requires internet to load from CDN. For offline use:

1. Download Chart.js library
2. Edit script's `Get-HTMLTemplate` function
3. Change CDN URL to local file path

### Issue: Script hangs during subscription scan

**Cause:** Permissions prompt or subscription with many VMs

**Solution:**
```powershell
# Check progress bar output
# Press Ctrl+C to cancel

# Run with specific subscription
.\Get-AzVMZoneDistribution.ps1 -SubscriptionId "guid"

# Check subscription has VMs
Set-AzContext -SubscriptionId "guid"
Get-AzVM
```

### Issue: Color coding not showing in HTML

**Cause:** Browser security settings

**Solution:**
- Right-click HTML file → Properties → Unblock
- Or copy file to trusted location
- Try different browser (Chrome, Edge, Firefox)

## Best Practices

1. **Regular scanning** - Schedule weekly/monthly reports for governance
2. **Version control reports** - Track zone distribution changes over time
3. **Automate alerts** - Trigger alerts when unzoned VMs exceed threshold
4. **Secure storage** - HTML reports contain sensitive VM inventory data
5. **Combine with monitoring** - Integrate with Azure Monitor for real-time tracking
6. **Document exceptions** - Maintain list of VMs that legitimately don't need zones
7. **Test DR scenarios** - Use reports to plan zone failover testing

## Integration Examples

### PowerShell Pipeline

```powershell
# Generate report and extract metrics
.\Get-AzVMZoneDistribution.ps1 -OutputPath "report.html"

# Parse HTML to get VM count
$html = Get-Content "report.html" -Raw
if ($html -match "Total VMs:\s*(\d+)") {
    $totalVMs = [int]$Matches[1]
    Write-Host "Found $totalVMs VMs"
}
```

### Azure DevOps Pipeline

```yaml
steps:
- task: AzurePowerShell@5
  inputs:
    azureSubscription: 'MyServiceConnection'
    scriptType: 'FilePath'
    scriptPath: 'Get-AzVMZoneDistribution.ps1'
    scriptArguments: '-OutputPath "$(Build.ArtifactStagingDirectory)/vm-zones.html"'
    azurePowerShellVersion: 'LatestVersion'

- task: PublishBuildArtifacts@1
  inputs:
    pathToPublish: '$(Build.ArtifactStagingDirectory)'
    artifactName: 'zone-reports'
```

### Azure Automation Runbook

```powershell
# Runbook: Weekly-VM-Zone-Report

# Authenticate with Managed Identity
Connect-AzAccount -Identity

# Generate report
$timestamp = Get-Date -Format "yyyyMMdd"
$reportPath = "C:\Temp\vm-zones-$timestamp.html"

.\Get-AzVMZoneDistribution.ps1 -OutputPath $reportPath

# Upload to Storage Account
$storageContext = New-AzStorageContext -StorageAccountName "reports" -UseConnectedAccount
Set-AzStorageBlobContent -File $reportPath -Container "zone-reports" `
    -Blob "vm-zones-$timestamp.html" -Context $storageContext
```

## Related Scripts

- **Get-AzZoneMappings.ps1** - Discovers physical zone mappings (called internally)
- See [README-Get-AzZoneMappings.md](README-Get-AzZoneMappings.md)

## See Also

- [Main README](README.md) - Repository overview
- [Azure Availability Zones](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview)
- [Azure PowerShell Documentation](https://learn.microsoft.com/en-us/powershell/azure/)
- [Chart.js Documentation](https://www.chartjs.org/docs/)
