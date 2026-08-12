# grc_meta dev image: a ROS 2 base with the non-ROS system packages that
# script-setup requires (it only checks for them, never installs). Build the
# workspace at runtime with script-setup; run it via script-docker, which wires
# up the host display + GPU.
ARG ROS_DISTRO=lyrical
FROM ros:${ROS_DISTRO}

# Workspace packages plus ant/java required by `motion-spec setup`, and unzip
# for robif2b's Kortex auto-download (default colcon.meta builds the hardware
# backend; CI overrides that off via colcon.ci.meta).
# Keep apt's package lists (no rm of /var/lib/apt/lists): script-setup's
# `rosdep install` resolves and apt-installs a few more deps at runtime
# (e.g. libcppunit-dev), which needs the lists present.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ant \
    build-essential \
    ca-certificates \
    cmake \
    default-jre \
    git \
    libegl-dev \
    libeigen3-dev \
    libgl-dev \
    libglfw3-dev \
    liborocos-kdl-dev \
    libprotobuf-dev \
    libtomlplusplus-dev \
    liburdfdom-dev \
    liburdfdom-headers-dev \
    make \
    ninja-build \
    pkg-config \
    protobuf-compiler \
    python3-pip \
    python3-venv \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool \
    unzip \
    ros-${ROS_DISTRO}-rclcpp \
    ros-${ROS_DISTRO}-realtime-tools

# ros images already initialize rosdep; ensure it (no-op if present).
# uv for the workspace venv: script-setup uses it when present and falls back to venv+pip
# otherwise, so this only decides how fast setup is, not whether it works.
RUN pip3 install --no-cache-dir --break-system-packages uv

RUN rosdep init 2>/dev/null || true
