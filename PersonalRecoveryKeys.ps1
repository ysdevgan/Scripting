#JAMF PRO creds
$Username = "USERNAME"
$password = "PASSWORD"
$jamfpro_url = "https://yourserver.jamfcloud.com"

# Define the function to get the Jamf Pro API token
Function Get-JamfProAPIToken {
    # Use user account's username and password credentials with Basic Authorization to request a bearer token
    $base64Creds = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($username):$($password)"))
    $tokenResponse = Invoke-RestMethod -Uri "$($jamfpro_url)/api/v1/auth/token" -Method Post -Headers @{
        "Authorization" = "Basic $base64Creds"
    }
    $api_token = $tokenResponse.token
    return $api_token
}

$api_token = Get-JamfProAPIToken

function Get-PersonalRecoveryKey {

    <#
    .SYNOPSIS
        Retrieves Personal Recovery Keys using a serial number.
    .DESCRIPTION
        This function queries Jamf Pro API to obtain the Personal Recovery Key associated with a device identified by its serial number.
        It also handles cases where the device or key is not found and provides informative messages accordingly.
    .NOTES
        Ensure that the API token and Jamf Pro URL are correctly set in the script before calling this function.
        This function requires internet connectivity to access the Jamf Pro API.
    .PARAMETER serial
        Specifies the serial number of the device for which the Personal Recovery Key is to be retrieved.
    .PARAMETER expand
        Indicates whether to expand certain properties (default is False).
    .EXAMPLE
        Get-PersonalRecoveryKey -serial SN123456
        Retrieves the Personal Recovery Key for the device with the specified serial number.
    #>    
    
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$true)] $serial,
        [Parameter(Mandatory=$false)] [Switch]$expand = $false
    )
    
    try {
        # API Authentication
        $headers = @{
            "Authorization"= "Bearer $api_token"
            "accept"= "application/JSON"
        }

        # Get list of all devices from Jamf Pro
        $jamfAllDevicesUri = "$jamfpro_url/api/v1/computers-inventory?section=HARDWARE&page=0&page-size=800"
        $AllJamfComputers = Invoke-RestMethod -Uri $jamfAllDevicesUri -Method GET -Headers $headers
        $listallcomputers = $AllJamfComputers.results

        # Extract id and serialNumber for each device
        $alldevices = @()
        foreach ($device in $listallcomputers) {
            $id = $device.id
            $serialnumber = $device.hardware.serialNumber

            $deviceInfo = @{
                id = $id
                serialNumber = $serialnumber
            }

            $alldevices += $deviceInfo
        }

        # Find deviceID based on serial number
        $deviceID = $alldevices | Where-Object {$_.SerialNumber -match $serial } | Select-Object -ExpandProperty id

        if ($deviceID) {
            $deviceURI = "$jamfpro_url/api/v1/computers-inventory/$deviceID/filevault"
            $response = Invoke-WebRequest -Uri $deviceURI -Method GET -Headers $headers
            $responseObject = $response | ConvertFrom-Json

            # Output the personal recovery key
            $responseObject.personalRecoveryKey
        }
        else {
            Write-Output "Device with serial number $serial not found."
        }
    }
    catch {
        Write-Output "FileVault recovery not available"
        #Write-Output "An error occurred: $_"
    }
}


Get-PersonalRecoveryKey -serial "SN12345"
