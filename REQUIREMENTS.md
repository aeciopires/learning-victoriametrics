<!-- TOC -->

- [Requirements](#requirements)
  - [Installed outside of mise](#installed-outside-of-mise)
  - [Installed by mise](#installed-by-mise)

<!-- TOC -->

# Requirements

For **Ubuntu**, follow the instructions to install softwares [softwares-ubuntu](softwares-ubuntu.md)

For **MacOS**, follow the instructions to install softwares [softwares-macos](softwares-macos.md)

## Installed outside of mise

| Software | Ubuntu | MacOS |
|---|---|---|
| Container runtime | Docker CE + ``docker compose`` plugin | Colima + ``docker`` CLI + ``docker-compose`` (Homebrew) |
| [mise](https://mise.jdx.dev) | ``curl https://mise.run \| sh`` | ``brew install mise`` |
| ``make``, ``curl``, ``gpg``, ``sudo`` | ``apt`` | Homebrew / MacOS |

## Installed by mise

The CLIs used by this repository are pinned in [mise.toml](mise.toml) and installed with ``mise install`` (``make up`` runs it automatically):

| Tool | Version |
|---|---|
| argocd | 3.6.1 |
| cmctl | 2.6.2 |
| helm | 4.3.2 (Helm 4 is required, Helm 3 is not supported) |
| jq | 1.8.2 |
| kind | 0.33.0 |
| kubectl | 1.37.2 |

The ``helm-diff`` and ``helm-secrets`` plugins are optional and installed with ``make helm-plugins`` (mise task ``helm-plugins``).

Run ``make requirements`` to check the softwares installed outside of mise and install the tools of [mise.toml](mise.toml).
