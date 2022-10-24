# Software install Script
#
# Applications to install:
#



#region Set logging 
$logFile = "c:\temp\" + (get-date -format 'yyyyMMdd') + '_softwareinstall.log'
function Write-Log {
    Param($message)
    Write-Output "$(get-date -format 'yyyyMMdd HH:mm:ss') $message" | Out-File -Encoding utf8 $logFile -Append
}
#endregion

#region Liquit Agent
try {
    Start-Process -filepath "c:\temp\software\liquit\Deploy-Application.exe" -Wait -ErrorAction Stop -ArgumentList 'install noninteractive'
    if (Test-Path "C:\Program Files (x86)\Liquit Workspace\Agent\UserHost.exe") {
        Write-Log "Liquit agent has been installed"
    }
    else {
        write-log "Error locating Liquit Agent executable"
    }
}
catch {
    $ErrorMessage = $_.Exception.message
    write-log "Error installing Liquit Agent: $ErrorMessage"
}
#endregion

#region Time Zone Redirection
$Name = "fEnableTimeZoneRedirection"
$value = "1"
# Add Registry value
try {
    New-ItemProperty -ErrorAction Stop -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name $name -Value $value -PropertyType DWORD -Force
    if ((Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services").PSObject.Properties.Name -contains $name) {
        Write-log "Added time zone redirection registry key"
    }
    else {
        write-log "Error locating the Teams registry key"
    }
}
catch {
    $ErrorMessage = $_.Exception.message
    write-log "Error adding teams registry KEY: $ErrorMessage"
}
#endregion
