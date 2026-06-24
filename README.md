# grc_meta

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
creates `.venv`, installs the Python workspace packages, builds STSTv4 (pinned,
run against StringTemplate 4.3.4), runs `colcon build`, and writes
`ws/setup-grc.bash`.

Run the default pick-place GUI example with:

```bash
ws/src/grc_meta/script-run-example ws
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
/grc_meta/script-run-example ws
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
