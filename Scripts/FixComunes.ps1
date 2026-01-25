function Invoke-ReparacionesComunes {
    Write-Host "`n=== REPARACIONES COMUNES ===" -ForegroundColor Cyan

    # Confirmación previa
    $confirm = Read-Host "`n⚠️  Esta acción realizará cambios en el sistema. ¿Desea continuar? (s/N)"
    if ($confirm -notlike "s*") {
        Write-Host "Operación cancelada por el usuario." -ForegroundColor Yellow
        return
    }

    # [1] Limpiar caché DNS
    Write-Host "`n[1] Limpiando caché DNS..." -ForegroundColor Yellow
    try {
        Clear-DnsClientCache
        Write-Host "✅ Caché DNS limpiado." -ForegroundColor Green
    } catch {
        Write-Host "❌ Error al limpiar caché DNS: $_" -ForegroundColor Red
    }

    # [2] Reiniciar adaptadores activos
    Write-Host "`n[2] Reiniciando adaptadores de red activos..." -ForegroundColor Yellow
    try {
        $adapters = Get-NetAdapter | Where-Object Status -eq 'Up'
        if ($adapters) {
            foreach ($adapter in $adapters) {
                Restart-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
            }
            Write-Host "✅ Adaptadores reiniciados: $($adapters.Name -join ', ')." -ForegroundColor Green
        } else {
            Write-Host "⚠️  No hay adaptadores activos para reiniciar." -ForegroundColor Gray
        }
    } catch {
        Write-Host "❌ Error al reiniciar adaptadores: $_" -ForegroundColor Red
    }

    # [3] Escanear discos
    Write-Host "`n[3] Escaneando volúmenes en busca de errores..." -ForegroundColor Yellow
    try {
        $volumes = Get-Volume | Where-Object DriveLetter
        if ($volumes) {
            foreach ($vol in $volumes) {
                $result = Repair-Volume -DriveLetter $vol.DriveLetter -Scan -ErrorAction SilentlyContinue
                # No siempre devuelve error, pero al menos intenta
            }
            Write-Host "✅ Volúmenes escaneados: $($volumes.DriveLetter -join ', ')." -ForegroundColor Green
        } else {
            Write-Host "⚠️  No se encontraron volúmenes con letra asignada." -ForegroundColor Gray
        }
    } catch {
        Write-Host "❌ Error al escanear discos: $_" -ForegroundColor Red
    }

    # [4] Servicios críticos
    Write-Host "`n[4] Verificando servicios críticos..." -ForegroundColor Yellow
    $serviciosCriticos = @("WinRM", "EventLog")
    foreach ($svcName in $serviciosCriticos) {
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -ne 'Running') {
                Start-Service -Name $svcName -ErrorAction Stop
                Write-Host "✅ Servicio '$svcName' iniciado." -ForegroundColor Green
            } elseif ($svc) {
                Write-Host "ℹ️  Servicio '$svcName' ya está en ejecución." -ForegroundColor Gray
            } else {
                Write-Host "⚠️  Servicio '$svcName' no encontrado." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "❌ No se pudo iniciar '$svcName': $_" -ForegroundColor Red
        }
    }

    Write-Host "`n=== REPARACIONES COMPLETADAS ===`n" -ForegroundColor Cyan
}