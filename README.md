# Gas Town on OpenClaw

Gas Town is a **multi-agent orchestration system** built on [OpenClaw](https://github.com/openclaw/openclaw) primitives. Inspired by industrial metaphors, Gas Town organizes AI agents into specialized worker roles that collaborate to execute complex workflows autonomously.

Gas Town leverages OpenClaw's session-based architecture to coordinate multiple agents, using persistent hooks and heartbeat-driven patrol loops to ensure work continues reliably across sessions, restarts, and interruptions.

## Table of Contents

- [Quick Start](#quick-start)
- [Architecture Overview](#architecture-overview)
- [Worker Roles](#worker-roles)
- [Key Concepts](#key-concepts)
- [Commands](#commands)
- [Formulas and Workflows](#formulas-and-workflows)
- [Configuration](#configuration)
- [Documentation](#documentation)

## Quick Start

### Prerequisites

- [OpenClaw](https://github.com/openclaw/openclaw) installed and configured
- `jq` for JSON processing
- Bash shell
- An LLM API proxy (or direct API access)

### Installation

**Option 1: Automated Install (Recommended)**

```bash
# Clone the repo
git clone https://github.com/codejeet/gastown.git
cd gastown

# Run the installer
./install.sh

# With custom LLM proxy settings
./install.sh \
  --proxy-url "http://127.0.0.1:3456/v1" \
  --model-id "claude-opus-4" \
  --api-key-env "LOCAL_LLM_KEY"

# Dry run to see what would happen
./install.sh --dry-run
```

The installer will:
1. Copy Gas Town scripts to `~/.openclaw/workspace/gastown/`
2. Register all agents (mayor, polecat-1, refinery, witness, deacon, dog-1, crew-1)
3. Set up model configs pointing to your LLM proxy
4. Display heartbeat cron schedules to configure

**Option 2: Manual Install**

1. Copy the `gastown` directory to your OpenClaw workspace:
   ```bash
   cp -r gastown $HOME/.openclaw/workspace/
   ```

2. Copy agent configs to OpenClaw agents directory:
   ```bash
   cp -r agents/* $HOME/.openclaw/agents/
   ```

3. Edit each agent's `models.json` to point to your LLM:
   ```bash
   # Template is at agents/models.template.json
   # Replace {{PROXY_URL}}, {{MODEL_ID}}, etc.
   ```

4. Restart OpenClaw gateway:
   ```bash
   openclaw gateway restart
   ```

### Post-Install Setup

1. **Set up heartbeat crons** (in OpenClaw):
   ```
   deacon:   */2 * * * *   (every 2 min)
   witness:  */5 * * * *   (every 5 min)
   mayor:    */5 * * * *   (every 5 min)
   refinery: */10 * * * *  (every 10 min)
   crew-1:   */15 * * * *  (every 15 min)
   ```

2. **Initialize Gas Town**:
   ```bash
   cd ~/.openclaw/workspace/gastown
   ./scripts/gt init
   ```

3. **Start the town**:
   ```bash
   ./scripts/gt-openclaw start
   ```

4. **Sling your first task**:
   ```bash
   ./scripts/gt sling "Fix the login bug" --to polecat
   ```

5. **Monitor progress**:
   ```bash
   ./scripts/gt status
   ./scripts/gt-openclaw dashboard
   ```

## Architecture Overview

```
                    ┌─────────────────────────────────────────┐
                    │              OVERSEER (You)             │
                    └─────────────────┬───────────────────────┘
                                      │ requests
                                      ▼
                    ┌─────────────────────────────────────────┐
                    │                 MAYOR                   │
                    │       (Concierge & Coordinator)         │
                    └───┬─────────────┬───────────────────┬───┘
                        │             │                   │
            ┌───────────┘             │                   └───────────┐
            ▼                         ▼                               ▼
    ┌───────────────┐       ┌─────────────────┐            ┌─────────────────┐
    │    POLECATS   │       │      CREW       │            │    REFINERY     │
    │   (Workers)   │       │   (Persistent)  │            │  (Merge Queue)  │
    └───────┬───────┘       └─────────────────┘            └────────┬────────┘
            │                                                       │
            │ work                                                  │ merges
            ▼                                                       ▼
    ┌───────────────┐                                      ┌─────────────────┐
    │   WITNESS     │◄────────── observes ─────────────────│      MAIN       │
    │  (Observer)   │                                      │     BRANCH      │
    └───────────────┘                                      └─────────────────┘
            │
            │ reports to
            ▼
    ┌───────────────┐       ┌─────────────────┐
    │    DEACON     │──────►│      DOGS       │
    │  (Heartbeat)  │       │   (Helpers)     │
    └───────────────┘       └─────────────────┘
```

### Core Components

- **MEOW Stack**: Molecular Expression of Work (Beads -> Molecules -> Formulas)
- **GUPP**: Gas Town Universal Propulsion Principle - "If there is work on your hook, YOU MUST RUN IT"
- **Convoys**: Work-order tracking and delivery units
- **Hooks**: Persistent work assignments that survive restarts

## Worker Roles

| Role | ID Pattern | Description |
|------|-----------|-------------|
| **Mayor** | `mayor` | Concierge and chief-of-staff. Receives requests, delegates work, monitors progress. Primary interface for the human overseer. |
| **Polecat** | `polecat-*` | Ephemeral swarm workers. Spawn, execute one task, submit work, terminate. Cattle, not pets. |
| **Refinery** | `refinery` | Merge queue manager. Processes MRs one at a time, handles conflicts, enforces quality gates. |
| **Witness** | `witness` | Observer role. Watches polecats and refinery, identifies stuck workers, triggers nudges or escalations. |
| **Deacon** | `deacon` | Daemon beacon. Runs the heartbeat system, propagates wake signals, maintains town health. |
| **Dog** | `dog-*` | Deacon helpers. Handle long-running maintenance tasks that would block the Deacon's patrol. |
| **Crew** | `crew-*` | Persistent workers for design, research, and interactive work requiring continuity. |

### Session Keys

Each worker operates in a dedicated OpenClaw session:
- `agent:mayor:main`
- `agent:polecat-{n}:main`
- `agent:refinery:main`
- `agent:witness:main`
- `agent:deacon:main`
- `agent:dog-{n}:main`
- `agent:crew-{name}:main`

## Key Concepts

### GUPP (Gas Town Universal Propulsion Principle)

Every worker has a **hook** - a persistent work assignment stored in Git. The GUPP rule ensures reliability:

> "If there is work on your hook, YOU MUST RUN IT."

Hooks survive session crashes, context compactions, and restarts. Workers check their hooks on every heartbeat and execute immediately without waiting for user input.

### The MEOW Stack

**Beads** - Atomic units of work (like issues):
```json
{"id":"bd-a1b2c3","title":"Fix login","status":"ready","assignee":"polecat-1"}
```

**Molecules** - Chained workflows with dependencies:
```json
{"id":"mol-x1y2","steps":["bd-a1b2c3","bd-d4e5f6"],"current":0}
```

**Formulas** - Reusable workflow templates in TOML:
```toml
[formula]
name = "feature"
steps = ["design", "implement", "test", "review"]
```

### Convoys

Every work unit is wrapped in a **Convoy** for tracking:
- Start time and duration
- Workers involved
- Status progression
- Activity feed as work progresses
- Completion notification

## Commands

### Basic CLI (`gt`)

```bash
# Initialize Gas Town
gt init

# Spawn a worker
gt spawn <role> [name]

# Sling work to a worker
gt sling "<task>" --to <worker>

# Nudge a worker (send heartbeat)
gt nudge <worker>

# Check a worker's hook
gt hook [worker]

# Get bead details
gt bead <id>

# Mark work complete
gt complete <bead-id> [worker]

# View town status
gt status

# View recent activity
gt activity [n]

# Manage rigs (projects)
gt rig add <path> [name]
gt rig list

# List convoys
gt convoy list
```

### OpenClaw Integration CLI (`gt-openclaw` / `gto`)

```bash
# Start Gas Town (spawn all workers, set up heartbeats)
gto start

# Stop Gas Town (remove crons)
gto stop

# Spawn a specific worker
gto spawn <role> [name]

# Spawn ephemeral polecat for a task
gto polecat "<task>"

# Spawn multiple polecats
gto swarm <count> "<task1>" "<task2>" ...

# Cook a formula into a molecule
gto cook <formula> var1=value1 var2=value2

# List available formulas
gto formulas

# Show dashboard
gto dashboard
```

## Formulas and Workflows

Gas Town includes pre-built formulas for common workflows:

### `feature` - Feature Implementation
Steps: design -> implement -> test -> review -> merge

### `bugfix` - Bug Fixes
Steps: investigate -> fix -> verify -> merge

### `release` - Release Process
Steps: prepare -> bump-version -> changelog -> build -> test-release -> tag -> gate-ci -> publish -> announce

### Creating Custom Formulas

Create a `.toml` file in `formulas/`:

```toml
[formula]
name = "my-workflow"
description = "Custom workflow"
version = "1.0"

[variables]
title = { required = true, description = "Task title" }

[[steps]]
id = "step1"
title = "First step: {{title}}"
role = "polecat"
instructions = "Do the first thing"
status = "ready"

[[steps]]
id = "step2"
title = "Second step: {{title}}"
role = "polecat"
depends_on = ["step1"]
status = "blocked"
```

## Configuration

### Directory Structure

```
gastown/
├── install.sh              # Automated installer
├── README.md               # This file
├── agents/                 # Agent templates
│   ├── models.template.json
│   ├── mayor/SOUL.md
│   ├── polecat/SOUL.md
│   ├── refinery/SOUL.md
│   ├── witness/SOUL.md
│   ├── deacon/SOUL.md
│   ├── dog/SOUL.md
│   └── crew/SOUL.md
├── config/
│   ├── town.json           # Town configuration
│   └── roles.json          # Role definitions and souls
├── beads/
│   ├── beads.jsonl         # Bead database (Git-tracked)
│   └── hooks.jsonl         # Worker hooks (GUPP)
├── molecules/
│   └── *.jsonl             # Active workflow instances
├── formulas/
│   └── *.toml              # Workflow templates
├── patrols/
│   └── *.md                # Patrol definitions
└── scripts/
    ├── gt                  # Basic CLI
    └── gt-openclaw         # OpenClaw integration CLI
```

### Installed Agents

After installation, you'll have these agents in `~/.openclaw/agents/`:

| Agent | Heartbeat | Purpose |
|-------|-----------|---------|
| `mayor` | */5 * * * * | Coordinator, delegates work |
| `polecat-1` | — | Ephemeral worker template |
| `refinery` | */10 * * * * | Merge queue manager |
| `witness` | */5 * * * * | Worker observer |
| `deacon` | */2 * * * * | Heartbeat daemon |
| `dog-1` | — | Deacon helper template |
| `crew-1` | */15 * * * * | Persistent worker |

### town.json

Configure town-level settings:
- `workspace`: Path to OpenClaw workspace
- `beadsPath`, `hooksPath`, `moleculesPath`: Data storage paths
- `settings.polecatPoolSize`: Maximum concurrent polecats
- `settings.mergeQueueBranch`: Target branch for merges

### roles.json

Define worker roles including:
- `soul`: System prompt for the agent
- `heartbeat`: Cron schedule for patrol loops
- `tools`: Available OpenClaw tools

## Documentation

### OpenClaw Resources

- [OpenClaw GitHub](https://github.com/openclaw/openclaw) - Main repository
- [OpenClaw Documentation](https://github.com/openclaw/openclaw/wiki) - Official wiki
- [OpenClaw Architecture Guide](https://vertu.com/ai-tools/openclaw-clawdbot-architecture-engineering-reliable-and-controllable-ai-agents/) - Deep dive into architecture

### Key OpenClaw Primitives Used

- **Sessions**: `sessions_spawn`, `sessions_send`, `sessions_list` for multi-agent coordination
- **Cron**: Heartbeat scheduling via `openclaw cron`
- **Agents**: Workspace-based agent isolation via `openclaw agents`
- **Tools**: Standard tool access (exec, read, write, edit, browser)

---

Gas Town brings industrial-scale orchestration to OpenClaw, enabling autonomous agent swarms that self-organize, self-heal, and deliver work reliably through the GUPP principle.
