# PSarktools

Conjunto de scripts en PowerShell para soporte técnico rápido en entornos Windows.

## Características
- Diagnóstico rápido del sistema, red y discos.
- Escaneo de puertos y conexiones activas.
- Reparaciones comunes (DNS, red, servicios).
- Gestión de usuarios y auditoría de administradores.
- Totalmente portable: funciona desde USB.

## Requisitos
- Windows 10/11 o Windows Server 2016+
- PowerShell 5.1 o superior
- Ejecución con permisos de administrador (recomendado)

## Uso
```powershell
.\SoporteTool.ps1          # Menú interactivo
.\SoporteTool.ps1 -Quick   # Modo rápido en consola
.\SoporteTool.ps1 -Report  # Genera reporte en ./Reportes/