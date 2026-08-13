#!/usr/bin/env python3
"""Hackathon 3.83 sanitizer for the real System Monitor product.

Creates an isolated source tree. It never edits the supplied source directory.
"""
from __future__ import annotations
import argparse
import shutil
from pathlib import Path

DEVOPS_SECTION = """      <section id="page-devops" class="page">
        <div class="panel">
          <div class="panel-head">
            <div>
              <h2>DevOps + DORA — Real Product Delivery</h2>
              <p class="muted">This is the real System Monitor UI. Runtime provenance is shown honestly; recorded/demo data is never presented as live.</p>
            </div>
            <button class="btn small" onclick="renderHackathonStatus()">Refresh</button>
          </div>
          <div class="command-grid">
            <article class="hero-panel compact"><div class="label">Product Runtime</div><div class="value" id="hackProductRuntime">Checking...</div><p class="muted" id="hackEnvironment"></p></article>
            <article class="hero-panel compact"><div class="label">Data Provenance</div><div class="value" id="hackDataMode">Checking...</div><p class="muted">Recorded/demo data is always labelled.</p></article>
            <article class="hero-panel compact"><div class="label">Delivery Mode</div><div class="value" id="hackDelivery">Checking...</div><p class="muted">Local production remains protected.</p></article>
          </div>
        </div>
        <div class="two-col">
          <section class="panel">
            <div class="panel-head"><h2>Build Provenance</h2></div>
            <div class="stack">
              <div><strong>Git revision</strong><p class="muted" id="hackGitSha">Not supplied to runtime</p></div>
              <div><strong>Image digest</strong><p class="muted" id="hackImageDigest">Not supplied to runtime</p></div>
              <div><strong>Progressive delivery</strong><p class="muted" id="hackRollout">Isolated hackathon environment</p></div>
            </div>
          </section>
          <section class="panel">
            <div class="panel-head"><h2>Mentor Demo Integrity</h2></div>
            <p id="hackMentorNote" class="muted">Loading runtime provenance...</p>
            <div class="deploy-help"><strong>Rule:</strong> The mentor sees this real System Monitor product. CI/CD, Argo, DORA, AI Ops and observability are supporting capabilities around the same codebase, not a replacement dashboard.</div>
          </section>
        </div>
      </section>
"""

JS_FUNCTION = """async function renderHackathonStatus(){
  const setText=(id,value,fallback='Not supplied to runtime')=>{const el=$('#'+id);if(el)el.textContent=(value===undefined||value===null||value==='')?fallback:String(value);};
  try{
    const d=await api('/api/hackathon/status');
    state.hackathon=d;
    setText('hackProductRuntime',`${d.product||'System Monitor'} v${d.product_version||''}`.trim());
    setText('hackEnvironment',`Environment: ${d.environment||'unknown'}`);
    setText('hackDataMode',d.data_label||d.data_mode||'Unknown');
    setText('hackDelivery',d.delivery_mode||'unknown');
    setText('hackGitSha',d.git_sha);
    setText('hackImageDigest',d.image_digest);
    setText('hackRollout',d.progressive_delivery,'Not configured');
    setText('hackMentorNote',d.mentor_note,'Runtime provenance unavailable');
  }catch(e){
    setText('hackProductRuntime','Unavailable');
    setText('hackEnvironment','Could not load /api/hackathon/status');
    setText('hackDataMode','Unknown');
    setText('hackDelivery','Unknown');
    console.error(e);
  }
}

"""

DOCKERFILE = """FROM python:3.12-slim
RUN useradd --create-home --uid 10000 appuser
WORKDIR /app
COPY server.py /app/server.py
COPY public /app/public
RUN mkdir -p /app/data && chown -R appuser:appuser /app
USER 10000:10000
EXPOSE 2278
ENV PYTHONUNBUFFERED=1
HEALTHCHECK --interval=20s --timeout=3s --start-period=10s --retries=3 CMD python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:2278/api/health', timeout=2).read()\"
CMD [\"python\",\"server.py\",\"--host\",\"0.0.0.0\",\"--port\",\"2278\"]
"""

def must(text: str, marker: str, label: str) -> None:
    if marker not in text:
        raise SystemExit(f"Expected marker missing ({label}); refusing to patch unknown source.")

