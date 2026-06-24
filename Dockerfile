# grc_meta dev image: a ROS 2 base with the non-ROS system packages that
# script-setup requires (it only checks for them, never installs). Build the
# workspace at runtime with script-setup; run it via script-docker, which wires
# up the host display + GPU.
ARG ROS_DISTRO=lyrical
FROM ros:${ROS_DISTRO}

# The same package list script-setup checks for. Already-present ones are no-ops.
# Keep apt's package lists (no rm of /var/lib/apt/lists): script-setup's
# `rosdep install` resolves and apt-installs a few more deps at runtime
# (e.g. libcppunit-dev), which needs the lists present.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ant \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    default-jre \
    git \
    libegl-dev \
    libeigen3-dev \
    libgl-dev \
    libglfw3-dev \
    liborocos-kdl-dev \
    liburdfdom-dev \
    liburdfdom-headers-dev \
    make \
    ninja-build \
    pkg-config \
    python3-pip \
    python3-venv \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool \
    unzip

# ros images already initialize rosdep; ensure it (no-op if present).
RUN rosdep init 2>/dev/null || true
