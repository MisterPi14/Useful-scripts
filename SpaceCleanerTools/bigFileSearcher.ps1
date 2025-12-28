
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
$outputDir = Join-Path $PSScriptRoot "Top 20 mas grandes por carpeta"
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

# --- PROCESAMIENTO ---
if ($isFullDriveScan) {
    Write-Host "`nEscaneando todo el disco $searchRoot (esto puede tardar)..." -ForegroundColor Cyan
    $allFiles = New-Object System.Collections.Generic.List[PSObject]
    
    # Obtener todos los archivos recursivamente
    Get-ChildItem -Path $searchRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        $item = $_
        
        # Filtros basicos
        # if ($item.Attributes -band [IO.FileAttributes]::Hidden) { return }
        if ($item.Attributes -band [IO.FileAttributes]::System) { return }
        
        # Filtro de extensiones
        $ext = ($item.Extension).TrimStart('.').ToLower()
        if ($excludeExtensions -contains $ext) { return }
        
        # Filtro de carpetas de sistema (Windows)
        if ($item.FullName -match '\\Windows\\') { return }
        
        $allFiles.Add($item)
    }
    
    if ($allFiles.Count -gt 0) {
        $top20 = $allFiles | Sort-Object Length -Descending | Select-Object -First 20 `
            | Select-Object @{Name='FullName';Expression={$_.FullName}},
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
            
            if (Test-Path $targetPath) {
                try {
                    $items = Get-ChildItem -Path $targetPath -File -Recurse -ErrorAction SilentlyContinue
                    foreach ($item in $items) {
                        # Filtros
                        # if ($item.Attributes -band [IO.FileAttributes]::Hidden) { continue }
                        if ($item.Attributes -band [IO.FileAttributes]::System) { continue }
                        
                        $ext = ($item.Extension).TrimStart('.').ToLower()
                        if ($excludeExtensions -contains $ext) { continue }
                        
                        if ($item.FullName -match '\\AppData\\') { continue }

                        $filesOfType += $item
                    }
                } catch {
                    # Ignorar errores de acceso
                }
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

Write-Host "`nProceso finalizado." -ForegroundColor Cyan
