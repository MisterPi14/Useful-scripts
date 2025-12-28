
# Busca el archivo de usuario más pesado en C:\Users, excluyendo archivos de configuración y sistema.
# Ejecutar en PowerShell con permisos estándar (no requiere admin), aunque con admin podrá leer más rutas.

# Carpetas típicas de contenido de usuario a inspeccionar
$userContentFolders = @('Desktop','Documents','Downloads','Pictures','Videos','Music')

# Extensiones a excluir por ser comúnmente de configuración/sistema o no útiles (sin el punto)
$excludeExtensions = @(
    'ini','cfg','conf','sys','dll','lnk','tmp','log','cache','db','manifest'
)

# Construir rutas de búsqueda bajo C:\Users para todos los perfiles
$baseUsersPath = 'C:\Users'

# Función para formatear tamaño
function Format-Size {
    param([long]$bytes)
    $units = "B","KB","MB","GB","TB"
    $i = 0
    $value = [double]$bytes
    while ($value -ge 1024 -and $i -lt ($units.Length - 1)) {
        $value = $value / 1024
        $i++
    }
    return ("{0:N2} {1}" -f $value, $units[$i])
}

function Select-Drive {
    $drives = Get-PSDrive -PSProvider FileSystem
    Write-Host "`nDiscos disponibles:"
    $d = 0
    foreach ($drive in $drives) {
        $d++
        Write-Host "[$d] $($drive.Name) ($($drive.Root))"
    }
    $drvIdx = Read-Host "Seleccione el disco"
    try {
        $selectedDrive = $drives[[int]$drvIdx - 1]
        if ($selectedDrive) {
            Write-Host "Seleccionado: $($selectedDrive.Root)" -ForegroundColor Green
            return $selectedDrive.Root
        } else { Write-Host "Seleccion invalida."; return $null }
    } catch { Write-Host "Entrada invalida."; return $null }
}

function Get-FuzzyRegex {
    param([string]$InputString)
    # Escapar caracteres especiales de regex
    $safeInput = [regex]::Escape($InputString)
    
    # 1. Match exacto (case insensitive por defecto en PS)
    $patterns = @($safeInput)
    
    # 2. Sustitución de un caracter (rekoj -> r.koj, re.oj, etc)
    for ($i = 0; $i -lt $safeInput.Length; $i++) {
        $prefix = if ($i -gt 0) { $safeInput.Substring(0, $i) } else { "" }
        $suffix = if ($i -lt $safeInput.Length - 1) { $safeInput.Substring($i + 1) } else { "" }
        $patterns += "${prefix}.${suffix}"
    }
    
    # Unir con OR
    return ($patterns -join "|")
}

# Función modular de búsqueda con optimización O(N)
function Find-Files {
    param (
        [string]$Path,
        [string]$ActivityName,
        [scriptblock]$CustomFilter,
        [string]$Mode = 'Heavy', # 'Heavy' or 'Name'
        [string]$NameRegex = $null,
        [int]$TopCount = 20,
        [System.Diagnostics.Stopwatch]$Timer
    )
    
    # Lista para resultados
    $results = New-Object System.Collections.Generic.List[PSObject]
    $counter = 0
    
    if (Test-Path $Path) {
        Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $counter++
            if ($counter % 1000 -eq 0) {
                $timeStr = if ($Timer) { " | Tiempo: $($Timer.Elapsed.ToString('mm\:ss'))" } else { "" }
                Write-Host -NoNewline "`r[$ActivityName] Archivos: $counter$timeStr   "
            }

            $item = $_
            
            # Filtros Globales (Sistema)
            if ($item.Attributes -band [IO.FileAttributes]::System) { return }
            
            # Filtros específicos por modo
            if ($Mode -eq 'Heavy') {
                $ext = ($item.Extension).TrimStart('.').ToLower()
                # $excludeExtensions debe estar definido en el scope superior
                if ($excludeExtensions -contains $ext) { return }
            }

            # Filtro Personalizado
            if ($CustomFilter) {
                $shouldKeep = & $CustomFilter $item
                if (-not $shouldKeep) { return }
            }

            # --- LÓGICA SEGÚN MODO ---
            if ($Mode -eq 'Heavy') {
                # ALGORITMO OPTIMIZADO (Min-Heap simulado)
                try {
                    if ($results.Count -lt $TopCount) {
                        $results.Add($item)
                        if ($results.Count -eq $TopCount) {
                            $sorted = $results | Sort-Object Length
                            $results.Clear()
                            $results.AddRange([PSObject[]]$sorted)
                        }
                    }
                    else {
                        if ($item.Length -gt $results[0].Length) {
                            $results[0] = $item
                            $sorted = $results | Sort-Object Length
                            $results.Clear()
                            $results.AddRange([PSObject[]]$sorted)
                        }
                    }
                } catch {}
            }
            elseif ($Mode -eq 'Name') {
                if ($item.Name -match $NameRegex) {
                    $results.Add($item)
                }
            }
        }
        Write-Host -NoNewline "`r[$ActivityName] Completado. ($counter archivos)          `n"
    }
    
    if ($Mode -eq 'Heavy') {
        return $results | Sort-Object Length -Descending
    } else {
        return $results # Return all matches found
    }
}

