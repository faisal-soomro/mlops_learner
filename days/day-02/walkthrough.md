# Day 2 — Walkthrough

> ⚠️ **Reconstructed walkthrough.** Outputs in this file are extrapolated from what the lab *would* produce, not captured from a real session. The next time someone runs this lab, replace the extrapolated outputs with the real ones. Tracked in [BACKLOG.md](../../BACKLOG.md).

The [README](README.md) covers the task and the diagnosis table. This file is the run: which order to check things in, what each command should print, and how to know the server is *really* reachable instead of just *probably* reachable.

## Starting state

A `jupyter_lab_config.py` exists at `/root/code/` but doesn't satisfy the criteria. The lab's "Jupyter UI" button fails to load. Possible failure modes the lab might plant:

- `c.ServerApp.ip = '127.0.0.1'` — proxy can't reach loopback.
- `c.ServerApp.port` set to something other than 8888.
- `c.ServerApp.root_dir = '/root/'` or a path that doesn't exist.
- Settings written under the legacy `c.NotebookApp.*` namespace that modern JupyterLab ignores.
- `c.ServerApp.open_browser = True` (cosmetic, but worth fixing).

## Step 1 — read the config first

```bash
cat /root/code/jupyter_lab_config.py
```

**Why first:** the broken setting is almost always in the file. Starting the server before reading the config just means parsing logs to find what the file already told you.

**What to look for:** every line that starts with `c.ServerApp.` or `c.NotebookApp.`. Cross-check each against the acceptance criteria.

## Step 2 — fix the config

Edit `/root/code/jupyter_lab_config.py` so it contains, at minimum:

```python
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.root_dir = '/root/notebooks/'
c.ServerApp.open_browser = False
```

**The bind-address question.** `127.0.0.1` is loopback — only the same machine can connect. The lab's reverse proxy is on a separate network namespace (or even a separate host); it gets `Connection refused`. `0.0.0.0` means "listen on every interface" — including the one the proxy can reach.

The same trade-off recurs for every web service later in this course (Flask, FastAPI, MLflow UI, Prometheus). Binding to `0.0.0.0` is convenient but exposes the service to anything that can route to the host — you rely on auth, a firewall, or a reverse proxy for safety.

**`ServerApp` vs `NotebookApp`.** JupyterLab 3+ uses `c.ServerApp.*`. The legacy `c.NotebookApp.*` namespace still parses but is ignored for most settings. If both appear in the same file, set the modern one.

## Step 3 — make the root directory exist

```bash
mkdir -p /root/notebooks
```

If `c.ServerApp.root_dir` points at a directory that doesn't exist, Jupyter logs an error and falls back to the launch directory — and the UI shows the wrong tree.

## Step 4 — activate the venv from Day 1, start the server

```bash
source /root/code/ml-env/bin/activate
jupyter lab --config=/root/code/jupyter_lab_config.py --allow-root --no-browser &
```

**What each flag does:**

- `--config=...` — explicit path, so there's no ambiguity about which config Jupyter is reading.
- `--allow-root` — Jupyter refuses to run as root by default. Fine for a lab; would be a finding in production.
- `--no-browser` — don't try to launch a GUI browser on a headless host.

**Expected behaviour:** Jupyter logs a few lines, including one that looks like `Jupyter Server X.Y.Z is running at:` followed by a URL with `0.0.0.0:8888` and a token query string. If the URL shows `127.0.0.1:8888`, something else still overrides — check CLI flags.

## Step 5 — confirm what's *actually* listening

```bash
ss -tlnp | grep 8888
# or
lsof -i :8888
```

**Why this matters:** the config file says `0.0.0.0`, the logs say `0.0.0.0`, but the *only* authoritative source is the kernel. `ss -tlnp` shows the actual bind address and the PID — if it shows `127.0.0.1:8888`, the proxy will still fail even though everything *looks* right in the logs.

**Expected output shape:** a `LISTEN` row with `0.0.0.0:8888` and `users:(("jupyter-lab",pid=...))`.

## Step 6 — click the lab's "Jupyter UI" button

If `ss` confirmed `0.0.0.0:8888`, the proxy should now route. If the button still fails, the next suspect is the token: a fresh Jupyter prints a one-time auth token in the logs and the proxy may not pass it through. The config can disable token auth (`c.ServerApp.token = ''`, `c.ServerApp.password = ''`) — fine for a sandboxed lab, dangerous anywhere else.

## Gotchas worth remembering

- **CLI flags beat the config file.** If `jupyter lab --ip=127.0.0.1 --config=...` is anywhere in a startup script, the CLI flag wins. Check both.
- **`ss -tlnp` is the truth.** Logs lie (or rather, they reflect what Jupyter *tried* to bind to; the actual bind can fail silently). The kernel's listen socket is authoritative.
- **Port collisions.** If something else holds 8888, Jupyter may bump to 8889 depending on `port_retries`. The proxy won't follow. Kill the conflicting process before starting.
- **Don't disable auth in a real deployment.** `c.ServerApp.token = ''` makes the lab work but is a notebook server open to anyone who can reach the port. Use a password or front it with SSO at the proxy.

## What this day proves for the rest of the course

Binding semantics (`0.0.0.0` vs `127.0.0.1`), port collisions, and "what's actually listening" come back every time we expose a service — Flask in Day 57, FastAPI in Day 58, MLflow UI in Days 20+, every dashboard later. `ss -tlnp` is the one diagnostic that always answers the question "is this thing actually reachable."

Once we have a second port-binding lab (Day 57 or 58), the cross-cutting writeup should be promoted to `notes/binding-and-ports.md` — tracked in BACKLOG under "Held".
