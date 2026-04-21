# Legacy — PowerShell-Skripte

Diese Dateien sind der ursprüngliche PowerShell-basierte Workflow und werden nicht mehr aktiv weiterentwickelt.

Die PWA (`../pwa/`) hat diesen Workflow vollständig ersetzt.

## Dateien

| Datei | Zweck |
|---|---|
| `ConvertFrom-PlantList.ps1` | Pflanzenliste aus CSV importieren |
| `ConvertTo-TreeCircle.ps1` | SVG-Baumkreis aus Pflanzendaten erzeugen |
| `Copy-ExamplePlantNames.ps1` | Beispiel-Pflanzennamen kopieren |
| `Import-PlantData.ps1` | Pflanzendaten importieren |
| `Test-PlantData.ps1` | Validierung der Pflanzendaten |
| `PermacultureTreeGuildsDesigner.psd1` | Modul-Manifest |
| `PermacultureTreeGuildsDesigner.psm1` | Haupt-Modul |
| `Assets/` | SVG-Vorlagen für Karten und Baumkreise |
| `Example/` | Beispiel-Pflanzenlisten (PlantNames.txt) |

## Migration zur PWA

Bestehende `.psd1`-Datensätze können als CSV in die PWA importiert werden.
Dazu die Pflanzendaten zunächst per PowerShell als CSV exportieren, dann in der PWA über „Import CSV" einlesen.
