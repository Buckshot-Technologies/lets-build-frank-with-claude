# Staged classroom prompts — with known outcomes

> **Instructor material.** These are the prompts you put on screen, with the
> outcomes each one actually produced in rehearsal. Students do not need this
> file — they get the prompts from you, one stage at a time.


Every prompt below was **actually run** in a full rehearsal of this course. The
"what you should see" lines are observed output, not predictions.

**Why staged prompts.** Twenty people free-forming produces twenty different
debugging sessions and one lost afternoon. Staged prompts converge the room on
one state, so the instructor debugs one problem, not twenty.

**The risk, and the antidote.** Staged prompts can decay into copy-paste
theatre. Every stage below therefore ends with a **Now change it** step — a
small deviation the student chooses. Copy to learn the shape; deviate to learn
the skill.

**Notice how short the prompts are.** That is the day's argument: the prompt is
one line because the ADR is three pages. The specification does the work.

---

## Stage order — this is the point, not a detail

| Stage | Clock | What |
|---|---|---|
| 1–2 | 1:00 | Fork, `/init`, read it, correct it |
| 3 | 1:45 | Build Frank from ADR-001 + ADR-002 |
| 4 | 2:40 | Draft ADR-009, Copilot attacks it |
| 5 | 3:10 | Build the tool **from the ADR they just wrote** |
| 6 | 3:40 | Push once, deploy once |

Stage 4 precedes stage 5 deliberately. An earlier agenda had them the other way
round — the tool at 1:50, the ADR at 2:40 — which taught implementation before
decision on the one slide the room stares at all day.

---

## STAGE 1 — Fork, and see what an agent can infer (1:00)

```
/init
```

Run it in your fork before touching anything else.

**Why this is first, not a warm-up server.** There is no sanitised practice
exercise. The class builds the real thing, and when something is missing — a
variable, a credential, a dependency — an agent works out what. That discovery
is the skill, not a detour around it.

**Now change it:** nothing yet. Read what it wrote. Stage 2 is where you take
it apart.

---

## STAGE 2 — `/init`, and why you must read it (1:00)

```
/init
```

**What you should see** — a `CLAUDE.md` that is genuinely good *and* contains
real defects. In our run it produced all of these:

1. **A laundered falsehood.** ADR-005 claims "no deployable password exists
   anywhere" while listing a Static Web Apps deploy token, which is exactly
   such a password. `/init` copied the contradiction into always-on context.
2. **Governance that does not exist.** *"`main` is protected."* Nothing
   configures branch protection, and **a fork does not inherit it** — while the
   next line says pushing to `main` deploys to Azure.
3. **Leaked local context** — the instructor's machine layout, inherited from a
   parent `CLAUDE.md`, about to be committed to a public fork.
4. **An unstated inference promoted to policy** — *"`PORT` must default to
   3000."* No ADR says that.

**The teaching line for stage 2:**

> `--target-port 3000` makes "the deployed process must listen on 3000" a
> legitimate derived constraint. "`PORT` must default to 3000" is not stated
> anywhere. **Verified inference is valuable; silently promoting it to
> architecture policy is the failure mode.**

**Now change it:** delete one wrong claim, add one thing only you know about
your fork, and commit. It is team config now.

---

## STAGE 3 — Architecture becomes executable (1:45)

```
Implement ADR-001 and ADR-002 in server/. Read both ADRs first; they are
the spec. Work on a branch build/adr-001-002; do not touch main.

When done, actually run `npm ci && npm test && npm run build` and report
the real output.
```

**What you should see** — this is the day's centrepiece, and it worked from that
one line:

```
Test Files  5 passed (5)
     Tests  47 passed (47)
GET  /healthz -> {"status":"ok","version":"0.1.0","uptimeSeconds":1}  [200]
POST /mcp     -> protocolVersion 2025-06-18, serverInfo "frank"
```

And unprompted, the agent wrote ADR-002's rules into the running server's MCP
`instructions` field:

> *"Frank is a read-only assistant… Tool names are verb_noun, where the verb is
> one of get, list, search or summarize."*

**Say this out loud:** the prompt was one sentence. The ADRs chose the SDK,
transport, endpoint, schemas, tool vocabulary, output shape, and safety
boundary. *That* is why one sentence was enough.

**Honest caveat, do not skip it:** 47 passing tests prove **conformance to the
spec**, not that the spec was right. Stage 4 exists because of that gap.

**Now change it:** add one read-only tool. The verb must come from
`get`/`list`/`search`/`summarize`. Watch the agent refuse a `create_*` name.