# --- MENÚ DE SELECCIÓN ---
Clear-Host
Write-Host "=== GENERADOR DE REPORTES DE ARCHIVOS GRANDES ===" -ForegroundColor Cyan
Write-Host "1. Seleccionar una carpeta especifica (ej. solo Downloads)"
Write-Host "2. Procesar TODAS las carpetas (Desktop, Documents, Downloads, etc.)"
Write-Host "3. Buscar en TODO un disco (Top 20 global del disco)"
Write-Host "4. Buscar archivo por nombre en TODO un disco (Busqueda difusa/regex)"
Write-Host ""
$opcion = Read-Host "Ingrese el numero de opcion (1, 2, 3 o 4)"

$foldersToProcess = @()
$isFullDriveScan = $false
$isNameSearch = $false
$searchRoot = $null
$searchName = $null
$fuzzyRegex = $null

if ($opcion -eq '1') {
    Write-Host "`nCarpetas disponibles:"
    for ($i=0; $i -lt $userContentFolders.Count; $i++) {
        Write-Host ("[{0}] {1}" -f ($i+1), $userContentFolders[$i])
    }
    $idx = Read-Host "Ingrese el numero de la carpeta a procesar"
    try {
        $selected = $userContentFolders[[int]$idx - 1]
        if ($selected) { 
            $foldersToProcess += $selected 
            Write-Host "Seleccionado: $selected" -ForegroundColor Green
        }
        else { Write-Host "Seleccion invalida."; return }
    } catch { Write-Host "Entrada invalida."; return }
} elseif ($opcion -eq '2') {
    $foldersToProcess = $userContentFolders
    Write-Host "Se procesaran todas las carpetas." -ForegroundColor Green
} elseif ($opcion -eq '3') {
    $isFullDriveScan = $true
    $searchRoot = Select-Drive
    if (-not $searchRoot) { return }
} elseif ($opcion -eq '4') {
    $isFullDriveScan = $true
    $isNameSearch = $true
    
    $searchRoot = Select-Drive
    if (-not $searchRoot) { return }
    
    $searchName = Read-Host "Ingrese el nombre del archivo a buscar"
    if ([string]::IsNullOrWhiteSpace($searchName)) {
        Write-Host "Nombre invalido." -ForegroundColor Red
        return
    }
    $fuzzyRegex = Get-FuzzyRegex -InputString $searchName
    Write-Host "Patron de busqueda generado: $fuzzyRegex" -ForegroundColor Gray
} else {
    Write-Host "Opcion no valida." -ForegroundColor Red
    return
}

# Crear carpeta de salida
$outputDir = Join-Path $PSScriptRoot "Top 20 archivos"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "`nCarpeta de salida creada: $outputDir" -ForegroundColor Yellow
} else {
    Write-Host "`nLos archivos se guardaran en: $outputDir" -ForegroundColor Yellow
}

# --- PROCESAMIENTO ---
$scriptTimer = [System.Diagnostics.Stopwatch]::StartNew()

