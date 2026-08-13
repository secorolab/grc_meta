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

Repositories are brought up to date by the same rules `$GRC sync` uses (`repo-update.sh`,
shared by both): push when ahead, stash/fast-forward/pop when behind, never a merge
commit. A repo that has diverged or whose stash conflicts is reported at the end and
does not abort the setup.

**Modes:**

| Flag | What it does |
|------|-------------|
| *(none)* | Full setup: import, fast-forward, rosdep, venv, and build |
| `--ff` | Update repos and submodules, then build only the packages that moved (skip rosdep/venv) |
| `--build` | Rebuild with colcon and refresh the editable Python installs (skip import/update) |

Example — update existing repos and rebuild what moved:
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

## $GRC

The generated environment exports one entry point, so a sourced shell never needs the
script paths, the workspace path or the distro:

| Command | What it does |
|---------|--------------|
| `$GRC setup [flags] [<ws> <distro>]` | Full setup; flags (`--clean`, `--ff`, `--build`) pass through |
| `$GRC sync` | Update every repo to what `grc_meta.repos` declares, rebuild what moved |
| `$GRC build` | `colcon build` the whole workspace and refresh the editable Python installs |
| `$GRC mj` | Rebuild `mj_kdl_wrapper` alone: colcon package and venv bindings |

Workspace and distro default to the sourced environment, so `$GRC setup --clean` is
the full invocation with nothing to remember.

## sync

`script-sync` (`$GRC sync`) brings an already-set-up workspace up to date and rebuilds
only what moved.

It checks grc_meta first — a stale `grc_meta.repos` would sync everything else to
older versions — and stops after updating itself so the rerun reads the new file.
Then, per repo, the declared version decides what outdated means:

| Declared version | Check | Action |
|------------------|-------|--------|
| a tag | is the checkout on that tag? | check it out (a moved pin downgrades too) |
| anything else | is the current branch behind its upstream? | fast-forward it |

A branch that is *ahead* of its upstream is pushed instead of pulled, so local commits
are published rather than left behind. Nothing is rebuilt for a push: publishing
commits does not change the checkout.

**No merge commits, ever.** Every update is `--ff-only`. A branch that is both ahead
and behind is left exactly as it is — reconciling it means a merge or a rebase, and
which one is yours to choose.

**No repo ever loses local work.** Uncommitted changes in a repo that has to move are
stashed, the update runs, and the stash is popped back. Only tracked changes are
stashed: an untracked file survives a checkout untouched, so it is left alone. A repo
that is already where it belongs is never stashed at all.

When a pop conflicts, the stash entry is kept, the working tree is reset to the clean
updated checkout — otherwise the rebuild would compile the conflict markers — and the
repo is reported at the end alongside anything else that could not be updated:

```
Could not update 2 repositories:
  pop_conflict: stashed changes conflict with origin/main -- git -C .../pop_conflict stash pop
  diverged: diverged from origin/main -- merge or rebase it yourself

Fix the conflicts, then rerun the sync:
  .../script-sync
```

That report comes *after* the rebuild and exits 1. Repos that did sync are rebuilt
first on purpose: one that moved but never got rebuilt would look up to date to the
rerun, and its build would be skipped for good.

A tag-pinned repo sitting on a *branch* is also left alone — `vcs import` leaves a
pinned repo detached, so a branch there is deliberate work that moving onto the tag
would silently detach.

A repo declared but not checked out is an error — it needs rosdep and the Python
install, so run `script-setup`. Repos that moved are rebuilt with `colcon build`, and
`mj_kdl_wrapper` through the script below.

`mj_kdl_wrapper` is checked by what is **installed**, not by what git says: it is
compiled into `install/` and the venv rather than used from the checkout, so those
can be stale while git reports nothing to do. The source `MJ_KDL_VERSION` is compared
against the installed `PACKAGE_VERSION` and `mj_kdl_wrapper.__version__` (which the
compiled extension reports), and any mismatch triggers the rebuild.

## rebuild mj_kdl_wrapper

`script-mj-kdl-wrapper` (`$GRC mj`) rebuilds that one package after a local edit or a version
bump. It is the only workspace package that compiles twice — the colcon package
into `install/` via CMake, and the Python bindings into the workspace venv via
scikit-build-core — so both steps run. It needs the workspace environment sourced,
and passes extra arguments through to `colcon build`.

```bash
source ws/setup-grc.bash          # or .zsh
"$GRC" mj
"$GRC" mj --cmake-clean-cache
```

## known issues

- **admittance_arc_single fails to build on Lyrical.** Its ROS-publish monitor
  (`also publish to topic ...`) generates code against `realtime_tools`'
  deprecated `RealtimePublisher` API (`trylock()` / `msg_` / `unlockAndPublish()`),
  which Lyrical's newer `realtime_tools` removed. Jazzy still has it (deprecated)
  so Jazzy CI passes. Fix: update motion-spec's codegen template
  (`src/motion_spec/templates/assembly_loop.stg`, `domain_monitors.stg`) to emit
  `try_publish(msg)` instead — supported on both distros, not a compat shim.
