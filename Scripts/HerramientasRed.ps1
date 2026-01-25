param(
    [string]$Target,
    [int[]]$Puertos = @(80, 443, 3389, 21, 22, 25)
)

Write-Host "=== HERRAMIENTAS DE RED ===" -ForegroundColor Cyan

# Modo: Escaneo de host remoto
if ($Target) {
    # Validación de destino
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($Target)
        if ($resolved.Count -eq 0) { throw "Sin direcciones resueltas." }
        Write-Host "`n✅ Destino validado: $Target → $($resolved[0].IPAddressToString)" -ForegroundColor Green
    } catch {
        Write-Host "❌ Error: '$Target' no es una IP válida ni un nombre resoluble." -ForegroundColor Red
        exit 1
    }

    # Escaneo de puertos
    Write-Host "`n[🔍 Escaneando puertos: $($Puertos -join ', ')]" -ForegroundColor Yellow
    foreach ($puerto in $Puertos) {
        try {
            $resultado = Test-NetConnection -ComputerName $Target -Port $puerto -WarningAction SilentlyContinue -TimeoutSec 2
            $estado = if ($resultado.TcpTestSucceeded) { "✅ ABIERTO" } else { "❌ CERRADO" }
            Write-Host "Puerto $puerto : $estado"
        } catch {
            Write-Host "Puerto $puerto : ❌ ERROR (timeout o inaccesible)"
        }
    }

    # Traceroute (solo si hay conectividad básica)
    Write-Host "`n[🗺️ Traceroute]" -ForegroundColor Magenta
    try {
        $trace = Test-NetConnection -ComputerName $Target -TraceRoute -ErrorAction Stop -WarningAction SilentlyContinue
        if ($trace.TraceRoute) {
            $trace.TraceRoute | ForEach-Object { "$($_.Hop): $($_.IPAddress)" }
        } else {
            Write-Host "  Sin ruta de trazado disponible."
        }
    } catch {
        Write-Host "  ❌ No se pudo realizar traceroute."
    }
}
# Modo: Información local (sin Target)
else {
    Write-Host "`n[🔗 Conexiones TCP establecidas]" -ForegroundColor Green
    Get-NetTCPConnection -State Established | ForEach-Object {
        $procName = try {
            (Get-Process -Id $_.OwningProcess -ErrorAction Stop).ProcessName
        } catch {
            "Desconocido"
        }
        [PSCustomObject]@{
            LocalAddress  = $_.LocalAddress
            LocalPort     = $_.LocalPort
            RemoteAddress = $_.RemoteAddress
            RemotePort    = $_.RemotePort
            ProcessName   = $procName
        }
    } | Format-Table -AutoSize

    Write-Host "`n[📡 Adaptadores de red]" -ForegroundColor Magenta
    Get-NetAdapter | Where-Object Status -eq 'Up' | Format-Table Name, InterfaceDescription, LinkSpeed, MacAddress
}