---

## STAGE 4 — Claude drafts, Copilot attacks (2:40)

```
# in the Claude pane
Draft ADR-009: let Frank read what is running in his own Azure resource
group. Follow docs/adr/template.md. One page.
```

```
# in the Copilot pane
Attack this ADR draft. Edge cases, security holes, simpler alternatives.
Be blunt. Under 300 words.
```

**What you should see** — a real disagreement. The recorded example is from an
ADR-008 draft in rehearsal: Copilot found that a proposed static bearer token,
shipped in a static site's JavaScript bundle, is **not an authentication
boundary at all**, and that CORS is not one either since non-browser callers
ignore it. The first fix was wrong; the attack caught it. That draft became
[ADR-007](../docs/adr/ADR-007-mcp-endpoint-authentication.md), kept at status
**Rejected** so students can see what a rejected decision looks like.

On an ADR-009 draft expect a different attack — scope, whether the tool should
take a resource group parameter, what happens when the credential is absent.
Do not script the disagreement; let it happen.

**The point:** different weights, different blind spots. Their confident
mistakes rarely overlap.

**Now change it:** take one Copilot criticism you disagree with and defend your
draft. You are the referee, not a spectator.

---

**This block comes before the tool, deliberately.** An earlier agenda built the
Azure tool at 1:50 and drafted the ADR at 2:40 — implementation before decision,
on the one slide the room stares at all day. Architecture precedes
implementation, including on the clock.

---

## STAGE 5 — Write the Azure tool from the ADR you just wrote (3:10)

**Verified: this produced `list_resources` in the pilot run**, deployed to a real
Container App, answering from live Azure state.

```
Read ADR-002 and the existing tools in server/src/tools/. Add a tool that
reports what is running in Frank's own resource group. Authenticate with
DefaultAzureCredential — the pipeline puts the credential in the container's
environment. Do NOT take a resource group parameter: read the scope from the
environment, so a caller cannot point Frank somewhere else. Then run npm test
and report the real output.
```

**What you should see** — a tool obeying eight or nine conventions the prompt
never mentions: `verb_noun` from the closed set, a strict `zod` schema, `summary`
plus typed detail fields, `isError` with a plain-language message, one module per
tool, registered in `index.ts`, with a test. All of it from ADR-002 and the
`frank-tools` skill.

**The teaching moment.** Count the constraints in the prompt: four. Count the
conventions in the result: nine. Ask the room where the difference came from.

> The prompt was four sentences **because** the ADRs were three pages. A short
> prompt is a *result* of good architecture, not a substitute for it.

**Known failure, and it's a good one:** an agent may invent a `resourceGroup`
parameter. ADR-002 doesn't forbid it — the *prompt* did. Ask which of the two
should own that rule, and whether it belongs in an ADR. That question is the
exercise.

**Also verified:** the tool needs `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`,
`AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` and `AZURE_RESOURCE_GROUP` on the
container. The pipeline sets all five; before the pilot run it did not, and the
tool failed at 4:10 looking like a permissions problem when it was configuration.
**Say that out loud** — "permission denied" is what a missing environment
variable looks like from the outside, and students will misdiagnose it the same
way.

**Note for anyone who taught an earlier version:** this prompt used to say "use
the container's managed identity — no stored credential." ADR-010 removed the
managed identity. If you say that sentence, the agent will build something that
cannot work.

---

## STAGE 6 — Push once, deploy once (3:40)

```bash
gh secret set AZURE_CREDENTIALS --body "$(curl -s <the URL on screen>)"
git push origin main
```

One secret. **No repository variables** — the resource group, registry and
environment names are committed in `deploy.yml`, because none of them is secret.

Worth saying out loud: the credential never appears on screen. `curl` pipes it
into `gh secret set`, so it skips the projector, the clipboard and shell
history. Only the URL is visible, and it is public on purpose.
That single observation is what deleted the seat cards ([ADR-010](../docs/adr/ADR-010-one-open-credential.md)).

**What you should see** — one pipeline run, then in the job summary:

```
Console: https://<app>.<region>.azurecontainerapps.io/
MCP:     https://<app>.<region>.azurecontainerapps.io/mcp
Health:  https://<app>.<region>.azurecontainerapps.io/healthz
```

**Known failure:** GitHub expands a missing secret or variable to an **empty
string**, and `az` then fails with something unrelated-looking. The preflight
step in `deploy.yml` catches this and names the missing value.

**Now change it:** open `/healthz` in a browser, then add Frank to Claude
Desktop as a connector using the `/mcp` URL, and ask him something.
