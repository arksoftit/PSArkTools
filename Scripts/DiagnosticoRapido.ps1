function Invoke-DiagnosticoRapido {
    Write-Host "`n=== DIAGNÓSTICO RÁPIDO DEL SISTEMA ===" -ForegroundColor White -BackgroundColor DarkCyan

    # --- Sistema ---
    Write-Host "`n[💻 Sistema]" -ForegroundColor Cyan
    $sys = Get-ComputerInfo -Property WindowsProductName, WindowsVersion, CsName
    Write-Host "Equipo: $($sys.CsName)"
    Write-Host "OS: $($sys.WindowsProductName) $($sys.WindowsVersion)"

    # --- Red (IP y DNS) ---
    Write-Host "`n[🌐 Red]" -ForegroundColor Green
    $ipConfig = Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq 'Up' }
    foreach ($iface in $ipConfig) {
        $ipv4 = $iface.IPv4Address.IPAddress
        $gateway = $iface.IPv4DefaultGateway.NextHop
        Write-Host "$($iface.InterfaceAlias): $ipv4 (GW: $gateway)"
    }

    Write-Host "`n[📡 DNS]" -ForegroundColor Yellow
    $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object ServerAddresses
    if ($dnsServers) {
        foreach ($dns in $dnsServers) {
            Write-Host "$($dns.InterfaceAlias): $($dns.ServerAddresses -join ', ')"
        }
    } else {
        Write-Host "No se encontraron servidores DNS configurados." -ForegroundColor Gray
    }

    # --- Discos ---
    Write-Host "`n[💾 Discos]" -ForegroundColor Magenta
    Get-Volume | Where-Object DriveLetter | ForEach-Object {
        $free = [math]::Round($_.SizeRemaining / 1GB)
        $total = [math]::Round($_.Size / 1GB)
        Write-Host "$($_.DriveLetter): $free GB libre de $total GB"
    }

    # --- Servicios automáticos detenidos ---
    Write-Host "`n[⚠️ Servicios automáticos detenidos]" -ForegroundColor Red
    $stoppedAutoServices = Get-Service -ErrorAction SilentlyContinue |
        Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' }

    if ($stoppedAutoServices) {
        $stoppedAutoServices | ForEach-Object {
            Write-Host "  ❌ $($_.Name) - $($_.DisplayName)"
        }
    } else {
        Write-Host "  ✅ Todos los servicios automáticos accesibles están en ejecución."
}

    # --- Firewall ---
    Write-Host "`n[🛡️ Firewall]" -ForegroundColor Blue
    $firewallProfiles = Get-NetFirewallProfile
    foreach ($fwProfile in $firewallProfiles) {
        $estado = if ($fwProfile.Enabled) { "✅ ACTIVADO" } else { "❌ DESACTIVADO" }
        Write-Host "  $($fwProfile.Name): $estado"
    }

    Write-Host "`n=== FIN DEL DIAGNÓSTICO ===`n" -ForegroundColor White -BackgroundColor DarkCyan
}

# Ejecutar automáticamente si se llama directamente (no se importa como módulo)
if ($MyInvocation.InvocationName -eq '.' -or $MyInvocation.Line -like "*&*") {
    # No auto-ejecutar si se está importando
} else {
    Invoke-DiagnosticoRapido
}