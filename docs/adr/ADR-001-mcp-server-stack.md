# ADR-001: Frank's MCP server — TypeScript, official MCP SDK, Streamable HTTP

**Status:** Accepted
**Date:** 2026-08

## Context

Frank is an MCP (Model Context Protocol) server: he exposes tools that MCP
clients — Claude Desktop, Claude Code, our Cloudscape console — can discover and
call. We must choose a language, framework, and transport.

Course constraints matter as much as production constraints: the stack must be
deeply **in-distribution** for coding agents (so Claude and Copilot build it
correctly on the first pass), quick to containerize, and simple for a mixed
class to debug in minutes, not hours.

## Decision

- **Language:** TypeScript on Node.js 22+.
- **MCP implementation:** the official `@modelcontextprotocol/sdk` package.
  No hand-rolled protocol code.
- **Transport:** Streamable HTTP (the current MCP remote transport), served by
  an Express app. Endpoint: `POST /mcp`. A plain `GET /healthz` returns 200 for
  container health probes.
- **Validation:** every tool's input schema is defined with `zod` and exported
  from a single `server/src/tools/` module per tool.
- **Config:** all settings via environment variables (`PORT`, plus the Azure and
  Anthropic settings introduced by later ADRs). No config files with values in them.
- **Layout:** `server/` is a self-contained npm package with `npm run dev`,
  `npm test`, `npm run build`, and a `Dockerfile`.

## Consequences

- TypeScript + Express + zod + official SDK is about as in-distribution as a
  stack gets; agents rarely hallucinate its APIs.
- Streamable HTTP lets one deployed Frank serve many clients concurrently —
  required for a classroom, and how real remote MCP servers ship.
- Node 22 aligns with the Copilot CLI's own requirement, so the class needs one runtime.
- Rejected: Python (fine, but splits the class across two toolchains once the
  Cloudscape UI forces Node anyway); stdio transport (local-only — Frank must be reachable on Azure).
