# Day 2 — Set Up and Configure a Jupyter Notebook Server

> **Step-by-step diagnosis and run-through:** see [walkthrough.md](walkthrough.md). This README is the TL;DR.

## Task

A teammate's JupyterLab config is broken. Diagnose it and bring the server up so the lab's "Jupyter UI" button works.

**Acceptance criteria:**

- JupyterLab is running from the venv at `/root/code/ml-env/`.
- The server listens on `0.0.0.0:8888` (not `127.0.0.1`).
- The notebook root directory is `/root/notebooks/`, and the directory exists.
- `/root/code/jupyter_lab_config.py` reflects the corrected settings.

## Why this matters

Three classes of bug recur for every web service in this course (Flask, FastAPI, MLflow UI, Prometheus dashboards): bind address (loopback vs all-interfaces), port mismatch, wrong working directory. JupyterLab is the first place we hit them.

Binding to `127.0.0.1` accepts connections only from the same machine — a reverse proxy or a container host can't reach it. `0.0.0.0` listens on every interface. This is the single most common "but it works on my laptop" cause.

## How to diagnose

| Setting | Wrong | Right |
|---|---|---|
| `c.ServerApp.ip` | `'127.0.0.1'` or `'localhost'` | `'0.0.0.0'` |
| `c.ServerApp.port` | anything other than `8888` | `8888` |
| `c.ServerApp.root_dir` | missing, `'/root/'`, or a non-existent path | `'/root/notebooks/'` |
| `c.ServerApp.open_browser` | `True` (cosmetic) | `False` |

Modern Jupyter (Lab 3+) uses `c.ServerApp.*`. Legacy `c.NotebookApp.*` parses but is ignored for most settings — fix the modern namespace.

A corrected reference config is in [`jupyter_lab_config.py`](jupyter_lab_config.py).

## How to run

```bash
mkdir -p /root/notebooks
source /root/code/ml-env/bin/activate
jupyter lab --config=/root/code/jupyter_lab_config.py --allow-root --no-browser &
ss -tlnp | grep 8888    # confirm 0.0.0.0:8888 actually listening
```

[`start.sh`](start.sh) wraps this. Click the lab's Jupyter UI button once `ss` shows `LISTEN 0.0.0.0:8888`.

## Key gotchas

- **`ss -tlnp` is the truth.** Logs and config files describe intent; the kernel's listen socket is the only authoritative answer to "is this thing actually reachable."
- **CLI flags beat the config file.** `--ip=127.0.0.1` on the command line overrides whatever the config says.
- **Port collisions.** If something else holds 8888, Jupyter may auto-bump to 8889 — the proxy won't follow. Kill the conflicting process.
- **`--allow-root`** is needed because the lab runs as root, but is a finding in production. Use a non-root user.
- **Never disable auth in a real deployment.** Use a password or front it with SSO at the proxy.

## Resources

- [Jupyter Server — Configuration](https://jupyter-server.readthedocs.io/en/latest/operators/configuring-server.html)
- [JupyterLab — Running a notebook server](https://jupyterlab.readthedocs.io/en/stable/getting_started/installation.html)
- [Jupyter Server security](https://jupyter-server.readthedocs.io/en/latest/operators/security.html)
- [`ss(8)` man page](https://man7.org/linux/man-pages/man8/ss.8.html)
