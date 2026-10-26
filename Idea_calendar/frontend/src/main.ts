type L = "en" | "de";
type T = Record<L, string>;
interface Idea { date: string; title: T; desc: T; usage: T; app_url: string; snapshots: string[] }

const TX = {
  en: { app: "30 Days · 30 Apps", sub: "One app idea per day. Browse, get inspired.", pick: "Pick a date in the calendar.",
    none: "No idea has been published for this day yet.", shots: "Snapshots", live: "Live app", how: "How to use it",
    login: "Creator login", logout: "Log out", pw: "Password", bad: "Wrong password.", edit: "Add or edit this day",
    save: "Save", del: "Delete", cancel: "Cancel", url: "App URL (optional)", title: "Title", desc: "Idea and code",
    use: "How to use it", files: "Add snapshots", keep: "Keep", today: "Today", err: "Could not save. Check the fields and try again.",
    sure: "Delete this idea?" },
  de: { app: "30 Tage · 30 Apps", sub: "Jeden Tag eine App-Idee. Stöbern und inspirieren lassen.", pick: "Wähle ein Datum im Kalender.",
    none: "Für diesen Tag wurde noch keine Idee veröffentlicht.", shots: "Screenshots", live: "Live-App", how: "So wird's benutzt",
    login: "Creator-Login", logout: "Abmelden", pw: "Passwort", bad: "Falsches Passwort.", edit: "Diesen Tag anlegen oder bearbeiten",
    save: "Speichern", del: "Löschen", cancel: "Abbrechen", url: "App-URL (optional)", title: "Titel", desc: "Idee und Code",
    use: "Anleitung", files: "Screenshots hinzufügen", keep: "Behalten", today: "Heute", err: "Speichern fehlgeschlagen. Eingaben prüfen und erneut versuchen.",
    sure: "Diese Idee löschen?" },
};

const $ = (s: string) => document.querySelector(s) as HTMLElement;
let lang: L = (localStorage.getItem("lang") as L) || (navigator.language.startsWith("de") ? "de" : "en");
let token = localStorage.getItem("token") || "";
let view = new Date(), sel = "", tab: "live" | "shots" = "shots";
let days = new Map<string, T>(), current: Idea | null = null;
const t = () => TX[lang];
const iso = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

function h(tag: string, attrs: Record<string, any> = {}, ...kids: (Node | string)[]) {
  const e = document.createElement(tag) as any;
  for (const [k, v] of Object.entries(attrs)) {
    if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
    else if (k in e) e[k] = v; else e.setAttribute(k, v);
  }
  e.append(...kids);
  return e as HTMLElement;
}

async function api(path: string, init: RequestInit = {}) {
  const hd = new Headers(init.headers);
  if (token) hd.set("Authorization", "Bearer " + token);
  const r = await fetch("/api" + path, { ...init, headers: hd });
  if (r.status === 401 && token) { setToken(""); }
  if (!r.ok) throw new Error(String(r.status));
  return r.json();
}
function setToken(v: string) { token = v; v ? localStorage.setItem("token", v) : localStorage.removeItem("token"); renderAll(); }

async function loadDays() {
  const list: { date: string; title: T }[] = await api("/ideas");
  days = new Map(list.map((i) => [i.date, i.title]));
}

function renderTop() {
  const seg = h("div", { className: "seg" }, ...(["en", "de"] as L[]).map((l) =>
    h("button", { "aria-pressed": String(l === lang), onclick: () => { lang = l; localStorage.setItem("lang", l); document.documentElement.lang = l; renderAll(); } }, l.toUpperCase())));
  const auth = token ? h("button", { onclick: () => setToken("") }, t().logout) : h("button", { onclick: loginDialog }, t().login);
  $("#top").replaceChildren(h("h1", {}, t().app), h("p", {}, t().sub), seg, auth);
  document.title = t().app;
}

function renderCal() {
  const y = view.getFullYear(), m = view.getMonth(), todayIso = iso(new Date());
  const nav = (d: number) => () => { view = new Date(y, m + d, 1); renderCal(); };
  const grid = h("div", { className: "grid" });
  for (let i = 0; i < 7; i++) grid.append(h("span", {}, new Date(2024, 0, 1 + i).toLocaleDateString(lang, { weekday: "short" })));
  for (let i = 0; i < (new Date(y, m, 1).getDay() + 6) % 7; i++) grid.append(h("span"));
  for (let d = 1; d <= new Date(y, m + 1, 0).getDate(); d++) {
    const key = iso(new Date(y, m, d));
    const cls = ["day", days.has(key) && "has", key === sel && "sel", key === todayIso && "today"].filter(Boolean).join(" ");
    const title = days.get(key)?.[lang] || days.get(key)?.en || "";
    grid.append(h("button", { className: cls, title, onclick: () => select(key) }, String(d)));
  }
  $("#cal").replaceChildren(
    h("div", { className: "calhead" }, h("button", { onclick: nav(-1), "aria-label": "‹" }, "‹"),
      h("strong", {}, view.toLocaleDateString(lang, { month: "long", year: "numeric" })), h("button", { onclick: nav(1), "aria-label": "›" }, "›")),
    grid, h("p", {}, h("button", { onclick: () => { view = new Date(); select(iso(new Date())); } }, t().today)));
}

