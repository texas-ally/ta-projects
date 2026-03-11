# Texas Ally — Development Environment

Multi-project platform for Texas data analysis and visualization.

## Quick Start

```bash
git clone https://github.com/texas-ally/ta-projects.git
cd ta-projects
./dev-setup.sh
```

The setup script will walk you through:
1. Checking prerequisites (Docker, Node.js, git)
2. Creating your `.env` from the template
3. Cloning project repositories
4. Booting the shared database
5. Running data imports (opt-in, interactive)
6. Installing npm dependencies

## Platform Support

This project runs on **Linux** and **macOS**. The setup script requires bash, Docker, ssh/scp, and standard Unix tools.

**Windows users:** The script does not run natively on Windows. Use one of these:

| Method | Recommended? | Notes |
|--------|-------------|-------|
| **WSL2 (Ubuntu)** | Yes | Install from Microsoft Store, runs everything natively |
| **VirtualBox + Ubuntu** | Yes | Full Linux VM, what the lead dev uses in production |
| Git Bash | No | Partial support — docker path issues, ssh may work |
| PowerShell | No | Won't work |

For VirtualBox: install [Ubuntu Server](https://ubuntu.com/download/server) or Desktop, give it 4+ GB RAM and 40+ GB disk, install Docker and Node.js inside the VM, then clone and run.

## Dependencies

Install everything below before running `dev-setup.sh`. Commands are provided for **Ubuntu 24.04** and **macOS** (Homebrew).

### Core stack (required)

| Tool | Purpose | Version on prod |
|------|---------|-----------------|
| Docker + Compose | Database and services | 29.x / v5.x |
| Node.js 22+ (via nvm) | API servers and frontend builds | 22.22.0 |
| npm | Package management | 10.9.x |
| git | Source control | 2.48+ |
| curl, wget | Data downloads in import scripts | — |
| jq | JSON processing in scripts | 1.7 |
| unzip | Extract downloaded archives | — |
| ssh, scp | Production DB clone | — |

**Ubuntu 24.04:**

```bash
# System packages
sudo apt update && sudo apt install -y \
  git curl wget jq unzip openssh-client \
  build-essential ca-certificates gnupg

# Docker (official repo)
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER   # log out and back in after this

# Node.js 22 via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm install 22
nvm use 22
```

**macOS (Homebrew):**

```bash
brew install git curl wget jq unzip
brew install --cask docker   # Docker Desktop (includes Compose)

# Node.js 22 via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.zshrc
nvm install 22
nvm use 22
```

### PostgreSQL client tools (required for imports and db-clone)

| Tool | Purpose |
|------|---------|
| psql | Run SQL against the database |
| pg_dump / pg_restore | Database backup and restore |
| libpq-dev | PostgreSQL C library (needed by Python psycopg2) |

**Ubuntu 24.04:**

```bash
sudo apt install -y postgresql-client libpq-dev
```

**macOS:**

```bash
brew install libpq
brew link --force libpq
```

### GIS tools (required for geography imports)

| Tool | Purpose |
|------|---------|
| osm2pgsql | Import OpenStreetMap data into PostGIS |
| gdal-bin (ogr2ogr) | Convert shapefiles and geodata formats |

**Ubuntu 24.04:**

```bash
sudo apt install -y osm2pgsql gdal-bin
```

**macOS:**

```bash
brew install osm2pgsql gdal
```

### Python 3 + packages (required for scraping and data processing)

| Package | Purpose |
|---------|---------|
| python3, pip | Runtime and package manager |
| selenium | Browser automation for data scraping |
| requests | HTTP client for API calls |
| python3-venv | Virtual environments for import scripts |

**Ubuntu 24.04:**

```bash
sudo apt install -y python3 python3-pip python3-venv
pip3 install --user selenium requests
```

**macOS:**

```bash
brew install python@3.12
pip3 install selenium requests
```

### Google Chrome + ChromeDriver (required for Selenium scraping)

**Ubuntu 24.04:**

```bash
# Chrome
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | \
  sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update && sudo apt install -y google-chrome-stable

# ChromeDriver (auto-managed by Selenium 4.6+ — no manual install needed)
```

**macOS:**

```bash
brew install --cask google-chrome
# ChromeDriver is auto-managed by Selenium 4.6+
```

### GitHub CLI + Claude Code (for AI-assisted development)

| Tool | Purpose |
|------|---------|
| gh | GitHub PRs, issues, repo management from terminal |
| claude | Claude Code CLI — AI pair programming |

**Ubuntu 24.04:**

```bash
# GitHub CLI
(type -p wget >/dev/null || sudo apt install wget) && \
  sudo mkdir -p -m 755 /etc/apt/keyrings && \
  out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg && \
  cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
  sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
  sudo apt update && sudo apt install gh -y
gh auth login

# Claude Code
npm install -g @anthropic-ai/claude-code
```

**macOS:**

```bash
brew install gh
gh auth login

npm install -g @anthropic-ai/claude-code
```

### One-liner: install everything (Ubuntu 24.04)

```bash
# System packages (run as your user, not root)
sudo apt update && sudo apt install -y \
  git curl wget jq unzip openssh-client build-essential ca-certificates gnupg \
  postgresql-client libpq-dev osm2pgsql gdal-bin \
  python3 python3-pip python3-venv

# Python packages
pip3 install --user selenium requests

# Docker, Node.js, GitHub CLI, Claude Code — see sections above
# (these require adding external repos or running install scripts)
```

## API Keys

Some data imports require API keys. Add them to your `.env` file:

| Key | Source | Required for |
|-----|--------|-------------|
| `CENSUS_API_KEY` | [census.gov](https://api.census.gov/data/key_signup.html) | Demographics import (free, instant) |
| `HERE_API_KEY` | [developer.here.com](https://developer.here.com/) | Local resources & POI data |

## Project Structure

```
ta-projects/
├── database/           PostgreSQL 15 + PostGIS + pgvector (Supabase)
├── ta-neighborhoods/   Neighborhoods app — API (:3000) + Frontend (:5173)
├── allymetrix/         Alcohol sales analytics — API (:3002) + Frontend (:5174)
├── ta-schools/         School ratings explorer — API (:3003) + Frontend (:5175)
├── ta-shared-tools/    Import scripts, docs, design system
├── vibe-n8n/           n8n workflow automation
├── vibe-zapier/        Zapier integration
├── dev-setup.sh        This setup script
└── .env.sample         Environment template
```

Each project is its own git repo. This umbrella repo ties them together.

## Services

After running `dev-setup.sh`, these services are available:

| Service | URL | Purpose |
|---------|-----|---------|
| PostgreSQL | `localhost:5432` | Shared database |
| Supabase API | `localhost:8000` | REST API gateway (Kong) |
| Supabase Studio | `localhost:3001` | Database dashboard |

## Running Apps

```bash
# Neighborhoods
cd ta-neighborhoods/api && npm start     # API on :3000
cd ta-neighborhoods/app && npm run dev   # Frontend on :5173

# Allymetrix
cd allymetrix/api && npm start           # API on :3002
cd allymetrix/app && npm run dev         # Frontend on :5174

# Schools
cd ta-schools/api && npm start           # API on :3003
cd ta-schools/app && npm run dev         # Frontend on :5175
```

## Clone Database from Production

The fastest way to get a fully populated database — pulls a `pg_dump` from the production server over SSH:

```bash
# Standalone (re-run anytime for a fresh copy)
./dev-setup.sh --db-clone

# Or choose "Clone from production" during interactive setup
./dev-setup.sh
```

The script will:
- Ask for SSH host, user, and remote path (saved to `.env` for next time)
- Create or reuse today's backup on production (`backups/ta-db-YYYY-MM-DD.dump`)
- Download and restore into your local `supabase-db`

Backups are cached by date — re-running the same day reuses the existing dump unless you request a fresh one.

## Data Imports

Import scripts live in `ta-shared-tools/scripts/import/`. The setup script offers to run them interactively, or run them manually:

```bash
cd ta-shared-tools/scripts/import

# Core geography (no API keys)
./import-tiger.sh          # Census TIGER boundaries
./import-geonames.sh       # GeoNames places

# Build unified tables
./build-unified-neighborhoods.sh
./build-unified-cities.sh
./build-unified-counties.sh
./build-unified-zipCodes.sh

# Enrichment data
./import-census-acs.sh     # Demographics (needs CENSUS_API_KEY)
./import-bea-rpp.sh        # Cost of living
./import-bls-qcew.sh       # Employment data
./import-txdot-aadt.sh     # Traffic counts
./import-tax-rates.sh      # Property tax rates
./import-tea-schools.sh    # School ratings

# TABC/sales tax (for Allymetrix)
./import-tx-open-data.sh
```

## Git Workflow

Each project is its own repo under the [texas-ally](https://github.com/texas-ally) GitHub org:

- `main` — production-ready code
- `feature/*` — individual work, PR back to main

This umbrella repo (`ta-projects`) is cloned once to set up the workspace. Day-to-day git work happens inside each project repo.
