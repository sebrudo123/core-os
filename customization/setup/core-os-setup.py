#!/usr/bin/env python3
# ===========================================================================
#  core-os-setup.py — Asistente de instalación de Core OS (estilo Windows 11).
#
#  Se ejecuta en la sesión EN VIVO (medio de instalación) y muestra un
#  asistente a pantalla completa. El backend realiza la instalación REAL en el
#  disco elegido: particiona, formatea, copia el sistema, instala GRUB y
#  configura usuario/idioma/teclado.
#
#  La interfaz es HTML/CSS/JS servida localmente y se muestra con WebKit2GTK.
# ===========================================================================
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

# ---------------------------------------------------------------------------
# Estado compartido con la interfaz
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
    with _LOCK:
        STATE["log"].append(text)
        if len(STATE["log"]) > 500:
            STATE["log"] = STATE["log"][-500:]


def set_state(**kw):
    with _LOCK:
        STATE.update(kw)


def run(cmd, check=True, **kw):
    """Ejecuta un comando y registra su salida."""
    pretty = cmd if isinstance(cmd, str) else " ".join(cmd)
    log_line("$ " + pretty)
    p = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if p.stdout:
        log_line(p.stdout.rstrip())
    if p.stderr:
        log_line(p.stderr.rstrip())
    if check and p.returncode != 0:
        raise RuntimeError(f"falló ({p.returncode}): {pretty}\n{p.stderr.strip()}")
    return p


def run_chroot(command):
    """Ejecuta un comando dentro del sistema destino."""
    return run(["chroot", TARGET, "/bin/bash", "-c", command])


# ---------------------------------------------------------------------------
# Discos disponibles
# ---------------------------------------------------------------------------
def list_disks():
    out = subprocess.run(
        ["lsblk", "-J", "-dno", "NAME,SIZE,MODEL,TYPE,TRAN,ROTA"],
        capture_output=True, text=True,
    ).stdout
    disks = []
    try:
        for d in json.loads(out).get("blockdevices", []):
            if d.get("type") != "disk":
                continue
            name = d["name"]
            if name.startswith(("loop", "sr", "zram")):
                continue
            disks.append({
                "device": f"/dev/{name}",
                "size": (d.get("size") or "").strip(),
                "model": (d.get("model") or "Disco").strip(),
                "rotational": d.get("rota") in (True, "1", 1),
            })
    except Exception as exc:  # pragma: no cover
        log_line(f"error listando discos: {exc}")
    return disks


def part_name(disk, index):
    """Nombre de la partición según el tipo de dispositivo."""
    if re.match(r".*(nvme\d+n\d+|mmcblk\d+|loop\d+)$", disk):
        return f"{disk}p{index}"
    return f"{disk}{index}"


# ---------------------------------------------------------------------------
# Instalación
# ---------------------------------------------------------------------------
def is_uefi():
    return os.path.isdir("/sys/firmware/efi")


def progress(pct, msg):
    set_state(percent=int(pct), message=msg)
    log_line(f"[{pct}%] {msg}")