async function select(day: string) {
  sel = day; current = null;
  try { current = await api("/ideas/" + day); } catch { /* no idea that day */ }
  tab = current?.app_url ? "live" : "shots";
  renderCal(); renderIdea();
}

function renderIdea() {
  const st = $("#stage"), info = $("#info"), i = current;
  st.replaceChildren(); info.replaceChildren();
  if (!sel) { st.append(h("p", { className: "empty" }, t().pick)); return; }
  const date = new Date(sel + "T00:00").toLocaleDateString(lang, { dateStyle: "full" });
  if (token) info.append(h("p", {}, h("button", { className: "primary", onclick: editDialog }, t().edit)));
  if (!i) { info.append(h("time", {}, date), h("p", { className: "empty" }, t().none)); st.append(h("p", { className: "empty" }, t().none)); return; }
  info.append(h("time", {}, date), h("h2", {}, i.title[lang] || i.title.en),
    h("div", { className: "txt" }, i.desc[lang] || i.desc.en),
    h("h3", {}, t().how), h("div", { className: "txt" }, i.usage[lang] || i.usage.en));
  if (i.app_url && i.snapshots.length)
    st.append(h("div", { className: "tabs" }, ...(["live", "shots"] as const).map((k) =>
      h("button", { "aria-pressed": String(tab === k), onclick: () => { tab = k; renderIdea(); } }, k === "live" ? t().live : t().shots))));
  if (tab === "live" && i.app_url) st.append(h("iframe", { src: i.app_url, sandbox: "allow-scripts allow-forms allow-popups", title: i.title[lang] }));
  else i.snapshots.forEach((s) => st.append(h("img", { src: "/uploads/" + s, alt: i.title[lang] || i.title.en, loading: "lazy" })));
}

function loginDialog() {
  const pw = h("input", { type: "password", autocomplete: "current-password" }) as HTMLInputElement;
  const err = h("p", { className: "err" });
  const dlg = h("dialog", {}, h("label", {}, t().pw), pw, err, h("menu", {},
    h("button", { onclick: () => dlg.remove() }, t().cancel),
    h("button", { className: "primary", onclick: async () => {
      try {
        const r = await api("/login", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ password: pw.value }) });
        dlg.remove(); setToken(r.token);
      } catch { err.textContent = t().bad; }
    } }, t().login))) as HTMLDialogElement;
  document.body.append(dlg); dlg.showModal(); pw.focus();
}

function editDialog() {
  const i = current, f: Record<string, HTMLInputElement> = {};
  const field = (key: string, label: string, area = false) => {
    const el = h(area ? "textarea" : "input", area ? { rows: 5 } : { type: "text" }) as HTMLInputElement;
    el.value = i ? (i as any)[key]?.[key.split(".")[1] ?? ""] ?? "" : "";
    return el;
  };
  const row = (name: "title" | "desc" | "usage", label: string, area: boolean) => {
    const els = (["en", "de"] as L[]).map((l) => {
      const el = h(area ? "textarea" : "input", area ? { rows: 5 } : { type: "text" }) as HTMLInputElement;
      el.value = i ? i[name][l] : ""; el.placeholder = l.toUpperCase(); f[name + l] = el; return el;
    });
    return [h("label", {}, label), h("div", { className: "row" }, ...els)];
  };
  const url = h("input", { type: "text", value: i?.app_url ?? "", placeholder: "https://" }) as HTMLInputElement;
  const files = h("input", { type: "file", accept: "image/*", multiple: true }) as HTMLInputElement;
  const keeps = (i?.snapshots ?? []).map((s) => {
    const cb = h("input", { type: "checkbox", checked: true, value: s }) as HTMLInputElement;
    return h("label", {}, cb, ` ${t().keep}: `, h("img", { src: "/uploads/" + s, height: 40, alt: "" }));
  });
  const err = h("p", { className: "err" });
  void field;
  const dlg = h("dialog", {}, ...row("title", t().title, false), ...row("desc", t().desc, true), ...row("usage", t().use, true),
    h("label", {}, t().url), url, h("label", {}, t().files), files, ...keeps, err,
    h("menu", {},
      i ? h("button", { onclick: async () => { if (confirm(t().sure)) { await api("/ideas/" + sel, { method: "DELETE" }); dlg.remove(); await refresh(); } } }, t().del) : "",
      h("button", { onclick: () => dlg.remove() }, t().cancel),
      h("button", { className: "primary", onclick: async () => {
        const g = (n: string) => ({ en: f[n + "en"].value, de: f[n + "de"].value });
        const fd = new FormData();
        fd.set("data", JSON.stringify({ title: g("title"), desc: g("desc"), usage: g("usage"), app_url: url.value }));
        fd.set("keep", JSON.stringify(keeps.map((k) => (k.querySelector("input") as HTMLInputElement)).filter((c) => c.checked).map((c) => c.value)));
        Array.from(files.files ?? []).forEach((x) => fd.append("files", x));
        try { await api("/ideas/" + sel, { method: "PUT", body: fd }); dlg.remove(); await refresh(); } catch { err.textContent = t().err; }
      } }, t().save))) as HTMLDialogElement;
  document.body.append(dlg); dlg.showModal();
}

async function refresh() { await loadDays(); await select(sel); }
function renderAll() { document.documentElement.lang = lang; renderTop(); renderCal(); renderIdea(); }

(async () => { await loadDays().catch(() => {}); renderAll(); await select(iso(new Date())); })();
