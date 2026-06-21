<#
    FiveM database backup-script

    Brug:
      Tag backup nu:              powershell -ExecutionPolicy Bypass -File backup.ps1
      Installer auto-backup 2x:   powershell -ExecutionPolicy Bypass -File backup.ps1 -Install
      Fjern auto-backup igen:     powershell -ExecutionPolicy Bypass -File backup.ps1 -Uninstall

    -Install opretter en planlagt opgave i Windows Task Scheduler, der koerer
    dette script automatisk paa de tidspunkter, der staar i $BackupTimes nedenfor.

    Backuppen kan valgfrit komprimeres til .zip ($CompressBackup) og uploades
    automatisk til skyen ($CloudEnabled) via rclone eller en mappe-/netvaerkskopi.
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
$DbPassword     = "KODE"
$DbName         = "Database_navn"

# Hvor backups gemmes
$BackupDir      = "C:\Backups"

# Hvor mange dage backups beholdes (aeldre slettes automatisk)
$RetentionDays  = 7

# Tidspunkter for automatisk backup (bruges af -Install). 24-timers format "HH:mm"
$BackupTimes    = @("05:00", "17:00")

# Navn paa den planlagte opgave i Task Scheduler
$TaskName       = "FiveM DB Backup"

# ---- Komprimering ----------------------------------------------------------
# Pak backuppen som .zip foer upload (sparer plads og baandbredde)
$CompressBackup = $true

# ---- Cloud-upload ----------------------------------------------------------
# Slaa cloud-upload til/fra
$CloudEnabled   = $false

# Metode: "rclone" (Google Drive/OneDrive/Dropbox/S3/FTP m.fl.) eller "copy" (kopi til mappe/netvaerksdrev)
$CloudMethod    = "rclone"

# -- Hvis $CloudMethod = "rclone":
#    Installer og konfigurer rclone foerst (se: https://rclone.org/docs/  ->  rclone config)
$RcloneExe      = "C:\Program Files\rclone\rclone.exe"
# Remote-navn fra din rclone-config + mappe, f.eks. "gdrive:fivem-backups"
$RcloneRemote   = "gdrive:fivem-backups"

# -- Hvis $CloudMethod = "copy":
#    En sti til et mappe/netvaerksdrev eller en synkroniseret cloud-mappe (OneDrive/Google Drive desktop)
$CloudCopyDir   = "Z:\fivem-backups"

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

    # Komprimer evt. til .zip
    if ($CompressBackup) {
        $fil = Compress-BackupFile -Path $fil
    }

    # Upload evt. til skyen
    if ($CloudEnabled) {
        Send-ToCloud -Path $fil
    }

    # Rotation: slet lokale backups aeldre end $RetentionDays dage (baade .sql og .zip)
    Get-ChildItem (Join-Path $BackupDir "esx_*.*") |
        Where-Object { $_.Extension -in ".sql", ".zip" -and $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
        Remove-Item -Force

    Write-Host "Gamle backups (aeldre end $RetentionDays dage) er ryddet op."
}

function Compress-BackupFile {
    param([string]$Path)

    $zip = [System.IO.Path]::ChangeExtension($Path, ".zip")
    Write-Host "Komprimerer -> $zip"
    Compress-Archive -Path $Path -DestinationPath $zip -Force

    # Slet den raa .sql naar zip'en er lavet
    Remove-Item $Path -Force
    return $zip
}

function Send-ToCloud {
    param([string]$Path)

    switch ($CloudMethod) {
        "rclone" {
            if (-not (Test-Path $RcloneExe)) {
                Write-Error "rclone blev ikke fundet: $RcloneExe (cloud-upload sprunget over)"
                return
            }
            Write-Host "Uploader til skyen via rclone -> $RcloneRemote"
            & $RcloneExe copy $Path $RcloneRemote
            if ($LASTEXITCODE -ne 0) {
                Write-Error "rclone-upload fejlede (exit code $LASTEXITCODE)"
            } else {
                Write-Host "Cloud-upload faerdig."
            }
        }
        "copy" {
            if (-not (Test-Path $CloudCopyDir)) {
                New-Item -ItemType Directory -Path $CloudCopyDir -Force | Out-Null
            }
            Write-Host "Kopierer til cloud-mappe -> $CloudCopyDir"
            Copy-Item -Path $Path -Destination $CloudCopyDir -Force
            Write-Host "Cloud-kopi faerdig."
        }
        default {
            Write-Error "Ukendt CloudMethod: '$CloudMethod' (brug 'rclone' eller 'copy')"
        }
    }
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
