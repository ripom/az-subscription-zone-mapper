# az-subscription-zone-mapper

Discovers Azure availability zone mappings across all subscriptions in the current tenant. Queries the first region with zone data, extracts physical-to-logical zone pairs, and exports results to CSV for audit, planning, or compliance.

## Description

This PowerShell script automates the discovery of Azure availability zone mappings across multiple subscriptions. It:
- Lists all Azure subscriptions in the current tenant
- Iterates through each subscription and sets the subscription context
- Queries the first region with availabilityZoneMappings via Azure REST API
- Extracts physical-to-logical zone pairs
- Displays mappings in the console with color-coded output
- Exports results to a CSV file for further analysis

## Prerequisites

- **Azure CLI** (`az`) must be installed
- **PowerShell** 5.1 or later (PowerShell Core 7+ recommended)
- You must be authenticated to Azure (`az login`)
- Appropriate permissions to list subscriptions and query location data

## Installation

1. Clone this repository or download the `Get-AzSubscriptionZoneMapper.ps1` script
2. Ensure Azure CLI is installed: [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
3. Login to Azure: `az login`

## Usage

### Basic Usage

```powershell
.\Get-AzSubscriptionZoneMapper.ps1
```

This will:
- Process all subscriptions in your current tenant
- Export results to `zone-mappings.csv` in the current directory

### Custom Output Path

```powershell
.\Get-AzSubscriptionZoneMapper.ps1 -OutputPath "C:\Reports\azure-zones.csv"
```

### Get Help

```powershell
Get-Help .\Get-AzSubscriptionZoneMapper.ps1 -Full
```

## Output

### Console Output
The script provides color-coded console output showing:
- Subscription being processed (Cyan)
- Status messages (Yellow/Green/Red)
- Physical-to-logical zone mappings (White)
- Summary statistics

### CSV Output
The exported CSV file contains the following columns:
- **SubscriptionId**: Azure subscription ID
- **SubscriptionName**: Friendly name of the subscription
- **Region**: Region code (e.g., "eastus", "westeurope")
- **RegionDisplayName**: Friendly region name (e.g., "East US", "West Europe")
- **PhysicalZone**: Physical zone identifier
- **LogicalZone**: Logical zone number (1, 2, or 3)

### Example CSV Output
```csv
SubscriptionId,SubscriptionName,Region,RegionDisplayName,PhysicalZone,LogicalZone
12345678-1234-1234-1234-123456789012,Production,eastus,East US,eastus-az1,1
12345678-1234-1234-1234-123456789012,Production,eastus,East US,eastus-az2,2
12345678-1234-1234-1234-123456789012,Production,eastus,East US,eastus-az3,3
```

## Error Handling

The script handles various error conditions gracefully:
- **Not logged in**: Prompts to run `az login`
- **No subscriptions found**: Exits with a warning
- **Failed to set subscription**: Skips the subscription and continues
- **No zone mappings**: Reports that the subscription doesn't support availability zones
- **Failed to export CSV**: Reports the error but continues

## Use Cases

- **Audit**: Verify zone mappings across multiple subscriptions
- **Planning**: Understand availability zone layouts before deployment
- **Compliance**: Document zone configurations for regulatory requirements
- **Migration**: Plan cross-subscription migrations with zone awareness

## Notes

- The script queries only the **first region** with availability zone mappings per subscription
- Some subscriptions or regions may not support availability zones
- Zone mappings are subscription-specific (physical zones can map to different logical zones across subscriptions)
- The script uses the Azure REST API directly for detailed zone information

## Troubleshooting

**Issue**: "Failed to retrieve subscriptions"
- **Solution**: Run `az login` to authenticate

**Issue**: "No availability zone mappings found"
- **Solution**: This is normal for subscriptions without zone-enabled regions

**Issue**: Script hangs or times out
- **Solution**: Check your network connection and Azure service health

## License

This project is provided as-is for use with Azure environments.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
