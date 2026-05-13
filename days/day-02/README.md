# Day 2 — Set Up and Configure a Jupyter Notebook Server

## Task

A teammate's JupyterLab config is broken. Diagnose it and bring the server up so the lab's "Jupyter UI" button works.

**Acceptance criteria:**
- JupyterLab is running from the venv at `/root/code/ml-env/`.
- The server listens on `0.0.0.0:8888` (not `127.0.0.1`).
- The notebook root directory is `/root/notebooks/`, and the directory exists.
- `/root/code/jupyter_lab_config.py` reflects the corrected settings.

## Why this matters

Three classes of bug show up over and over when running a notebook server behind a proxy or inside a container — and they're the same three you'll hit later with FastAPI, MLflow's UI, Prometheus, every web service in this course:

- **Bind address.** A process listening on `127.0.0.1` (loopback) accepts connections only from inside the same machine. A reverse proxy, a host running Docker, or another node on a Kubernetes pod cannot reach it. The fix is `0.0.0.0` (all interfaces). This is the single most common "but it works on my laptop" cause.
- **Port mismatch.** The proxy expects a specific port; if the app picks a different one (or auto-bumps when 8888 is busy), the proxy's URL 404s.
- **Wrong working directory.** Notebook root, data paths, MLflow artifact paths — when relative, they resolve against wherever the process was launched, not where you think.

Debugging this is mostly a matter of knowing the questions: *what is it actually listening on?* (`ss -tlnp`, `lsof -i :8888`), *what does the config file say?*, *what do the startup logs say?*

## Use case

The team wants a shared JupyterLab on a small VM so analysts can prototype without setting up Python locally. The VM sits behind a reverse proxy that terminates TLS and forwards `/jupyter/` to port 8888. The same proxy pattern reappears every time we expose an MLflow UI, an Evidently dashboard, or a FastAPI inference service later in the course.

If the server binds to `127.0.0.1`, the proxy gets connection-refused and analysts see a blank page. If the root directory is wrong, they can't see the shared `/root/notebooks/` directory and end up creating notebooks in random places that no one else can find.

## How to diagnose

Open `/root/code/jupyter_lab_config.py` and check every setting against the acceptance criteria. Typical broken values to look for:

| Setting | Wrong | Right |
|---|---|---|
| `c.ServerApp.ip` | `'127.0.0.1'` or `'localhost'` | `'0.0.0.0'` |
| `c.ServerApp.port` | anything other than `8888` | `8888` |
| `c.ServerApp.root_dir` | missing, `'/root/'`, or a path that doesn't exist | `'/root/notebooks/'` |
| `c.ServerApp.open_browser` | `True` (harmless but noisy in headless setups) | `False` |

Some configs use the legacy `c.NotebookApp.*` namespace. Modern Jupyter (JupyterLab 3+) uses `c.ServerApp.*`. Both can appear in old configs — fix the one that's actually being read (modern Jupyter ignores `NotebookApp` for most settings).

A corrected reference config is in [`jupyter_lab_config.py`](jupyter_lab_config.py).

## How to run

```bash
# 1. Make sure the notebook root exists
mkdir -p /root/notebooks

# 2. Activate the venv from Day 1
source /root/code/ml-env/bin/activate

# 3. Start JupyterLab with the corrected config
jupyter lab --config=/root/code/jupyter_lab_config.py --allow-root --no-browser &

# 4. Verify it's actually listening on 0.0.0.0:8888
ss -tlnp | grep 8888    # or: lsof -i :8888
```

`start.sh` in this directory wraps the above. Click the lab's Jupyter UI button once `ss` shows a `LISTEN` on `0.0.0.0:8888`.

## Notes & gotchas

- **`--allow-root`** is needed because the lab runs as root, and Jupyter refuses to start as root by default. Fine for a lab box; don't do this in production — run as a non-root user.
- **`--no-browser`** prevents Jupyter from trying to open a browser on a headless host (would just log an error).
- **Token / password.** A fresh Jupyter prints a one-time token URL in the logs. The lab's proxy button likely strips that, or the config disables auth — check `c.ServerApp.token` and `c.ServerApp.password`. For a real deployment, never disable auth; use a password or put it behind SSO at the proxy.
- **CLI flags override config file.** If you pass `--ip=127.0.0.1` on the command line, it wins over the file. Check both.
- **Port already in use.** If something else holds 8888, Jupyter will either fail or bump to 8889 (depending on `port_retries`). Kill the old process — don't let it auto-bump, because the proxy won't follow.

## Resources

- [Jupyter Server — Configuration](https://jupyter-server.readthedocs.io/en/latest/operators/configuring-server.html) — authoritative list of `c.ServerApp.*` settings.
- [JupyterLab — Running a notebook server](https://jupyterlab.readthedocs.io/en/stable/getting_started/installation.html) — install + first-run basics.
- [Jupyter Server security](https://jupyter-server.readthedocs.io/en/latest/operators/security.html) — read before exposing a notebook server to anything beyond localhost.
- [The Linux Documentation Project — `ss(8)`](https://man7.org/linux/man-pages/man8/ss.8.html) — `ss -tlnp` is the quickest way to answer "what's actually listening?".
- [Real Python — Jupyter Notebook: An Introduction](https://realpython.com/jupyter-notebook-introduction/) — readable background if Jupyter itself is new.
