# .robmot to C++ Translation Pipeline

## Required Packages

### System Dependencies

```bash
sudo apt install libglfw3-dev libgl-dev libegl-dev liborocos-kdl-dev
```

### MuJoCo

`mj_kdl_wrapper` has a `FETCH_MUJOCO=ON` CMake option to auto-download MuJoCo. See its repo for details.

### Python Packages

Install rdflib first, then the rest with `--no-deps` to prevent rdflib version changes, then install missing transitive deps explicitly:

```bash
pip install rdflib
pip install --no-deps -e $ROOT/src/motion-spec-dsl
pip install --no-deps -e $ROOT/src/motion-spec
pip install --no-deps -e $ROOT/src/coord-dsl
pip install --no-deps -e $ROOT/src/rdf-utils
pip install "textX[cli]" jinja2 platformdirs pyshacl numpy
```

### Metamodels

```bash
git clone git@github.com:secorolab/metamodels.git -b feat/runtime-environment-metamodel
export METAMODELS_PATH=/path/to/metamodels
```

Set `METAMODELS_PATH` to the cloned path (required by `jsonld` step). This branch is **not published online** — the local checkout is mandatory for resolving SHACL constraints and ontologies.

### C++ Dependencies (colcon build)

```bash
cd $ROOT
colcon build --packages-up-to mj_kdl_wrapper
```

## Translation Pipeline

All steps assume `MODEL` is set (e.g., `pick_place`), `GEN=gen/$(MODEL)`, and `METAMODELS_PATH` is exported.

### 1. JSON-LD Generation (`jsonld`)

```bash
textx generate $MODEL.robmot --target jsonld -o $GEN
```

Parses the `.robmot` DSL file using textX grammar from `motion_spec_dsl` and outputs JSON-LD (RDF) to `gen/$MODEL/$MODEL-app.json`. Requires `METAMODELS_PATH` to be set.

### 2. Intermediate Representation (`ir`)

```bash
motion-spec-ir-gen $GEN/$MODEL-app.json -o $GEN/ir.json
```

Validates the RDF graph using SHACL shapes and generates an intermediate representation (`ir.json`) with motion-spec metadata.

### 3. C++ Code Generation (`codegen`)

```bash
python -m motion_spec.codegen $GEN/ir.json -o $GEN --stst-bin stst
```

Generates C++ source files (headers in `$GEN/headers/`, `ref_main.cpp`, `CMakeLists.txt`) using StringTemplate templates bundled in `motion_spec`.

### 4. CMake Configure (`configure`)

The Makefile handles this — pass `ROOT` and optionally `OROCOS_DIR`:

```bash
make configure MODEL=<name> ROOT=/path/to/workspace \
    OROCOS_DIR=/path/to/orocos_kdl/share/orocos_kdl/cmake
```

Configures the CMake build with Eigen3, orocos-kdl, and mj_kdl_wrapper dependencies.

### 5. Build (`build`)

```bash
cmake --build $GEN/build --parallel $(nproc)
```

Compiles the generated C++ into a `main` executable.

### 6. Run (`run`)

```bash
$GEN/build/main                    # with GUI
$GEN/build/main --headless --steps 45000  # headless
```

## Makefile Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `MODEL`  | **yes** | Model name (matches `.robmot` file) |
| `ROOT`   | no | Defaults to `$(CURDIR)` |
| `GEN`    | no | Defaults to `gen/$(MODEL)` |
| `STST`   | no | StringTemplate binary (default: `stst`) |
| `STEPS`  | no | Headless sim steps (default: `45000`) |
| `JOBS`   | no | Parallel build jobs (default: `$(shell nproc)`) |
| `INSTALL`| no | CMake install prefix (default: `$(ROOT)/install`) |
| `OROCOS_DIR` | no | Path to orocos_kdl cmake config (needed for custom solver builds) |

## Makefile Targets (dependency chain)

```
build
  └─ configure
       └─ codegen
            └─ ir
                 └─ jsonld
                      ├─ check-deps
                      └─ *.robmot
```

| Target | Runs |
|--------|------|
| `make check-deps` | Verify tools on PATH |
| `make jsonld MODEL=<name>` | Step 1 only |
| `make ir MODEL=<name>` | Steps 1-2 |
| `make codegen MODEL=<name>` | Steps 1-3 |
| `make configure MODEL=<name> ROOT=<path>` | Steps 1-4 (add `OROCOS_DIR=...` for custom orocos) |
| `make build MODEL=<name> ROOT=<path>` | Steps 1-5 (default) |
| `make run MODEL=<name> ROOT=<path>` | Steps 1-6 (with GUI) |
| `make run-headless MODEL=<name> ROOT=<path>` | Steps 1-6 (headless) |
| `make just-run MODEL=<name> ROOT=<path>` | Rebuild and run (no full pipeline) |
| `make jrh MODEL=<name> ROOT=<path>` | Rebuild and run headless |
| `make clean MODEL=<name>` | Remove `$GEN/` entirely |
