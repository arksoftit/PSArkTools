# PSarktools

Conjunto de scripts en PowerShell para soporte técnico rápido en entornos Windows.

---

## 📦 Versión 0.1.1

### Características

- Diagnóstico rápido del sistema, red y discos.
- Escaneo de puertos y conexiones activas.
- Reparaciones comunes (DNS, red, servicios).
- Gestión de usuarios y auditoría de administradores.
- Totalmente portable: funciona desde USB.

---

## 📦 Versión 0.1.2

### Características agregadas Versión 0.1.2

- **Configuración regional internacional** (separadores decimales, formato de fecha, símbolo de moneda).

---

## 📦 Versión 0.1.4

### Características agregadas Versión 0.1.4

- **Gestión de permisos NTFS** en carpetas (lectura y asignación).
- **Detección de dispositivos USB** conectados.
- **Configuración y prueba de puertos seriales (COM)** para impresoras fiscales.
- **Información de TPM** (Trusted Platform Module) y compatibilidad.
- **Detalles de la placa base** (fabricante, modelo, número de serie).
- **Identificación de hardware PCI/PCIe** para búsqueda precisa de controladores.

---

## ⚙️ Requisitos (todas las versiones)

- Windows 10/11 o Windows Server 2016+
- PowerShell 5.1 o superior
- Ejecución con permisos de administrador (recomendado para reparaciones, gestión de permisos y diagnóstico completo)

## ▶️ Uso (todas las versiones)

```powershell
.\SoporteTool.ps1          # Menú interactivo
.\SoporteTool.ps1 -Quick   # Modo rápido en consola
.\SoporteTool.ps1 -Report  # Genera reporte en ./Reportes/

# ⚠️ Advertencias Importantes
## 1. Habilitar la ejecución de scripts en PowerShell
Si recibes el error "no se puede cargar el archivo porque la ejecución de scripts está deshabilitada", ejecuta una vez en PowerShell (como usuario normal):

powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    
Esto permite ejecutar scripts locales sin afectar la seguridad del sistema.

## 2. Versión mínima requerida de PowerShell
Este script requiere PowerShell 5.1 o superior (incluido en Windows 10/11).
verifique su version con:
  $PSVersionTable.PSVersion
Si la repuesta es algo como
  Major  Minor  Build  Revision
-----  -----  -----  --------
5      1      26100  7462
debes actualizar a mas reciente más reciente, descárgala desde:
🔗 https://aka.ms/powershell-release?tag=stable

 y obtener algo como:
 $PSVersionTable.PSVersion

Major  Minor  Patch  PreReleaseLabel BuildLabel
-----  -----  -----  --------------- ----------
7      5      4
