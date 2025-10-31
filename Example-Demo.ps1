# Example Test/Demonstration Script for Get-AzZoneMappings.ps1
# This script demonstrates the expected behavior and output format

Write-Host "=== Azure Subscription Zone Mapper - Example Demonstration ===" -ForegroundColor Magenta
Write-Host ""

# Display what the script checks for
Write-Host "Prerequisites Check:" -ForegroundColor Cyan
Write-Host "  1. Azure CLI (az) - Required" -ForegroundColor Yellow
Write-Host "  2. PowerShell Core or Windows PowerShell - Required" -ForegroundColor Yellow
Write-Host "  3. Azure Authentication (az login) - Required" -ForegroundColor Yellow
Write-Host ""

# Check if Azure CLI is available
$azExists = Get-Command az -ErrorAction SilentlyContinue
if ($azExists) {
    Write-Host "✓ Azure CLI is installed" -ForegroundColor Green
} else {
    Write-Host "✗ Azure CLI is NOT installed" -ForegroundColor Red
    Write-Host "  Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Expected Script Flow ===" -ForegroundColor Magenta
Write-Host ""

Write-Host "Step 1: Retrieve current tenant information" -ForegroundColor Cyan
Write-Host "  Command: az account show --output json" -ForegroundColor Gray
Write-Host "  Parses JSON to extract tenantId" -ForegroundColor Gray
Write-Host ""

Write-Host "Step 2: List all subscriptions" -ForegroundColor Cyan
Write-Host "  Command: az account list --output json" -ForegroundColor Gray
Write-Host "  Filters subscriptions matching current tenant" -ForegroundColor Gray
Write-Host ""

Write-Host "Step 3: For each subscription:" -ForegroundColor Cyan
Write-Host "  3a. Set subscription context: az account set --subscription <id>" -ForegroundColor Gray
Write-Host "  3b. List locations: az account list-locations" -ForegroundColor Gray
Write-Host "  3c. Query each location for zone mappings:" -ForegroundColor Gray
Write-Host "      az rest --uri https://management.azure.com/subscriptions/{id}/locations/{location}?api-version=2022-12-01" -ForegroundColor Gray
Write-Host ""

Write-Host "Step 4: Extract zone mappings" -ForegroundColor Cyan
Write-Host "  Identifies first region with availabilityZoneMappings" -ForegroundColor Gray
Write-Host "  Extracts physicalZone and logicalZone pairs" -ForegroundColor Gray
Write-Host ""

Write-Host "Step 5: Export results" -ForegroundColor Cyan
Write-Host "  Outputs to console (Format-Table)" -ForegroundColor Gray
Write-Host "  Exports to CSV file (zone-mappings.csv)" -ForegroundColor Gray
Write-Host ""

Write-Host "=== Example Output Format ===" -ForegroundColor Magenta
Write-Host ""

# Create example data structure
$exampleMappings = @(
    [PSCustomObject]@{
        SubscriptionId   = "12345678-1234-1234-1234-123456789abc"
        SubscriptionName = "Production"
        Region           = "eastus"
        LogicalZone      = "1"
        PhysicalZone     = "eastus-az1"
    },
    [PSCustomObject]@{
        SubscriptionId   = "12345678-1234-1234-1234-123456789abc"
        SubscriptionName = "Production"
        Region           = "eastus"
        LogicalZone      = "2"
        PhysicalZone     = "eastus-az3"
    },
    [PSCustomObject]@{
        SubscriptionId   = "12345678-1234-1234-1234-123456789abc"
        SubscriptionName = "Production"
        Region           = "eastus"
        LogicalZone      = "3"
        PhysicalZone     = "eastus-az2"
    }
)

Write-Host "Console Output:" -ForegroundColor Cyan
$exampleMappings | Format-Table -AutoSize

Write-Host ""
Write-Host "CSV Output (zone-mappings.csv):" -ForegroundColor Cyan
$exampleMappings | ConvertTo-Csv -NoTypeInformation | ForEach-Object { Write-Host $_ -ForegroundColor Gray }

Write-Host ""
Write-Host "=== Error Handling ===" -ForegroundColor Magenta
Write-Host ""
Write-Host "The script handles the following scenarios:" -ForegroundColor Cyan
Write-Host "  • Missing Azure CLI authentication" -ForegroundColor Yellow
Write-Host "  • Subscriptions without zone mappings" -ForegroundColor Yellow
Write-Host "  • Malformed JSON responses" -ForegroundColor Yellow
Write-Host "  • Network or API errors" -ForegroundColor Yellow
Write-Host "  • Empty subscription lists" -ForegroundColor Yellow
Write-Host ""

Write-Host "=== Usage Examples ===" -ForegroundColor Magenta
Write-Host ""
Write-Host "Basic usage:" -ForegroundColor Cyan
Write-Host "  ./Get-AzZoneMappings.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Custom output path:" -ForegroundColor Cyan
Write-Host "  ./Get-AzZoneMappings.ps1 -OutputPath 'C:\output\mappings.csv'" -ForegroundColor Gray
Write-Host ""
Write-Host "Get help:" -ForegroundColor Cyan
Write-Host "  Get-Help ./Get-AzZoneMappings.ps1 -Full" -ForegroundColor Gray
Write-Host ""

Write-Host "=== Demonstration Complete ===" -ForegroundColor Magenta
