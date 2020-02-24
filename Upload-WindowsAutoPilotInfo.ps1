<#
.SYNOPSIS
    .
.DESCRIPTION
    Use this script to pull AutoPilot device hash and upload to Azure Blob storage.
    This script contains Get-WindowsAutoPilotInfo.ps1 (https://www.powershellgallery.com/packages/Get-WindowsAutoPilotInfo/1.6)
converted to a PS function.
.PARAMETER url
    This should be the url of the container where the hash will be uploaded to - 
https://storage-acct-name.blob.core.windows.net/container-name.
.PARAMETER sas
    This should be a SAS token generated for the container.
.EXAMPLE
    .\Upload-WindowsAutoPilotInfo.ps1 -url "https://storage-acct-name.blob.core.windows.net/container-name" -sas "?insert_sas_string_here"
.NOTES
    Version:         0.1
    Author:          Zachary Choate
    Creation Date:   02/24/2020
    URL:             
#>
param(
[string] $url,
[string] $sas
)
#
#################################################################################
#You shouldn't need to modify the below contents

### Get-WindowsAutoPilotInfo.ps1 as script. ###
function Get-WindowsAutoPilotInfo {
    param(
	[Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0)][alias("DNSHostName","ComputerName","Computer")] [String[]] $Name = @("localhost"),
	[Parameter(Mandatory=$False)] [String] $OutputFile = "", 
	[Parameter(Mandatory=$False)] [String] $GroupTag = "",
	[Parameter(Mandatory=$False)] [Switch] $Append = $false,
	[Parameter(Mandatory=$False)] [System.Management.Automation.PSCredential] $Credential = $null,
	[Parameter(Mandatory=$False)] [Switch] $Partner = $false,
	[Parameter(Mandatory=$False)] [Switch] $Force = $false
)

Begin
{
	# Initialize empty list
	$computers = @()
}

Process
{
	foreach ($comp in $Name)
	{
		$bad = $false

		# Get a CIM session
		if ($comp -eq "localhost") {
			$session = New-CimSession
		}
		else
		{
			$session = New-CimSession -ComputerName $comp -Credential $Credential
		}

		# Get the common properties.
		Write-Verbose "Checking $comp"
		$serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber

		# Get the hash (if available)
		$devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
		if ($devDetail -and (-not $Force))
		{
			$hash = $devDetail.DeviceHardwareData
		}
		else
		{
			$bad = $true
			$hash = ""
		}

		# If the hash isn't available, get the make and model
		if ($bad -or $Force)
		{
			$cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
			$make = $cs.Manufacturer.Trim()
			$model = $cs.Model.Trim()
			if ($Partner)
			{
				$bad = $false
			}
		}
		else
		{
			$make = ""
			$model = ""
		}

		# Getting the PKID is generally problematic for anyone other than OEMs, so let's skip it here
		$product = ""

		# Depending on the format requested, create the necessary object
		if ($Partner)
		{
			# Create a pipeline object
			$c = New-Object psobject -Property @{
				"Device Serial Number" = $serial
				"Windows Product ID" = $product
				"Hardware Hash" = $hash
				"Manufacturer name" = $make
				"Device model" = $model
			}
			# From spec:
			#	"Manufacturer Name" = $make
			#	"Device Name" = $model

		}
		elseif ($GroupTag -ne "")
		{
			# Create a pipeline object
			$c = New-Object psobject -Property @{
				"Device Serial Number" = $serial
				"Windows Product ID" = $product
				"Hardware Hash" = $hash
				"Group Tag" = $GroupTag
			}
		}
		else
		{
			# Create a pipeline object
			$c = New-Object psobject -Property @{
				"Device Serial Number" = $serial
				"Windows Product ID" = $product
				"Hardware Hash" = $hash
			}
		}

		# Write the object to the pipeline or array
		if ($bad)
		{
			# Report an error when the hash isn't available
			Write-Error -Message "Unable to retrieve device hardware data (hash) from computer $comp" -Category DeviceError
		}
		elseif ($OutputFile -eq "")
		{
			$c
		}
		else
		{
			$computers += $c
		}

		Remove-CimSession $session
	}
}

End
{
	if ($OutputFile -ne "")
	{
		if ($Append)
		{
			if (Test-Path $OutputFile)
			{
				$computers += Import-CSV -Path $OutputFile
			}
		}
		if ($Partner)
		{
			$computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash", "Manufacturer name", "Device model" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
		}
		elseif ($GroupTag -ne "")
		{
			$computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash", "Group Tag" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
		}
		else
		{
			$computers | Select "Device Serial Number", "Windows Product ID", "Hardware Hash" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
		}
	}
}
}

#AutoPilot Info File:
$file = "$env:Temp\$env:COMPUTERNAME.csv"

#Get Hash:
Get-WindowsAutoPilotInfo -outputfile $file

#Get the file name without path:
$name = (Get-Item $file).Name

#The target URL with SAS Token:
$uri = "$url/$($name)$sas"

#Define required Headers:
$headers = @{
    'x-ms-blob-type' = 'BlockBlob'
}

#Upload File:
Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -InFile $file 

#Clean up AutoPilot Info File:
Remove-Item $file