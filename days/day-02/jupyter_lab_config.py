# Corrected reference config for Day 2.
# Drop in at /root/code/jupyter_lab_config.py and start with:
#   jupyter lab --config=/root/code/jupyter_lab_config.py --allow-root --no-browser &

c = get_config()  # type: ignore[name-defined]  # noqa: F821  (injected by Jupyter at load time)

# Bind on all interfaces so the lab proxy (not on localhost) can reach the server.
c.ServerApp.ip = "0.0.0.0"

# Fixed port the proxy expects. Do not let Jupyter auto-bump.
c.ServerApp.port = 8888
c.ServerApp.port_retries = 0

# Where notebooks live. Directory must exist on disk (mkdir -p /root/notebooks).
c.ServerApp.root_dir = "/root/notebooks/"

# Headless host — don't try to launch a browser.
c.ServerApp.open_browser = False
