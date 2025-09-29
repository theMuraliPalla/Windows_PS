<#
.SYNOPSIS
    Performs a comprehensive audit of recent changes on a Windows server,
    including installed patches, system events, and application installations.

.DESCRIPTION
    This script executes three main queries:
    1. Installed Hotfixes (KB patches).
    2. System Event Log for service installations, system startups, and major changes (last 20 days).
    3. Application Event Log for successful MSI-based application installations (last 20 days).
    It uses robust try/catch blocks to gracefully handle "No events found" conditions.

.NOTES
    Owner: Murali Palla
    Contact: contact@muralipalla.com
    Usage Summary: PowerShell script to perform a quick security and modification audit 
    by listing installed patches and querying System and Application event logs for 
    recent changes and installations over the last 20 days.
#>
# SCRIPT: Server-Modification-Audit.ps1

# Define the lookback period
$DaysToLookBack = -7
$CutoffDate = (Get-Date).AddDays($DaysToLookBack)
$DaysAbsolute = $DaysToLookBack * -1

# =========================================================================
# 1. INSTALLED HOTFIXES (PATCHES)
# =========================================================================
Write-Host "`n----- 1. INSTALLED WINDOWS HOTFIXES (KB PATCHES) on $($env:COMPUTERNAME) -----" -ForegroundColor Cyan
Write-Host "Displaying all installed Windows updates, sorted by most recent date." -ForegroundColor DarkCyan

$Hotfixes = Get-HotFix
if ($Hotfixes) {
    $Hotfixes | 
        Select-Object -Property HotFixID, Description, InstalledOn, InstalledBy | 
        Sort-Object -Property InstalledOn -Descending | 
        Format-Table -AutoSize
} else {
    Write-Host "No hotfixes or patches were found." -ForegroundColor DarkCyan
}

# ====================================================================================================================
# 2. SYSTEM EVENT LOG QUERIES (INSTALLATIONS, STARTUPS, SERVICE CHANGES)
# ====================================================================================================================
Write-Host "`n----- 2. RECENT SYSTEM LOG EVENTS (Last $DaysAbsolute Days) on $($env:COMPUTERNAME)  -----" -ForegroundColor Yellow
Write-Host "Events include System Startup/Shutdown and Service/MSIInstaller activity." -ForegroundColor DarkYellow

$SystemEventIDs = @(
    1033,    # MSIInstaller: Installation or change success
    7045,    # Service Control Manager: Service was installed
    6005,    # EventLog: The Event log service was started (System Startup)
    6006     # EventLog: The Event log service was stopped (System Shutdown)
)

try {
    # Search the System log, suppressing all errors during this command
    $SystemEvents = Get-WinEvent -FilterHashtable @{
        LogName   = 'System'
        StartTime = $CutoffDate
        ID        = $SystemEventIDs
    } -ErrorAction Stop # Use Stop to force the try/catch block to execute on error

    # If the try block succeeds and returns events:
    $SystemEvents |
        Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
        Sort-Object TimeCreated -Descending |
        Format-List

} catch {
    # The common "No events found" error is of type System.Management.Automation.CommandNotFoundException 
    # when Get-WinEvent is run. We output a custom message instead of the raw error.
    Write-Host "No matching System log events found in the last $DaysAbsolute days." -ForegroundColor DarkYellow
}


# ==========================================================================================================
# 3. APPLICATION EVENT LOG QUERIES (SUCCESSFUL MSI INSTALLATIONS) on $($env:COMPUTERNAME) 
# ==========================================================================================================
Write-Host "`n----- 3. APPLICATION LOG: SUCCESSFUL INSTALLATIONS (Last $DaysAbsolute Days) on $($env:COMPUTERNAME)  -----" -ForegroundColor Green
Write-Host "Events show successfully completed MSI application installations (ID 11707)." -ForegroundColor DarkGreen

try {
    # Search the Application log, suppressing all errors during this command
    $AppInstallEvents = Get-WinEvent -FilterHashtable @{
        LogName      = 'Application'
        StartTime    = $CutoffDate
        ID           = 11707       # Event ID for 'Installation operation successfully completed'
        ProviderName = 'MsiInstaller'
    } -ErrorAction Stop # Use Stop to force the try/catch block to execute on error

    # If the try block succeeds and returns events:
    $AppInstallEvents |
        Select-Object TimeCreated, Id, ProviderName, Message |
        Sort-Object TimeCreated -Descending |
        Format-Table -AutoSize

} catch {
    # The common "No events found" error is trapped here.
    Write-Host "No successful application installations (MSI ID 11707) found in the last $DaysAbsolute days." -ForegroundColor DarkGreen
}
