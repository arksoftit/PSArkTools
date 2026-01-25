param(
    [string]$Computer = $env:COMPUTERNAME,
    [switch]$Quick,
    [switch]$Report,
    [string]$ReportPath,
    [string]$LogPath
)

# Directorio donde está SoporteTool.ps1
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent

# Rutas predeterminadas (usando carpetas existentes)
if (-not $ReportPath) { $ReportPath = "$scriptDir\Reportes" }
if (-not $LogPath)    { $LogPath     = "$scriptDir\Logs" }

# Crear carpetas si no existen (por seguridad)
if (!(Test-Path $ReportPath)) { New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null }
if (!(Test-Path $LogPath))    { New-Item -Path $LogPath    -ItemType Directory -Force | Out-Null }
# Importar funciones auxiliares
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
. "$scriptDir\Scripts\FixComunes.ps1"

# Función auxiliar para obtener info del sistema
function Get-SystemSummary {
    $info = Get-ComputerInfo -Property WindowsProductName, WindowsVersion, OsArchitecture, CsName, CsTotalPhysicalMemory
    return @{
        Nombre = $info.CsName
        OS = "$($info.WindowsProductName) $($info.WindowsVersion)"
        Arquitectura = $info.OsArchitecture
        MemoriaGB = [math]::Round($info.CsTotalPhysicalMemory / 1GB, 1)
    }
}

# Modo rápido
if ($Quick) {
    Write-Host "=== SISTEMA ===" -ForegroundColor Cyan
    $sys = Get-SystemSummary
    Write-Host "Nombre: $($sys.Nombre)"
    Write-Host "OS: $($sys.OS)"
    Write-Host "Arquitectura: $($sys.Arquitectura)"
    Write-Host "Memoria: $($sys.MemoriaGB) GB"

    Write-Host "`n=== RED ===" -ForegroundColor Green
    Get-NetIPConfiguration | Format-Table InterfaceAlias, IPv4Address, IPv4DefaultGateway

    Write-Host "`n=== DISCOS ===" -ForegroundColor Yellow
    Get-Volume | Where-Object DriveLetter | ForEach-Object {
        $freeGB = [math]::Round($_.SizeRemaining/1GB, 1)
        $totalGB = [math]::Round($_.Size/1GB, 1)
        Write-Host "$($_.DriveLetter): $freeGB GB libre de $totalGB GB"
    }
    exit
}

# Modo reporte
if ($Report) {
    $reportFile = "$ReportPath\Reporte_$Computer_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    
    # Sistema
    $sys = Get-SystemSummary
    "=== REPORTE TECNICO ===" | Out-File $reportFile
    "Fecha: $(Get-Date)" | Out-File $reportFile -Append
    "Equipo: $Computer" | Out-File $reportFile -Append
    "Tecnico: $env:USERNAME" | Out-File $reportFile -Append
    "`n=== SISTEMA ===" | Out-File $reportFile -Append
    "Nombre: $($sys.Nombre)" | Out-File $reportFile -Append
    "OS: $($sys.OS)" | Out-File $reportFile -Append
    "Arquitectura: $($sys.Arquitectura)" | Out-File $reportFile -Append
    "Memoria: $($sys.MemoriaGB) GB" | Out-File $reportFile -Append

    "`n=== RED ===" | Out-File $reportFile -Append
    ipconfig /all | Out-File $reportFile -Append

    "`n=== DISCOS ===" | Out-File $reportFile -Append
    Get-Volume | Where-Object DriveLetter | ForEach-Object {
        $freeGB = [math]::Round($_.SizeRemaining/1GB, 1)
        $totalGB = [math]::Round($_.Size/1GB, 1)
        "$($_.DriveLetter): $freeGB GB libre de $totalGB GB" | Out-File $reportFile -Append
    }

    Write-Host "Reporte guardado: $reportFile" -ForegroundColor Green
    exit
}

