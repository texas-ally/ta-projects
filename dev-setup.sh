#!/usr/bin/env bash
#
# Texas Ally — Developer Setup
#
# Interactive script to set up a local development environment.
# Clones repos, boots database, and optionally runs data imports.
#
# Usage:
#   ./dev-setup.sh              # Interactive setup
#   ./dev-setup.sh --all        # Clone all repos, skip prompts for repos
#   ./dev-setup.sh --db-clone   # Pull database from production (skip other steps)
#   ./dev-setup.sh --help       # Show help
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[✗]${NC} $1"; }
log_step()    { echo -e "\n${BLUE}${BOLD}── $1 ──${NC}\n"; }
log_substep() { echo -e "  ${CYAN}→${NC} $1"; }

# ─── Helpers ─────────────────────────────────────────────────────────────────
confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local yn
    if [ "$default" = "y" ]; then
        read -rp "$(echo -e "${CYAN}?${NC} ${prompt} [Y/n] ")" yn
        yn="${yn:-y}"
    else
        read -rp "$(echo -e "${CYAN}?${NC} ${prompt} [y/N] ")" yn
        yn="${yn:-n}"
    fi
    [[ "$yn" =~ ^[Yy] ]]
}

check_command() {
    if command -v "$1" &>/dev/null; then
        log_info "$1 found: $(command -v "$1")"
        return 0
    else
        log_error "$1 not found"
        return 1
    fi
}

clone_repo() {
    local url="$1"
    local dir="$2"
    if [ -d "$dir/.git" ]; then
        log_info "$dir/ already exists — pulling latest"
        (cd "$dir" && git pull --ff-only 2>/dev/null) || log_warn "$dir/ pull failed — may have local changes"
    else
        log_substep "Cloning $url → $dir/"
        git clone "$url" "$dir"
    fi
}

