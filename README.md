# Upload-WindowsAutoPilotInfo
Script for uploading Windows AutoPilot Info

### DESCRIPTION
Use this script to pull AutoPilot device hash and upload to Azure Blob storage.
This script contains Get-WindowsAutoPilotInfo.ps1 (https://www.powershellgallery.com/packages/Get-WindowsAutoPilotInfo/1.6)
converted to a PS function.
### PARAMETER url
This should be the url of the container where the hash will be uploaded to - https://storage-acct-name.blob.core.windows.net/container-name.
### PARAMETER sas
This should be a SAS token generated for the container.
### PARAMETER webhook
This should be the URL to POST to upon completion to trigger further action. Ex - trigger Azure Automation job.
### EXAMPLE
```
Upload-WindowsAutoPilotInfo.ps1 -url "https://storage-acct-name.blob.core.windows.net/container-name" -sas "?insert_sas_string_here" -webhook "https://events.azure-automation.com/webhooks?token=tokenmctokerson"
```
### NOTES
    Version:         0.2
    Last Updated:    05/07/2020
    Creation Date:   02/24/2020
    Author:          Zachary Choate
    URL:             https://raw.githubusercontent.com/zchoate/Upload-WindowsAutoPilotInfo/master/Upload-WindowsAutoPilotInfo.ps1
