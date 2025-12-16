<#
.SYNOPSIS
    Analyzes VM distribution across availability zones in an Azure tenant.

.DESCRIPTION
    Lists all accessible Azure tenants, prompts for selection, scans all subscriptions in the 
    selected tenant for deployed VMs, maps them to physical zones, checks availability sets,
    and generates an HTML report with tables, summaries, and charts showing zone distribution
    and VM infrastructure protection configuration.

.PARAMETER TenantId
    Optional. Specific tenant ID to connect to. If not provided, will prompt for tenant selection.

.PARAMETER SubscriptionId
    Optional. Specific subscription ID to scan. If not provided, all subscriptions in the tenant will be scanned.

.PARAMETER OutputPath
    Optional. Path to the output HTML file. If not provided, results will be displayed as a summary on console.

.PARAMETER ExportCSV
    Optional. Path to export VM details table to CSV file. When specified, exports all VM data to the provided CSV file path.

.EXAMPLE
    .\Get-AzVMZoneDistribution.ps1
    Generate console summary with tenant selection prompt for all subscriptions.

.EXAMPLE
    .\Get-AzVMZoneDistribution.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"
    Generate console summary for a specific subscription.

.EXAMPLE
    .\Get-AzVMZoneDistribution.ps1 -OutputPath "vm-zones.html"
    Generate HTML report for all subscriptions.

.EXAMPLE
    .\Get-AzVMZoneDistribution.ps1 -TenantId "12345678-1234-1234-1234-123456789012"
    Generate console summary for specific tenant.

.EXAMPLE
    .\Get-AzVMZoneDistribution.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -OutputPath "report.html"
    Generate HTML report for a specific subscription.

.EXAMPLE
    .\Get-AzVMZoneDistribution.ps1 -OutputPath "report.html" -ExportCSV "vm-details.csv"
    Generate HTML report and export VM details to CSV file.

.EXAMPLE
    .\Get-AzVMZoneDistribution.ps1 -ExportCSV "vm-zone-distribution.csv"
    Generate console summary and export VM details to CSV file.

.NOTES
    Requires Azure PowerShell module (Az).
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TenantId,
    
    [Parameter()]
    [string]$SubscriptionId,
    
    [Parameter()]
    [string]$OutputPath,
    
    [Parameter()]
    [string]$ExportCSV
)

#region Helper Functions

function Select-AzureTenant {
    Write-Host "`n=== Select Azure Tenant ===" -ForegroundColor Cyan
    
    # Get all tenants
    $tenants = Get-AzTenant
    
    if ($tenants.Count -eq 0) {
        Write-Host "No tenants found." -ForegroundColor Red
        return $null
    }
    
    if ($tenants.Count -eq 1) {
        Write-Host "Only one tenant available: $($tenants[0].Name) ($($tenants[0].Id))" -ForegroundColor Green
        return $tenants[0].Id
    }
    
    # Display available tenants
    Write-Host "`nAvailable Tenants:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $tenants.Count; $i++) {
        $displayName = if ($tenants[$i].Name) { $tenants[$i].Name } else { "Unnamed" }
        Write-Host "  [$($i + 1)] $displayName - $($tenants[$i].Id)" -ForegroundColor White
    }
    
    # Prompt for selection
    do {
        Write-Host "`nSelect a tenant (1-$($tenants.Count)): " -ForegroundColor Yellow -NoNewline
        $selection = Read-Host
        $selectionInt = 0
        $validSelection = [int]::TryParse($selection, [ref]$selectionInt) -and $selectionInt -ge 1 -and $selectionInt -le $tenants.Count
        
        if (-not $validSelection) {
            Write-Host "Invalid selection. Please enter a number between 1 and $($tenants.Count)." -ForegroundColor Red
        }
    } while (-not $validSelection)
    
    $selectedTenant = $tenants[$selectionInt - 1]
    Write-Host "`nSelected Tenant: $(if ($selectedTenant.Name) { $selectedTenant.Name } else { $selectedTenant.Id })" -ForegroundColor Green
    
    return $selectedTenant.Id
}