# ─── Production DB clone ────────────────────────────────────────────────────
pull_prod_db() {
    log_step "Clone database from production"

    local BACKUP_DIR="${SCRIPT_DIR}/backups"
    mkdir -p "$BACKUP_DIR"

    local TODAY
    TODAY=$(date +%Y-%m-%d)

    # Load saved production config from .env if available
    local saved_host saved_user saved_path
    saved_host=$(grep '^PROD_HOST=' .env 2>/dev/null | cut -d'=' -f2) || true
    saved_user=$(grep '^PROD_USER=' .env 2>/dev/null | cut -d'=' -f2) || true
    saved_path=$(grep '^PROD_TA_PATH=' .env 2>/dev/null | cut -d'=' -f2) || true

    # Ask for connection details
    local prod_host prod_user prod_path

    local host_default="${saved_host:-}"
    if [ -n "$host_default" ]; then
        read -rp "$(echo -e "${CYAN}?${NC} Production host [${host_default}]: ")" prod_host
        prod_host="${prod_host:-$host_default}"
    else
        read -rp "$(echo -e "${CYAN}?${NC} Production host (IP or hostname): ")" prod_host
    fi

    if [ -z "$prod_host" ]; then
        log_error "Host is required"
        return 1
    fi

    local user_default="${saved_user:-$(whoami)}"
    read -rp "$(echo -e "${CYAN}?${NC} SSH user [${user_default}]: ")" prod_user
    prod_user="${prod_user:-$user_default}"

    local path_default="${saved_path:-/home/lib/ta-projects}"
    read -rp "$(echo -e "${CYAN}?${NC} Remote ta-projects path [${path_default}]: ")" prod_path
    prod_path="${prod_path:-$path_default}"

    # Save config for next time
    for var in PROD_HOST PROD_USER PROD_TA_PATH; do
        sed -i "/^${var}=/d" .env 2>/dev/null || true
    done
    {
        echo "PROD_HOST=${prod_host}"
        echo "PROD_USER=${prod_user}"
        echo "PROD_TA_PATH=${prod_path}"
    } >> .env

    local REMOTE_BACKUP_DIR="${prod_path}/backups"
    local DUMP_FILE="ta-db-${TODAY}.dump"
    local LOCAL_DUMP="${BACKUP_DIR}/${DUMP_FILE}"

    # Check if we already downloaded today's backup
    if [ -f "$LOCAL_DUMP" ]; then
        local size
        size=$(du -sh "$LOCAL_DUMP" | cut -f1)
        log_info "Today's backup already exists locally: ${DUMP_FILE} (${size})"
        if ! confirm "Download a fresh backup from production?" "n"; then
            log_substep "Using existing backup"
            restore_prod_db "$LOCAL_DUMP"
            return $?
        fi
    fi

    echo ""
    log_substep "Connecting to ${prod_user}@${prod_host}..."
    echo -e "  ${YELLOW}(You may be prompted for your SSH password or key passphrase)${NC}"
    echo ""

    # Create backup dir on remote and generate or reuse today's dump
    log_substep "Checking for existing backup on production..."
    local REMOTE_HAS_BACKUP
    REMOTE_HAS_BACKUP=$(ssh "${prod_user}@${prod_host}" \
        "[ -f '${REMOTE_BACKUP_DIR}/${DUMP_FILE}' ] && echo 'yes' || echo 'no'") || {
        log_error "SSH connection failed. Check your host, user, and credentials."
        return 1
    }

    if [ "$REMOTE_HAS_BACKUP" = "yes" ]; then
        log_info "Today's backup already exists on production"
    else
        log_substep "Creating database backup on production..."
        ssh "${prod_user}@${prod_host}" \
            "mkdir -p '${REMOTE_BACKUP_DIR}' && \
             docker exec supabase-db pg_dump -U postgres -Fc --no-owner postgres \
             > '${REMOTE_BACKUP_DIR}/${DUMP_FILE}'" || {
            log_error "Remote pg_dump failed. Is supabase-db running on production?"
            return 1
        }
        log_info "Backup created on production"
    fi

    # Download
    log_substep "Downloading ${DUMP_FILE}..."
    scp "${prod_user}@${prod_host}:${REMOTE_BACKUP_DIR}/${DUMP_FILE}" "$LOCAL_DUMP" || {
        log_error "Download failed"
        return 1
    }
    local dl_size
    dl_size=$(du -sh "$LOCAL_DUMP" | cut -f1)
    log_info "Downloaded ${DUMP_FILE} (${dl_size})"

    restore_prod_db "$LOCAL_DUMP"
}

restore_prod_db() {
    local dump_file="$1"

    # Ensure local DB is running
    if ! docker ps --format '{{.Names}}' | grep -q '^supabase-db$'; then
        if [ -d "database" ]; then
            log_substep "Starting local database first..."
            (cd database && docker compose up -d)
            local retries=30
            until docker exec supabase-db pg_isready -U postgres &>/dev/null || [ $retries -eq 0 ]; do
                sleep 2
                ((retries--))
            done
            if [ $retries -eq 0 ]; then
                log_error "Local database did not start in time"
                return 1
            fi
        else
            log_error "database/ not found and supabase-db not running. Clone and start the database first."
            return 1
        fi
    fi

    echo ""
    log_warn "This will REPLACE all data in your local database."
    if ! confirm "Restore ${dump_file##*/} into local supabase-db?"; then
        log_warn "Skipped restore — backup saved at: ${dump_file}"
        return 0
    fi

    log_substep "Restoring database (this may take a few minutes)..."

    # Drop and recreate to get a clean slate
    docker exec supabase-db psql -U postgres -c "
        SELECT pg_terminate_backend(pid) FROM pg_stat_activity
        WHERE datname = 'postgres' AND pid <> pg_backend_pid();" &>/dev/null || true

    docker exec -i supabase-db pg_restore -U postgres -d postgres \
        --clean --if-exists --no-owner --no-privileges \
        < "$dump_file" 2>/dev/null || true
    # pg_restore returns non-zero on warnings (e.g., "role does not exist"), which is normal

    # Verify
    local table_count
    table_count=$(docker exec supabase-db psql -U postgres -d postgres -t \
        -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" | tr -d ' ')
    log_info "Restore complete — ${table_count} tables in public schema"

    local db_size
    db_size=$(docker exec supabase-db psql -U postgres -t \
        -c "SELECT pg_size_pretty(pg_database_size('postgres'));" | tr -d ' ')
    log_info "Local database size: ${db_size}"
}

# ─── Parse args ──────────────────────────────────────────────────────────────
CLONE_ALL=false
DB_CLONE_ONLY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --all) CLONE_ALL=true; shift ;;
        --db-clone) DB_CLONE_ONLY=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--all] [--db-clone] [--help]"
            echo ""
            echo "Options:"
            echo "  --all       Clone all repos without prompting"
            echo "  --db-clone  Pull a fresh database copy from production (standalone)"
            echo "  --help      Show this help"
            echo ""
            echo "API keys needed for data imports:"
            echo "  CENSUS_API_KEY  — https://api.census.gov/data/key_signup.html"
            echo "  HERE_API_KEY    — https://developer.here.com/"
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