def replace_default_password_line(text: str) -> str:
    lines = text.splitlines()
    found = False
    out = []
    for line in lines:
        if line.strip().startswith('DEFAULT_ADMIN_PASSWORD = os.environ.get("CMP_ADMIN_PASSWORD"'):
            if found:
                raise SystemExit("Multiple admin fallback assignments found.")
            found = True
            out.extend([
                'DEFAULT_ADMIN_PASSWORD = (os.environ.get("CMP_ADMIN_PASSWORD") or "").strip()',
                'HACKATHON_ENVIRONMENT = (os.environ.get("CMP_HACKATHON_ENVIRONMENT") or "local-isolated").strip()',
                'HACKATHON_DATA_MODE = (os.environ.get("CMP_DATA_MODE") or "live").strip().lower()',
                'HACKATHON_GIT_SHA = (os.environ.get("CMP_GIT_SHA") or "").strip()',
                'HACKATHON_IMAGE_DIGEST = (os.environ.get("CMP_IMAGE_DIGEST") or "").strip()',
                'HACKATHON_DELIVERY = (os.environ.get("CMP_DELIVERY_MODE") or "local-runtime").strip()',
                'SESSION_COOKIE_SECURE = (os.environ.get("CMP_SECURE_COOKIE") or "0").strip().lower() in {"1","true","yes","on"}',
            ])
        else:
            out.append(line)
    if not found:
        raise SystemExit("Admin fallback assignment not found.")
    return "\n".join(out) + "\n"

def replace_password_print(text: str) -> str:
    lines = text.splitlines()
    found = False
    out = []
    for line in lines:
        if 'print("Default admin password:' in line:
            found = True
            indent = line[:len(line)-len(line.lstrip())]
            out.append(indent + 'print("Admin password: runtime secret configured (value intentionally not printed)")')
        else:
            out.append(line)
    if not found:
        raise SystemExit("Default-password print line not found.")
    return "\n".join(out) + "\n"

