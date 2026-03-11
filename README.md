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

## Prerequisites

| Tool | Required | Notes |
|------|----------|-------|
| Linux or macOS | Yes | See platform support above for Windows |
| Docker | Yes | Database and services run in containers |
| Node.js 22+ | Yes | API and frontend builds (LTS recommended) |
| git | Yes | Source control |
| osm2pgsql | Optional | Only for OSM neighborhood import |

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
