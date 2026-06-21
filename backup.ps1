<#
    FiveM database backup-script

    Brug:
      Tag backup nu:              powershell -ExecutionPolicy Bypass -File backup.ps1
      Installer auto-backup 2x:   powershell -ExecutionPolicy Bypass -File backup.ps1 -Install
      Fjern auto-backup igen:     powershell -ExecutionPolicy Bypass -File backup.ps1 -Uninstall

    -Install opretter en planlagt opgave i Windows Task Scheduler, der koerer
    dette script automatisk paa de tidspunkter, der staar i $BackupTimes nedenfor.
#>

param(
    [switch]$Install,
    [switch]$Uninstall
)

# ============================================================================
#  CONFIG - ret kun vaerdierne herunder
# ============================================================================

# Sti til mysqldump.exe (ret versionsnummeret hvis noedvendigt)
$DumpExe        = "C:\Program Files\MariaDB 12.3\bin\mysqldump.exe"

# Database-login
$DbUser         = "root"
$DbPassword     = "admin123"
$DbName         = "ESXLegacy_96C629"

# Hvor backups gemmes
$BackupDir      = "C:\Backups"

# Hvor mange dage backups beholdes (aeldre slettes automatisk)
$RetentionDays  = 7

# Tidspunkter for automatisk backup (bruges af -Install). 24-timers format "HH:mm"
$BackupTimes    = @("05:00", "17:00")

# Navn paa den planlagte opgave i Task Scheduler
$TaskName       = "FiveM DB Backup"

# ============================================================================
#  Herunder behoever du normalt ikke aendre noget
# ============================================================================

function Invoke-Backup {
    if (-not (Test-Path $DumpExe)) {
        Write-Error "mysqldump blev ikke fundet: $DumpExe"
        exit 1
    }

    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir | Out-Null
    }

    $dato = Get-Date -Format "yyyy-MM-dd_HHmm"
    $fil  = Join-Path $BackupDir "esx_$dato.sql"

    Write-Host "Tager backup af '$DbName' -> $fil"

    # --result-file skriver direkte til filen (undgaar PowerShells UTF-16-redirect, der kan oedelaegge dumpet)
    # --password= uden mellemrum (ellers opfattes vaerdien som databasenavn)
    & $DumpExe "-u$DbUser" "--password=$DbPassword" --single-transaction --quick "--result-file=$fil" $DbName

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Backup fejlede (exit code $LASTEXITCODE)"
        exit $LASTEXITCODE
    }

    Write-Host "Backup faerdig."

    # Rotation: slet backups aeldre end $RetentionDays dage
    Get-ChildItem (Join-Path $BackupDir "esx_*.sql") |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
        Remove-Item -Force

    Write-Host "Gamle backups (aeldre end $RetentionDays dage) er ryddet op."
}

function Install-Schedule {
    $scriptPath = $MyInvocation.MyCommand.Definition
    if (-not $scriptPath) { $scriptPath = $PSCommandPath }

    $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

    # En trigger pr. tidspunkt i $BackupTimes
    $triggers = foreach ($t in $BackupTimes) {
        New-ScheduledTaskTrigger -Daily -At $t
    }

    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers `
        -Settings $settings -Description "Automatisk FiveM database backup" `
        -RunLevel Highest -Force | Out-Null

    Write-Host "Planlagt opgave '$TaskName' oprettet. Koerer dagligt kl. $($BackupTimes -join ' og ')."
}

function Uninstall-Schedule {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Planlagt opgave '$TaskName' fjernet."
}

if ($Install) {
    Install-Schedule
}
elseif ($Uninstall) {
    Uninstall-Schedule
}
else {
    Invoke-Backup
}