def build(source: Path, output: Path) -> None:
    public_src = source / "public"
    required = [source/"server.py", public_src/"app.js", public_src/"index.html", public_src/"styles.css"]
    for p in required:
        if not p.exists():
            raise SystemExit(f"Missing required source: {p}")
    if output.exists():
        raise SystemExit(f"Output already exists: {output}")
    (output/"public").mkdir(parents=True)
    shutil.copy2(source/"server.py", output/"server.py")
    for name in ("app.js","index.html","styles.css","retention-manager.html"):
        p = public_src/name
        if p.exists():
            shutil.copy2(p, output/"public"/name)
    if (public_src/"branding").exists():
        shutil.copytree(public_src/"branding", output/"public"/"branding")

    server = (output/"server.py").read_text(encoding="utf-8")
    server = replace_default_password_line(server)

    marker = "def now_iso() -> str:\n    return dt.datetime.now(dt.timezone.utc).isoformat()\n"
    must(server, marker, "now_iso")
    server = server.replace(marker, marker + """

def hackathon_runtime_status() -> Dict[str, Any]:
    data_mode = HACKATHON_DATA_MODE if HACKATHON_DATA_MODE in {"live", "recorded", "demo", "replay"} else "unknown"
    return {
        "ok": True,
        "product": APP_NAME,
        "product_version": "8.4",
        "environment": HACKATHON_ENVIRONMENT,
        "data_mode": data_mode,
        "data_label": "Live telemetry" if data_mode == "live" else "Recorded / demo telemetry",
        "git_sha": HACKATHON_GIT_SHA,
        "image_digest": HACKATHON_IMAGE_DIGEST,
        "delivery_mode": HACKATHON_DELIVERY,
        "progressive_delivery": "Argo Rollouts 10% -> 25% -> 50% -> 100% (isolated hackathon environment)",
        "mentor_note": "This is the real System Monitor product UI. Delivery/observability evidence is integrated around the same product; recorded data is never represented as live.",
        "time": now_iso(),
    }
""", 1)

    marker = '            if not self.require_auth(path, "GET"):\n                return\n            if path == "/api/isp-check":'
    must(server, marker, "authenticated GET routing")
    server = server.replace(marker,
        '            if not self.require_auth(path, "GET"):\n'
        '                return\n'
        '            if path == "/api/hackathon/status":\n'
        '                return self.send_json(hackathon_runtime_status())\n'
        '            if path == "/api/isp-check":', 1)

    server = server.replace(
        '{"Set-Cookie": f"cmp_session={token}; HttpOnly; SameSite=Lax; Path=/; Max-Age={SESSION_TTL_SECONDS}"}',
        '{"Set-Cookie": f"cmp_session={token}; HttpOnly; SameSite=Lax; Path=/; Max-Age={SESSION_TTL_SECONDS}" + ("; Secure" if SESSION_COOKIE_SECURE else "")}'
    )
    server = server.replace(
        '{"Set-Cookie":"cmp_session=; HttpOnly; SameSite=Lax; Path=/; Max-Age=0"}',
        '{"Set-Cookie":"cmp_session=; HttpOnly; SameSite=Lax; Path=/; Max-Age=0" + ("; Secure" if SESSION_COOKIE_SECURE else "")}'
    )

    marker = "    args = parser.parse_args()\n    init_db()\n"
    must(server, marker, "main bootstrap")
    server = server.replace(marker,
        "    args = parser.parse_args()\n"
        "    if not DEFAULT_ADMIN_PASSWORD:\n"
        '        raise SystemExit("CMP_ADMIN_PASSWORD must be set for this sanitized hackathon runtime; no hard-coded fallback is permitted.")\n'
        "    init_db()\n", 1)
    server = replace_password_print(server)
    (output/"server.py").write_text(server, encoding="utf-8", newline="\n")

    html = (output/"public"/"index.html").read_text(encoding="utf-8")
    marker = '      <button class="nav" data-page="deploy">Deploy</button>\n      <button class="nav" data-page="settings">Settings</button>'
    must(html, marker, "Deploy/Settings nav")
    html = html.replace(marker,
        '      <button class="nav" data-page="deploy">Deploy</button>\n'
        '      <button class="nav" data-page="devops">DevOps + DORA</button>\n'
        '      <button class="nav" data-page="settings">Settings</button>', 1)
    marker = '<section id="page-settings" class="page">'
    must(html, marker, "Settings page")
    html = html.replace(marker, DEVOPS_SECTION + marker, 1)
    (output/"public"/"index.html").write_text(html, encoding="utf-8", newline="\n")

    js = (output/"public"/"app.js").read_text(encoding="utf-8")
    must(js, "  lastRefresh: null\n};", "state")
    js = js.replace("  lastRefresh: null\n};", "  lastRefresh: null,\n  hackathon: null\n};", 1)
    oldq = "const quietPages = new Set(['machine360','network','hardware','software','usb','changes','history','deploy','settings','messages','notifications']);"
    must(js, oldq, "quiet pages")
    js = js.replace(oldq, "const quietPages = new Set(['machine360','network','hardware','software','usb','changes','history','deploy','devops','settings','messages','notifications']);", 1)
    marker = "function renderAll(){"
    must(js, marker, "renderAll")
    js = js.replace(marker, JS_FUNCTION + marker, 1)
    marker = "  if(page==='deploy') return renderDeployCommands();\n"
    must(js, marker, "Deploy renderer")
    js = js.replace(marker, marker + "  if(page==='devops') return renderHackathonStatus();\n", 1)
    old = "deploy:['Deploy','Copy-ready current commands for Windows and Ubuntu clients.'],settings:['Settings','Users, password and refresh control.']"
    must(js, old, "page titles")
    js = js.replace(old,
        "deploy:['Deploy','Copy-ready current commands for Windows and Ubuntu clients.'],"
        "devops:['DevOps + DORA','Delivery provenance and hackathon evidence for this real System Monitor product.'],"
        "settings:['Settings','Users, password and refresh control.']", 1)
    (output/"public"/"app.js").write_text(js, encoding="utf-8", newline="\n")

    (output/"Dockerfile").write_text(DOCKERFILE, encoding="utf-8", newline="\n")
    (output/".dockerignore").write_text(
        "data/\n*.db\n*.log\n*.bak*\n*.tmp\n*.before_*\n.env\n*.pem\n*.key\n*.crt\n__pycache__/\n", encoding="utf-8")
    (output/".env.example").write_text(
        "# Never commit real values.\n"
        "CMP_ADMIN_PASSWORD=REPLACE_AT_RUNTIME\n"
        "CMP_HACKATHON_ENVIRONMENT=local-isolated\n"
        "CMP_DATA_MODE=live\n"
        "CMP_GIT_SHA=\n"
        "CMP_IMAGE_DIGEST=\n"
        "CMP_DELIVERY_MODE=local-runtime\n"
        "CMP_SECURE_COOKIE=0\n", encoding="utf-8")
    print(f"Sanitized Hackathon 3.83 source created at: {output}")

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--source", required=True)
    p.add_argument("--output", required=True)
    a = p.parse_args()
    build(Path(a.source), Path(a.output))

if __name__ == "__main__":
    main()
