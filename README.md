---
title: Dokumentation
description: Oversigt over guides til database, backup og optimering af FiveM-serveren.
sidebar_label: Oversigt
sidebar_position: 0
---

# Dokumentation

Velkommen til dokumentationen for FiveM-serveren. Her finder du guides til opsætning, drift og optimering af serverens database.

## Indhold

| Guide | Beskrivelse |
| ----- | ----------- |
| [Migrering fra XAMPP til MariaDB](./migrering-xampp-til-mariadb.md) | Step-by-step: flyt databasen fra XAMPP til en standalone MariaDB-server. |
| [Optimering af database (MariaDB)](./optimering-af-database.md) | Sådan tuner du MariaDB, så alt kører så smooth som muligt. |
| [Backup-script (`backup.ps1`)](#backup-script) | Automatisk database-backup 2 gange dagligt. |

## Filer i denne mappe

| Fil | Formål |
| --- | ------ |
| `migrering-xampp-til-mariadb.md` | Migrerings-guide (Markdown). |
| `migrering-xampp-til-mariadb.html` | Samme guide som HTML — klar til import i GitBook. |
| `optimering-af-database.md` | Guide til database-optimering. |
| `my.ini.example` | Færdig MariaDB-konfiguration med optimerede settings. |
| `backup.ps1` | PowerShell-script til automatisk database-backup. |

---

## Backup-script

`backup.ps1` tager en komplet backup af databasen med `mysqldump`, gemmer den med dato i filnavnet og rydder automatisk gamle backups op.

### Konfiguration

Åbn `backup.ps1` og ret værdierne i **CONFIG**-blokken øverst:

| Variabel | Beskrivelse |
| -------- | ----------- |
| `$DumpExe` | Sti til `mysqldump.exe` (ret versionsnummeret). |
| `$DbUser` | Database-bruger (f.eks. `root`). |
| `$DbPassword` | Adgangskode til databasen. |
| `$DbName` | Navnet på databasen. |
| `$BackupDir` | Mappe hvor backups gemmes. |
| `$RetentionDays` | Antal dage backups beholdes (ældre slettes). |
| `$BackupTimes` | Tidspunkter for automatisk backup (24-timers format). |
| `$TaskName` | Navn på den planlagte opgave i Task Scheduler. |
| `$CompressBackup` | Pak backuppen som `.zip` før upload (`$true`/`$false`). |
| `$CloudEnabled` | Slå automatisk cloud-upload til/fra. |
| `$CloudMethod` | `"rclone"` (Google Drive m.fl.) eller `"copy"` (mappe/netværksdrev). |
| `$RcloneExe` | Sti til `rclone.exe`. |
| `$RcloneRemote` | Remote + mappe, f.eks. `gdrive:fivem-backups`. |
| `$CloudCopyDir` | Mål-mappe når `$CloudMethod = "copy"`. |

### Brug

**Tag en backup nu (manuelt):**

```powershell
powershell -ExecutionPolicy Bypass -File backup.ps1
```

**Slå automatisk backup til (2 gange dagligt):**

Kør som **administrator** én gang — opretter en planlagt opgave, der kører på tidspunkterne i `$BackupTimes`:

```powershell
powershell -ExecutionPolicy Bypass -File backup.ps1 -Install
```

**Fjern automatisk backup igen:**

```powershell
powershell -ExecutionPolicy Bypass -File backup.ps1 -Uninstall
```

### Bemærkninger

- Scriptet bruger `--single-transaction`, så spillere ikke fryser, mens backuppen tages.
- Backups skrives med `--result-file` (korrekt UTF-8), så utf8mb4/emojis ikke ødelægges.
- `-Install` kræver, at PowerShell køres som **administrator**.
- **Test gendannelse** af en backup mindst én gang, og opbevar gerne kopier et andet sted (off-site).

---

## Cloud-backup med rclone (Google Drive)

Scriptet kan automatisk uploade hver backup til skyen via [rclone](https://rclone.org/), som understøtter Google Drive, OneDrive, Dropbox, S3, FTP m.fl. Herunder vises opsætning til **Google Drive**.

### 1. Download rclone

- Hent **Windows AMD64**-zip fra <https://rclone.org/downloads/>.
- Udpak den, og noter stien til `rclone.exe`.
- Sæt `$RcloneExe` i `backup.ps1` til den fulde sti.

### 2. Opret en remote

Kør konfigurationen:

```powershell
rclone.exe config
```

Følg menuen:

| Spørgsmål | Svar |
| --------- | ---- |
| `n/s/q` | `n` (New remote) |
| `name` | `gdrive` (skal matche `$RcloneRemote`) |
| `Storage` | `drive` (Google Drive) |
| `client_id` / `client_secret` | tom (tryk Enter) |
| `scope` | `1` (Full access) |
| `service_account_file` | tom (tryk Enter) |
| `Edit advanced config` | `n` |
| `Use web browser to authenticate` | `y` |

### 3. Log ind i browseren

rclone åbner din browser — vælg din Google-konto og giv adgang. Når der står **"Success!"**, gå tilbage til PowerShell.

- `Configure this as a Shared Drive (Team Drive)?` → `n`
- `y/e/d` → `y`, derefter `q` for at afslutte.

### 4. Test forbindelsen

```powershell
rclone.exe lsd gdrive:
rclone.exe mkdir gdrive:fivem-backups
```

### 5. Aktivér i `backup.ps1`

```powershell
$CloudEnabled   = $true
$CloudMethod    = "rclone"
$RcloneRemote   = "gdrive:fivem-backups"
```

Kør en manuel backup for at teste — du skal se `Cloud-upload faerdig.` i outputtet.

:::warning Planlagt opgave og rclone-config
rclone gemmer sin config pr. Windows-bruger i `%APPDATA%\rclone\rclone.conf`. Hvis den planlagte opgave kører som en **anden bruger** (f.eks. SYSTEM), finder den ikke din config. Kør derfor opgaven som **din egen bruger**, eller peg på en fast config-fil med `--config`.
:::

---

## Import til GitBook

HTML-filerne i mappen kan importeres direkte i GitBook via **Import → HTML**. Markdown-filerne kan tilsvarende importeres eller synkroniseres via Git.
