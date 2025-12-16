<#
.SYNOPSIS
    Extracts Azure availability zone mappings from all subscriptions or a specific subscription in the current tenant.

.DESCRIPTION
    This script filters subscriptions by the current tenant ID, queries the first region with 
    availabilityZoneMappings, extracts physical-to-logical zone relationships, and exports 
    the results to a CSV file. Includes progress bar and color-coded output.

.PARAMETER SubscriptionId
    Optional. If provided, process only the specified subscription ID. 
    If not provided, process all subscriptions in the current tenant.

.PARAMETER OutputPath
    Optional. Path to the output CSV file. If not provided, results will be returned as objects.

.EXAMPLE
    .\Get-AzZoneMappings.ps1
    Returns zone mappings for all subscriptions as PowerShell objects.

.EXAMPLE
    $zones = .\Get-AzZoneMappings.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"
    Returns zone mappings for the specified subscription as PowerShell objects.

.EXAMPLE
    .\Get-AzZoneMappings.ps1 -OutputPath "zones.csv"
    Exports zone mappings for all subscriptions to a CSV file.

.NOTES
    Requires Azure PowerShell module (Az) and an active Azure connection via Connect-AzAccount.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SubscriptionId,

    [Parameter()]
    [string]$OutputPath
)

# Check if connected to Azure
try {
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context) {
        Write-Host "Not connected to Azure. Please run 'Connect-AzAccount' first." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Not connected to Azure. Please run 'Connect-AzAccount' first." -ForegroundColor Red
    exit 1
}

# Step 1: Get current tenant ID
$currentTenantId = $context.Tenant.Id

# Step 2: Get subscriptions for the current tenant only

if ($SubscriptionId) {
    # Process only the specified subscription
    $allSubscriptions = Get-AzSubscription -TenantId $currentTenantId
    
    $subscriptions = $allSubscriptions | Where-Object { $_.Id -eq $SubscriptionId }
    
    if ($subscriptions.Count -eq 0) {
        Write-Host "Error: Subscription ID '$SubscriptionId' not found in the current tenant." -ForegroundColor Red
        exit 1
    }
} else {
    # Process all subscriptions
    $subscriptions = Get-AzSubscription -TenantId $currentTenantId
}

# Prepare an array to collect output
$zoneMappings = @()

$total = $subscriptions.Count
$count = 0

foreach ($sub in $subscriptions) {
    $count++
    $subscriptionId = $sub.Id
    $subscriptionName = $sub.Name

    # Update progress bar
    Write-Progress -Activity "Processing subscriptions..." `
                   -Status "[$count/$total] $subscriptionName" `
                   -PercentComplete (($count / $total) * 100)

    # Step 3: Set current subscription context
    $null = Set-AzContext -SubscriptionId $subscriptionId -ErrorAction SilentlyContinue

    # Step 4: Query all regions with zone mappings using Azure PowerShell REST API
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/locations?api-version=2022-12-01"
    
    try {
        $response = Invoke-AzRestMethod -Method GET -Path "/subscriptions/$subscriptionId/locations?api-version=2022-12-01"
        
        if ($response.StatusCode -eq 200) {
            $locations = ($response.Content | ConvertFrom-Json).value
            
            # Step 5: Use original logic for first region with zone mappings
            $firstRegion = $locations | Where-Object { $_.availabilityZoneMappings } | Select-Object -First 1

            if ($firstRegion) {
                $zoneMap = $firstRegion.availabilityZoneMappings

                $zones = $zoneMap.physicalZone -split "-"
                $logical = $zoneMap.logicalZone

                # Collect results
                $zoneMappings += [PSCustomObject]@{
                    Subscription   = $subscriptionName
                    SubscriptionId = $subscriptionId
                    PhysicalZone   = $zones[1]
                    LogicalZone    = $logical[0]
                }
                $zoneMappings += [PSCustomObject]@{
                    Subscription   = $subscriptionName
                    SubscriptionId = $subscriptionId
                    PhysicalZone   = $zones[3]
                    LogicalZone    = $logical[1]
                }
                $zoneMappings += [PSCustomObject]@{
                    Subscription   = $subscriptionName
                    SubscriptionId = $subscriptionId
                    PhysicalZone   = $zones[5]
                    LogicalZone    = $logical[2]
                }
            }
        }
    } catch {
        Write-Warning "Failed to query locations for subscription '$subscriptionName': $_"
    }
}

Write-Progress -Activity "Processing subscriptions..." -Completed

# Step 6: Export to CSV if OutputPath is provided, otherwise return objects
if ($OutputPath) {
    $zoneMappings | Export-Csv -Path "./$OutputPath" -NoTypeInformation -Encoding UTF8
    Write-Host "Results exported to: $OutputPath" -ForegroundColor Green
} else {
    return $zoneMappings
}
