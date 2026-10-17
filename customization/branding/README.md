# branding/ — Identidad visual de Core OS

| Ruta | Descripción |
| --- | --- |
| `logo/core-os.svg` | Logo principal (vectorial). Se instala en `/usr/share/pixmaps` y como icono en `/usr/share/icons/hicolor/<size>/apps`. |
| `wallpapers/` | Fondos de pantalla. Se copian a `/usr/share/backgrounds/core-os`. |

## Añadir tus propios recursos

1. Coloca el logo como `logo/core-os.png` (512×512 recomendado) — tiene
   prioridad sobre el `.svg` incluido.
2. Añade fondos en `wallpapers/` (`.png`, `.jpg` o `.svg`).
   El fondo por defecto es `core-os-default.svg`; si añades uno nuevo y quieres
   que sea el predeterminado, edita `../gnome/dconf/core-os.dconf` y
   `../gnome/99-core-os.gschema.override`.

Los scripts de personalización detectan automáticamente los archivos presentes.
