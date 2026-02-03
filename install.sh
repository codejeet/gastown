#!/usr/bin/env bash
#
# Gas Town on OpenClaw - Installation Script
#
# This script registers Gas Town agents with OpenClaw and sets up heartbeat cron jobs.
#
# Usage:
#   ./install.sh [OPTIONS]
#
# Options:
#   --proxy-url URL      LLM proxy URL (default: http://127.0.0.1:3456/v1)
#   --model-id ID        Model ID (default: claude-opus-4)
#   --model-name NAME    Model display name (default: Claude Opus 4)
#   --api-key-env VAR    Env var name for API key (default: LOCAL_LLM_KEY)
#   --dry-run            Show what would be done without making changes
#   --help               Show this help
#
set -euo pipefail

# Defaults
PROXY_URL="${PROXY_URL:-http://127.0.0.1:3456/v1}"
MODEL_ID="${MODEL_ID:-claude-opus-4}"
MODEL_NAME="${MODEL_NAME:-Claude Opus 4}"
API_KEY_ENV="${API_KEY_ENV:-LOCAL_LLM_KEY}"
DRY_RUN=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --proxy-url)   PROXY_URL="$2"; shift 2 ;;
    --model-id)    MODEL_ID="$2"; shift 2 ;;
    --model-name)  MODEL_NAME="$2"; shift 2 ;;
    --api-key-env) API_KEY_ENV="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --help)
      head -25 "$0" | tail -n +2 | sed 's/^# \?//'
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_DIR="${HOME}/.openclaw"
AGENTS_DIR="${OPENCLAW_DIR}/agents"
WORKSPACE_DIR="${OPENCLAW_DIR}/workspace"
GASTOWN_DIR="${WORKSPACE_DIR}/gastown"

log_info "Gas Town on OpenClaw Installer"
log_info "=============================="
log_info "Proxy URL:    $PROXY_URL"
log_info "Model ID:     $MODEL_ID"
log_info "Model Name:   $MODEL_NAME"
log_info "API Key Env:  $API_KEY_ENV"
log_info "Dry Run:      $DRY_RUN"
echo

# Check OpenClaw exists
if [[ ! -d "$OPENCLAW_DIR" ]]; then
  log_error "OpenClaw not found at $OPENCLAW_DIR"
  log_error "Please install OpenClaw first: https://docs.openclaw.ai"
  exit 1
fi

# Agents to install (with heartbeat cron schedules)
declare -A AGENTS=(
  [mayor]="*/5 * * * *"
  [polecat]=""
  [refinery]="*/10 * * * *"
  [witness]="*/5 * * * *"
  [deacon]="*/2 * * * *"
  [dog]=""
  [crew]="*/15 * * * *"
)

# Generate models.json from template
generate_models_json() {
  local template="${SCRIPT_DIR}/agents/models.template.json"
  sed -e "s|{{PROXY_URL}}|$PROXY_URL|g" \
      -e "s|{{MODEL_ID}}|$MODEL_ID|g" \
      -e "s|{{MODEL_NAME}}|$MODEL_NAME|g" \
      -e "s|{{API_KEY_ENV}}|$API_KEY_ENV|g" \
      "$template"
}

