# az-subscription-zone-mapper

Discovers Azure availability zone mappings across all subscriptions in the current tenant. Queries the first region with zone data, extracts physical-to-logical zone pairs, and exports results to CSV for audit, planning, or compliance.

## Overview

This PowerShell script automates the discovery of Azure availability zone mappings across all subscriptions in your current tenant. It extracts the physical-to-logical zone pairs, and exports the data to a CSV file for analysis.

## Prerequisites

- **Azure CLI** (`az`) must be installed and available in your PATH
- **PowerShell Core** (pwsh) or Windows PowerShell
- Active Azure authentication (run `az login` before executing the script)

## Features

- Iterates through all Azure subscriptions in the current tenant
- Filters subscriptions by the current tenant ID
- Queries Azure REST API for location metadata
- Identifies regions with `availabilityZoneMappings`
- Extracts physical-to-logical zone pairs
- Exports results to CSV format

## Usage

### Basic Usage

```powershell
./Get-AzZoneMappings.ps1
```

This will create a `zone-mappings.csv` file in the current directory.

### Custom Output Path

```powershell
./Get-AzZoneMappings.ps1 -OutputPath "C:\output\my-mappings.csv"
```

### Help

```powershell
Get-Help ./Get-AzZoneMappings.ps1 -Full
```

## Output Format

The CSV file contains the following columns:

- **SubscriptionId**: Azure subscription ID
- **Subscription**: Friendly name of the subscription
- **Logical Zone**: Logical zone number (subscription-specific)
- **Physical Zone**: Physical zone identifier (datacenter-specific)

## Example Output

```
Subscription, SubscriptionID, Physical Zone, Logical Zone
Production,12345678-1234-1234-1234-123456789abc,az1,2
Production,12345678-1234-1234-1234-123456789abc,az2,3
Production,12345678-1234-1234-1234-123456789abc,az3,1
```

## Error Handling

The script includes comprehensive error handling:

- Validates Azure CLI authentication
- Checks for empty or malformed JSON responses
- Continues processing other subscriptions if one fails
- Displays warnings for subscriptions without zone mappings
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

### "No zone mappings found in any subscription"

Not all Azure regions support availability zones. The script will only find mappings in regions that support this feature.

## License

MIT License - feel free to use and modify as needed.