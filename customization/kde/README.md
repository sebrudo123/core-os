# kde/ — Perfil alternativo para KDE Plasma (opcional)

Core OS usa **GNOME** por defecto. Si quieres una edición con **KDE Plasma**,
esta carpeta contiene la base para personalizarla. Copia o adapta los archivos
a tu proyecto Cubic/headless.

## Enfoque

En lugar de dconf/gschema (GNOME), Plasma usa:

- `kdeglobals` — tema de aplicaciones, colores, iconos.
- `plasmarc` — tema del escritorio.
- `kwinrc` — comportamiento del gestor de ventanas.
- `kde/` — *look and feel* empaquetado (`plasma-look-and-feel`).

Se instalan en:

```
/etc/skel/.config/       # ajustes por defecto para usuarios nuevos
/usr/share/plasma/look-and-feel/org.core-os.desktop/
```

## Paquetes mínimos (añádelos a packages/packages.list si usas KDE)

```
kde-plasma-desktop
plasma-workspace
sddm
sddm-theme-debian-elarun
kde-config-sddm
dolphin
konsole
```

## Script sugerido

Crea `scripts/20-kde-theme.sh` (o cámbialo por `20-gnome-theme.sh`) con:

```bash
install -D -m 0644 kde/kdeglobals /etc/skel/.config/kdeglobals
install -D -m 0644 kde/plasmarc   /etc/skel/.config/plasmarc
install -D -m 0644 kde/kwinrc     /etc/skel/.config/kwinrc
```

> Estado: **placeholder**. La edición KDE de Core OS está en el roadmap.
