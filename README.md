# bagitops

A lightweight GitOps deployment utility. Pull a Docker image stored as split chunks in a Git repo, load it into Docker, and start containers — all in one command.

## How it works

1. **pull** — clones/updates a Git repo, reassembles `image.tar.part.*` chunks into a Docker image, and loads it into Docker
2. **run** — starts containers using the `docker-compose.yml` found in the pulled repo

The app repo is expected to contain:
- `image.tar.part.*` — Docker image split into ordered chunks
- `docker-compose.yml` — compose file used to start the containers

## Requirements

- `git`
- `docker` (with `docker compose` or `docker-compose`)

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/bakoly/gitops-deploy/main/install.sh | bash
```

Or clone and run manually:

```bash
git clone https://github.com/bakoly/gitops-deploy.git
bash gitops-deploy/install.sh
```

This installs `bagitops` to `/usr/local/bin` and stores the CLI under `~/.bagitops/cli`.

## Usage

```
bagitops pull <git-repo-url> [--ssh-key <path>]
bagitops run
bagitops update
bagitops uninstall
```

### Commands

| Command | Description |
|---|---|
| `pull <url>` | Clone/update the app repo, assemble image chunks, load into Docker |
| `run` | Start containers via `docker-compose.yml` in the pulled repo |
| `update` | Pull the latest `bagitops` CLI from its own repo |
| `uninstall` | Remove `bagitops` and all its data from `~/.bagitops` |

### Options

| Option | Description |
|---|---|
| `--ssh-key <path>` | Path to an SSH private key for authenticated Git clones |

## Examples

```bash
# Pull and deploy from a public repo
bagitops pull https://github.com/your-org/your-app-repo.git
bagitops run

# Pull from a private repo using SSH
bagitops pull git@github.com:your-org/your-app-repo.git --ssh-key ~/.ssh/deploy_key
bagitops run
```

## Data directory

bagitops stores its state under `~/.bagitops/`:

```
~/.bagitops/
  cli/       # bagitops CLI source (managed by install/update)
  repo/      # last pulled app repo
  config     # saved repo URL, SSH key, and repo path
```