def install(opts):
    disk = opts["disk"]
    user = re.sub(r"[^a-z0-9_-]", "", (opts.get("user") or "coreos").lower()) or "coreos"
    password = opts.get("password") or "coreos"
    hostname = re.sub(r"[^a-zA-Z0-9-]", "", (opts.get("hostname") or "core-os")) or "core-os"
    lang = opts.get("lang") or "es"
    layout = opts.get("layout") or "es"
    timezone = opts.get("timezone") or "Europe/Madrid"

    uefi = is_uefi()
    log_line(f"Modo de arranque: {'UEFI' if uefi else 'BIOS/legacy'}")

    # --- 1. Particionado ---------------------------------------------------
    progress(3, "Preparando el disco…")
    run(["umount", "-R", TARGET], check=False)
    run(["swapoff", "-a"], check=False)
    run(["sgdisk", "--zap-all", disk])

    if uefi:
        run(["sgdisk", "-n", "1:0:+512M", "-t", "1:ef00", "-c", "1:EFI System", disk])
        run(["sgdisk", "-n", "2:0:0", "-t", "2:8300", "-c", "2:Core OS", disk])
        esp, root = part_name(disk, 1), part_name(disk, 2)
    else:
        run(["sgdisk", "-n", "1:0:+2M", "-t", "1:ef02", "-c", "1:BIOS boot", disk])
        run(["sgdisk", "-n", "2:0:0", "-t", "2:8300", "-c", "2:Core OS", disk])
        esp, root = None, part_name(disk, 2)

    run(["partprobe", disk], check=False)
    time.sleep(2)

    # --- 2. Formateo -------------------------------------------------------
    progress(8, "Formateando…")
    run(["mkfs.ext4", "-F", "-L", "CoreOS", root])
    if esp:
        run(["mkfs.vfat", "-F32", "-n", "COREOS-EFI", esp])

    # --- 3. Montaje --------------------------------------------------------
    progress(12, "Montando el sistema de archivos…")
    os.makedirs(TARGET, exist_ok=True)
    run(["mount", root, TARGET])
    if esp:
        os.makedirs(os.path.join(TARGET, "boot/efi"), exist_ok=True)
        run(["mount", esp, os.path.join(TARGET, "boot/efi")])

    # --- 4. Copia del sistema ---------------------------------------------
    progress(16, "Copiando Core OS al disco (esto tarda unos minutos)…")
    excludes = [
        "/proc/*", "/sys/*", "/dev/*", "/run/*", "/tmp/*", "/mnt/*",
        "/media/*", "/cdrom/*", "/target/*", "/lost+found",
        "/var/cache/apt/archives/*", "/var/lib/docker/*", "/swapfile",
        "/etc/resolv.conf",
    ]
    cmd = ["rsync", "-aHAX", "-x", "--info=progress2", "--no-inc-recursive"]
    for e in excludes:
        cmd += ["--exclude", e]
    cmd += ["/", TARGET + "/"]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in proc.stdout:
        m = re.search(r"(\d+)%", line)
        if m:
            pct = 16 + int(m.group(1)) * 0.44  # 16% -> 60%
            set_state(percent=int(pct), message="Copiando Core OS al disco…")
    proc.wait()
    if proc.returncode != 0:
        raise RuntimeError("rsync falló al copiar el sistema")
    log_line("Copia completada")

    # --- 5. Configuración del sistema destino -----------------------------
    progress(62, "Configurando el sistema…")
    for m in ("proc", "sys", "dev", "dev/pts", "run"):
        os.makedirs(os.path.join(TARGET, m), exist_ok=True)
        run(["mount", "--bind", f"/{m}", f"{TARGET}/{m}"], check=False)

    # DNS para el sistema destino (por si instala paquetes).
    run(["cp", "-f", "/etc/resolv.conf", f"{TARGET}/etc/resolv.conf"], check=False)

    # fstab con UUIDs
    def uuid(dev):
        return subprocess.run(["blkid", "-s", "UUID", "-o", "value", dev],
                              capture_output=True, text=True).stdout.strip()

    fstab = [f"UUID={uuid(root)}  /  ext4  defaults,noatime  0 1"]
    if esp:
        fstab.append(f"UUID={uuid(esp)}  /boot/efi  vfat  umask=0077  0 1")
    with open(os.path.join(TARGET, "etc/fstab"), "w") as fh:
        fh.write("\n".join(fstab) + "\n")

    run_chroot(f"echo {hostname} > /etc/hostname")
    run_chroot(
        f"printf '127.0.0.1 localhost\\n127.0.1.1 {hostname}\\n' > /etc/hosts"
    )
    run_chroot(f"ln -sf /usr/share/zoneinfo/{timezone} /etc/localtime")
    run_chroot("hwclock --systohc || true")

    locale = "es_ES.UTF-8" if lang == "es" else "en_US.UTF-8"
    run_chroot(f"locale-gen {locale} || true")
    run_chroot(f"printf 'LANG={locale}\\nLC_ALL={locale}\\n' > /etc/default/locale")
    run_chroot(f"printf 'XKBLAYOUT=\"{layout}\"\\nXKBVARIANT=\"\"\\nBACKSPACE=\"guess\"\\n' > /etc/default/keyboard")

    # --- 6. Usuario --------------------------------------------------------
    progress(70, "Creando la cuenta de usuario…")
    run_chroot(f"id {user} >/dev/null 2>&1 || adduser --disabled-password "
               f"--gecos \"{user}\" {user}")
    run_chroot(f"usermod -aG sudo,adm,docker {user} || usermod -aG sudo,adm {user}")
    safe_pw = password.replace("'", "'\\''")
    run_chroot(f"echo '{user}:{safe_pw}' | chpasswd")
    run_chroot(f"chage -m 0 -M 99999 -I -1 -E -1 {user}")

    # Elimina el asistente del sistema instalado (solo vive en el medio).
    run_chroot("rm -f /etc/xdg/autostart/core-os-setup.desktop || true")
    # Elimina el usuario del medio en vivo (creado por casper con UID 1000 sin
    # contraseña y con sudo sin contraseña): no debe quedar en el sistema final.
    run_chroot("userdel -r ubuntu 2>/dev/null || true")
    run_chroot("rm -f /etc/sudoers.d/casper || true")

    # --- 7. Gestor de arranque --------------------------------------------
    progress(80, "Instalando el gestor de arranque (GRUB)…")
    if uefi:
        run_chroot('grub-install --target=x86_64-efi --efi-directory=/boot/efi '
                   '--bootloader-id="Core OS" --recheck')
        # Ruta de respaldo para medios extraíbles.
        run_chroot('mkdir -p /boot/efi/EFI/BOOT && '
                   'cp -f /boot/efi/EFI/CoreOS/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI '
                   '2>/dev/null || true')
    else:
        run_chroot(f'grub-install --target=i386-pc --recheck --boot-directory=/boot {disk}')
    run_chroot("update-grub")

    # --- 8. Servicios ------------------------------------------------------
    progress(92, "Habilitando servicios…")
    run_chroot("systemctl enable gdm3 ssh || true")
    run_chroot("systemctl set-default graphical.target || true")
    run_chroot("install -d /var/lib && touch /var/lib/core-os-installed")

    # --- 9. Limpieza -------------------------------------------------------
    progress(96, "Finalizando…")
    run(["sync"])
    for m in ("dev/pts", "dev", "sys", "proc", "run"):
        run(["umount", "-l", f"{TARGET}/{m}"], check=False)
    if esp:
        run(["umount", "-l", f"{TARGET}/boot/efi"], check=False)
    run(["umount", "-l", TARGET], check=False)

    progress(100, "Instalación completada")
    set_state(done=True, message="Instalación completada")


