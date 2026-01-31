param(
    [string]$Computer = $env:COMPUTERNAME,
    [switch]$Quick,
    [switch]$Report,
    [string]$ReportPath,
    [string]$LogPath
)
# ==================================================================
# VERIFICACIÓN DE VERSIÓN DE POWERSHELL (requerida para cmdlets usados)
# ==================================================================
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
    Write-Host "❌ Requisito no cumplido: Se necesita PowerShell 5.1 o superior." -ForegroundColor Red
    Write-Host "   Versión actual: $psVersion" -ForegroundColor Yellow
    Write-Host "   Descarga: https://aka.ms/powershell-release?tag=stable" -ForegroundColor Cyan
    exit 1
}
# ==================================================================

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

function Get-RegionalSettings {
    Write-Host "`n=== CONFIGURACIÓN REGIONAL (INTERNACIONAL) ===" -ForegroundColor Cyan
    try {
        $key = "HKCU:\Control Panel\International"
        if (-not (Test-Path $key)) {
            Write-Host "❌ Clave de registro no encontrada." -ForegroundColor Red
            return
        }

        $props = @{
            sDecimal         = "Separador Decimal"
            sThousand        = "Separador de Miles"
            sMonDecimalSep   = "Separador Decimal (Moneda)"
            sMonThousandSep  = "Separador de Miles (Moneda)"
            sShortDate       = "Formato Fecha Corta"
            sTimeFormat      = "Formato de Hora"
            sCurrency        = "Símbolo de Moneda"
        }

        foreach ($prop in $props.Keys) {
            $value = (Get-ItemProperty -Path $key -Name $prop -ErrorAction SilentlyContinue).$prop
            if ($null -eq $value) { $value = "No definido" }
            Write-Host "$($props[$prop]) ($prop): $value"
        }
    } catch {
        Write-Host "❌ Error al leer configuración regional: $_" -ForegroundColor Red
    }
}

function Set-RegionalSettings {
    Write-Host "`n[🔧 Aplicando configuración regional estándar...]" -ForegroundColor Yellow
    $key = "HKCU:\Control Panel\International"
    
    try {
        # Crear la clave si no existe (poco probable, pero por seguridad)
        if (-not (Test-Path $key)) {
            New-Item -Path $key -Force | Out-Null
        }

        Set-ItemProperty -Path $key -Name "sDecimal" -Value "."
        Set-ItemProperty -Path $key -Name "sThousand" -Value ","
        Set-ItemProperty -Path $key -Name "sMonDecimalSep" -Value "."
        Set-ItemProperty -Path $key -Name "sMonThousandSep" -Value ","
        Set-ItemProperty -Path $key -Name "sShortDate" -Value "dd/MM/yyyy"
        Set-ItemProperty -Path $key -Name "sTimeFormat" -Value "hh:mm:ss tt"
        Set-ItemProperty -Path $key -Name "sCurrency" -Value "Bs."

        Write-Host "✅ Configuración regional actualizada correctamente." -ForegroundColor Green
        Write-Host "⚠️  Los cambios se aplicarán en nuevas sesiones o tras reiniciar el Explorador." -ForegroundColor Gray
    } catch {
        Write-Host "❌ Error al modificar configuración regional: $_" -ForegroundColor Red
    }
}

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

function Get-FolderPermissions {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Host "❌ La ruta '$Path' no existe." -ForegroundColor Red
        return
    }

    Write-Host "`n=== PERMISOS ACTUALES DE: $Path ===" -ForegroundColor Cyan
    try {
        $acl = Get-Acl -Path $Path
        $acl.Access | Select-Object IdentityReference, FileSystemRights, AccessControlType, IsInherited |
            Format-Table -AutoSize
    } catch {
        Write-Host "❌ Error al leer permisos: $_" -ForegroundColor Red
    }
}

