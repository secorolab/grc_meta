# grc_meta

## setup

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
cp grc_meta/colcon.meta .
cp grc_meta/colcon_defaults.yaml .
```

## build

```bash
cd ~/ws
colcon build
```

