<#
.SYNOPSIS
    Performs a comprehensive audit of recent changes on a Windows server,
    including installed patches, system events, and application installations.

.DESCRIPTION
    This script executes three main queries:
    1. Installed Hotfixes (KB patches).
    2. System Event Log for service installations, system startups, and major changes (last 20 days).
    3. Application Event Log for successful MSI-based application installations (last 20 days).

.NOTES
    Owner: Murali Palla
    Contact: contact@muralipalla.com
    Usage Summary: PowerShell script to perform a quick security and modification audit 
    by listing installed patches and querying System and Application event logs for 
    recent changes and installations over the last 20 days.
#>
# SCRIPT: Server-Modification-Audit.ps1

# Define the lookback period based on user input
$DaysToLookBack = -20
$CutoffDate = (Get-Date).AddDays($DaysToLookBack)

# =========================================================================
# 1. INSTALLED HOTFIXES (PATCHES)
# =========================================================================
Write-Host "`n----- 1. INSTALLED WINDOWS HOTFIXES (KB PATCHES) -----" -ForegroundColor Cyan
Write-Host "Displaying all installed Windows updates, sorted by most recent date." -ForegroundColor DarkCyan

Get-HotFix | 
    Select-Object -Property HotFixID, Description, InstalledOn, InstalledBy | 
    Sort-Object -Property InstalledOn -Descending | 
    Format-Table -AutoSize

# =========================================================================
# 2. SYSTEM EVENT LOG QUERIES (INSTALLATIONS, STARTUPS, SERVICE CHANGES)
# =========================================================================
Write-Host "`n----- 2. RECENT SYSTEM LOG EVENTS (Last $($DaysToLookBack * -1) Days) -----" -ForegroundColor Yellow
Write-Host "Events include System Startup/Shutdown and Service/MSIInstaller activity." -ForegroundColor DarkYellow

$SystemEventIDs = @(
    1033,    # MSIInstaller: Installation or change success
    # 7036,  # Service Control Manager: Service entered the running state (or stopped) - Excluded in user's prompt
    7045,    # Service Control Manager: Service was installed
    6005,    # EventLog: The Event log service was started (System Startup)
    6006     # EventLog: The Event log service was stopped (System Shutdown)
)

Get-WinEvent -FilterHashtable @{
    LogName   = 'System'
    StartTime = $CutoffDate
    ID        = $SystemEventIDs
} |
    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
    Sort-Object TimeCreated -Descending |
    Format-List

# =========================================================================
# 3. APPLICATION EVENT LOG QUERIES (SUCCESSFUL MSI INSTALLATIONS)
# =========================================================================
Write-Host "`n----- 3. APPLICATION LOG: SUCCESSFUL INSTALLATIONS (Last $($DaysToLookBack * -1) Days) -----" -ForegroundColor Green
Write-Host "Events show successfully completed MSI application installations (ID 11707)." -ForegroundColor DarkGreen

Get-WinEvent -FilterHashtable @{
    LogName      = 'Application'
    StartTime    = $CutoffDate
    ID           = 11707       # Event ID for 'Installation operation successfully completed'
    ProviderName = 'MsiInstaller'
} |
    Select-Object TimeCreated, Id, ProviderName, Message |
    Sort-Object TimeCreated -Descending |
    Format-Table -AutoSize
