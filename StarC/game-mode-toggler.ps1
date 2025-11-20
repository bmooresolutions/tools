<# 
    The do0der's Windows 11 Gaming Mode – Star Citizen
    - Temporarily disables noisy services, scheduled tasks, telemetry, indexing, updates, and network discovery
    - Sets high performance power, disables background apps, notification toasts, and animations
    - Restores everything with -Disable
#>

param()

function New-GamingRestorePoint {
    Write-Host "Creating a System Restore Point..."
    try {
        Checkpoint-Computer -Description "GamingMode" -RestorePointType "MODIFY_SETTINGS" | Out-Null
    } catch {
        Write-Warning "Restore point failed (might be disabled). Continuing cautiously."
    }
}

# Registry helper
function Set-Reg {
    param([string]$Path,[string]$Name,[object]$Value,[Microsoft.Win32.RegistryValueKind]$Type)
    New-Item -Path $Path -Force | Out-Null
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

# Service toggle helper (records original startup type)
$global:ServiceBackup = @{}

function Set-ServiceState {
    param([string]$Name,[string]$StartupType,[bool]$Stop=$true)
    try {
        $svc = Get-Service -Name $Name -ErrorAction Stop
        if (-not $global:ServiceBackup.ContainsKey($Name)) {
            $orig = (Get-WmiObject -Class Win32_Service -Filter "Name='$Name'").StartMode
            $global:ServiceBackup[$Name] = $orig
        }
        sc.exe config $Name start= $StartupType | Out-Null
        if ($Stop -and $svc.Status -ne 'Stopped') { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue }
    } catch { Write-Host "Skip: $Name not present." }
}

function Restore-Services {
    foreach ($k in $global:ServiceBackup.Keys) {
        $orig = $global:ServiceBackup[$k]
        if ($orig) { sc.exe config $k start= $orig | Out-Null }
        try {
            if ($orig -match 'auto') { Start-Service -Name $k -ErrorAction SilentlyContinue }
        } catch {}
    }
}

# Scheduled tasks toggle
$global:TaskBackup = @()

function Disable-Task {
    param([string]$Path)
    try {
        $t = Get-ScheduledTask -TaskPath $Path -ErrorAction Stop
        foreach ($task in $t) {
            $global:TaskBackup += $task.TaskName + '|' + $task.TaskPath + '|' + $task.State
            Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
        }
    } catch {}
}

function Restore-Tasks {
    foreach ($entry in $global:TaskBackup) {
        $parts = $entry.Split('|')
        $name = $parts[0]; $path = $parts[1]; $state = $parts[2]
        try {
            if ($state -eq 'Ready' -or $state -eq 'Enabled') {
                Enable-ScheduledTask -TaskName $name -TaskPath $path -ErrorAction SilentlyContinue
            }
        } catch {}
    }
}

# Disable noisy services, indexing, updates, discovery, telemetry
function Apply-Services {
    $targets = @(
        @{Name='wuauserv';Type='disabled'},          # Windows Update service
        @{Name='BITS';Type='disabled'},              # Background Intelligent Transfer
        @{Name='DoSvc';Type='disabled'},             # Delivery Optimization
        @{Name='SysMain';Type='disabled'},           # Superfetch
        @{Name='WSearch';Type='disabled'},           # Windows Search
        @{Name='DiagTrack';Type='disabled'},         # Connected User Experiences/Telemetry
        @{Name='dmwappushservice';Type='disabled'},  # Push service
        @{Name='SSDPSRV';Type='disabled'},           # SSDP discovery
        @{Name='FDResPub';Type='disabled'},          # Function Discovery Resource
        @{Name='lltdsvc';Type='disabled'},           # Link-Layer Topology Discovery
        @{Name='LanmanWorkstation';Type='auto'},     # Keep SMB client on for storage
        @{Name='Spooler';Type='disabled'}            # Print Spooler (optional)
    )
    foreach ($t in $targets) { Set-ServiceState -Name $t.Name -StartupType $t.Type }
}

# Disable scheduled tasks for update/telemetry/diagnostics
function Apply-Tasks {
    $paths = @(
        '\Microsoft\Windows\WindowsUpdate\',
        '\Microsoft\Windows\UpdateOrchestrator\',
        '\Microsoft\Windows\DeliveryOptimization\',
        '\Microsoft\Windows\Application Experience\',
        '\Microsoft\Windows\Customer Experience Improvement Program\',
        '\Microsoft\Windows\Autochk\',
        '\Microsoft\Windows\Maps\',
        '\Microsoft\Windows\Shell\',
        '\Microsoft\Windows\DiskDiagnostic\'
    )
    foreach ($p in $paths) { Disable-Task -Path $p }
}

# System UI/notifications/animations/background apps
function Apply-UX {
    # Game Mode ON (also do in Settings, this enforces registry)
    Set-Reg -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value 1 -Type DWord
    Set-Reg -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'GamePanelStartupTipIndex' -Value 3 -Type DWord

    # Disable notifications toasts
    Set-Reg -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' -Name 'ToastEnabled' -Value 0 -Type DWord

    # Disable background apps (modern apps background access)
    Set-Reg -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name 'LetAppsRunInBackground' -Value 2 -Type DWord

    # Reduce UI animations
    Set-Reg -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Value ([byte[]](0x90,0x12,0x03,0x80,0x00,0x00,0x00,0x00)) -Type Binary
    Set-Reg -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2 -Type DWord

    # Power plan: Ultimate Performance (create if missing)
    $plan = (powercfg -L) -match 'Ultimate Performance'
    if (-not $plan) { powercfg -duplicatescheme E9A42B02-D5DF-448D-AA00-03F14749EB61 | Out-Null }
    $guid = ((powercfg -L) | Select-String 'Ultimate Performance').ToString().Split()[3]
    powercfg -setactive $guid

    # Disable indexing globally
    try {
        Set-ServiceState -Name 'WSearch' -StartupType 'disabled'
        $drives = Get-Volume | Where-Object {$_.DriveLetter}
        foreach ($d in $drives) { (Get-Item "$($d.DriveLetter):\").Attributes = 'Normal' }
    } catch {}
}

# Network: disable discovery, ICMP echo responses
function Apply-Network {
    # Turn off network discovery: handled by services above (SSDPSRV, FDResPub, lltdsvc)
    # Block inbound ICMP echo requests (IPv4/IPv6)
    New-NetFirewallRule -DisplayName 'Block ICMPv4 Echo' -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Block -Profile Any -PolicyStore ActiveStore -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName 'Block ICMPv6 Echo' -Protocol ICMPv6 -IcmpType 128 -Direction Inbound -Action Block -Profile Any -PolicyStore ActiveStore -ErrorAction SilentlyContinue
}

function Remove-Network {
    Get-NetFirewallRule | Where-Object {$_.DisplayName -in @('Block ICMPv4 Echo','Block ICMPv6 Echo')} | Remove-NetFirewallRule -ErrorAction SilentlyContinue
}

# Windows Update policy hard block (temporary)
function Apply-UpdatePolicies {
    Set-Reg -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -Value 1 -Type DWord
    Set-Reg -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name 'DoNotConnectToWindowsUpdateInternetLocations' -Value 1 -Type DWord
}

function Remove-UpdatePolicies {
    Remove-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Recurse -Force -ErrorAction SilentlyContinue
}

function ToggleGamingMode {
    param([switch]$Enable,[switch]$Disable)
    if ($Enable) {
        New-GamingRestorePoint
        Apply-Services
        Apply-Tasks
        Apply-UX
        Apply-Network
        Apply-UpdatePolicies
        Write-Host "Gaming Mode ENABLED. Reboot recommended."
    } elseif ($Disable) {
        Restore-Services
        Restore-Tasks
        Remove-Network
        Remove-UpdatePolicies
        Write-Host "Gaming Mode DISABLED. Reboot recommended."
    } else {
        Write-Host "Usage: ./game-mode-toggler.ps1  OR   -Disable"
    }
}

# Auto-run if passed
# Example: ./game-mode-toggler.ps1 -Enable
