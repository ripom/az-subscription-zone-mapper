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
    Optional. Path to the output CSV file. If not provided, results will only be displayed on screen.

.EXAMPLE
    .\Get-AzZoneMappings.ps1
    Process all subscriptions in the current tenant.

.EXAMPLE
    .\Get-AzZoneMappings.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"
    Process only the specified subscription.

.NOTES
    Requires Azure CLI and REST API access.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SubscriptionId,

    [Parameter()]
    [string]$OutputPath
)

# Step 1: Get current tenant ID
Write-Host "`n=== Reading current Tenant ID ===" -ForegroundColor Magenta
$currentTenantId = (az account show --output json | ConvertFrom-Json).tenantId

# Step 2: Get subscriptions for the current tenant only
Write-Host "`n=== Gathering the Subscription IDs filtered by Current Tenant ID ===" -ForegroundColor Magenta

if ($SubscriptionId) {
    # Process only the specified subscription
    $allSubscriptions = az account list --output json `
        --query "[?tenantId=='$currentTenantId']" | ConvertFrom-Json
    
    $subscriptions = $allSubscriptions | Where-Object { $_.id -eq $SubscriptionId }
    
    if ($subscriptions.Count -eq 0) {
        Write-Host "Error: Subscription ID '$SubscriptionId' not found in the current tenant." -ForegroundColor Red
        exit 1
    }
} else {
    # Process all subscriptions
    $subscriptions = az account list --output json `
        --query "[?tenantId=='$currentTenantId']" | ConvertFrom-Json
}

# Prepare an array to collect output
$zoneMappings = @()
Write-Host "Generating result for Zone Mappings" -ForegroundColor Cyan
Write-Host "Subscription, SubscriptionID, Physical Zone, Logical Zone"

$total = $subscriptions.Count
$count = 0

foreach ($sub in $subscriptions) {
    $count++
    $subscriptionId = $sub.id
    $subscriptionName = $sub.name

    # Update progress bar
    Write-Progress -Activity "Processing subscriptions..." `
                   -Status "[$count/$total] $subscriptionName" `
                   -PercentComplete (($count / $total) * 100)

    # Step 3: Set current subscription
    az account set --subscription $subscriptionId

    # Step 4: Query all regions with zone mappings
    $uri = "/subscriptions/$subscriptionId/locations?api-version=2022-12-01"
    $response = az rest --method get --uri $uri --output json | ConvertFrom-Json

    # Step 5: Use original logic for first region with zone mappings
    $firstRegion = $response.value | Where-Object { $_.availabilityZoneMappings } | Select-Object -First 1

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
        Write-Host "$subscriptionName, $SubscriptionId, $($zones[1]), $($logical[0])"
        $zoneMappings += [PSCustomObject]@{
            Subscription   = $subscriptionName
            SubscriptionId = $subscriptionId
            PhysicalZone   = $zones[3]
            LogicalZone    = $logical[1]
        }
        Write-Host "$subscriptionName, $SubscriptionId, $($zones[3]), $($logical[1])"
        $zoneMappings += [PSCustomObject]@{
            Subscription   = $subscriptionName
            SubscriptionId = $subscriptionId
            PhysicalZone   = $zones[5]
            LogicalZone    = $logical[2]
        }
        Write-Host "$subscriptionName, $SubscriptionId, $($zones[5]), $($logical[2])"
    }
}

# Step 6: Export to CSV if OutputPath is provided
if ($OutputPath) {
    $zoneMappings | Export-Csv -Path "./$OutputPath" -NoTypeInformation -Encoding UTF8
    Write-Host "Results exported to: $OutputPath" -ForegroundColor Green
} else {
    Write-Host "`nResults displayed above (no file export requested)" -ForegroundColor Yellow
}
