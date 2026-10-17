#!/usr/bin/env python3
# ===========================================================================
#  Core OS Setup — asistente de instalación (estilo Windows 11)
#
#  Este programa TIENE DOS MODOS:
#
#    --server-only   Se ejecuta como root (servicio core-os-setupd). Levanta la
#                    API local en 127.0.0.1:8765 y hace la instalación REAL.
#    --ui-only       Se ejecuta en la sesión gráfica del medio en vivo y muestra
#                    la interfaz a pantalla completa (WebKit2GTK).
#
#  La instalación es real: particiona el disco, formatea, copia Core OS, genera
#  el initramfs, instala GRUB y crea la cuenta del usuario. Está escrita para
#  Arch Linux (pacman/mkinitcpio/GRUB), que es la base de Core OS.
# ===========================================================================
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UI_DIR = os.path.join(BASE_DIR, "ui")
PORT = 8765

TARGET = "/target"
ISO_BOOTMNTS = ("/run/archiso/bootmnt",)

# ---------------------------------------------------------------------------
# Estado compartido con la interfaz gráfica
# ---------------------------------------------------------------------------
STATE = {
    "running": False,
    "done": False,
    "error": None,
    "step": "idle",
    "percent": 0,
    "message": "Listo para instalar",
    "log": [],
}
_LOCK = threading.Lock()


def log_line(text):
    text = str(text).rstrip()
    if not text:
        return
    with _LOCK:
        STATE["log"].append(text)
        if len(STATE["log"]) > 800:
            STATE["log"] = STATE["log"][-800:]


def set_state(**kw):
    with _LOCK:
        STATE.update(kw)


def progress(pct, msg):
    set_state(percent=int(pct), message=msg)
    log_line(f"[{int(pct):3d}%] {msg}")


# ---------------------------------------------------------------------------
# Ejecución de comandos
# ---------------------------------------------------------------------------
def sh(cmd, check=True, input_text=None, quiet=False):
    """Ejecuta un comando del sistema y registra su salida."""
    pretty = cmd if isinstance(cmd, str) else " ".join(cmd)
    if not quiet:
        log_line("$ " + pretty)
    p = subprocess.run(
        cmd, shell=isinstance(cmd, str), capture_output=True, text=True, input=input_text
    )
    if not quiet:
        if p.stdout:
            log_line(p.stdout)
        if p.stderr:
            log_line(p.stderr)
    if check and p.returncode != 0:
        raise RuntimeError(f"El comando falló ({p.returncode}): {pretty}")
    return p


def in_target(command, check=True, input_text=None):
    """Ejecuta un comando dentro del sistema instalado (arch-chroot)."""
    return sh(["arch-chroot", TARGET, "/bin/bash", "-c", command],
              check=check, input_text=input_text)


def have(program):
    return shutil.which(program) is not None


# ---------------------------------------------------------------------------
# Detección de discos y del firmware
# ---------------------------------------------------------------------------
def is_uefi():
    return os.path.isdir("/sys/firmware/efi")


def list_disks():
    out = subprocess.run(
        ["lsblk", "-J", "-dno", "NAME,SIZE,MODEL,TYPE,TRAN,ROTA"],
        capture_output=True, text=True,
    ).stdout
    disks = []
    try:
        for dev in json.loads(out).get("blockdevices", []):
            if dev.get("type") != "disk":
                continue
            name = dev["name"]
            if name.startswith(("loop", "sr", "zram", "ram", "dm-")):
                continue
            size = (dev.get("size") or "").strip()
            if not size:
                continue
            disks.append({
                "device": f"/dev/{name}",
                "size": size,
                "model": (dev.get("model") or "Disco").strip(),
                "removable": dev.get("tran") in ("usb", "mmc"),
                "rotational": dev.get("rota") in (True, "1", 1),
            })
    except Exception as exc:
        log_line(f"no se pudieron listar los discos: {exc}")
    return disks


def partition_path(disk, index):
    """Ruta de la partición número `index` del disco indicado."""
    if re.match(r".*(nvme\d+n\d+|mmcblk\d+|loop\d+|md\d+)$", disk):
        return f"{disk}p{index}"
    return f"{disk}{index}"