# ─── Standalone db-clone mode ────────────────────────────────────────────────
if [ "$DB_CLONE_ONLY" = true ]; then
    echo ""
    echo -e "${BLUE}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║       Texas Ally — Production DB Clone           ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    pull_prod_db
    exit $?
fi

# ─── Banner ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║          Texas Ally — Developer Setup            ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ─── Step 1: Prerequisites ──────────────────────────────────────────────────
log_step "Step 1: Checking prerequisites"

MISSING=0
check_command git      || ((MISSING++))
check_command docker   || ((MISSING++))
check_command node     || ((MISSING++))
check_command npm      || ((MISSING++))

# Check Docker is running
if docker info &>/dev/null; then
    log_info "Docker daemon is running"
else
    log_error "Docker is installed but not running — start Docker first"
    ((MISSING++))
fi

# Optional: check for osm2pgsql (only needed for OSM import)
if command -v osm2pgsql &>/dev/null; then
    log_info "osm2pgsql found (needed for OSM import)"
else
    log_warn "osm2pgsql not found — OSM import will be unavailable"
fi

if [ "$MISSING" -gt 0 ]; then
    log_error "Missing $MISSING prerequisite(s). Install them and re-run."
    exit 1
fi

echo ""
log_info "All prerequisites met"

# ─── Step 2: Environment file ───────────────────────────────────────────────
log_step "Step 2: Environment configuration"

if [ -f .env ]; then
    log_info ".env already exists"
    if confirm "Overwrite .env with fresh template?" "n"; then
        cp .env.sample .env
        log_info "Copied .env.sample → .env"
    fi
else
    cp .env.sample .env
    log_info "Created .env from template"
    log_warn "Edit .env to add your API keys before running imports"
    echo ""
    echo -e "  Required for imports:"
    echo -e "    ${BOLD}CENSUS_API_KEY${NC}  — https://api.census.gov/data/key_signup.html"
    echo -e "    ${BOLD}HERE_API_KEY${NC}    — https://developer.here.com/"
    echo ""
    if confirm "Open .env in your editor now?" "n"; then
        ${EDITOR:-nano} .env
    fi
fi

# ─── Step 3: Clone repos ────────────────────────────────────────────────────
log_step "Step 3: Clone project repositories"

# Repo definitions: git_url:local_dir:description
CORE_REPOS=(
    "https://github.com/texas-ally/ta-database.git:database:Shared PostgreSQL/PostGIS database"
    "https://github.com/texas-ally/ta-shared-tools.git:ta-shared-tools:Import scripts and shared tooling"
    "https://github.com/texas-ally/ta_neighborhoods.git:ta-neighborhoods:Neighborhoods app (API + frontend)"
)

APP_REPOS=(
    "https://github.com/texas-ally/allymetrix.git:allymetrix:Alcohol sales analytics"
    "https://github.com/texas-ally/ta-schools.git:ta-schools:School ratings explorer"
)

