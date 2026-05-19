# Docker for Python (and Python ML services)

Cross-cutting notes on building, sizing, and shipping Python applications — especially ML services — as Docker images. Will keep growing as Domain 6 (Docker for ML) and Domain 7 (Model Serving) introduce more patterns.

## Contents

- [Wheel vs Docker image — what each one packages](#wheel-vs-docker-image--what-each-one-packages)
  - [The relationship between them](#the-relationship-between-them)
  - [When to reach for which](#when-to-reach-for-which)
  - [The trap: native dependencies](#the-trap-native-dependencies)
  - [One-line summary](#one-line-summary)
- [Shrinking Python images — patterns](#shrinking-python-images--patterns)
  - [Reference: the Go pattern](#reference-the-go-pattern)
  - [Pattern 1 — multi-stage venv copy (the standard)](#pattern-1--multi-stage-venv-copy-the-standard)
  - [Pattern 2 — distroless final stage](#pattern-2--distroless-final-stage)
  - [Pattern 3 — PEX / shiv (bundle the venv into one executable)](#pattern-3--pex--shiv-bundle-the-venv-into-one-executable)
  - [Pattern 4 — Nuitka (actually compile to C)](#pattern-4--nuitka-actually-compile-to-c)
  - [Pattern 5 — PyInstaller](#pattern-5--pyinstaller)
  - [Comparison](#comparison)
  - [Recommendation](#recommendation)
  - [The deeper lesson](#the-deeper-lesson)
- [The MLOps deployment cycle](#the-mlops-deployment-cycle)
  - [Why some teams skip wheels for ML](#why-some-teams-skip-wheels-for-ml)
- [See also](#see-also)

## Wheel vs Docker image — what each one packages

You'll see both in MLOps codebases. They solve overlapping problems, but at different scopes.

**A wheel** packages **Python code + its declared Python dependencies**.

It does *not* package:
- The Python interpreter itself.
- System libraries (`libstdc++`, `libgomp`, CUDA, BLAS).
- OS-level packages.
- Config files outside the package directory.
- Models, data, certificates.

When you `pip install fraud_detection-0.1.0.whl`, you need:
- A Python interpreter that matches `requires-python`.
- A filesystem where pip can install transitive deps from PyPI.
- A platform where those deps have available wheels (this gets messy with native code — see below).

**A Docker image** packages **everything from the OS up**:
- The base OS layer (Debian, Alpine, NVIDIA's CUDA runtime, etc.).
- The Python interpreter (specific version, baked in).
- System libraries (apt-installed `libgomp1`, `libpq-dev`, drivers).
- Your wheels (installed during build).
- Config, entrypoints, the user the process runs as.
- Sometimes the data and model artifacts (often not — they get mounted in).

A `docker run fraud-detection:0.1.0` doesn't need *anything* on the host beyond Docker itself.

### The relationship between them

Key insight: **a Docker image usually contains your wheel.** They aren't either-or; they nest.

A typical Dockerfile for an ML service:

```dockerfile
FROM python:3.12-slim

# System deps (the things wheels can't include)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
 && rm -rf /var/lib/apt/lists/*

# Copy and install your wheel
COPY dist/fraud_detection-0.1.0-py3-none-any.whl /tmp/
RUN pip install /tmp/fraud_detection-0.1.0-py3-none-any.whl

ENTRYPOINT ["python", "-m", "fraud_detection.serve"]
```

The wheel is a *layer* in the image. CI builds the wheel once, then builds N images that consume it (training image, inference image, batch image — each with different system deps).

### When to reach for which

| Situation | Reach for |
|---|---|
| Internal library shared between services on the same Python version | **Wheel.** Publish to an internal index. Services `pip install`. |
| Model code that runs in a notebook today, a CI job tomorrow | **Wheel.** Lets you `pip install -e .` for dev. |
| A *deployable service* (inference API, training job, batch processor) | **Image.** It needs a guaranteed runtime, system deps, an entrypoint. |
| Anything with CUDA / native deps that the deploy target doesn't have | **Image.** You don't want to debug GLIBC versions in production. |
| Pinning the *exact* environment for reproducibility audit | **Image.** Wheel can drift via transitive deps; image is byte-identical. |
| Lambda / Cloud Run / similar serverless | **Image** (or zip, but image more often now). |
| Distributing to other Python users (open-source, internal teams) | **Wheel.** |

### The trap: native dependencies

A "pure Python" wheel installs anywhere Python runs. Easy.

But your wheel declares `dependencies = ["scikit-learn"]`. scikit-learn is C/Cython/Fortran. It ships as **platform-specific wheels** on PyPI — `scikit_learn-1.8.0-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl`, plus separate wheels for `aarch64`, `macosx`, `win_amd64`, etc. The wheel format encodes the target platform in the filename.

When you `pip install` your wheel:

- **Linux x86_64**: pip finds the manylinux wheel, life is good.
- **Linux ARM64** (e.g. AWS Graviton): pip finds the aarch64 wheel.
- **Alpine container** (stripped-down, musl libc instead of glibc): no compatible manylinux wheel — pip falls back to building from source, which needs gcc, libatlas, etc. This is the "why does my Docker build take 40 minutes" moment.

Images solve this by **fixing the platform**. The image's base layer determines glibc, CPU arch, kernel ABI. The build pulls one specific platform's wheels into one specific environment. No `pip install` surprises in production.

**In practice: the wheel is portable; the image is the version that's actually pinned.**

### One-line summary

> A wheel says "here is the code"; an image says "here is the entire runnable environment."

You want both. The wheel is the unit of code reuse. The image is the unit of deployment.

## Shrinking Python images — patterns

Python can't quite reach Go's "single static binary in scratch" because the runtime is fundamentally different. But you can get close. Patterns in order of how close they get to the Go ideal.

### Reference: the Go pattern

```dockerfile
# Stage 1: build
FROM golang:1.22 AS builder
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /app/server .

# Stage 2: run — minimal, no toolchain
FROM gcr.io/distroless/static:nonroot
COPY --from=builder /app/server /server
ENTRYPOINT ["/server"]
```

Final image: ~10–20 MB. No glibc, no shell, no package manager. The binary is fully self-contained because Go statically links its own runtime.

### Pattern 1 — multi-stage venv copy (the standard)

Build wheels and the venv in a fat builder stage; copy *just the venv* into a slim runtime stage.

```dockerfile
# Stage 1: build — has gcc, build-essential, dev headers
FROM python:3.12-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc build-essential \
 && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY dist/fraud_detection-0.1.0-py3-none-any.whl /tmp/
RUN pip install --no-cache-dir /tmp/fraud_detection-0.1.0-py3-none-any.whl

# Stage 2: runtime — no toolchain, just Python + the venv
FROM python:3.12-slim

# Only the *runtime* system libs (not the compiler)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

ENTRYPOINT ["python", "-m", "fraud_detection.serve"]
```

**Gets you:**

- Final image typically ~150–400 MB for a numpy/scikit-learn workload, down from ~1.5–3 GB if you `pip install` on a development base.
- No gcc, no apt dev packages, no pip cache in the final image.
- Same single-deployable story as Go: one image, runs anywhere Docker runs.

**Still carrying:** the Python interpreter, the standard library, the venv site-packages (numpy ~30 MB, scipy ~80 MB, scikit-learn ~30 MB). Irreducible cost of having a Python runtime.

**This is what 90% of production ML services use.**

### Pattern 2 — distroless final stage

Swap the runtime image for Google's distroless Python:

```dockerfile
FROM gcr.io/distroless/python3-debian12
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
ENTRYPOINT ["python", "-m", "fraud_detection.serve"]
```

Distroless images contain:

- The Python interpreter.
- A minimal set of system libraries Python needs.
- Nothing else. No shell. No package manager. No coreutils.

Image size: ~50 MB base + your venv. Closer to Go territory.

**Tradeoffs:**

- **No shell** → can't `docker exec -it … sh` to debug. Use distroless's `:debug` variant in dev.
- **No package manager** → any apt-installable system lib your code needs at runtime (e.g. `libgomp1`) must be carried over from the builder stage manually, or switch to a `:debian12` base that has them.
- Smaller attack surface — no shell to drop into if something's compromised.

What production-conscious ML platforms (Kubeflow, KServe) tend to use.

### Pattern 3 — PEX / shiv (bundle the venv into one executable)

[PEX](https://github.com/pantsbuild/pex) and [shiv](https://github.com/linkedin/shiv) bundle your code, all dependencies, and an entrypoint into a single executable zip. You still need Python on the host, but everything else is one file.

```bash
pex fraud_detection -o fraud-detection.pex -c fraud-detection-serve
./fraud-detection.pex
```

In Docker:

```dockerfile
FROM python:3.12-slim
COPY fraud-detection.pex /app/
ENTRYPOINT ["/app/fraud-detection.pex"]
```

Closer to Go in *deployment shape* (one artifact), similar size in practice. Useful when shipping the same app to multiple environments (some Docker, some bare metal).

**Caveat:** PEX struggles with C extensions that have `.so` files (numpy, scikit-learn). It handles them, but bundling gets complex and platform-specific. For ML workloads, usually more pain than it's worth.

### Pattern 4 — Nuitka (actually compile to C)

[Nuitka](https://nuitka.net/) is the closest analogue to `go build`. Transpiles Python to C and compiles to a real native binary.

```bash
python -m nuitka --standalone --onefile fraud_detection/serve.py
```

```dockerfile
FROM gcr.io/distroless/cc-debian12
COPY --from=builder /app/serve.bin /serve
ENTRYPOINT ["/serve"]
```

Theoretically closest to Go's pattern. In practice for ML:

- ✅ Works great for pure-Python code (web servers, business logic).
- ❌ Breaks regularly on heavy ML deps. Has to bundle numpy's `.so` files, sklearn's compiled extensions, PyTorch's CUDA libraries. Sometimes works; sometimes the binary is 2GB and slower than the interpreter.
- ❌ Compile times are very long for large dep trees.

Good for: Python CLI tools with no heavy native deps. Bad for: ML inference services.

### Pattern 5 — PyInstaller

[PyInstaller](https://pyinstaller.org/) bundles Python + your code + dependencies into one executable. Mature, long-established.

```bash
pyinstaller --onefile fraud_detection/serve.py
```

The catch: the binary contains an *embedded* Python interpreter — not compiled to native code, it's an interpreter that extracts a bundled Python at runtime. Cold-start is noticeably worse. Same native-dep gotchas as PEX/Nuitka with ML libraries.

Better than Nuitka for "just work" reliability; worse than Nuitka for true compilation. Used for desktop Python apps; rarely for ML services.

### Comparison

| Approach | Final size (ML service) | Cold start | Reliability with numpy/sklearn | Closeness to Go pattern |
|---|---|---|---|---|
| `pip install` on full image | 1.5–3 GB | fast | high | not close |
| **Multi-stage venv copy** | 150–400 MB | fast | high | reasonable |
| **Multi-stage + distroless** | 50–200 MB | fast | high (with care) | close |
| PEX / shiv | 100–300 MB | fast | medium (C exts fiddly) | shape-similar |
| Nuitka | varies wildly | medium | low-medium for ML | spirit-similar |
| PyInstaller | 200–800 MB | slow | medium | shape-similar |

### Recommendation

- **ML services in production:** multi-stage venv copy + distroless (patterns 1 + 2). Closest practical analogue to Go's pattern, doesn't fight Python's nature, tooling is boring and well-understood.
- **Pure-Python CLI:** shiv or PEX for a single deployable file. Nuitka if true compilation matters and the dep tree is friendly.
- **ML training job on a beefy box:** don't optimise. A 2 GB image is fine if it ships once a day.

### The deeper lesson

Go's "compile to a single static binary" is possible because Go was designed with that as a first-class goal — no dynamic linking by default, runtime baked in, no separate interpreter. Python was designed for interactive use and incremental loading. Forcing it into Go's model fights the language.

The Python ecosystem's answer is **multi-stage builds + distroless**: keep the layers you need (interpreter, runtime libs), drop everything else (build tools, package manager, pip cache). You can't get to 10 MB, but 50 MB is good enough for most production purposes.

## The MLOps deployment cycle

For a typical project:

1. **Develop** in a venv. `pip install -e .` against local source.
2. **CI builds the wheel** on every tag. `python -m build` → `dist/fraud_detection-0.1.0-py3-none-any.whl`. Stored in an internal Python package index, or attached to the GitHub release.
3. **CI builds the image** from the wheel. `docker build -t fraud-detection:0.1.0 .` The Dockerfile copies the wheel from step 2 and installs it. Stored in the container registry.
4. **Deploy** the image. Kubernetes, Cloud Run, ECS — they all consume images, not wheels.
5. **Audit:** "what code was in production on 2026-05-15?" → which image tag was running → which wheel that image contains (`pip show fraud-detection` inside it) → which git tag the wheel was built from. Three layers of pin, all aligned.

### Why some teams skip wheels for ML

Smaller ML teams often build images directly from `src/`, no wheel intermediate:

```dockerfile
FROM python:3.12-slim
COPY pyproject.toml requirements.txt /app/
RUN pip install -r /app/requirements.txt
COPY src/ /app/src/
ENV PYTHONPATH=/app/src
ENTRYPOINT ["python", "/app/src/fraud_detection/serve.py"]
```

Works. Simpler. But costs:

- No way to distribute the code outside Docker.
- No version metadata baked in (`pip show` won't find it).
- Tests that import the package as installed (vs. PYTHONPATH hacks) are harder to set up.
- Image is the only artifact; if it's garbage-collected from the registry, you've lost the code unless you can rebuild from the git tag.

For a single-service ML project: defensible. For anything that grows past one service: the wheel + image stack pays back fast.

## See also

- [notes/python-packaging.md](python-packaging.md) — what wheels are, how `pyproject.toml` works.
- [Distroless containers](https://github.com/GoogleContainerTools/distroless) — official repo.
- [Docker multi-stage builds](https://docs.docker.com/build/building/multi-stage/) — official docs.
- `days/day-50/` onward (Domain 6) — will expand on these patterns with concrete labs.
