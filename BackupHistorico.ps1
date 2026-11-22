# BackupHistorico.ps1
param(
    [Parameter(Mandatory=$true)]
    [string[]]$CarpetasOrigen,      # Rutas de carpetas a respaldar (array)
    [Parameter(Mandatory=$true)]
    [string]$DestinoDropbox,        # Carpeta destino en Dropbox
    [string]$NombreBase = "Respaldo" # Nombre base del archivo
)

# Validar existencia de carpetas origen
foreach ($carpeta in $CarpetasOrigen) {
    if (-not (Test-Path $carpeta)) {
        Write-Error "❌ Carpeta no encontrada: $carpeta"
        exit 1
    }
}

# Crear estructura de directorios si no existe
if (-not (Test-Path $DestinoDropbox)) {
    New-Item -Path $DestinoDropbox -ItemType Directory -Force | Out-Null
}

# Generar nombre con marca de tiempo (evita sobrescrituras)
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$archivoZip = Join-Path $DestinoDropbox "${NombreBase}_${timestamp}.zip"

# Crear estructura temporal para incluir nombres de carpetas en el ZIP
$tempBase = Join-Path ([System.IO.Path]::GetTempPath()) "backup_$timestamp"
New-Item -Path $tempBase -ItemType Directory -Force | Out-Null

try {
    # Copiar cada carpeta al directorio temporal manteniendo su nombre
    foreach ($carpeta in $CarpetasOrigen) {
        $nombreCarpeta = Split-Path $carpeta -Leaf
        $destinoTemp = Join-Path $tempBase $nombreCarpeta
        Copy-Item -Path $carpeta -Destination $destinoTemp -Recurse -Force
    }

    # Comprimir (PowerShell 5.0+ nativo)
    Compress-Archive -Path "$tempBase\*" -DestinationPath $archivoZip -CompressionLevel Optimal

    Write-Host "✅ Respaldo creado: $archivoZip" -ForegroundColor Green
    Write-Host "📊 Tamaño: $((Get-Item $archivoZip).Length / 1MB -as [int]) MB" -ForegroundColor Cyan

    # Opcional: Limpiar respaldos antiguos (ej: mantener últimos 7)
    $respaldos = Get-ChildItem -Path $DestinoDropbox -Filter "${NombreBase}_*.zip" | Sort-Object CreationTime -Descending
    if ($respaldos.Count -gt 7) {
        $respaldos[7..($respaldos.Count-1)] | ForEach-Object {
            Remove-Item $_.FullName -Force
            Write-Host "🧹 Eliminado histórico antiguo: $($_.Name)" -ForegroundColor Yellow
        }
    }
}
finally {
    # Limpiar directorio temporal
    if (Test-Path $tempBase) { Remove-Item $tempBase -Recurse -Force }
}