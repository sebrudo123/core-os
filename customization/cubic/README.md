# Cubic — flujo gráfico de personalización

[Cubic](https://github.com/PJ-Singh-001/Cubic) (Custom Ubuntu ISO Creator) es
una herramienta GTK que permite editar una ISO de Ubuntu de forma **interactiva**:
abre la ISO, la descomprime, te da una terminal *chroot* para que hagas cambios
y luego la vuelve a empaquetar.

## Cuándo usar Cubic

| Escenario | Herramienta recomendada |
| --- | --- |
| Prototipar/ajustar la personalización a mano | **Cubic** (GUI) |
| Reproducibilidad y CI/CD | **`build-iso.sh`** (scripts) |
| Explorar qué trae la ISO base | Cubic (o `unsquashfs` manual) |

Cubic y `build-iso.sh` producen el **mismo resultado**: la diferencia es que
Cubic requiere interacción, mientras que `build-iso.sh` es headless (**necesario**
para GitHub Actions, que no tiene pantalla).

## Uso de Cubic paso a paso

1. Instala Cubic en un host Ubuntu 22.04/24.04:

   ```bash
   sudo apt-add-repository universe
   sudo apt-add-repository ppa:cubic-wizard/release
   sudo apt update && sudo apt install cubic
   ```

2. Descarga la ISO base: `ubuntu-24.04.x-desktop-amd64.iso`.
3. Ejecuta `cubic`, elige un **directorio de proyecto** y la **ISO base**.
4. En el paso *Customizations*, introduce el nombre de Core OS
   (p. ej. `Core OS 1.0.0`).
5. En la pantalla de la **terminal del chroot**, ejecuta:

   ```bash
   # Copia este repositorio dentro del chroot (desde el host, antes o montando)
   mkdir -p /opt/core-os
   # (arrastra/copia la carpeta customization/ a /opt/core-os)
   cd /opt/core-os
   export CORE_OS_RELEASE=1.0.0
   for s in scripts/0*.sh scripts/1*.sh scripts/2*.sh scripts/3*.sh scripts/4*.sh scripts/9*.sh; do
     echo "==> $s"; bash "$s"
   done
   ```

   > Los scripts detectan que están dentro del chroot y aplican exactamente los
   > mismos cambios que la build headless.

6. En el paso *Options*, elige hora/idioma/zona y la compresión.
7. Pulsa **Generate** → Cubic produce `core-os-*.iso`.

## Hooks útiles de Cubic

Cubic permite hooks de pre/post en el proyecto. Este repositorio trae
`cubic/pre-chroot.sh` y `cubic/post-chroot.sh` de ejemplo que puedes enlazar
desde la carpeta del proyecto Cubic (`.cubic/`). Consulta esos archivos.

## Notas

- Cubic **no** se ejecuta sin entorno gráfico: por eso el pipeline usa
  `build-iso.sh`.
- Mantén la lista de paquetes sincronizada 100 % en `packages/packages.list`:
  es la única fuente de verdad, tanto para Cubic como para la build headless.
