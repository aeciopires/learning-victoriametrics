<!-- TOC -->

- [Ubuntu](#ubuntu)
  - [Essentials](#essentials)
    - [Notes for Ubuntu 26.04](#notes-for-ubuntu-2604)
  - [Optionals](#optionals)
- [docker](#docker)
- [mise](#mise)
- [inotify limits](#inotify-limits)

<!-- TOC -->

Specific instructions for Ubuntu. What is common to every operating system (tools installed by mise, Helm plugins, kind, optional VSCode plugins) is in [REQUIREMENTS.md](REQUIREMENTS.md).

# Ubuntu

Supported versions (64 bits): **Ubuntu 26.04 LTS**, **24.04 LTS** and **22.04 LTS**. ``make requirements`` prints a warning on other Ubuntu versions.

## Essentials

Run the following commands:

```bash
sudo apt update
sudo apt install -y vim netcat-openbsd git elinks curl wget net-tools python3 python3-pip python3-venv python-is-python3 default-jdk make gnupg acl
```

> ``python-is-python3`` creates the ``/usr/bin/python`` symbolic link to the default ``python3`` of the release, whatever its version, so no ``update-alternatives`` is needed.

Optionally, install ``telnet`` (``sudo apt install -y telnet``). It's not required by this repository; ``nc`` (netcat-openbsd) covers the same port tests.

### Notes for Ubuntu 26.04

Ubuntu 26.04 replaced some core packages with Rust implementations: ``sudo`` is [sudo-rs](https://github.com/trifectatechfoundation/sudo-rs) and most of the core utilities come from [uutils coreutils](https://github.com/uutils/coreutils). The scripts of this repository (``Makefile``, ``run.sh`` and the ``helm-plugins`` mise task) only use common options of ``sudo``, ``sysctl``, ``tee``, ``tr``, ``uname``, ``mktemp`` and ``cat``, so they work with both implementations. If you hit an incompatibility, the original ``sudo`` (sudo.ws) and GNU coreutils are still packaged by Ubuntu, see the release notes of Ubuntu 26.04.

## Optionals

See the list of optional software and VSCode plugins in [REQUIREMENTS.md](REQUIREMENTS.md#optionals). On Ubuntu:

- Google Chrome: https://www.google.com/chrome/
- Visual Studio Code: https://code.visualstudio.com/docs/setup/linux

# docker

Docker and Docker Compose are installed outside of mise. Install Docker CE (Community Edition) following the instructions on the page: <https://docs.docker.com/engine/install/ubuntu/>. The convenience script also installs the ``docker compose`` plugin. Docker supports Ubuntu 22.04 (jammy), 24.04 (noble) and 26.04 (resolute).

```bash
curl -fsSL https://get.docker.com -o get-docker.sh;
sudo sh get-docker.sh;
sudo usermod -aG docker $USER;
sudo setfacl -m user:$USER:rw /var/run/docker.sock

docker version
docker compose version
```

Alternatively, if the Docker apt repository doesn't publish packages for your Ubuntu release (e.g. in the first weeks after a new release), install the Docker packages of the Ubuntu archive. They are older than Docker CE, but also provide ``docker compose``:

```bash
sudo apt install -y docker.io docker-compose-v2 docker-buildx
sudo usermod -aG docker $USER;
sudo setfacl -m user:$USER:rw /var/run/docker.sock
```

Reference: <https://docs.docker.com/engine/install/linux-postinstall/#configure-docker-to-start-on-boot>

# mise

Install mise and activate it in your shell:

```bash
curl https://mise.run | sh

echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc

mise --version
```

> If you use zsh, run ``echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc`` instead.

To update mise later, run ``mise self-update``.

Then install the tools of this repository: see [Tools installed by mise](REQUIREMENTS.md#tools-installed-by-mise).

# inotify limits

See why in [REQUIREMENTS.md](REQUIREMENTS.md#inotify-limits). ``run.sh`` raises the limits of the host only until the next reboot. To make the change permanent:

```bash
cat << EOF | sudo tee /etc/sysctl.d/99-kind-inotify.conf
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF

sudo sysctl --system
sysctl fs.inotify.max_user_watches fs.inotify.max_user_instances
```