function Test-AzureConnection {
    param(
        [string]$TenantId,
        [string]$SubscriptionId
    )
    
    try {
        $context = Get-AzContext
        
        # If not connected at all, throw error
        if (-not $context) {
            Write-Host "Not connected to Azure. Please run 'Connect-AzAccount' first." -ForegroundColor Red
            throw "No active Azure connection found."
        }
        
        # If SubscriptionId is provided but TenantId is not, get tenant from subscription
        if ($SubscriptionId -and -not $TenantId) {
            $subscription = Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
            if ($subscription) {
                $TenantId = $subscription.TenantId
                Write-Host "Using tenant from subscription: $TenantId" -ForegroundColor Cyan
            }
        }
        
        # Only prompt for tenant selection if TenantId was not provided and SubscriptionId was not provided
        if (-not $TenantId) {
            # Prompt user to select a tenant
            $TenantId = Select-AzureTenant
            
            if (-not $TenantId) {
                Write-Host "No tenant selected. Using current tenant: $($context.Tenant.Id)" -ForegroundColor Yellow
            }
        }
        
        # Switch to the selected/specified tenant if different from current
        if ($TenantId -and $context.Tenant.Id -ne $TenantId) {
            Write-Host "Switching to tenant: $TenantId" -ForegroundColor Cyan
            Set-AzContext -TenantId $TenantId | Out-Null
            $context = Get-AzContext
        }
        
        Write-Host "Connected to Azure as $($context.Account.Id)" -ForegroundColor Green
        Write-Host "Tenant: $($context.Tenant.Id)" -ForegroundColor Cyan
        return $context
    }
    catch {
        Write-Host "Failed to connect to Azure: $_" -ForegroundColor Red
        throw
    }
}

function Get-ZoneMappings {
    param(
        [string]$SubscriptionId
    )
    
    try {
        # Use Get-AzZoneMappings.ps1 script to get zone mappings
        $scriptPath = Join-Path $PSScriptRoot "Get-AzZoneMappings.ps1"
        
        if (-not (Test-Path $scriptPath)) {
            Write-Host "Warning: Get-AzZoneMappings.ps1 not found in script directory" -ForegroundColor Yellow
            return $null
        }
        
        # Call the script with -AsObject to get PowerShell objects
        $zoneMappingObjects = & $scriptPath -SubscriptionId $SubscriptionId
        
        if (-not $zoneMappingObjects -or $zoneMappingObjects.Count -eq 0) {
            return $null
        }
        
        # Convert to hashtable mapping logical zone to physical zone
        $mapping = @{}
        foreach ($obj in $zoneMappingObjects) {
            $mapping[$obj.LogicalZone.ToString()] = $obj.PhysicalZone
        }
        
        return $mapping
    }
    catch {
        Write-Host "Warning: Could not retrieve zone mappings for subscription $SubscriptionId" -ForegroundColor Yellow
        return $null
    }
}

