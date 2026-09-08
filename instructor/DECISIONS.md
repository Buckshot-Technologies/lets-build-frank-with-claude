# Course decisions — what was decided, and what each decision killed

**Why this file exists.** Course decisions were made in conversation and applied
by memory. That failed three times in one week: the seat card survived a purge
of seat cards, `az login` survived a purge of Azure prerequisites, and the
hello-frank warm-up server survived being deleted. Each time the fix was to grep
for the *old wording* — which finds the old wording, not the old assumption.

**How to use it.** Before any teaching artifact ships, walk this list and ask of
each row: *does the README, the deck, the runbook, or PROMPTS.md still assume the
dead thing?* Check against the decision, never against remembered vocabulary.
The "killed" column is the important one — that is what leaks.

Architecture decisions live in [`docs/adr/`](../docs/adr/). This file is for
decisions about **the course**: what is taught, in what order, and why.

---

## D-01 — Course intent

> Demystify AI-assisted software delivery for a mixed-skill audience by showing
> that people direct Claude with prompts, architecture, context, tools and
> review — not by trusting a chatbot to magically write production software.

Audience runs from chat-only users to people who could teach the instructor.
**Killed:** any framing of the day as a prompt cookbook or a tools tour.

## D-02 — MCP is the hands-on

The afternoon builds something real and useful. Students use whatever surface
they prefer; the instructor drives herdr. **Killed:** a prescribed toolchain,
and any "watch me" afternoon.

## D-03 — No warm-up server

There is no `hello-frank`, no sanitised practice exercise, no local five-minute
MCP server before lunch. The class builds the real thing, and when something is
missing an agent works out what — that discovery *is* the skill.

**Killed:** the claim *"every attendee connects to and calls an MCP server
before lunch… it needs Node and five minutes — no cloud, no credentials, no
pipeline."* Students **do** call an MCP server before lunch, but through the
**10:30 Slack and Chrome connector round** — a connector is an MCP server
someone else wrote. Different mechanism, so the justification had to change too.

## D-04 — Morning is fundamentals and Claude depth; afternoon builds

9:00–12:05 — LLMs and in/out-of-distribution, every surface opened and working,
connectors, then skills/agents/commands/rules. 1:00–5:00 — build, deploy,
connect. **Killed:** an afternoon front-loaded with process before tooling.

## D-05 — DeltaTrails Frank is a real product, and it demos before lunch

Frank in DeltaTrails is Buckshot's hypervisor security and compliance MCP
server (AWS, Azure, K8s). It is the 11:40 demo — the payoff of the morning, not
a 9am scene-setter. The class builds a small thing **named after** it.
**Killed:** any text that conflates the two Franks. Keep them distinguishable
everywhere.

## D-06 — Architecture precedes implementation, including on the clock

Students draft ADR-009, have Copilot attack it, **then** build the tool from it.
An earlier agenda wrote the Azure tool at 1:50 and drafted the ADR at 2:40,
which inverted the day's entire thesis on the one slide the room stares at.

**Killed:** `PROMPTS.md`'s "STAGE 3b — the 1:50 block" placement. The Azure tool
is now the **3:10** block.

## D-07 — Frank's build is its own agenda block

"Implement ADR-001 and ADR-002" — one sentence, a server, a UI, 114 tests — is
the day's centrepiece and now appears on the agenda at **1:45**. It was
previously invisible, folded inside another block. **Killed:** the assumption
that the room infers a block the slide does not show.

## D-08 — Students bring nothing from Azure

No subscription, no credentials, no API key, **no `az login`, no Azure CLI**.
One deliberately public credential goes on screen; they paste it with one
command. See [ADR-010](../docs/adr/ADR-010-one-open-credential.md).

**Killed:** seat cards, `provision-class.sh`, `setup-seat.sh`, `handout.sh`, the
prerequisites rows for an Azure subscription and an Anthropic API key, `az login`
in the verify block, "bring credentials" in the closing line, and per-seat
provisioning language throughout.

## D-09 — No managed identity, no instructor Reader grant

Frank authenticates with the same credential the pipeline deploys with, via
`DefaultAzureCredential` reading container environment variables. Verified in
rehearsal at `identity.type: None` with no role assignment anywhere.

**Killed:** the runbook's "privileged handoff — do not forget this" section,
`PROMPTS.md`'s "use the container's managed identity — no stored credential",
the reference tool's Reader-grant error message, and every "granted read-only
access" phrasing. This is the single leakiest dead decision in the repo — it had
surfaced in four separate files.

## D-10 — One container, one deploy target

The server serves `/`, `/mcp` and `/healthz`. **Killed:** Static Web Apps, the
second deploy target, and the CORS boundary between UI and server. Two
architecture diagrams still show the dead shape — they are shapes and arrows in
Google Slides, so they need a human.

## D-11 — Security honesty over security theatre

Name the trade-off out loud: the credential holds Contributor, Frank only reads,
and the read-only guarantee lives in ADR-002's tool surface — **not** in the
credential. **Killed:** any wording implying the credential enforces read-only.

## D-12 — Keep a rejected ADR

ADR-007 stays at status **Rejected** as a teaching artifact. Students should see
what a rejected decision looks like, not only accepted ones.

## D-13 — Delegation by description is not demoed live

Tested with a well-matched description and a natural prompt: **it did not fire**,
and the main agent did the review itself in 18 minutes. Demo delegation through
`/adr`, which names the agent and is deterministic; pre-record the A/B.
**Killed:** "descriptions reliably fire agents" as a claim anywhere.

## D-14 — The class runs on public forks

Actions runs in a public fork bill **zero minutes**. Students do not need a paid
plan. **Killed:** the paid-plan prerequisite question, which will be asked.

## D-15 — Close on energy, not process

Poll "where did we wait today?", make the bottleneck argument from their own
answers, peak on Frank operating his own world, then **one** Monday action.
**Killed:** ending on a process lecture after a green deploy.

---

## Known open

- **Concurrent deploys at class scale are untested.** Students share one
  resource group; app names derive from the GitHub owner, so collision takes
  deliberate effort — but that is not the same as tested with twenty people.
- **Two architecture diagrams still show the pre-D-10 shape.**
