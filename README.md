# az-subscription-zone-mapper

Discovers Azure availability zone mappings across all subscriptions or a specific subscription in the current tenant. Queries the first region with zone data, extracts physical-to-logical zone pairs, and optionally exports results to CSV for audit, planning, or compliance.

## Overview

This PowerShell script automates the discovery of Azure availability zone mappings for subscriptions in your current tenant. It extracts the physical-to-logical zone pairs and can either display them on screen or export to a CSV file for analysis.

## Prerequisites

- **Azure CLI** (`az`) must be installed and available in your PATH
- **PowerShell Core** (pwsh) or Windows PowerShell
- Active Azure authentication (run `az login` before executing the script)

## Features

- Processes all Azure subscriptions in the current tenant or a specific subscription
- Filters subscriptions by the current tenant ID
- Queries Azure REST API for location metadata
- Identifies regions with `availabilityZoneMappings`
- Extracts physical-to-logical zone pairs
- Optional CSV export or screen-only display
- Progress bar for multi-subscription processing
- Color-coded console output

## Usage

### Display Results for All Subscriptions (Screen Only)

```powershell
./Get-AzZoneMappings.ps1
```

Results are displayed in the console without creating a file.

### Display Results for a Specific Subscription

```powershell
./Get-AzZoneMappings.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"
```

### Export All Subscriptions to CSV

```powershell
./Get-AzZoneMappings.ps1 -OutputPath "zone-mappings.csv"
```

### Export Specific Subscription to CSV

```powershell
./Get-AzZoneMappings.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -OutputPath "my-zones.csv"
```

### Help

```powershell
Get-Help ./Get-AzZoneMappings.ps1 -Full
```

## Parameters

- **`-SubscriptionId`** (Optional): Azure subscription ID. If provided, only that subscription is processed. If omitted, all subscriptions in the current tenant are processed.
- **`-OutputPath`** (Optional): Path to export results as a CSV file. If omitted, results are only displayed on screen.

## Output Format

### Console Output

Results are displayed in the console with color-coded sections:

```
=== Reading current Tenant ID ===
=== Gathering the Subscription IDs filtered by Current Tenant ID ===
Generating result for Zone Mappings
Subscription, SubscriptionID, Physical Zone, Logical Zone
Production, 12345678-1234-1234-1234-123456789abc, 1, 2
Production, 12345678-1234-1234-1234-123456789abc, 2, 3
Production, 12345678-1234-1234-1234-123456789abc, 3, 1
```

### CSV Output (When OutputPath is Specified)

The CSV file contains the following columns:

- **Subscription**: Friendly name of the subscription
- **SubscriptionId**: Azure subscription ID
- **PhysicalZone**: Physical zone identifier (datacenter-specific)
- **LogicalZone**: Logical zone number (subscription-specific)

## Example Output

```
Subscription, SubscriptionID, Physical Zone, Logical Zone
Production,12345678-1234-1234-1234-123456789abc,1,2
Production,12345678-1234-1234-1234-123456789abc,2,3
Production,12345678-1234-1234-1234-123456789abc,3,1
```

## Error Handling

The script includes comprehensive error handling:

- Validates Azure CLI authentication
- Verifies subscription ID exists in the current tenant (when specified)
- Checks for empty or malformed JSON responses
- Continues processing other subscriptions if one fails
- Displays warnings for subscriptions without zone mappings
- Color-coded error messages for better visibility
- Exits with error code 1 on critical failures

## Technical Details

### Azure CLI Commands Used

- `az account show`: Retrieves current account and tenant information
- `az account list`: Lists all subscriptions
- `az account set`: Sets the active subscription context
- `az rest`: Makes authenticated REST API calls to Azure Resource Manager

### Azure REST API

The script uses the Azure Resource Manager REST API to query location metadata:

```
GET https://management.azure.com/subscriptions/{subscriptionId}/locations/{locationName}?api-version=2022-12-01
```

## Troubleshooting

### "Failed to get current account information"

Run `az login` to authenticate with Azure.

### "No subscriptions found in the current tenant"

Ensure you have access to at least one subscription in the current tenant. Check with `az account list`.

### "Error: Subscription ID 'xxx' not found in the current tenant"

The specified subscription ID either doesn't exist or is not accessible in your current tenant. Verify the subscription ID and ensure you have access to it.

### "No zone mappings found in any subscription"

Not all Azure regions support availability zones. The script will only find mappings in regions that support this feature.

## License

MIT License - feel free to use and modify as needed.