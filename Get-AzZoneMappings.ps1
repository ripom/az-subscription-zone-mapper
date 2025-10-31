<#
.SYNOPSIS
    Extracts Azure availability zone mappings from all subscriptions in the current tenant.

.DESCRIPTION
    This script filters subscriptions by the current tenant ID, queries the first region with 
    availabilityZoneMappings, extracts physical-to-logical zone relationships, and exports 
    the results to a CSV file. Includes progress bar and color-coded output.

.NOTES
    Requires Azure CLI and REST API access.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = "zone-mappings.csv"
)

# Step 1: Get current tenant ID
Write-ColorOutput "`n=== Reading current Tenant ID ===" "Magenta"
$currentTenantId = (az account show --output json | ConvertFrom-Json).tenantId

# Step 2: Get subscriptions for the current tenant only
Write-ColorOutput "`n=== Gathering the Subscription IDs filtered by Current Tenant ID ===" "Magenta"
$subscriptions = az account list --output json `
    --query "[?tenantId=='$currentTenantId']" | ConvertFrom-Json

# Prepare an array to collect output
$zoneMappings = @()
Write-ColorOutput "Generating result for Zone Mappings" "Cyan"
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

# Step 6: Export to CSV
$zoneMappings | Export-Csv -Path "./$OutputPath" -NoTypeInformation -Encoding UTF8
Write-ColorOutput "Results exported to: $OutputPath" "Green"
