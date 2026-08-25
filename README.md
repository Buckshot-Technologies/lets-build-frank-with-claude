# Let's Build Frank — with Claude (& Copilot)

A one-day, hands-on engineering course from **Buckshot Technologies**.

By 5pm you will have designed, built, deployed, and **talked to** a real system —
**Frank**, an MCP server with a Cloudscape web console, running in your own Azure
subscription — using Claude and GitHub Copilot as your engineering team.

---

## Why this course exists

AI coding has crossed a threshold. Agents no longer just autocomplete lines —
they plan features, write and test code, drive CI/CD, and help operate running
systems. That changes the engineer's job: from writing every line to **directing
teams of agents well**.

This course teaches that job, hands-on:

1. **Foundations** — what an LLM actually is, what *weights* are, and why
   *in-distribution vs. out-of-distribution* decides where agents are brilliant
   and where they confidently guess. Your organization's private conventions are
   out-of-distribution *by definition* — the winning move is to write them down
   (ADRs, `CLAUDE.md`, skills, rules) so every agent session starts in-distribution.
2. **The Claude surfaces** — Desktop (connections, scheduled tasks, skills),
   Claude Code in the terminal and in VS Code, herdr for running fleets of
   agents, and the mobile app for remote control.
3. **Project Frank** — ADR-driven design → build → deploy → operate, using
   Claude and Copilot *adversarially*: one proposes, the other attacks, you referee.
4. **Enterprise & security** — API keys, AWS Bedrock and Microsoft Foundry,
   scoped PATs, vaulted secrets, and least-privilege agents.

The repo you are reading is the classroom. Fork it and build.

## Meet Frank

Frank is:

- an **MCP server** (Model Context Protocol) exposing tools that any AI client —
  Claude Desktop, Claude Code, the Cloudscape UI — can discover and call;
- a **Cloudscape web console** for talking to Frank directly;
- deployed to **Azure** through the GitHub Actions pipeline in this repo;
- granted **read-only** access to the Azure environment he runs in, so he can
  report on his own world (*"Frank, what's running in your resource group?"*).

The core architecture decisions are already made and recorded in
[`docs/adr/`](docs/adr/). During the class you will write two more ADRs —
connecting Frank to the GitHub pipeline, and granting him read access to Azure —
and have the agents implement them.

## What you need before class

### Accounts & credentials

| What | Why |
|---|---|
| **GitHub account** | You'll fork this repo and run its Actions pipeline |
| **GitHub Copilot subscription** | Powers the Copilot CLI, our second agent |
| **Azure subscription** | Frank's home. A personal/dev subscription is fine |
| **Azure deploy credentials** | A service principal (or OIDC federation) scoped to one resource group, added as secrets **in your fork** — see below |
| **Claude account** | Sign-in for Claude Desktop, Claude Code, and mobile |
| **Anthropic API key** | We generate this together in the afternoon — don't worry about it yet |

### Installed on your laptop

```bash
# Claude Code (CLI)
npm install -g @anthropic-ai/claude-code

# GitHub Copilot CLI  (Node.js 22+)
npm install -g @github/copilot
```

Also install:

- **Claude Desktop** — https://claude.com/download
- **herdr** — agent-aware terminal multiplexer — https://herdr.dev
- **VS Code** + the **Claude Code** extension
- **git**, **GitHub CLI (`gh`)**, **Node.js 22+**
- **Claude mobile app** (iOS/Android) — for the remote-control segment

Verify before class:

```bash
claude --version
copilot --version
herdr --version
gh auth status
az login    # Azure CLI, logged into your subscription
```

## Getting started (we do this together in class)

```bash
# 1 — fork under YOUR account, and clone
gh repo fork Buckshot-Technologies/lets-build-frank-with-claude --clone
cd lets-build-frank-with-claude

# 2 — start Claude Code inside the repo
claude

# 3 — scaffold CLAUDE.md + .claude/ for THIS project
> /init
```

Then, in **your fork's** GitHub settings → *Secrets and variables → Actions*,
add the Azure credentials the pipeline needs (see
[ADR-005](docs/adr/ADR-005-github-actions-deployment.md)):

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

> **Never** commit credentials to the repo, paste them into prompts, or put them
> in `CLAUDE.md` or an ADR. Secrets live in GitHub Actions secrets and Azure —
> nowhere else.

## Repo layout

```
.
├── README.md                  ← you are here
├── docs/
│   └── adr/                   ← the decisions Frank is built from
├── .github/
│   └── workflows/
│       └── deploy.yml         ← build → test → deploy pipeline (you feed it secrets)
├── server/                    ← Frank's MCP server   (built in class, per ADR-001/002)
├── ui/                        ← Cloudscape console   (built in class, per ADR-003)
├── CLAUDE.md                  ← created by /init, then curated by YOU
└── .claude/                   ← skills, rules, commands (authored in class)
```

`server/` and `ui/` start empty on purpose — the agents build them from the ADRs.
That's the point of the course.

## The ADRs

| ADR | Decision | Status |
|---|---|---|
| [ADR-000](docs/adr/ADR-000-record-architecture-decisions.md) | We record decisions as ADRs (and why that matters for agents) | Accepted |
| [ADR-001](docs/adr/ADR-001-mcp-server-stack.md) | Frank's stack: TypeScript + official MCP SDK, Streamable HTTP | Accepted |
| [ADR-002](docs/adr/ADR-002-mcp-tool-conventions.md) | Tool naming, schemas, and the read-only rule | Accepted |
| [ADR-003](docs/adr/ADR-003-cloudscape-ui.md) | The console: React + Vite + Cloudscape | Accepted |
| [ADR-004](docs/adr/ADR-004-azure-hosting.md) | Hosting: Container Apps (Frank) + Static Web Apps (UI) | Accepted |
| [ADR-005](docs/adr/ADR-005-github-actions-deployment.md) | Deployment: GitHub Actions with OIDC to Azure | Accepted |
| ADR-006 | Connect Frank to the GitHub pipeline | **You write this in class** |
| ADR-007 | Grant Frank read access to his Azure environment | **You write this in class** |

## Ground rules (security)

- Fine-grained PATs only, minimal scopes, short expiry — and only if a step truly needs one.
- Deploy identity is scoped to **one resource group**.
- Frank **reads** Azure; he does not write. Expansions of scope require an ADR.
- Claude Code permission prompts stay **on** for destructive actions.
- Branch protection on `main`; agents propose, cross-model review helps, a human merges.

## During class, you will

1. Tour and configure every Claude surface (Desktop, CLI + herdr, VS Code, mobile).
2. Fork this repo, run `/init`, and curate `CLAUDE.md` into real team config.
3. Author a skill, a rules entry, and a `/adr` command in `.claude/`.
4. Draft ADR-006 and ADR-007 — Claude drafts, Copilot attacks, you decide.
5. Build Frank and the UI, push, and watch the pipeline ship them to Azure.
6. Add Frank as a connector in Claude Desktop and ask him about his own world.

Bring a laptop, bring credentials, bring skepticism. The agents will supply the
confidence — your job is to supply the judgment.

---

*Questions before class? Open an issue on this repo.*
