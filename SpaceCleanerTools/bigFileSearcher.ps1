
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

# --- MENÚ DE SELECCIÓN ---
Clear-Host
Write-Host "=== GENERADOR DE REPORTES DE ARCHIVOS GRANDES ===" -ForegroundColor Cyan
Write-Host "1. Seleccionar una carpeta especifica (ej. solo Downloads)"
Write-Host "2. Procesar TODAS las carpetas (Desktop, Documents, Downloads, etc.)"
Write-Host "3. Buscar en TODO un disco (Top 20 global del disco)"
Write-Host ""
$opcion = Read-Host "Ingrese el numero de opcion (1, 2 o 3)"

$foldersToProcess = @()
$isFullDriveScan = $false
$searchRoot = $null

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
            $searchRoot = $selectedDrive.Root
            Write-Host "Seleccionado: $searchRoot" -ForegroundColor Green
        } else { Write-Host "Seleccion invalida."; return }
    } catch { Write-Host "Entrada invalida."; return }
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

# Función modular de búsqueda con optimización O(N)
function Find-HeavyFiles {
    param (
        [string]$Path,
        [string]$ActivityName,
        [scriptblock]$CustomFilter,
        [int]$TopCount = 20,
        [System.Diagnostics.Stopwatch]$Timer
    )
    
    # Lista para mantener solo los Top K archivos.
    # Se mantendrá ordenada ascendentemente por tamaño (índice 0 = el más pequeño de los grandes).
    $topFiles = New-Object System.Collections.Generic.List[PSObject]
    $counter = 0
    
    if (Test-Path $Path) {
        Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $counter++
            if ($counter % 1000 -eq 0) {
                $timeStr = if ($Timer) { " | Tiempo: $($Timer.Elapsed.ToString('mm\:ss'))" } else { "" }
                Write-Host -NoNewline "`r[$ActivityName] Archivos: $counter$timeStr   "
            }

            $item = $_
            
            # Filtros Globales (Sistema y Extensiones)
            if ($item.Attributes -band [IO.FileAttributes]::System) { return }
            $ext = ($item.Extension).TrimStart('.').ToLower()
            if ($excludeExtensions -contains $ext) { return }

            # Filtro Personalizado
            if ($CustomFilter) {
                $shouldKeep = & $CustomFilter $item
                if (-not $shouldKeep) { return }
            }

            # --- ALGORITMO OPTIMIZADO (Min-Heap simulado) ---
            # Complejidad Espacial: O(K) donde K=20
            # Complejidad Temporal: O(N)
            
            try {
                if ($topFiles.Count -lt $TopCount) {
                    $topFiles.Add($item)
                    if ($topFiles.Count -eq $TopCount) {
                        # Ordenar inicial para tener el menor en index 0
                        $sorted = $topFiles | Sort-Object Length
                        $topFiles.Clear()
                        $topFiles.AddRange([PSObject[]]$sorted)
                    }
                }
                else {
                    # Si el archivo actual es más grande que el más pequeño de nuestro Top 20
                    if ($item.Length -gt $topFiles[0].Length) {
                        $topFiles[0] = $item
                        # Reordenar lista pequeña (muy rápido para 20 items)
                        $sorted = $topFiles | Sort-Object Length
                        $topFiles.Clear()
                        $topFiles.AddRange([PSObject[]]$sorted)
                    }
                }
            } catch {
                # Ignorar errores puntuales en archivos problematicos
            }
        }
        # Limpiar linea al terminar esta carpeta
        Write-Host -NoNewline "`r[$ActivityName] Completado. ($counter archivos)          `n"
    }
    # Retornar ordenado descendente (Mayor a menor) para el reporte
    return $topFiles | Sort-Object Length -Descending
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

    $top20Files = Find-HeavyFiles -Path $searchRoot -ActivityName "Escaneando Disco Completo" -CustomFilter $driveFilter -Timer $scriptTimer
    
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

            $found = Find-HeavyFiles -Path $targetPath -ActivityName "Buscando en $folderType ($($_.Name))" -CustomFilter $userFolderFilter -Timer $scriptTimer
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