if ($isFullDriveScan) {
    Write-Host "`nEscaneando todo el disco $searchRoot (esto puede tardar)..." -ForegroundColor Cyan
    
    # Filtro específico para escaneo de disco completo
    $driveFilter = {
        param($f)
        # Excluir carpeta Windows
        if ($f.FullName -match '\\Windows\\') { return $false }
        return $true
    }

    if ($isNameSearch) {
        $foundFiles = Find-Files -Path $searchRoot -ActivityName "Buscando '$searchName'" -CustomFilter $driveFilter -Timer $scriptTimer -Mode 'Name' -NameRegex $fuzzyRegex
        
        if ($foundFiles.Count -gt 0) {
            $results = $foundFiles | Select-Object @{Name='FullName';Expression={$_.FullName}},
                               @{Name='SizeBytes';Expression={$_.Length}},
                               @{Name='SizeHuman';Expression={ Format-Size $_.Length }},
                               @{Name='LastWriteTime';Expression={$_.LastWriteTime}}
            
            $driveLetter = $searchRoot.Replace(":\","").Replace("\","")
            # Sanitize search name for filename
            $safeSearchName = $searchName -replace '[\\/:*?"<>|]', '_'
            $csvName = "Search_${safeSearchName}_Drive_${driveLetter}.csv"
            $csvPath = Join-Path $outputDir $csvName
            $results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host " -> [OK] Reporte generado: $csvName ($($foundFiles.Count) archivos encontrados)" -ForegroundColor Green
        } else {
            Write-Host " -> [INFO] No se encontraron archivos coincidentes en $searchRoot" -ForegroundColor Gray
        }
    } else {
        $top20Files = Find-Files -Path $searchRoot -ActivityName "Escaneando Disco Completo" -CustomFilter $driveFilter -Timer $scriptTimer -Mode 'Heavy'
        
        if ($top20Files.Count -gt 0) {
            $top20 = $top20Files | Select-Object @{Name='FullName';Expression={$_.FullName}},
                               @{Name='SizeBytes';Expression={$_.Length}},
                               @{Name='SizeHuman';Expression={ Format-Size $_.Length }},
                               @{Name='LastWriteTime';Expression={$_.LastWriteTime}}
            
            $driveLetter = $searchRoot.Replace(":\","").Replace("\","")
            $csvName = "Top20_Drive_${driveLetter}_Global.csv"
            $csvPath = Join-Path $outputDir $csvName
            $top20 | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host " -> [OK] Reporte generado: $csvName" -ForegroundColor Green
        } else {
            Write-Host " -> [INFO] No se encontraron archivos validos en $searchRoot" -ForegroundColor Gray
        }
    }

} else {
    foreach ($folderType in $foldersToProcess) {
        Write-Host "`nBuscando en carpetas tipo '$folderType' de todos los usuarios..." -ForegroundColor Cyan
        $filesOfType = @()

        # Recorrer usuarios
        Get-ChildItem -Path $baseUsersPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $userDir = $_.FullName
            # Ignorar carpetas de sistema
            if ($_.Name -in @('Public','Default','Default User','All Users')) { return }

            $targetPath = Join-Path $userDir $folderType
            
            # Filtro específico para carpetas de usuario
            $userFolderFilter = {
                param($f)
                if ($f.FullName -match '\\AppData\\') { return $false }
                return $true
            }

            $found = Find-Files -Path $targetPath -ActivityName "Buscando en $folderType ($($_.Name))" -CustomFilter $userFolderFilter -Timer $scriptTimer -Mode 'Heavy'
            if ($found) {
                $filesOfType += $found
            }
        }

        # Generar CSV si hay archivos
        if ($filesOfType.Count -gt 0) {
            $top20 = $filesOfType | Sort-Object Length -Descending | Select-Object -First 20 `
                | Select-Object @{Name='FullName';Expression={$_.FullName}},
                               @{Name='SizeBytes';Expression={$_.Length}},
                               @{Name='SizeHuman';Expression={ Format-Size $_.Length }},
                               @{Name='LastWriteTime';Expression={$_.LastWriteTime}}
            
            $csvName = "Top20_$folderType.csv"
            $csvPath = Join-Path $outputDir $csvName
            $top20 | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host " -> [OK] Reporte generado: $csvName" -ForegroundColor Green
        } else {
            Write-Host " -> [INFO] No se encontraron archivos validos para $folderType" -ForegroundColor Gray
        }
    }
}

$scriptTimer.Stop()
Write-Host ("`nTiempo total de ejecucion: {0:hh}:{0:mm}:{0:ss}.{0:fff}" -f $scriptTimer.Elapsed) -ForegroundColor DarkCyan

Write-Host "`nProceso finalizado." -ForegroundColor Cyan
