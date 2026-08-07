# grc_meta

[![Jazzy (Ubuntu 24.04)](https://github.com/secorolab/grc_meta/actions/workflows/jazzy.yml/badge.svg)](https://github.com/secorolab/grc_meta/actions/workflows/jazzy.yml)
[![Lyrical (Ubuntu 26.04)](https://github.com/secorolab/grc_meta/actions/workflows/lyrical.yml/badge.svg)](https://github.com/secorolab/grc_meta/actions/workflows/lyrical.yml)

## setup

### scripted setup

```bash
mkdir -p ws/src
git clone git@github.com:secorolab/grc_meta.git ws/src/grc_meta
ros_distro=jazzy
ws/src/grc_meta/script-setup ws "$ros_distro"
```

For a ROS Docker image or a machine without GitHub SSH configured, use HTTPS
repository URLs:

```bash
GRC_GIT_TRANSPORT=https ws/src/grc_meta/script-setup ws "$ros_distro"
```

The setup script requires an existing ROS 2 distro at `/opt/ros/$ros_distro`.
It checks for the required non-ROS system packages and, if any are missing,
prints the `apt-get install` line and exits so you can install them (the only
step needing sudo) and rerun. It then imports the workspace repositories,
creates `.venv`, installs the Python workspace packages, runs `colcon build`, and writes
`ws/setup-grc.<ext>` (`.zsh` when `$SHELL` is zsh, `.bash` otherwise).

**Modes:**

| Flag | What it does |
|------|-------------|
| *(none)* | Full setup: import, fast-forward, rosdep, venv, and build |
| `--ff` | Fast-forward repos and submodules only (skip rosdep/venv/build) |
| `--build` | Rebuild only (skip import/ff/submodules — assumes already set up) |

Example — fast-forward existing repos without rebuilding:
```bash
ws/src/grc_meta/script-setup --ff ws "$ros_distro"
```

Example — rebuild after pulling:
```bash
ws/src/grc_meta/script-setup --build ws "$ros_distro"
```

Source the generated environment, install STST through the motion-spec CLI, and
check the target dependencies:

```bash
source ws/setup-grc.bash          # or .zsh
motion-spec setup --prefix "$GRC_WS"
motion-spec health --target mujoco
```

Run a model directly through the CLI. Each invocation creates a uniquely named
generation with its build and recorded runs:

```bash
cd "$GRC_WS/src/motion-spec"
motion-spec run \
  "$GRC_WS/src/motion-spec-dsl/models/pick_place_single/pick_place_single.robmot" \
  --prefix "$GRC_WS/install" \
  --headless
```

### docker

`script-docker` builds a dev image from the `Dockerfile` (a ROS 2 base with the
required system packages preinstalled) and runs it with the host display and GPU
forwarded, so the MuJoCo GUI renders on your screen. It auto-detects X11 vs
Wayland (and sets `DISPLAY`/`WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR` accordingly) and
NVIDIA (`--gpus all`) vs Intel/AMD (`/dev/dri`).

```bash
# from this grc_meta checkout; ROS_DISTRO defaults to lyrical
ws/src/grc_meta/script-docker            # build image + interactive shell

# then inside the container:
GRC_GIT_TRANSPORT=https /grc_meta/script-setup ws lyrical
source ws/setup-grc.bash
motion-spec setup --prefix "$GRC_WS"
motion-spec health --target mujoco
```

### workspace

```bash
mkdir -p ws/src
cd ws/src
git clone git@github.com:secorolab/grc_meta.git
vcs import < grc_meta/grc_meta.repos
```

### colcon setup

```bash
cd ~/ws
cp src/grc_meta/colcon.meta .
cp src/grc_meta/colcon_defaults.yaml .
```

## build

```bash
cd ~/ws
colcon build
```

## known issues

- **admittance_arc_single fails to build on Lyrical.** Its ROS-publish monitor
  (`also publish to topic ...`) generates code against `realtime_tools`'
  deprecated `RealtimePublisher` API (`trylock()` / `msg_` / `unlockAndPublish()`),
  which Lyrical's newer `realtime_tools` removed. Jazzy still has it (deprecated)
  so Jazzy CI passes. Fix: update motion-spec's codegen template
  (`src/motion_spec/templates/assembly_loop.stg`, `domain_monitors.stg`) to emit
  `try_publish(msg)` instead — supported on both distros, not a compat shim.
