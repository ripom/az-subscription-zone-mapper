#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Discovers Azure availability zone mappings across all subscriptions in the current tenant.

.DESCRIPTION
    This script iterates through all Azure subscriptions in the current tenant,
    identifies the first region with availabilityZoneMappings, extracts physical-to-logical
    zone pairs, and exports the results to a CSV file.

.PARAMETER OutputPath
    The path for the output CSV file. Defaults to 'zone-mappings.csv' in the current directory.

.EXAMPLE
    ./Get-AzZoneMappings.ps1
    
.EXAMPLE
    ./Get-AzZoneMappings.ps1 -OutputPath "C:\output\mappings.csv"

.NOTES
    Requires Azure CLI (az) to be installed and authenticated.
    Run 'az login' before executing this script.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = "zone-mappings.csv"
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to write colored output to console
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to get zone mappings for a subscription
function Get-SubscriptionZoneMappings {
    param(
        [string]$SubscriptionId,
        [string]$SubscriptionName
    )
    
    try {
        Write-ColorOutput "  Processing subscription: $SubscriptionName ($SubscriptionId)" "Cyan"
        
        # Set the active subscription context
        $null = az account set --subscription $SubscriptionId 2>&1
        
        # Get all locations for the subscription
        $locationsJson = az account list-locations --output json 2>&1 | Out-String
        
        if ([string]::IsNullOrWhiteSpace($locationsJson)) {
            Write-ColorOutput "    No locations found for subscription" "Yellow"
            return $null
        }
        
        $locations = $locationsJson | ConvertFrom-Json
        
        # Iterate through locations to find one with zone mappings
        foreach ($location in $locations) {
            $locationName = $location.name
            
            # Query the location metadata including zone mappings
            $uri = "https://management.azure.com/subscriptions/$SubscriptionId/locations/$locationName`?api-version=2022-12-01"
            $locationDetailsJson = az rest --uri $uri --method GET 2>&1 | Out-String
            
            if ([string]::IsNullOrWhiteSpace($locationDetailsJson)) {
                continue
            }
            
            try {
                $locationDetails = $locationDetailsJson | ConvertFrom-Json
                
                # Check if this location has availabilityZoneMappings
                if ($locationDetails.PSObject.Properties.Name -contains 'availabilityZoneMappings' -and 
                    $locationDetails.availabilityZoneMappings -and 
                    $locationDetails.availabilityZoneMappings.Count -gt 0) {
                    
                    Write-ColorOutput "    Found zone mappings in region: $locationName" "Green"
                    
                    # Extract zone mapping pairs
                    $zoneMappings = @()
                    foreach ($mapping in $locationDetails.availabilityZoneMappings) {
                        $zoneMappings += [PSCustomObject]@{
                            SubscriptionId   = $SubscriptionId
                            SubscriptionName = $SubscriptionName
                            Region           = $locationName
                            LogicalZone      = $mapping.logicalZone
                            PhysicalZone     = $mapping.physicalZone
                        }
                    }
                    
                    Write-ColorOutput "    Extracted $($zoneMappings.Count) zone mapping(s)" "Green"
                    return $zoneMappings
                }
            }
            catch {
                # Handle malformed JSON or parsing errors gracefully
                Write-ColorOutput "    Warning: Failed to parse location details for $locationName - $($_.Exception.Message)" "Yellow"
                continue
            }
        }
        
        Write-ColorOutput "    No regions with zone mappings found in this subscription" "Yellow"
        return $null
    }
    catch {
        # Handle errors gracefully and continue with other subscriptions
        Write-ColorOutput "    Error processing subscription: $($_.Exception.Message)" "Red"
        return $null
    }
}

# Main script execution
try {
    Write-ColorOutput "`n=== Azure Subscription Zone Mapper ===" "Magenta"
    Write-ColorOutput "Starting discovery process...`n" "Magenta"
    
    # Get the current tenant ID to filter subscriptions
    Write-ColorOutput "Retrieving current tenant information..." "Cyan"
    $accountJson = az account show --output json 2>&1 | Out-String
    
    if ([string]::IsNullOrWhiteSpace($accountJson)) {
        throw "Failed to get current account information. Please run 'az login' first."
    }
    
    $currentAccount = $accountJson | ConvertFrom-Json
    $currentTenantId = $currentAccount.tenantId
    Write-ColorOutput "Current Tenant ID: $currentTenantId`n" "Green"
    
    # Get all subscriptions
    Write-ColorOutput "Retrieving all subscriptions in the tenant..." "Cyan"
    $subscriptionsJson = az account list --output json 2>&1 | Out-String
    
    if ([string]::IsNullOrWhiteSpace($subscriptionsJson)) {
        throw "Failed to retrieve subscriptions list."
    }
    
    $allSubscriptions = $subscriptionsJson | ConvertFrom-Json
    
    # Filter subscriptions by current tenant
    $subscriptions = $allSubscriptions | Where-Object { $_.tenantId -eq $currentTenantId }
    
    Write-ColorOutput "Found $($subscriptions.Count) subscription(s) in the current tenant`n" "Green"
    
    if ($subscriptions.Count -eq 0) {
        throw "No subscriptions found in the current tenant."
    }
    
    # Collect all zone mappings
    $allZoneMappings = @()
    
    foreach ($subscription in $subscriptions) {
        $mappings = Get-SubscriptionZoneMappings -SubscriptionId $subscription.id -SubscriptionName $subscription.name
        
        if ($mappings) {
            $allZoneMappings += $mappings
            # We found mappings, so we can stop (requirement: first region with availabilityZoneMappings)
            # However, based on the description, we should process all subscriptions
        }
    }
    
    # Output results
    Write-ColorOutput "`n=== Results ===" "Magenta"
    
    if ($allZoneMappings.Count -eq 0) {
        Write-ColorOutput "No zone mappings found in any subscription." "Yellow"
    }
    else {
        Write-ColorOutput "Total zone mappings discovered: $($allZoneMappings.Count)`n" "Green"
        
        # Display results to console
        Write-ColorOutput "Zone Mappings:" "Cyan"
        $allZoneMappings | Format-Table -AutoSize | Out-String | Write-Host
        
        # Export to CSV
        $allZoneMappings | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-ColorOutput "Results exported to: $OutputPath" "Green"
        
        # Display the absolute path
        $absolutePath = (Resolve-Path -Path $OutputPath).Path
        Write-ColorOutput "Absolute path: $absolutePath" "Green"
    }
    
    Write-ColorOutput "`n=== Discovery Complete ===" "Magenta"
}
catch {
    Write-ColorOutput "`nERROR: $($_.Exception.Message)" "Red"
    Write-ColorOutput "Stack Trace: $($_.ScriptStackTrace)" "Red"
    exit 1
}
