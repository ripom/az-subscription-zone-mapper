<#
.SYNOPSIS
    Lists all Azure subscriptions and maps their availability zones.

.DESCRIPTION
    This script discovers Azure availability zone mappings across all subscriptions in the current tenant.
    It queries the first region with availabilityZoneMappings via REST API, extracts physical-to-logical 
    zone pairs, prints them to the console, and exports results to a CSV file.

.PARAMETER OutputPath
    Path to the output CSV file. Default: ./zone-mappings.csv

.EXAMPLE
    .\Get-AzSubscriptionZoneMapper.ps1
    Lists zone mappings for all subscriptions and exports to zone-mappings.csv

.EXAMPLE
    .\Get-AzSubscriptionZoneMapper.ps1 -OutputPath "C:\output\zones.csv"
    Lists zone mappings and exports to specified path

.NOTES
    Requires Azure CLI (az) to be installed and authenticated.
    Run 'az login' before executing this script.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "zone-mappings.csv"
)

# Initialize results array to store all zone mappings
$results = @()

# Write header
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "Azure Subscription Zone Mapper" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# Get all subscriptions in the current tenant
Write-Host "Retrieving all subscriptions in the current tenant..." -ForegroundColor Yellow
$subscriptionsJson = az account list --query "[].{id:id, name:name}" -o json 2>&1

# Check if the command succeeded
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to retrieve subscriptions. Please ensure you are logged in with 'az login'." -ForegroundColor Red
    Write-Host "Error details: $subscriptionsJson" -ForegroundColor Red
    exit 1
}

# Convert JSON response to PowerShell objects
$subscriptions = $subscriptionsJson | ConvertFrom-Json

# Check if any subscriptions were found
if ($null -eq $subscriptions -or $subscriptions.Count -eq 0) {
    Write-Host "WARNING: No subscriptions found in the current tenant." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($subscriptions.Count) subscription(s)" -ForegroundColor Green
Write-Host ""

# Iterate through each subscription
foreach ($subscription in $subscriptions) {
    Write-Host "---------------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "Processing subscription: $($subscription.name)" -ForegroundColor Cyan
    Write-Host "Subscription ID: $($subscription.id)" -ForegroundColor Gray
    
    # Set the current subscription context
    Write-Host "  Setting subscription context..." -ForegroundColor Yellow
    az account set --subscription $subscription.id 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to set subscription context for '$($subscription.name)'" -ForegroundColor Red
        Write-Host "  Skipping this subscription..." -ForegroundColor Yellow
        continue
    }
    
    # Query location details via REST API to get availability zone mappings
    Write-Host "  Querying region availability zone mappings via REST API..." -ForegroundColor Yellow
    $locationDetailsJson = az rest --method get --url "https://management.azure.com/subscriptions/$($subscription.id)/locations?api-version=2022-12-01" -o json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  WARNING: Failed to query location details via REST API" -ForegroundColor Yellow
        Write-Host "  Skipping this subscription..." -ForegroundColor Yellow
        continue
    }
    
    $locationDetails = $locationDetailsJson | ConvertFrom-Json
    
    if ($null -eq $locationDetails.value -or $locationDetails.value.Count -eq 0) {
        Write-Host "  WARNING: No location details found for subscription '$($subscription.name)'" -ForegroundColor Yellow
        continue
    }
    
    # Flag to track if we found zone mappings
    $foundMappings = $false
    
    # Look for the first location with availabilityZoneMappings
    foreach ($locationDetail in $locationDetails.value) {
        if ($null -ne $locationDetail.availabilityZoneMappings -and $locationDetail.availabilityZoneMappings.Count -gt 0) {
            $foundMappings = $true
            $regionName = $locationDetail.name
            $regionDisplayName = $locationDetail.displayName
            
            Write-Host "  Found zone mappings in region: $regionDisplayName ($regionName)" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Physical Zone -> Logical Zone Mappings:" -ForegroundColor White
            
            # Extract and display each physical-to-logical zone mapping
            foreach ($mapping in $locationDetail.availabilityZoneMappings) {
                $physicalZone = $mapping.physicalZone
                $logicalZone = $mapping.logicalZone
                
                # Display the mapping
                Write-Host "    Physical Zone: $physicalZone -> Logical Zone: $logicalZone" -ForegroundColor White
                
                # Add to results array for CSV export
                $results += [PSCustomObject]@{
                    SubscriptionId   = $subscription.id
                    SubscriptionName = $subscription.name
                    Region           = $regionName
                    RegionDisplayName = $regionDisplayName
                    PhysicalZone     = $physicalZone
                    LogicalZone      = $logicalZone
                }
            }
            
            Write-Host ""
            # Only process the first region with mappings
            break
        }
    }
    
    # Handle case where no mappings were found
    if (-not $foundMappings) {
        Write-Host "  INFO: No availability zone mappings found for subscription '$($subscription.name)'" -ForegroundColor Yellow
        Write-Host "        This subscription may not support availability zones in any region." -ForegroundColor Gray
    }
    
    Write-Host ""
}

# Summary and CSV export
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "Total subscriptions processed: $($subscriptions.Count)" -ForegroundColor White
Write-Host "Total zone mappings found: $($results.Count)" -ForegroundColor White
Write-Host ""

# Export results to CSV if we have any results
if ($results.Count -gt 0) {
    try {
        $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "Results exported to: $OutputPath" -ForegroundColor Green
        Write-Host ""
        
        # Display preview of CSV content
        Write-Host "Preview of exported data:" -ForegroundColor Yellow
        $results | Format-Table -AutoSize
    }
    catch {
        Write-Host "ERROR: Failed to export results to CSV" -ForegroundColor Red
        Write-Host "Error details: $_" -ForegroundColor Red
    }
}
else {
    Write-Host "No zone mappings found to export." -ForegroundColor Yellow
}

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "Script completed successfully" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Cyan
