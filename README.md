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

### Características agregadas
- **Configuración regional internacional** (separadores decimales, formato de fecha, símbolo de moneda).

---

## 📦 Versión 0.1.4

### Características agregadas
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