function Get-HTMLTemplate {
    param(
        [string]$Title,
        [array]$VMData,
        [hashtable]$Summary,
        [hashtable]$ZoneDistribution
    )
    
    # Generate table rows
    $tableRows = ""
    foreach ($vm in $VMData) {
        $rowClass = ""
        $powerStateClass = ""
        $protectionClass = ""
        
        # Add class for running VMs (green)
        if ($vm.PowerState -like "*running*") {
            $powerStateClass = "vm-running"
        }
        
        # Add class for VMs without zones
        if ($vm.LogicalZone -eq "No Zone") {
            $rowClass = "no-zone"
        }
        
        # Add class for protection level
        if ($vm.ProtectionLevel -eq "No Protection") {
            $protectionClass = "no-protection"
        } elseif ($vm.ProtectionLevel -like "Zone*") {
            $protectionClass = "zone-protected"
        } elseif ($vm.ProtectionLevel -like "Avail*") {
            $protectionClass = "availset-protected"
        }
        
        $tableRows += @"
            <tr class="$rowClass">
                <td>$($vm.VMName)</td>
                <td>$($vm.SubscriptionName)</td>
                <td>$($vm.ResourceGroup)</td>
                <td>$($vm.Location)</td>
                <td>$($vm.LogicalZone)</td>
                <td>$($vm.PhysicalZone)</td>
                <td>$($vm.AvailabilitySet)</td>
                <td class="$protectionClass">$($vm.ProtectionLevel)</td>
                <td>$($vm.VMSize)</td>
                <td class="$powerStateClass">$($vm.PowerState)</td>
            </tr>
"@
    }
    
    # Generate chart data
    $chartLabels = ($ZoneDistribution.Keys | Sort-Object) -join '","'
    $chartData = ($ZoneDistribution.Keys | Sort-Object | ForEach-Object { $ZoneDistribution[$_] }) -join ','
    
    # Generate zone distribution table
    $zoneDistTable = ""
    foreach ($zone in ($ZoneDistribution.Keys | Sort-Object)) {
        $count = $ZoneDistribution[$zone]
        $percentage = if ($Summary.TotalVMs -gt 0) { [math]::Round(($count / $Summary.TotalVMs) * 100, 2) } else { 0 }
        $zoneDistTable += @"
            <tr>
                <td>$zone</td>
                <td>$count</td>
                <td>$percentage%</td>
            </tr>
"@
    }
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$Title</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1600px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        .content {
            padding: 30px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }
        .summary-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .summary-card h3 {
            font-size: 0.85em;
            opacity: 0.9;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .summary-card p {
            font-size: 2em;
            font-weight: bold;
        }
        .section {
            margin-bottom: 40px;
        }
        .section h2 {
            color: #667eea;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 3px solid #667eea;
            font-size: 1.8em;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            font-size: 0.9em;
        }
        th {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px 10px;
            text-align: left;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.8em;
            letter-spacing: 0.5px;
        }
        td {
            padding: 10px;
            border-bottom: 1px solid #e0e0e0;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        tr:nth-child(even) {
            background-color: #fafafa;
        }
        tr.no-zone {
            background-color: #fff9c4 !important;
        }
        tr.no-zone:hover {
            background-color: #fff59d !important;
        }
        td.vm-running {
            background-color: #c8e6c9;
            font-weight: 600;
            color: #2e7d32;
        }
        td.zone-protected {
            background-color: #c8e6c9;
            font-weight: 600;
            color: #2e7d32;
        }
        td.availset-protected {
            background-color: #b3e5fc;
            font-weight: 600;
            color: #01579b;
        }
        td.no-protection {
            background-color: #ffccbc;
            font-weight: 600;
            color: #bf360c;
        }
        .chart-container {
            position: relative;
            height: 400px;
            margin: 30px auto;
            max-width: 800px;
        }
        .legend {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            margin: 20px 0;
            padding: 15px;
            background: #f5f5f5;
            border-radius: 8px;
        }
        .legend-item {
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .legend-color {
            width: 20px;
            height: 20px;
            border-radius: 3px;
        }
        .info-box {
            background: #e3f2fd;
            border-left: 4px solid #2196f3;
            padding: 15px 20px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .info-box h4 {
            color: #1976d2;
            margin: 0 0 10px 0;
            font-size: 1em;
        }
        .info-box ul {
            margin: 10px 0 10px 20px;
            color: #555;
        }
        .info-box li {
            margin: 5px 0;
        }
        .info-box .note {
            margin-top: 10px;
            font-style: italic;
            color: #666;
            font-size: 0.9em;
        }
        .footer {
            background: #f5f5f5;
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Azure VM Zone Distribution Report</h1>
            <p>Availability Zone & Infrastructure Protection Analysis</p>
        </div>
        
        <div class="content">
            <div class="summary">
                <div class="summary-card">
                    <h3>Total VMs</h3>
                    <p>$($Summary.TotalVMs)</p>
                </div>
                <div class="summary-card">
                    <h3>Subscriptions</h3>
                    <p>$($Summary.TotalSubscriptions)</p>
                </div>
                <div class="summary-card">
                    <h3>VMs with Zones</h3>
                    <p>$($Summary.VMsWithZones)</p>
                </div>
                <div class="summary-card">
                    <h3>VMs in Avail Sets</h3>
                    <p>$($Summary.VMsWithAvailSets)</p>
                </div>
                <div class="summary-card">
                    <h3>No Protection</h3>
                    <p>$($Summary.VMsWithoutProtection)</p>
                </div>
            </div>
            
            <div class="info-box">
                <h4>ℹ️ Understanding VM Protection Levels</h4>
                <ul>
                    <li><strong>Zone-Isolated:</strong> VM deployed in an availability zone (datacenter-level isolation)</li>
                    <li><strong>Availability Set:</strong> VM in an availability set (fault/update domain separation within datacenter)</li>
                    <li><strong>No Protection:</strong> Single instance VM without zone or availability set configuration</li>
                </ul>
                <div class="note">
                    <strong>Note:</strong> True High Availability requires multiple VM instances with load balancing. 
                    This report shows individual VM infrastructure protection configurations.
                </div>
            </div>
            
            <div class="section">
                <h2>Zone Distribution</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Physical Zone</th>
                            <th>VM Count</th>
                            <th>Percentage</th>
                        </tr>
                    </thead>
                    <tbody>
                        $zoneDistTable
                    </tbody>
                </table>
            </div>
            
            <div class="section">
                <h2>Zone Distribution Chart</h2>
                <div class="chart-container">
                    <canvas id="zoneChart"></canvas>
                </div>
            </div>
            
            <div class="section">
                <h2>VM Details</h2>
                <div class="legend">
                    <div class="legend-item">
                        <div class="legend-color" style="background-color: #c8e6c9;"></div>
                        <span>Zone-Isolated (Datacenter Protection)</span>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color" style="background-color: #b3e5fc;"></div>
                        <span>Availability Set (Rack Protection)</span>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color" style="background-color: #ffccbc;"></div>
                        <span>No Protection</span>
                    </div>
                    <div class="legend-item">
                        <div class="legend-color" style="background-color: #fff9c4;"></div>
                        <span>No Zone (Row Highlight)</span>
                    </div>
                </div>
                <table>
                    <thead>
                        <tr>
                            <th>VM Name</th>
                            <th>Subscription</th>
                            <th>Resource Group</th>
                            <th>Location</th>
                            <th>Logical Zone</th>
                            <th>Physical Zone</th>
                            <th>Availability Set</th>
                            <th>Protection Level</th>
                            <th>VM Size</th>
                            <th>Power State</th>
                        </tr>
                    </thead>
                    <tbody>
                        $tableRows
                    </tbody>
                </table>
            </div>
        </div>
        
        <div class="footer">
            Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") | Azure VM Zone Distribution & Infrastructure Protection Analysis
        </div>
    </div>
    
    <script>
        const ctx = document.getElementById('zoneChart').getContext('2d');
        const zoneChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: ["$chartLabels"],
                datasets: [{
                    label: 'Number of VMs',
                    data: [$chartData],
                    backgroundColor: [
                        'rgba(102, 126, 234, 0.8)',
                        'rgba(118, 75, 162, 0.8)',
                        'rgba(237, 100, 166, 0.8)',
                        'rgba(255, 159, 64, 0.8)',
                        'rgba(75, 192, 192, 0.8)'
                    ],
                    borderColor: [
                        'rgba(102, 126, 234, 1)',
                        'rgba(118, 75, 162, 1)',
                        'rgba(237, 100, 166, 1)',
                        'rgba(255, 159, 64, 1)',
                        'rgba(75, 192, 192, 1)'
                    ],
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    title: {
                        display: true,
                        text: 'VM Distribution Across Physical Zones',
                        font: {
                            size: 18
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            stepSize: 1
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
"@
    
    return $html
}

#endregion

#region Main Script

Write-Host "`n=== Azure VM Zone Distribution Report ===" -ForegroundColor Cyan
Write-Host "This script will analyze VM distribution across availability zones.`n" -ForegroundColor White

# Step 1: Test Azure connection and select tenant
Write-Host "=== Step 1: Connecting to Azure ===" -ForegroundColor Magenta
$context = Test-AzureConnection -TenantId $TenantId -SubscriptionId $SubscriptionId

# Get the selected tenant ID from context
$selectedTenantId = $context.Tenant.Id

# Step 2: Get all subscriptions in the selected tenant
Write-Host "`n=== Step 2: Retrieving Subscriptions in Tenant ===" -ForegroundColor Magenta

if ($SubscriptionId) {
    # Get only the specified subscription
    $allSubscriptions = Get-AzSubscription -TenantId $selectedTenantId
    $subscriptions = $allSubscriptions | Where-Object { $_.Id -eq $SubscriptionId }
    
    if ($subscriptions.Count -eq 0) {
        Write-Host "Error: Subscription ID '$SubscriptionId' not found in the selected tenant." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Processing specific subscription: $($subscriptions[0].Name)" -ForegroundColor Green
} else {
    # Get all subscriptions
    $subscriptions = Get-AzSubscription -TenantId $selectedTenantId
    
    if ($subscriptions.Count -eq 0) {
        Write-Host "Warning: No subscriptions found in the selected tenant." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Found $($subscriptions.Count) subscription(s) in tenant." -ForegroundColor Green
}

# Step 3: Scan VMs across all subscriptions
Write-Host "`n=== Step 3: Scanning VMs Across Subscriptions ===" -ForegroundColor Magenta

$allVMs = @()
$zoneMappingCache = @{}
$subCount = 0
$totalSubs = $subscriptions.Count

foreach ($sub in $subscriptions) {
    $subCount++
    $subscriptionId = $sub.Id
    $subscriptionName = $sub.Name
    
    # Update progress
    Write-Progress -Activity "Scanning subscriptions for VMs" `
                   -Status "[$subCount/$totalSubs] $subscriptionName" `
                   -PercentComplete (($subCount / $totalSubs) * 100)
    
    Write-Host "  Processing: $subscriptionName" -ForegroundColor Cyan
    
    # Set subscription context
    try {
        Set-AzContext -SubscriptionId $subscriptionId -TenantId $selectedTenantId | Out-Null
    }
    catch {
        Write-Host "    Error setting context for subscription: $subscriptionName" -ForegroundColor Red
        continue
    }
    
    # Get zone mappings for this subscription (cache it)
    if (-not $zoneMappingCache.ContainsKey($subscriptionId)) {
        $zoneMappingCache[$subscriptionId] = Get-ZoneMappings -SubscriptionId $subscriptionId
    }
    $zoneMapping = $zoneMappingCache[$subscriptionId]
    
    # Get all VMs in subscription
    try {
        $vms = Get-AzVM -Status
    }
    catch {
        Write-Host "    Error retrieving VMs: $_" -ForegroundColor Red
        continue
    }
    
    if ($vms.Count -eq 0) {
        Write-Host "    No VMs found in this subscription." -ForegroundColor Gray
        continue
    }
    
    Write-Host "    Found $($vms.Count) VM(s)" -ForegroundColor Green
    
    # Process each VM
    foreach ($vm in $vms) {
        $logicalZone = if ($vm.Zones -and $vm.Zones.Count -gt 0) { $vm.Zones[0] } else { "No Zone" }
        $physicalZone = if ($logicalZone -ne "No Zone" -and $zoneMapping) {
            if ($zoneMapping.ContainsKey($logicalZone)) {
                $zoneMapping[$logicalZone]
            } else {
                "Unknown"
            }
        } elseif ($logicalZone -eq "No Zone") {
            "No Zone"
        } else {
            "Unknown"
        }
        
        # Get Availability Set information
        $availSet = "None"
        $protectionLevel = "No Protection"
        
        if ($vm.AvailabilitySetReference -and $vm.AvailabilitySetReference.Id) {
            # Extract availability set name from resource ID
            $availSetId = $vm.AvailabilitySetReference.Id
            $availSetName = $availSetId.Split('/')[-1]
            $availSet = $availSetName
            $protectionLevel = "Availability Set"
        }
        
        # Determine protection level
        if ($logicalZone -ne "No Zone") {
            $protectionLevel = "Zone-Isolated"
        } elseif ($availSet -ne "None") {
            $protectionLevel = "Availability Set"
        } else {
            $protectionLevel = "No Protection"
        }
        
        # Get power state - try multiple methods
        $powerState = "Unknown"
        
        # Method 1: Check PowerState property directly
        if ($vm.PowerState) {
            $powerState = $vm.PowerState
        }
        # Method 2: Check Statuses collection
        elseif ($vm.Statuses) {
            $powerStatusObj = $vm.Statuses | Where-Object { $_.Code -like "PowerState/*" } | Select-Object -First 1
            if ($powerStatusObj) {
                $powerState = $powerStatusObj.DisplayStatus
            }
        }
        # Method 3: Check InstanceView if available
        elseif ($vm.InstanceView -and $vm.InstanceView.Statuses) {
            $powerStatusObj = $vm.InstanceView.Statuses | Where-Object { $_.Code -like "PowerState/*" } | Select-Object -First 1
            if ($powerStatusObj) {
                $powerState = $powerStatusObj.DisplayStatus
            }
        }
        
        $allVMs += [PSCustomObject]@{
            VMName           = $vm.Name
            SubscriptionName = $subscriptionName
            SubscriptionId   = $subscriptionId
            ResourceGroup    = $vm.ResourceGroupName
            Location         = $vm.Location
            LogicalZone      = $logicalZone
            PhysicalZone     = $physicalZone
            AvailabilitySet  = $availSet
            ProtectionLevel  = $protectionLevel
            VMSize           = $vm.HardwareProfile.VmSize
            PowerState       = $powerState
        }
    }
}

Write-Progress -Activity "Scanning subscriptions for VMs" -Completed

# Step 4: Generate summary and distribution
Write-Host "`n=== Step 4: Generating Report ===" -ForegroundColor Magenta

$summary = @{
    TotalVMs              = $allVMs.Count
    TotalSubscriptions    = $subscriptions.Count
    VMsWithZones          = ($allVMs | Where-Object { $_.LogicalZone -ne "No Zone" }).Count
    VMsWithAvailSets      = ($allVMs | Where-Object { $_.AvailabilitySet -ne "None" }).Count
    VMsWithoutProtection  = ($allVMs | Where-Object { $_.ProtectionLevel -eq "No Protection" }).Count
}

# Calculate zone distribution
$zoneDistribution = @{}
foreach ($vm in $allVMs) {
    $zone = $vm.PhysicalZone
    if ($zoneDistribution.ContainsKey($zone)) {
        $zoneDistribution[$zone]++
    } else {
        $zoneDistribution[$zone] = 1
    }
}

if ($OutputPath) {
    # Generate HTML report
    Write-Host "Generating HTML report..." -ForegroundColor Cyan
    $htmlContent = Get-HTMLTemplate -Title "Azure VM Zone Distribution" -VMData $allVMs -Summary $summary -ZoneDistribution $zoneDistribution

    # Save to file
    $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8

    Write-Host "`n=== Report Generated Successfully ===" -ForegroundColor Green
    Write-Host "Report saved to: $OutputPath" -ForegroundColor Green
    Write-Host "Open the file in a web browser to view the full report with charts." -ForegroundColor Yellow

} else {
    # Display console summary
    Write-Host "`n=== VM Zone Distribution Summary ===" -ForegroundColor Green
    Write-Host "`nOverview:" -ForegroundColor Cyan
    Write-Host "  Total VMs: $($summary.TotalVMs)" -ForegroundColor White
    Write-Host "  VMs with Zones: $($summary.VMsWithZones)" -ForegroundColor White
    Write-Host "  VMs in Availability Sets: $($summary.VMsWithAvailSets)" -ForegroundColor White
    Write-Host "  VMs without Protection: $($summary.VMsWithoutProtection)" -ForegroundColor White
    Write-Host "  Subscriptions Scanned: $($summary.TotalSubscriptions)" -ForegroundColor White
    
    Write-Host "`nZone Distribution:" -ForegroundColor Cyan
    foreach ($zone in ($zoneDistribution.Keys | Sort-Object)) {
        $count = $zoneDistribution[$zone]
        $percentage = if ($summary.TotalVMs -gt 0) { [math]::Round(($count / $summary.TotalVMs) * 100, 2) } else { 0 }
        Write-Host "  Physical Zone $zone`: $count VMs ($percentage%)" -ForegroundColor White
    }
    
    if ($allVMs.Count -gt 0) {
        Write-Host "`nVM Details:" -ForegroundColor Cyan
        $allVMs | Format-Table -Property VMName, SubscriptionName, ResourceGroup, Location, LogicalZone, PhysicalZone, AvailabilitySet, ProtectionLevel, VMSize, PowerState -AutoSize
    }
    
    Write-Host "\nTip: Use -OutputPath parameter to generate an HTML report with charts." -ForegroundColor Yellow
}

# Export to CSV if requested (works with or without HTML report)
if ($ExportCSV) {
    Write-Host "\nExporting VM details to CSV..." -ForegroundColor Cyan
    $allVMs | Select-Object VMName, SubscriptionName, ResourceGroup, Location, LogicalZone, PhysicalZone, AvailabilitySet, ProtectionLevel, VMSize, PowerState | Export-Csv -Path $ExportCSV -NoTypeInformation -Encoding UTF8
    Write-Host "CSV file saved to: $ExportCSV" -ForegroundColor Green
}

#endregion
