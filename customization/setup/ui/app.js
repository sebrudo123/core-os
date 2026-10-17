/* Core OS Setup — lógica del asistente (estilo Windows 11) */
(() => {
  const PAGES = ["lang", "start", "disk", "account", "progress", "done", "error"];
  const PERCENT_STEP = { lang: 1, start: 1, disk: 2, account: 3, progress: 4, done: 4 };
  const slides = [
    "Tu sistema, tus reglas.",
    "Un escritorio propio, inspirado en lo mejor de cada mundo.",
    "Panel de administración integrado en http://localhost:8080",
    "Aplicaciones con Flatpak, sin ataduras.",
    "Arranque rápido y sin telemetría.",
    "Todo listo en unos minutos.",
  ];

  const $ = (id) => document.getElementById(id);
  let current = "lang";
  let selectedDisk = null;
  let slideTimer = null;
  let pollTimer = null;

  function show(page) {
    PAGES.forEach((p) => $("page-" + p).classList.remove("active"));
    $("page-" + page).classList.add("active");
    current = page;
    $("step-label").textContent = `Paso ${PERCENT_STEP[page]} de 4`;
    $("btn-back").disabled = !["disk", "account"].includes(page);
    const next = $("btn-next");
    const inWizard = ["lang", "disk", "account"].includes(page);
    next.classList.toggle("hidden", !inWizard);
    if (page === "start") $("btn-install-now").classList.remove("hidden");
  }

  function next() {
    if (current === "lang") return show("start");
    if (current === "start") return loadDisks();
    if (current === "disk") {
      if (!selectedDisk) return;
      return show("account");
    }
    if (current === "account") return startInstall();
  }

  function back() {
    if (current === "disk") return show("start");
    if (current === "account") return show("disk");
  }

  async function api(path, body) {
    const opts = body
      ? { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) }
      : {};
    const res = await fetch(path, opts);
    return res.json();
  }

  async function loadDisks() {
    const data = await api("/api/disks");
    const list = $("disk-list");
    list.innerHTML = "";
    selectedDisk = null;
    if (!data.disks.length) {
      list.innerHTML =
        '<div class="disk"><div class="info"><span class="name">No se encontraron discos</span>' +
        '<span class="meta">Conecta un disco y vuelve a intentarlo.</span></div></div>';
    }
    data.disks.forEach((d) => {
      const el = document.createElement("div");
      el.className = "disk";
      el.innerHTML =
        `<span class="radio"></span><div class="info">` +
        `<span class="name">${d.model || "Disco"} · ${d.device}</span>` +
        `<span class="meta">${d.size} · ${d.rotational ? "HDD" : "SSD"}</span>` +
        `</div>`;
      el.onclick = () => {
        document.querySelectorAll(".disk").forEach((x) => x.classList.remove("sel"));
        el.classList.add("sel");
        selectedDisk = d.device;
      };
      list.appendChild(el);
    });
    show("disk");
  }

  async function startInstall() {
    const payload = {
      disk: selectedDisk,
      user: $("user").value,
      password: $("password").value,
      hostname: $("hostname").value,
      lang: $("lang").value,
      layout: $("layout").value,
      timezone: $("timezone").value,
    };
    if (!payload.disk) {
      alert("Selecciona un disco.");
      return show("disk");
    }
    show("progress");
    startSlides();
    await api("/api/install", payload);
    poll();
  }

  function startSlides() {
    let i = 0;
    $("slide").textContent = slides[0];
    slideTimer = setInterval(() => {
      i = (i + 1) % slides.length;
      $("slide").textContent = slides[i];
    }, 4500);
  }

  function poll() {
    clearInterval(pollTimer);
    pollTimer = setInterval(async () => {
      const s = await api("/api/progress");
      $("prog-bar").style.width = s.percent + "%";
      $("prog-pct").textContent = s.percent + "%";
      $("prog-msg").textContent = s.message || "";
      $("log").textContent = (s.log || []).join("\n");
      $("log").scrollTop = $("log").scrollHeight;
      if (s.error) {
        clearInterval(pollTimer);
        clearInterval(slideTimer);
        $("err-msg").textContent = s.error;
        $("err-log").textContent = (s.log || []).join("\n");
        return show("error");
      }
      if (s.done) {
        clearInterval(pollTimer);
        clearInterval(slideTimer);
        return show("done");
      }
    }, 900);
  }

  $("btn-next").onclick = next;
  $("btn-back").onclick = back;
  $("btn-install-now").onclick = () => loadDisks();
  $("btn-reboot").onclick = () => api("/api/reboot", {});

  show("lang");
})();