# ---------------------------------------------------------------------------
# Kernel e initramfs
# ---------------------------------------------------------------------------
def find_iso_kernel():
    """Localiza el kernel dentro de la ISO (archiso borra /boot del sistema en
    vivo, así que el kernel solo está en el directorio del ISO)."""
    patterns = []
    for mnt in ISO_BOOTMNTS:
        patterns += [
            f"{mnt}/*/boot/*/vmlinuz-*",
            f"{mnt}/*/boot/vmlinuz-*",
            f"{mnt}/boot/*/vmlinuz-*",
        ]
    for pattern in patterns:
        found = sorted(glob.glob(pattern))
        if found:
            return found[0]
    return None


def copy_kernel_to_target():
    """Copia el kernel (y los microcódigos) de la ISO al /boot del sistema."""
    kernel = find_iso_kernel()
    if not kernel:
        raise RuntimeError(
            "No se encontró el kernel de Core OS dentro de la ISO "
            "(¿se está ejecutando desde el medio en vivo?)"
        )
    log_line(f"Kernel de la ISO: {kernel}")
    sh(["install", "-m", "0644", kernel, f"{TARGET}/boot/"])
    boot_dir = os.path.dirname(kernel)
    for ucode in ("amd-ucode.img", "intel-ucode.img"):
        for candidate in (os.path.join(boot_dir, ucode),
                          os.path.join(os.path.dirname(boot_dir), ucode)):
            if os.path.isfile(candidate):
                sh(["install", "-m", "0644", candidate, f"{TARGET}/boot/"])
                break
    return os.path.basename(kernel)


# ---------------------------------------------------------------------------
# Instalación
# ---------------------------------------------------------------------------
def sanitize_user(value):
    value = re.sub(r"[^a-z0-9_-]", "", (value or "").lower())
    return value if re.match(r"^[a-z]", value or "") else "coreos"


def sanitize_host(value):
    value = re.sub(r"[^a-zA-Z0-9-]", "", value or "")
    return value.strip("-") or "core-os"


