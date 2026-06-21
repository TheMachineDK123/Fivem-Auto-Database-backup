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