# Install a single agent
install_agent() {
  local agent_id="$1"
  local heartbeat="${AGENTS[$agent_id]}"

  # For polecat/dog/crew, we create numbered instances
  local target_id="$agent_id"
  if [[ "$agent_id" == "polecat" || "$agent_id" == "dog" || "$agent_id" == "crew" ]]; then
    target_id="${agent_id}-1"
  fi

  local agent_dir="${AGENTS_DIR}/${target_id}"
  local source_dir="${SCRIPT_DIR}/agents/${agent_id}"

  log_info "Installing agent: $target_id"

  if $DRY_RUN; then
    log_info "  Would create: $agent_dir"
    log_info "  Would copy SOUL.md from: $source_dir"
    [[ -n "$heartbeat" ]] && log_info "  Would set heartbeat: $heartbeat"
    return
  fi

  # Create agent directory structure
  mkdir -p "${agent_dir}/agent"
  mkdir -p "${agent_dir}/sessions"

  # Generate models.json
  generate_models_json > "${agent_dir}/agent/models.json"

  # Create empty auth-profiles.json
  echo '{}' > "${agent_dir}/agent/auth-profiles.json"

  # Create empty sessions.json
  echo '{"sessions":[]}' > "${agent_dir}/sessions/sessions.json"

  # Copy SOUL.md if it exists
  if [[ -f "${source_dir}/SOUL.md" ]]; then
    cp "${source_dir}/SOUL.md" "${agent_dir}/SOUL.md"
  fi

  log_ok "Installed: $target_id"

  # Set up heartbeat cron if specified
  if [[ -n "$heartbeat" ]]; then
    setup_heartbeat "$target_id" "$heartbeat"
  fi
}

# Set up heartbeat cron job
setup_heartbeat() {
  local agent_id="$1"
  local schedule="$2"
  local heartbeat_prompt="Gas Town heartbeat. Check your hook. If work exists, run it. If nothing, reply HEARTBEAT_OK."

  log_info "  Setting heartbeat for $agent_id: $schedule"

  if $DRY_RUN; then
    return
  fi

  # Use OpenClaw's cron tool via CLI
  # Note: This assumes openclaw CLI is available
  if command -v openclaw &> /dev/null; then
    # Try to set up via the cron command
    # This is a simplified version - actual implementation depends on OpenClaw's cron API
    log_warn "  Heartbeat cron setup requires manual configuration or running inside OpenClaw"
    log_info "  Schedule: $schedule"
    log_info "  Agent: $agent_id"
  else
    log_warn "  OpenClaw CLI not found in PATH, skipping cron setup"
  fi
}

# Copy Gas Town scripts to workspace
install_gastown_scripts() {
  log_info "Installing Gas Town scripts to workspace..."

  if $DRY_RUN; then
    log_info "  Would copy scripts to: $GASTOWN_DIR"
    return
  fi

  mkdir -p "$GASTOWN_DIR"

  # Copy everything except agents/ (those go to ~/.openclaw/agents/)
  for item in "$SCRIPT_DIR"/*; do
    local name=$(basename "$item")
    [[ "$name" == "agents" ]] && continue
    [[ "$name" == "install.sh" ]] && continue

    if [[ -d "$item" ]]; then
      cp -r "$item" "${GASTOWN_DIR}/"
    else
      cp "$item" "${GASTOWN_DIR}/"
    fi
  done

  # Make scripts executable
  chmod +x "${GASTOWN_DIR}/scripts/"* 2>/dev/null || true

  log_ok "Gas Town scripts installed to: $GASTOWN_DIR"
}

# Main installation
main() {
  echo
  log_info "Step 1: Installing Gas Town scripts..."
  install_gastown_scripts

  echo
  log_info "Step 2: Installing agents..."
  for agent_id in "${!AGENTS[@]}"; do
    install_agent "$agent_id"
  done

  echo
  log_ok "Installation complete!"
  echo
  log_info "Next steps:"
  log_info "1. Restart OpenClaw gateway: openclaw gateway restart"
  log_info "2. Verify agents: Check the OpenClaw dashboard"
  log_info "3. Set up heartbeats manually via OpenClaw's cron tool"
  log_info ""
  log_info "Heartbeat schedules needed:"
  for agent_id in "${!AGENTS[@]}"; do
    local heartbeat="${AGENTS[$agent_id]}"
    if [[ -n "$heartbeat" ]]; then
      local target_id="$agent_id"
      [[ "$agent_id" == "crew" ]] && target_id="crew-1"
      echo "   $target_id: $heartbeat"
    fi
  done
  echo
  log_info "Quick test:"
  log_info "  cd $GASTOWN_DIR && ./scripts/gt status"
}

main