def install(opts):
    disk = opts["disk"]
    user = sanitize_user(opts.get("user"))
    password = opts.get("password") or "coreos"
    hostname = sanitize_host(opts.get("hostname"))
    locale = opts.get("locale") or "es_ES.UTF-8"
    keymap = opts.get("keymap") or "es"
    timezone = opts.get("timezone") or "Europe/Madrid"

    uefi = is_uefi()
    log_line("=" * 62)
    log_line("Instalación de Core OS")
    log_line("=" * 62)
    log_line(f"  Disco:        {disk}")
    log_line(f"  Arranque:     {'UEFI' if uefi else 'BIOS (MBR)'}")
    log_line(f"  Usuario:      {user}")
    log_line(f"  Equipo:       {hostname}")
    log_line(f"  Idioma:       {locale}")
    log_line(f"  Teclado:      {keymap}")
    log_line(f"  Zona horaria: {timezone}")

    # --- 1. Preparar el disco ---------------------------------------------
    progress(3, "Preparando el disco…")
    sh(["umount", "-R", TARGET], check=False, quiet=True)
    sh(["swapoff", "-a"], check=False, quiet=True)
    sh(["sgdisk", "--zap-all", disk])

    esp = None
    if uefi:
        sh(["sgdisk", "-n", "1:0:+512M", "-t", "1:ef00", "-c", "1:COREOS-EFI", disk])
        sh(["sgdisk", "-n", "2:0:0", "-t", "2:8300", "-c", "2:Core OS", disk])
        esp, root = partition_path(disk, 1), partition_path(disk, 2)
    else:
        sh(["sgdisk", "-n", "1:0:+2M", "-t", "1:ef02", "-c", "1:Core OS BIOS", disk])
        sh(["sgdisk", "-n", "2:0:0", "-t", "2:8300", "-c", "2:Core OS", disk])
        root = partition_path(disk, 2)

    sh(["partprobe", disk], check=False)
    time.sleep(2)

    # --- 2. Formatear ------------------------------------------------------
    progress(8, "Formateando las particiones…")
    sh(["mkfs.ext4", "-F", "-L", "CoreOS", root])
    if esp:
        sh(["mkfs.vfat", "-F32", "-n", "COREOS-EFI", esp])

    # --- 3. Montar ---------------------------------------------------------
    progress(12, "Montando el sistema de archivos…")
    os.makedirs(TARGET, exist_ok=True)
    sh(["mount", root, TARGET])
    if esp:
        os.makedirs(os.path.join(TARGET, "boot/efi"), exist_ok=True)
        sh(["mount", esp, os.path.join(TARGET, "boot/efi")])

    # --- 4. Copiar Core OS -------------------------------------------------
    progress(16, "Copiando Core OS al disco (varios minutos)…")
    excludes = [
        "/proc/*", "/sys/*", "/dev/*", "/run/*", "/tmp/*", "/mnt/*",
        "/media/*", "/lost+found", "/target/*", "/cdrom/*",
        "/var/cache/pacman/pkg/*", "/var/lib/docker/*", "/swapfile",
        "/etc/resolv.conf",
    ]
    cmd = ["rsync", "-aHAX", "-x", "--info=progress2", "--no-inc-recursive"]
    for pattern in excludes:
        cmd += ["--exclude", pattern]
    cmd += ["/", TARGET + "/"]

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in proc.stdout:
        match = re.search(r"(\d+)%", line)
        if match:
            set_state(percent=int(16 + int(match.group(1)) * 0.40),
                      message="Copiando Core OS al disco…")
    proc.wait()
    if proc.returncode != 0:
        raise RuntimeError("La copia del sistema (rsync) falló")
    log_line("Copia completada")

    # --- 5. Sistema de archivos / fstab -----------------------------------
    progress(58, "Configurando el sistema…")
    if have("genfstab"):
        fstab = subprocess.run(["genfstab", "-U", TARGET],
                               capture_output=True, text=True).stdout
        if fstab.strip():
            with open(os.path.join(TARGET, "etc/fstab"), "w") as fh:
                fh.write(fstab)
            log_line("fstab generado con genfstab")
        else:
            raise RuntimeError("genfstab no devolvió ninguna entrada")
    else:
        def uuid_of(dev):
            return subprocess.run(["blkid", "-s", "UUID", "-o", "value", dev],
                                  capture_output=True, text=True).stdout.strip()
        lines = [f"UUID={uuid_of(root)}  /  ext4  rw,relatime  0 1"]
        if esp:
            lines.append(f"UUID={uuid_of(esp)}  /boot/efi  vfat  umask=0077  0 2")
        with open(os.path.join(TARGET, "etc/fstab"), "w") as fh:
            fh.write("\n".join(lines) + "\n")
        log_line("fstab generado manualmente")

    # --- 6. Kernel del sistema instalado ----------------------------------
    progress(62, "Instalando el kernel en el disco…")
    copy_kernel_to_target()

    # --- 7. Ajustes básicos del sistema -----------------------------------
    progress(66, "Aplicando idioma, teclado y zona horaria…")
    sh(["ln", "-sf", f"../usr/lib/os-release", f"{TARGET}/etc/os-release"], check=False)
    in_target(f"printf '%s\\n' '{hostname}' > /etc/hostname")
    in_target(
        "printf '127.0.0.1\\tlocalhost\\n::1\\t\\tlocalhost\\n"
        f"127.0.1.1\\t{hostname}.localdomain\\t{hostname}\\n' > /etc/hosts"
    )
    in_target(f"ln -sf /usr/share/zoneinfo/{timezone} /etc/localtime")
    in_target("hwclock --systohc --utc || true", check=False)
    in_target(
        f"sed -i 's|^#\\({locale.replace('.', r'\.')}\\)|\\1|' /etc/locale.gen; "
        f"grep -qx '{locale}' /etc/locale.gen || echo '{locale}' >> /etc/locale.gen; "
        "locale-gen",
        check=False,
    )
    in_target(f"printf 'LANG={locale}\\n' > /etc/locale.conf")
    in_target(f"printf 'KEYMAP={keymap}\\nFONT=lat9w-16\\n' > /etc/vconsole.conf")
    keymap_conf = os.path.join(TARGET, "etc/X11/xorg.conf.d/00-core-os-keyboard.conf")
    os.makedirs(os.path.dirname(keymap_conf), exist_ok=True)
    with open(keymap_conf, "w") as fh:
        fh.write(
            '# Core OS — teclado elegido durante la instalación.\n'
            'Section "InputClass"\n'
            '    Identifier "core-os-keyboard"\n'
            '    MatchIsKeyboard "on"\n'
            f'    Option "XkbLayout" "{keymap}"\n'
            '    Option "XkbVariant" ""\n'
            'EndSection\n'
        )

    # --- 8. Quitar los restos del medio en vivo ----------------------------
    progress(72, "Retirando los restos del medio en vivo…")
    # Usuario y permisos del medio en vivo
    in_target(f"userdel -r {user} 2>/dev/null || true", check=False)
    in_target("userdel -r core 2>/dev/null || true", check=False)
    in_target("rm -f /etc/sudoers.d/90-core-os-live")
    # Consolas automáticas (solo tienen sentido en el medio en vivo)
    in_target("rm -rf /etc/systemd/system/serial-getty@ttyS0.service.d "
              "/etc/systemd/system/getty@tty2.service.d")
    in_target("systemctl disable serial-getty@ttyS0.service getty@tty2.service",
              check=False)
    # Sin inicio de sesión automático en el sistema final
    in_target("printf '[daemon]\\nAutomaticLoginEnable=false\\n\\n"
              "[security]\\n\\n[xdmcp]\\n\\n[chooser]\\n\\n[debug]\\n' "
              "> /etc/gdm/custom.conf")
    # El asistente de instalación no se copia al sistema instalado
    in_target("systemctl disable core-os-setupd.service", check=False)
    in_target("rm -f /etc/systemd/system/core-os-setupd.service "
              "/etc/xdg/autostart/core-os-setup.desktop "
              "/usr/local/bin/core-os-setup "
              "/usr/share/applications/core-os-setup.desktop")
    in_target("rm -rf /usr/lib/core-os/setup")
    # Restos propios de archiso (initramfs y servicios del medio en vivo)
    in_target("rm -f /etc/mkinitcpio.conf.d/archiso.conf")
    in_target("systemctl disable pacman-init.service etc-pacman.d-gnupg.mount",
              check=False)
    in_target("rm -f /etc/systemd/system/pacman-init.service "
              "/etc/systemd/system/etc-pacman.d-gnupg.mount")
    # Los ganchos de pacman de la ISO no deben quedarse en el sistema instalado
    in_target("rm -f /etc/pacman.d/hooks/uncomment-mirrors.hook "
              "/etc/pacman.d/hooks/zzzz99-remove-custom-hooks-from-airootfs.hook")

    # --- 9. Cuenta de usuario ---------------------------------------------
    progress(78, f"Creando la cuenta «{user}»…")
    in_target(
        f"id {user} >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "
        f"--comment '{user}' {user}"
    )
    in_target(
        "for g in wheel audio video optical storage power network rfkill lp "
        f"input games kvm docker adm; do getent group \"$g\" >/dev/null && "
        f"usermod -aG \"$g\" {user}; done"
    )
    # La contraseña se pasa por STDIN: nunca aparece en el registro.
    log_line("$ chpasswd  (contraseña oculta)")
    result = subprocess.run(["arch-chroot", TARGET, "chpasswd"],
                            input=f"{user}:{password}\n", capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError("No se pudo establecer la contraseña del usuario")
    in_target(f"chage -d \"$(date +%Y-%m-%d)\" -m 0 -M 99999 -I -1 -E -1 {user}")
    in_target("install -d -m 0755 /etc/sudoers.d")
    in_target("printf '# Core OS — el grupo wheel administra el sistema.\\n"
              "%%wheel ALL=(ALL:ALL) ALL\\n' > /etc/sudoers.d/10-core-os")
    in_target("chmod 0440 /etc/sudoers.d/10-core-os")

    # --- 10. Initramfs -----------------------------------------------------
    progress(84, "Generando el initramfs del sistema instalado…")
    in_target("mkinitcpio -P")

    # --- 11. Gestor de arranque -------------------------------------------
    progress(90, "Instalando el gestor de arranque (GRUB)…")
    # Tema de arranque de Core OS
    in_target("install -d -m 0755 /boot/grub/themes/core-os")
    in_target("cp -f /usr/share/core-os/grub-theme/* /boot/grub/themes/core-os/ "
              "2>/dev/null || true", check=False)
    if uefi:
        in_target('grub-install --target=x86_64-efi --efi-directory=/boot/efi '
                  '--bootloader-id="Core OS" --recheck')
        # Ruta de respaldo del firmware (medios extraíbles)
        in_target('install -d -m 0755 /boot/efi/EFI/BOOT && '
                  'cp -f /boot/efi/EFI/CoreOS/grubx64.efi '
                  '/boot/efi/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true', check=False)
    else:
        in_target(f"grub-install --target=i386-pc --recheck --boot-directory=/boot {disk}")
    in_target("grub-mkconfig -o /boot/grub/grub.cfg")

    # --- 12. Servicios y limpieza final ------------------------------------
    progress(96, "Habilitando los servicios del sistema…")
    in_target("systemctl enable gdm.service NetworkManager.service "
              "bluetooth.service cups.socket core-os-web-demo.service "
              "systemd-timesyncd.service fstrim.timer", check=False)
    in_target("systemctl set-default graphical.target", check=False)
    in_target("install -d -m 0755 /var/lib && "
              "printf 'Core OS %s\\n' \"$(sed -n 's/^CORE_OS_RELEASE=\"\\(.*\\)\"/\\1/p' "
              "/etc/core-os/release)\" > /var/lib/core-os-installed")
    sh(["sync"])
    in_target("rm -f /etc/resolv.conf && "
              "ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf", check=False)

    # --- 13. Desmontar -----------------------------------------------------
    sh(["umount", "-R", TARGET], check=False, quiet=True)
    time.sleep(1)

    progress(100, "¡Core OS se ha instalado correctamente!")
    set_state(done=True, message="Instalación completada")


def install_thread(opts):
    set_state(running=True, done=False, error=None, log=[], percent=0,
              message="Iniciando la instalación…")
    try:
        install(opts)
    except Exception as exc:  # noqa: BLE001
        log_line("ERROR: " + str(exc))
        set_state(error=str(exc), message="Error: " + str(exc))
    finally:
        set_state(running=False)


# ---------------------------------------------------------------------------
# API local
# ---------------------------------------------------------------------------
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=UI_DIR, **kwargs)

    def log_message(self, *args):
        pass

    def _json(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/api/system"):
            return self._json({
                "uefi": is_uefi(),
                "disks": list_disks(),
                "version": _core_os_version(),
            })
        if self.path.startswith("/api/progress"):
            with _LOCK:
                return self._json(dict(STATE))
        return super().do_GET()

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        data = json.loads(self.rfile.read(length) or b"{}") if length else {}
        if self.path.startswith("/api/install"):
            if not STATE["running"] and not STATE["done"]:
                threading.Thread(target=install_thread, args=(data,), daemon=True).start()
            return self._json({"ok": True})
        if self.path.startswith("/api/reboot"):
            subprocess.Popen(["systemctl", "reboot"])
            return self._json({"ok": True})
        self.send_error(404)


def _core_os_version():
    try:
        with open("/etc/core-os/release") as fh:
            for line in fh:
                if line.startswith("CORE_OS_RELEASE="):
                    return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return "1.0.0"


def start_server():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    log_line(f"API del instalador escuchando en 127.0.0.1:{PORT}")
    return server


# ---------------------------------------------------------------------------
# Interfaz gráfica (WebKit2GTK)
# ---------------------------------------------------------------------------
def open_window():
    try:
        import gi
        gi.require_version("Gtk", "3.0")
        gi.require_version("WebKit2", "4.1")
        from gi.repository import Gtk, WebKit2  # noqa: E402
    except Exception as exc:  # noqa: BLE001
        print(f"[core-os-setup] WebKit no disponible ({exc}). "
              f"Abre http://127.0.0.1:{PORT} en un navegador.", file=sys.stderr)
        while True:
            time.sleep(3600)

    url = f"http://127.0.0.1:{PORT}/index.html"
    window = Gtk.Window(title="Instalación de Core OS")
    window.set_decorated(False)
    window.fullscreen()
    window.connect("destroy", Gtk.main_quit)

    view = WebKit2.WebView()

    def on_load_failed(_view, _event, _uri, error):
        print(f"[core-os-setup] recargando ({error.message})", file=sys.stderr)
        time.sleep(1)
        _view.load_uri(url)
        return True

    view.connect("load-failed", on_load_failed)
    view.load_uri(url)
    window.add(view)
    window.show_all()
    Gtk.main()


def main():
    args = sys.argv[1:]
    if "--server-only" in args:
        # Servicio en segundo plano (root): expone la API y sirve la interfaz.
        start_server()
        threading.Event().wait()
        return
    if "--ui-only" in args:
        # La ventana la abre el usuario del medio en vivo y la interfaz se
        # sirve desde el servicio (root) que ya escucha en el puerto.
        open_window()
        return
    # Uso manual (desarrollo): servidor + ventana en el mismo proceso.
    start_server()
    open_window()


if __name__ == "__main__":
    main()