function Set-FolderPermissions {
    param(
        [string]$Path,
        [string]$Identity,      # Ej: "juanep", "Usuarios", "Administradores"
        [string]$Permission = "Modify",  # FullControl, ReadAndExecute, Modify, etc.
        [string]$AccessType = "Allow"    # Allow / Deny
    )

    if (-not (Test-Path $Path)) {
        Write-Host "❌ La ruta '$Path' no existe." -ForegroundColor Red
        return
    }

    try {
        $acl = Get-Acl -Path $Path
        $identityRef = New-Object System.Security.Principal.NTAccount($Identity)
        $permissionRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $identityRef, $Permission, "ContainerInherit,ObjectInherit", "None", $AccessType
        )
        $acl.SetAccessRule($permissionRule)
        Set-Acl -Path $Path -AclObject $acl

        Write-Host "✅ Permisos actualizados en '$Path' para '$Identity': $Permission ($AccessType)" -ForegroundColor Green
    } catch {
        Write-Host "❌ Error al modificar permisos: $_" -ForegroundColor Red
    }
}

function Get-USBDevices {
    Write-Host "`n=== DISPOSITIVOS USB CONECTADOS ===" -ForegroundColor Magenta
    try {
        $usbDevices = Get-PnpDevice | Where-Object {
            $_.Class -eq 'USB' -and $_.Status -eq 'OK' -and $_.Present
        }

        if ($usbDevices) {
            $usbDevices | Select-Object Name, Manufacturer, InstanceId |
                Format-Table -AutoSize
        } else {
            Write-Host "⚠️  No se encontraron dispositivos USB activos." -ForegroundColor Gray
        }
    } catch {
        Write-Host "❌ Error al consultar dispositivos USB: $_" -ForegroundColor Red
    }
}

function Get-SerialPortConfig {
    Write-Host "`n=== CONFIGURACIÓN DE PUERTOS SERIALES (COM) ===" -ForegroundColor Cyan
    try {
        # Ejecutar 'mode' y capturar toda la salida
        $modeOutput = & cmd /c "mode" 2>$null

        if ($null -eq $modeOutput) {
            Write-Host "⚠️  No se pudo ejecutar el comando 'mode'." -ForegroundColor Yellow
            return
        }

        # Bandera para saber si encontramos al menos un puerto COM
        $foundCom = $false

        # Procesar línea por línea
        for ($i = 0; $i -lt $modeOutput.Count; $i++) {
            $line = $modeOutput[$i]

            # Buscar líneas que comiencen con "Estado para dispositivo COM"
            if ($line -match "^Estado para dispositivo COM\d+:") {
                $foundCom = $true
                # Mostrar esta línea y las siguientes hasta la próxima sección o final
                Write-Host $line -ForegroundColor Green
                $i++  # Avanzar a la siguiente línea

                # Mostrar líneas de configuración (mientras tengan sangría o sean parte del bloque)
                while ($i -lt $modeOutput.Count -and 
                       ($modeOutput[$i] -match "^\s{4}[A-Z]" -or 
                        $modeOutput[$i] -match "^-{5,}")) {
                    Write-Host $modeOutput[$i]
                    $i++
                }
                $i--  # Compensar el incremento del bucle
            }
        }

        if (-not $foundCom) {
            Write-Host "⚠️  No se detectaron puertos seriales COM configurados." -ForegroundColor Gray
        }

    } catch {
        Write-Host "❌ Error al obtener configuración de puertos COM: $_" -ForegroundColor Red
    }   
}

function Get-AvailableComPorts {
    $ports = @()
    try {
        $serialKey = "HKLM:\HARDWARE\DEVICEMAP\SERIALCOMM"
        if (Test-Path $serialKey) {
            $props = Get-ItemProperty -Path $serialKey
            foreach ($prop in $props.PSObject.Properties) {
                if ($prop.Name -notlike "PS*") {
                    $ports += [PSCustomObject]@{
                        Device = $prop.Name
                        Port   = $prop.Value
                    }
                }
            }
        }
    } catch {}
    return $ports
}