def install_thread(opts):
    set_state(running=True, done=False, error=None, log=[], percent=0)
    try:
        install(opts)
    except Exception as exc:  # pragma: no cover
        log_line("ERROR: " + str(exc))
        set_state(error=str(exc), message="Error: " + str(exc))
    finally:
        set_state(running=False)


# ---------------------------------------------------------------------------
# Servidor HTTP local (interfaz + API)
# ---------------------------------------------------------------------------
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=UI_DIR, **kwargs)

    def log_message(self, *args):  # silencio
        pass

    def _json(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/api/disks"):
            return self._json({"disks": list_disks(), "uefi": is_uefi()})
        if self.path.startswith("/api/progress"):
            with _LOCK:
                return self._json(dict(STATE))
        return super().do_GET()

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        data = json.loads(self.rfile.read(length) or b"{}") if length else {}
        if self.path.startswith("/api/install"):
            if not STATE["running"]:
                threading.Thread(target=install_thread, args=(data,), daemon=True).start()
            return self._json({"ok": True})
        if self.path.startswith("/api/reboot"):
            subprocess.Popen(["systemctl", "reboot"])
            return self._json({"ok": True})
        self.send_error(404)


def start_server():
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def open_window():
    """Abre la ventana del asistente (WebKit2GTK) apuntando al servidor local."""
    try:
        import gi
        gi.require_version("Gtk", "3.0")
        gi.require_version("WebKit2", "4.1")
        from gi.repository import Gtk, WebKit2  # noqa: E402
    except Exception as exc:  # WebKit no disponible
        print(f"[core-os-setup] WebKit no disponible ({exc}); abre "
              f"http://127.0.0.1:{PORT} manualmente", file=sys.stderr)
        while True:
            time.sleep(3600)

    url = f"http://127.0.0.1:{PORT}/index.html"
    win = Gtk.Window(title="Instalación de Core OS")
    win.set_decorated(False)
    win.fullscreen()
    win.connect("destroy", Gtk.main_quit)
    view = WebKit2.WebView()

    def on_fail(_view, _event, _uri, error):
        # El servicio puede tardar un instante en estar listo: reintenta.
        print(f"[core-os-setup] reintentando ({error.message})", file=sys.stderr)
        time.sleep(1)
        _view.load_uri(url)
        return True

    view.connect("load-failed", on_fail)
    view.load_uri(url)
    win.add(view)
    win.show_all()
    Gtk.main()


def main():
    args = sys.argv[1:]
    if "--server-only" in args:
        # Servicio en segundo plano (root): expone la API de instalación.
        start_server()
        log_line("Servidor del instalador listo en 127.0.0.1:%d" % PORT)
        threading.Event().wait()
        return
    if "--ui-only" not in args:
        # Uso manual: levanta el servidor y muestra la interfaz.
        start_server()
    open_window()


if __name__ == "__main__":
    main()