# Modo interactivo
do {
    Clear-Host
    Write-Host "=== HERRAMIENTA DE SOPORTE ===" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "=== PSARKTOOLS ===" -ForegroundColor Yellow -BackgroundColor DarkBlue
    Write-Host "=== JUAN ERNESTO PAEZ ===" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "1. Informacion del Sistema"
    Write-Host "2. Configuracion de Red"
    Write-Host "3. Estado de Discos"
    Write-Host "4. Usuarios y Sesiones"
    Write-Host "5. Test de Conectividad"
    Write-Host "6. Generar Reporte Completo"
    Write-Host "7. Modo Rapido (Consola)"
    Write-Host "8. Aplicar Reparaciones Comunes"
    Write-Host "0. Salir"
    $opcion = Read-Host "`nSeleccione opcion"
    switch ($opcion) {
        '1' {
            Write-Host "`n=== INFORMACION DEL SISTEMA ===" -ForegroundColor Cyan
            Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsArchitecture, CsTotalPhysicalMemory | Format-List
            pause
        }
        '2' {
            Write-Host "`n=== CONFIGURACION DE RED ===" -ForegroundColor Green
            Get-NetIPConfiguration | Format-Table InterfaceAlias, IPv4Address, IPv4DefaultGateway, DNSServer
            pause
        }
        '3' {
            Write-Host "`n=== ESTADO DE DISCOS ===" -ForegroundColor Yellow
            Get-Volume | Where-Object DriveLetter | Format-Table DriveLetter, FileSystemLabel,
                @{Name="TotalGB";Expression={[math]::Round($_.Size/1GB,1)}},
                @{Name="LibreGB";Expression={[math]::Round($_.SizeRemaining/1GB,1)}},
                @{Name="% Libre";Expression={[math]::Round(($_.SizeRemaining/$_.Size)*100,1)}}
            pause
        }
        '4' {
            Write-Host "`n=== USUARIOS Y SESIONES ===" -ForegroundColor Magenta

            # Sesiones activas
            Write-Host "`n[👤 Sesiones activas]" -ForegroundColor Green
            try {
                $quserOutput = & quser 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $quserOutput | Out-Host
                } else {
                    Write-Host "  No hay sesiones interactivas activas." -ForegroundColor Gray
                }
            } catch {
                Write-Host "  ❌ No se pudo obtener información de sesiones." -ForegroundColor Yellow
            }

            # Usuarios locales
            Write-Host "`n[👥 Usuarios locales]" -ForegroundColor Yellow
            Get-LocalUser | Format-Table Name, Enabled, LastLogon, Description -AutoSize

            # Grupo de administradores
            Write-Host "`n[🛡️ Grupo de Administradores]" -ForegroundColor Cyan
            try {
                $adminGroup = (Get-LocalGroup | Where-Object { $_.SID -like "*-544" }).Name
                if ($adminGroup) {
                    Get-LocalGroupMember -Name $adminGroup -ErrorAction Stop |
                        Format-Table Name, PrincipalSource -AutoSize
                } else {
                    Write-Host "  ❌ No se encontró el grupo de administradores." -ForegroundColor Red
                }
            } catch {
                Write-Host "  ⚠️ No se pudo listar miembros del grupo de administradores." -ForegroundColor Yellow
            }

            pause
}
        '5' {
            Write-Host "`n=== TEST DE CONECTIVIDAD ===" -ForegroundColor Cyan
            $servers = @("8.8.8.8", "google.com", $env:USERDOMAIN)
            foreach ($server in $servers) {
                $result = Test-Connection $server -Count 1 -Quiet -ErrorAction SilentlyContinue
                $status = if ($result) { "✅" } else { "❌" }
                Write-Host "$status $server" -ForegroundColor $(if($result){"Green"}else{"Red"})
            }
            pause
        }
        '6' {
            & $MyInvocation.MyCommand.Path -Report -Computer $Computer -ReportPath $ReportPath -LogPath $LogPath
            pause
        }
        '7' {
            & $MyInvocation.MyCommand.Path -Quick
            pause
        }
        '8' {
            Write-Host "`n=== APLICANDO REPARACIONES COMUNES ===" -ForegroundColor White -BackgroundColor DarkRed
            Invoke-ReparacionesComunes
            pause
        }
    }   
} while ($opcion -ne '0')