INFRA_REPOS=(
    "https://github.com/texas-ally/vibe-n8n.git:vibe-n8n:n8n workflow automation"
    "https://github.com/texas-ally/vibe-zapier.git:vibe-zapier:Zapier integration"
)

clone_group() {
    local label="$1"
    shift
    local repos=("$@")
    echo -e "\n  ${BOLD}${label}:${NC}"
    for entry in "${repos[@]}"; do
        IFS=':' read -r url dir desc <<< "$entry"
        echo -e "    ${dir}/ — ${desc}"
    done
    echo ""
    if [ "$CLONE_ALL" = true ] || confirm "Clone ${label}?"; then
        for entry in "${repos[@]}"; do
            IFS=':' read -r url dir desc <<< "$entry"
            clone_repo "$url" "$dir"
        done
    else
        log_warn "Skipped ${label}"
    fi
}

clone_group "Core (required)" "${CORE_REPOS[@]}"
clone_group "App projects" "${APP_REPOS[@]}"
clone_group "Infrastructure" "${INFRA_REPOS[@]}"

# ─── Step 4: Distribute .env to sub-projects ────────────────────────────────
log_step "Step 4: Distribute environment config"

distribute_env() {
    local dir="$1"
    if [ -d "$dir" ] && [ -f "$dir/.env.sample" ] && [ ! -f "$dir/.env" ]; then
        # Copy relevant vars from root .env into project .env
        cp "$dir/.env.sample" "$dir/.env"
        # Overlay root .env values
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            if grep -q "^${key}=" "$dir/.env" 2>/dev/null; then
                sed -i "s|^${key}=.*|${key}=${value}|" "$dir/.env"
            fi
        done < .env
        log_info "Created $dir/.env from template + root values"
    elif [ -d "$dir" ] && [ -f "$dir/.env" ]; then
        log_info "$dir/.env already exists"
    fi
}

distribute_env "database"
distribute_env "ta-neighborhoods"
distribute_env "allymetrix"
distribute_env "ta-schools"
distribute_env "vibe-n8n"
distribute_env "vibe-zapier"

# ─── Step 5: Boot database ──────────────────────────────────────────────────
log_step "Step 5: Start database"

if [ ! -d "database" ]; then
    log_warn "database/ not cloned — skipping"