function Test-SerialPortCommunication {
    Write-Host "`n=== PRUEBA DE COMUNICACIÓN SERIAL ===" -ForegroundColor Cyan

    # Obtener puertos COM disponibles
    $comPorts = Get-AvailableComPorts
    if (-not $comPorts) {
        Write-Host "❌ No se encontraron puertos COM." -ForegroundColor Red
        return
    }

    # Mostrar lista numerada
    Write-Host "`nPuertos COM disponibles:"
    for ($i = 0; $i -lt $comPorts.Count; $i++) {
        Write-Host "[$($i+1)] $($comPorts[$i].Port) ($($comPorts[$i].Device))"
    }

    # Seleccionar puerto
    $selection = Read-Host "`nSeleccione un puerto (1-$($comPorts.Count)) o '0' para cancelar"
    if ($selection -eq '0') { return }
    if (-not ($selection -ge 1 -and $selection -le $comPorts.Count)) {
        Write-Host "⚠️  Selección inválida." -ForegroundColor Yellow
        return
    }

    $selectedPort = $comPorts[$selection - 1].Port
    Write-Host "`nProbando comunicación con $selectedPort..." -ForegroundColor Green

    # Configuración típica para impresoras fiscales
    $baudRate = 9600
    $dataBits = 8
    $parity = "None"
    $stopBits = "One"

    try {
        # Crear y configurar el puerto
        $port = New-Object System.IO.Ports.SerialPort
        $port.PortName = $selectedPort
        $port.BaudRate = $baudRate
        $port.DataBits = $dataBits
        $port.Parity = $parity
        $port.StopBits = $stopBits
        $port.ReadTimeout = 2000  # 2 segundos
        $port.WriteTimeout = 2000

        # Abrir puerto
        $port.Open()
        if (-not $port.IsOpen) {
            throw "No se pudo abrir el puerto."
        }

        # Enviar comando de prueba (ej: reinicio suave de impresora térmica)
        # ESC @ = Inicialización estándar en impresoras ESC/POS
        $initCommand = [byte[]]@(27, 64)  # ESC @
        $port.Write($initCommand, 0, $initCommand.Length)
        Start-Sleep -Milliseconds 300

        # Intentar leer respuesta (muchas impresoras no responden, pero otras sí)
        $response = ""
        try {
            $response = $port.ReadLine()
        } catch {
            # Timeout es normal en impresoras sin eco
        }

        $port.Close()

        if ($response) {
            Write-Host "✅ Respuesta recibida: $response" -ForegroundColor Green
        } else {
            Write-Host "ℹ️  Comando enviado. Sin respuesta (normal en impresoras sin eco)." -ForegroundColor Gray
        }

        } catch {
            Write-Host ("❌ Error al comunicarse con {0}: {1}" -f $selectedPort, $_.Exception.Message) -ForegroundColor Red
            if ($port.IsOpen) { $port.Close() }
        }
}
function Get-TPMInfo {
    Write-Host "`n=== INFORMACIÓN DE TPM ===" -ForegroundColor Magenta
    if (Get-Command Get-Tpm -ErrorAction SilentlyContinue) {
        try {
            $tpm = Get-Tpm
            if ($tpm.TpmPresent) {
                Write-Host "✅ TPM presente: Sí"
                Write-Host "Versión: $($tpm.ManufacturerVersion)"
                Write-Host "Fabricante: $($tpm.ManufacturerIdTxt)"
                Write-Host "Estado: $(if($tpm.TpmReady){'Listo'}else{'No configurado'})"
            } else {
                Write-Host "❌ TPM no detectado."
                Write-Host "ℹ️  Puede estar desactivado en BIOS/UEFI o no soportado por el hardware."
            }
        } catch {
            Write-Host "❌ Error al consultar TPM: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️  Cmdlet 'Get-Tpm' no disponible (requiere Windows 8+)." -ForegroundColor Yellow
    }
}

function Get-MotherboardInfo {
    Write-Host "`n=== INFORMACIÓN DE LA PLACA BASE ===" -ForegroundColor Cyan
    try {
        $mb = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop
        Write-Host "Fabricante: $($mb.Manufacturer)"
        Write-Host "Modelo: $($mb.Product)"
        Write-Host "Versión: $($mb.Version)"
        Write-Host "Número de serie: $($mb.SerialNumber)"
    } catch {
        Write-Host "❌ No se pudo obtener información de la placa base." -ForegroundColor Red
    }
}

function Get-PCIDevicesForDrivers {
    Write-Host "`n=== DISPOSITIVOS PCI/PCIe (para búsqueda de drivers) ===" -ForegroundColor Cyan
    try {
        $pciDevices = Get-PnpDevice | Where-Object {
            $_.InstanceId -match '^PCI\\' -and $_.Status -eq 'OK'
        }

        if ($pciDevices) {
            foreach ($dev in $pciDevices) {
                # Extraer VEN y DEV del InstanceId
                $venDev = if ($dev.InstanceId -match 'VEN_([0-9A-F]{4})&DEV_([0-9A-F]{4})') {
                    "VEN_$($matches[1])&DEV_$($matches[2])"
                } else {
                    "No disponible"
                }

                Write-Host "Nombre: $($dev.Name)"
                Write-Host "Fabricante: $($dev.Manufacturer)"
                Write-Host "ID para drivers: $venDev"
                Write-Host "InstanceId: $($dev.InstanceId)"
                Write-Host ("-" * 50)
            }
        } else {
            Write-Host "⚠️  No se encontraron dispositivos PCI/PCIe activos." -ForegroundColor Gray
        }
    } catch {
        Write-Host "❌ Error al consultar dispositivos PCI: $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "=== PSARKTOOLS Ver. 0.1.4 ===" -ForegroundColor Yellow -BackgroundColor DarkBlue
    Write-Host "=== Copyright (c) 2025 JUAN ERNESTO PÁEZ MUJÍCA ===" -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host "1. Informacion del Sistema"
    Write-Host "2. Configuracion de Red"
    Write-Host "3. Estado de Discos"
    Write-Host "4. Usuarios y Sesiones"
    Write-Host "5. Test de Conectividad"
    Write-Host "6. Generar Reporte Completo"
    Write-Host "7. Modo Rapido (Consola)"
    Write-Host "8. Aplicar Reparaciones Comunes"
    Write-Host "9. Configuración Regional"
    Write-Host "10. Gestión de Permisos de Carpetas"
    Write-Host "11. Dispositivos USB Conectados"
    Write-Host "12. Configuración de Puertos COM (Impresoras Fiscales)"
    Write-Host "13. Prueba de Comunicación Serial (Impresoras Fiscales)"
    Write-Host "14. Información de TPM"
    Write-Host "15. Información de Placa Base"
    Write-Host "16. Detectar Hardware PCI/PCIe (para Drivers)"
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
        '9' {
            do {
                Clear-Host
                Write-Host "=== CONFIGURACIÓN REGIONAL ===" -ForegroundColor White -BackgroundColor DarkCyan
                Write-Host "1. Ver configuración actual"
                Write-Host "2. Aplicar configuración estándar"
                Write-Host "0. Volver al menú principal"
                $subOpcion = Read-Host "`nSeleccione opción"
                switch ($subOpcion) {
                    '1' { Get-RegionalSettings; pause }
                    '2' { Set-RegionalSettings; pause }
                }
            } while ($subOpcion -ne '0')
        }
        '10' {
        Write-Host "`n=== GESTIÓN DE PERMISOS ===" -ForegroundColor Yellow
        $folder = Read-Host "Ingrese la ruta de la carpeta (ej. C:\Datos)"
        if (-not (Test-Path $folder)) {
            Write-Host "⚠️  La carpeta no existe." -ForegroundColor Red
            pause
            continue
        }

        Write-Host "`n[1] Ver permisos actuales"
        Write-Host "[2] Asignar permisos a un usuario/grupo"
        $subopt = Read-Host "Seleccione opción"

        if ($subopt -eq '1') {
            Get-FolderPermissions -Path $folder
        }
        elseif ($subopt -eq '2') {
            $user = Read-Host "Usuario o grupo (ej. juanep, Usuarios, Administradores)"
            $perm = Read-Host "Permiso (Modify, FullControl, ReadAndExecute, etc.) [Enter = Modify]"
            if ($perm -eq "") { $perm = "Modify" }
            Set-FolderPermissions -Path $folder -Identity $user -Permission $perm
        }
        pause
        }
        '11' {
            Get-USBDevices
            pause
        }
        '12' {
            Get-SerialPortConfig
            pause
        }
        '13' {
            Test-SerialPortCommunication
            pause
        }
        '14' {
            Get-TPMInfo
            pause
        }
        '15' {
            Get-MotherboardInfo
            pause
        }
        '16' {
            Get-PCIDevicesForDrivers
            pause
        }
    }   
} while ($opcion -ne '0')