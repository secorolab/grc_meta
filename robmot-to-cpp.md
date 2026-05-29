# .robmot to C++ Pipeline

A `.robmot` model goes through five stages:

```
.robmot → JSON-LD → IR (ir.json) → C++ → cmake build → ./main
```

The `Makefile` (in `bdd_collab_bhv_cpp/models/`) runs the whole chain.

---

## One-time setup

### 1. System packages

```bash
sudo apt install libglfw3-dev libgl-dev libegl-dev liborocos-kdl-dev
```

### 2. MuJoCo 3.8.0

Install to `/opt/mujoco-3.8.0` (or override later with `-DMUJOCO_ROOT=...`).

### 3. Python env

```bash
uv venv && source .venv/bin/activate          # or python3 -m venv .venv

uv pip install src/rdflib
uv pip install --no-deps -e src/motion-spec-dsl
uv pip install --no-deps -e src/motion-spec
uv pip install --no-deps -e src/coord-dsl
uv pip install --no-deps -e src/rdf-utils
uv pip install --no-deps "textX[cli]" jinja2 platformdirs pyshacl numpy
```

(Install `rdflib` first, then everything else with `--no-deps` so its version
doesn't get pulled forward.)

### 4. Metamodels (private branch — local checkout required)

```bash
git clone git@github.com:secorolab/metamodels.git -b feat/runtime-environment-metamodel
```

### 5. C++ workspace

```bash
ws=/path/to/workspace
mkdir -p $ws/src && cd $ws
colcon build --packages-up-to mj_kdl_wrapper
```

---

## Required environment variables

Two things must be in your shell environment before invoking `make`:

| Variable | What | Example |
|---|---|---|
| `METAMODELS_PATH` | Absolute path to the metamodels checkout (step 4). Read by the JSON-LD generator. | `export METAMODELS_PATH=$HOME/work/metamodels` |
| `INSTALL` | Absolute path to the colcon `install/` dir (step 5). Passed as `CMAKE_PREFIX_PATH`. | `export INSTALL=$ws/install` |

Both can also be passed inline (`make build MODEL=foo INSTALL=$ws/install`) —
exporting them once per shell is just less typing.

Optional: `OROCOS_DIR=/path/to/orocos_kdl` if you built KDL outside the
workspace.

---

## Running the pipeline

```bash
cd bdd_collab_bhv_cpp/models

make build MODEL=pick_place            # .robmot → executable
make run MODEL=pick_place              # build + run with viewer
make run-headless MODEL=pick_place     # build + run, no window
```

After the first build, iterate with:

```bash
make just-run MODEL=pick_place         # rebuild C++ only, run with viewer
make jrh MODEL=pick_place              # rebuild C++ only, run headless
```

---

## Makefile targets

The targets form a dependency chain — running any later target runs all
earlier ones it needs.

| Target | What it does |
|---|---|
| `check-deps` | Verify `textx` and `motion-spec-ir-gen` are on PATH |
| `jsonld` | `.robmot` → JSON-LD |
| `ir` | JSON-LD → `ir.json` |
| `codegen` | `ir.json` → C++ headers + `CMakeLists.txt` |
| `configure` | run `cmake` |
| `build` | compile to `gen/<MODEL>/build/main` |
| `run` / `run-headless` | execute the binary |
| `just-run` / `jrh` | rebuild C++ only (no regen), then run |
| `clean` | delete `gen/<MODEL>/` |

## Makefile variables

| Variable | Default | When to set |
|---|---|---|
| `MODEL` | — (required) | Pick the `.robmot` to build |
| `INSTALL` | `$(CURDIR)/install` | **Almost always override** — point at your colcon `install/` |
| `STEPS` | `45000` | Headless sim duration |
| `JOBS` | `$(nproc)` | Parallel build jobs |
| `STST` | `stst` | StringTemplate binary |
| `OROCOS_DIR` | — | Custom orocos_kdl location |
| `GEN` | `gen/$(MODEL)` | Output dir |
| `ROOT` | `$(CURDIR)` | Only used to derive `INSTALL` if you don't set it |