else
    if docker ps --format '{{.Names}}' | grep -q '^supabase-db$'; then
        log_info "supabase-db is already running"
    else
        log_substep "Starting PostgreSQL + Supabase services..."
        (cd database && docker compose up -d)
        echo ""
        log_substep "Waiting for database to be ready..."
        RETRIES=30
        until docker exec supabase-db pg_isready -U postgres &>/dev/null || [ $RETRIES -eq 0 ]; do
            sleep 2
            ((RETRIES--))
        done
        if [ $RETRIES -eq 0 ]; then
            log_error "Database did not become ready in time"
            exit 1
        fi
        log_info "Database is ready"
    fi

    # Run migrations
    log_substep "Applying database migrations..."
    for migration in database/migrations/*.sql; do
        if [ -f "$migration" ]; then
            name=$(basename "$migration")
            docker exec -i supabase-db psql -U postgres -d postgres < "$migration" &>/dev/null && \
                log_info "Applied $name" || \
                log_warn "$name — already applied or had warnings"
        fi
    done
fi

# ─── Step 6: Data imports (opt-in) ──────────────────────────────────────────
log_step "Step 6: Data imports"

if [ ! -d "ta-shared-tools/scripts/import" ]; then
    log_warn "ta-shared-tools/ not cloned — skipping imports"
else
    IMPORT_DIR="ta-shared-tools/scripts/import"

    echo -e "  You have two options to populate the database:\n"
    echo -e "  ${BOLD}Option A:${NC} Clone from production (fastest — pulls a pg_dump over SSH)"
    echo -e "  ${BOLD}Option B:${NC} Run import scripts from public data sources (slower, no SSH needed)\n"

    USE_PROD_CLONE=false
    if confirm "Clone database from production server?" "n"; then
        USE_PROD_CLONE=true
        pull_prod_db
    fi

    if [ "$USE_PROD_CLONE" = false ]; then

    echo -e "  Data imports populate the database from public sources."
    echo -e "  Some imports take a while. All are optional and can be re-run later.\n"

    # Group 1: Core geography (no API keys needed)
    echo -e "  ${BOLD}Core geography (no API keys needed):${NC}"
    echo -e "    1) TIGER boundaries — counties, places, ZCTAs (~2 min)"
    echo -e "    2) GeoNames places (~1 min)"
    echo -e "    3) OSM neighborhoods (requires osm2pgsql, ~10 min)"
    echo ""

    IMPORT_CORE_GEO=false
    if confirm "Run core geography imports (TIGER + GeoNames)?" "y"; then
        IMPORT_CORE_GEO=true
    fi

    IMPORT_OSM=false
    if command -v osm2pgsql &>/dev/null; then
        if confirm "Run OSM neighborhood import?" "n"; then
            IMPORT_OSM=true
        fi
    fi

    # Group 2: Build scripts (depend on core geography)
    echo ""
    echo -e "  ${BOLD}Build unified tables (depends on core geography):${NC}"
    echo -e "    4) Unified neighborhoods, cities, counties, ZIP codes"
    echo -e "    5) Zillow boundary merge"
    echo ""

    IMPORT_BUILD=false
    if confirm "Run build scripts after geography imports?" "y"; then
        IMPORT_BUILD=true
    fi

    # Group 3: Enrichment data (some need API keys)
    echo ""
    echo -e "  ${BOLD}Enrichment data:${NC}"
    echo -e "    6) Census ACS demographics (needs CENSUS_API_KEY)"
    echo -e "    7) BEA Regional Price Parities (no key)"
    echo -e "    8) BLS QCEW employment data (no key)"
    echo -e "    9) TxDOT traffic counts (no key)"
    echo -e "   10) TX property tax rates (no key)"
    echo -e "   11) TEA school data + TIGER school districts (no key)"
    echo ""

    IMPORT_ENRICHMENT=false
    if confirm "Run enrichment imports?" "n"; then
        IMPORT_ENRICHMENT=true
    fi

    # Group 4: HERE/POI data (needs HERE API key)
    echo ""
    echo -e "  ${BOLD}Points of interest (needs HERE_API_KEY):${NC}"
    echo -e "   12) HERE local resources lookup"
    echo -e "   13) Unified POI build"
    echo ""

    IMPORT_POI=false
    if confirm "Run HERE/POI imports?" "n"; then
        IMPORT_POI=true
    fi

    # Group 5: TX Open Data (TABC, sales tax — for Allymetrix)
    echo ""
    echo -e "  ${BOLD}Texas Open Data (TABC, sales tax — for Allymetrix):${NC}"
    echo -e "   14) TX Open Data import (no key, ~5 min)"
    echo ""

    IMPORT_TX_OPEN=false
    if confirm "Run TX Open Data import?" "n"; then
        IMPORT_TX_OPEN=true
    fi

    # Execute imports
    echo ""
    log_step "Running selected imports"

    run_import() {
        local script="$1"
        local label="$2"
        local path="${IMPORT_DIR}/${script}"
        if [ -x "$path" ]; then
            log_substep "Running: ${label}..."
            if "$path"; then
                log_info "${label} — done"
            else
                log_error "${label} — failed (continuing)"
            fi
        else
            log_warn "${script} not found or not executable"
        fi
    }

    if [ "$IMPORT_CORE_GEO" = true ]; then
        run_import "import-tiger.sh" "TIGER boundaries"
        run_import "import-geonames.sh" "GeoNames places"
    fi

    if [ "$IMPORT_OSM" = true ]; then
        run_import "import-osm.sh" "OSM neighborhoods"
    fi

    if [ "$IMPORT_BUILD" = true ]; then
        run_import "build-unified-neighborhoods.sh" "Unified neighborhoods"
        run_import "build-unified-cities.sh" "Unified cities"
        run_import "build-unified-counties.sh" "Unified counties"
        run_import "build-unified-zipCodes.sh" "Unified ZIP codes"
        run_import "import-zillow.sh" "Zillow boundaries"
        run_import "merge-zillow-polygons.sh" "Zillow polygon merge"
    fi

    if [ "$IMPORT_ENRICHMENT" = true ]; then
        run_import "import-census-acs.sh" "Census ACS demographics"
        run_import "import-bea-rpp.sh" "BEA Regional Price Parities"
        run_import "import-bls-qcew.sh" "BLS QCEW employment"
        run_import "import-txdot-aadt.sh" "TxDOT traffic counts"
        run_import "import-tax-rates.sh" "TX property tax rates"
        run_import "import-tea-schools.sh" "TEA school data"
        run_import "import-tiger-school-districts.sh" "TIGER school districts"
    fi

    if [ "$IMPORT_POI" = true ]; then
        run_import "import-here-resources.sh" "HERE local resources"
        run_import "build-unified-pois.sh" "Unified POIs"
    fi

    if [ "$IMPORT_TX_OPEN" = true ]; then
        run_import "import-tx-open-data.sh" "TX Open Data (TABC/sales tax)"
    fi

    fi # end of USE_PROD_CLONE=false branch
fi

# ─── Step 7: Install app dependencies ───────────────────────────────────────
log_step "Step 7: Install app dependencies"

install_app() {
    local dir="$1"
    local label="$2"
    if [ -d "$dir" ]; then
        if [ -d "$dir/api" ] && [ -f "$dir/api/package.json" ]; then
            log_substep "Installing $label API dependencies..."
            (cd "$dir/api" && npm install --silent)
        fi
        if [ -d "$dir/app" ] && [ -f "$dir/app/package.json" ]; then
            log_substep "Installing $label frontend dependencies..."
            (cd "$dir/app" && npm install --silent)
        fi
        log_info "$label dependencies installed"
    fi
}

if confirm "Install npm dependencies for cloned apps?"; then
    install_app "ta-neighborhoods" "Neighborhoods"
    install_app "allymetrix" "Allymetrix"
    install_app "ta-schools" "Schools"
else
    log_warn "Skipped — run 'npm install' in each app's api/ and app/ dirs when ready"
fi

# ─── Summary ────────────────────────────────────────────────────────────────
log_step "Setup complete"

echo -e "  ${BOLD}Services:${NC}"
echo -e "    PostgreSQL        → localhost:5432"
echo -e "    Supabase API      → localhost:8000"
echo -e "    Supabase Studio   → localhost:3001"
echo ""
echo -e "  ${BOLD}Start an app:${NC}"
echo -e "    cd ta-neighborhoods/api && npm start    # API on :3000"
echo -e "    cd ta-neighborhoods/app && npm run dev  # Frontend on :5173"
echo ""
echo -e "    cd allymetrix/api && npm start           # API on :3002"
echo -e "    cd allymetrix/app && npm run dev          # Frontend on :5174"
echo ""
echo -e "    cd ta-schools/api && npm start            # API on :3003"
echo -e "    cd ta-schools/app && npm run dev           # Frontend on :5175"
echo ""
echo -e "  ${BOLD}Refresh database from production:${NC}"
echo -e "    ./dev-setup.sh --db-clone"
echo ""
echo -e "  ${BOLD}Re-run imports from source:${NC}"
echo -e "    cd ta-shared-tools/scripts/import"
echo -e "    ./import-all.sh           # Core geography"
echo -e "    ./import-census-acs.sh    # Census demographics"
echo -e "    ./import-tx-open-data.sh  # TABC/sales tax data"
echo ""
echo -e "  ${BOLD}Git workflow:${NC}"
echo -e "    Each project is its own repo."
echo -e "    Branch from main, PR back when ready."
echo ""
log_info "Happy building!"
