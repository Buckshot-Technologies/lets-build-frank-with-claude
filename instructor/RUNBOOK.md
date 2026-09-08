# Instructor runbook — Let's Build Frank

Everything here was learned by running the class end to end, not by planning it.
**Timings are measured. Every failure listed actually happened.**

Read this with [ADR-010](../docs/adr/ADR-010-one-open-credential.md) open. The
credential model changed late, and it deleted most of what the old runbook told
you to do.

---

## T-minus one week

**Register the resource providers.** Subscription scope, one time, and it takes
**tens of minutes** — on a fresh subscription all of these were `NotRegistered`:

```bash
az provider register -n Microsoft.App
az provider register -n Microsoft.OperationalInsights
az provider register -n Microsoft.ContainerRegistry
# Microsoft.Web is NOT needed — Static Web Apps was removed in ADR-006
az provider show -n Microsoft.App --query registrationState -o tsv   # until "Registered"
```

This is the single longest lead-time item in the whole course. Do it first.

**Set a subscription budget.** The credential is published openly and holds
Contributor on one resource group. The realistic abuse is compute, not data —
someone scrapes it and mines cryptocurrency. A budget alert is the control that
matters; ADR-010 says so and means it.

**Pin your az CLI.** `az containerapp up --source .` crashes on some builds
(`OS.linux.value` on a `None`) — and **installing the `containerapp` extension
does not fix it**, because it calls the same core function. The class pipeline
uses `az acr build` + `az containerapp create/update` and avoids it entirely,
but you will hit it if you improvise on stage.

**You do not need a seat count.** Under ADR-010 provisioning is O(1): four
shared objects for any class size. This is the change that made 30 students
cost what 3 do.

---

## T-minus one day

```bash
./instructor/publish-credential.sh
```

One app registration, one client secret, Contributor on one resource group,
two-day expiry — published to a public blob with a random container name. It
prints the one-line command you put on screen. Note what that line does **not**
contain: the credential itself. `curl` pipes it straight into `gh secret set`, so
the key never appears on the projector, in anyone's clipboard, or in shell
history. Only the URL is visible, and it is public by design.

Pre-creating the shared registry and Container Apps environment matters: the
environment takes **~75–90s** and it is the long pole. Created once for the
class, not once per student.

**Verify the whole path yourself, end to end.** Fork, set the secret from the
URL, push, watch it deploy, open `/healthz`. A room of people discovering a
broken credential simultaneously is the worst hour of your life.

> **Do not commit the credential to any repo, including as an example.** GitHub
> secret scanning partners with Microsoft and will **auto-revoke** a committed
> Azure client secret. That breaks your class rather than protecting it. The
> published URL is the channel, deliberately.

---

## Morning setup, before anyone arrives

- Your own `node --version` ≥ 22. **A broken Node silently removes `copilot`** —
  `copilot --version` says "not found" and explains nothing.
- Nothing on **port 3000**. It is the Next.js/CRA default and a dev server of
  yours will silently answer requests meant for Frank. This happened.
- `herdr` running with your panes laid out.
- The **pre-recorded** vague-description clip queued (see *Demos that can fail*).
- A deliberately broken state in your own fork, in case every student deploys
  clean first time — the diagnosis is the lesson, not the green tick.
- `./instructor/publish-credential.sh show` on screen — the command, not the key.
  Do not put it in a shared doc that outlives the day.

---

## Measured timings

| Step | Time | Who |
|---|---|---|
| Provider registration | **tens of minutes** | you, T-1 week |
| Container Apps environment create | ~75–90s, **once for the class** | you, T-1 day |
| `az acr build` | **70s** (91s with tests) | pipeline |
| `az containerapp create/update` | <60s | pipeline |
| Cold start from scale-to-zero | **0.44s** | — |
| Agent implements ADR-001 + ADR-002 | ~10 min | students |
| Full ADR review by one agent | **18 min** | ← too slow for a live step |

**Budget ~2.5 minutes per student deploy.** The image build dominates and cannot
be optimized away: a prebuilt dependency image was tested and gave **no gain**
(72s vs 70s), and `az acr build` provides **no cross-build layer cache** (warm
rebuild 76s, zero `CACHED` steps). Stop trying; it is a network-bound push.

**Students do not need paid GitHub Actions.** Runs in a public fork bill **zero
minutes**. Verified — this question will be asked.

---

## What ADR-010 deleted — read this if you taught an earlier version

The old runbook had a section titled *"The privileged handoff — do not forget
this."* **It no longer applies, and following it will waste your afternoon.**

There is no managed identity and no `Reader` role assignment. Frank receives
`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`,
`AZURE_SUBSCRIPTION_ID` and `AZURE_RESOURCE_GROUP` as container environment
variables; `DefaultAzureCredential` picks them up. Verified in rehearsal with
`identity.type: None` and no role grant anywhere.

That was the blocker that made ADR-009 unimplementable — students cannot create
role assignments, and the identity did not exist until first deploy. Removing
the secret removed the blocker. Also deleted: `provision-class.sh`,
`setup-seat.sh`, `handout.sh`, and the printed seat cards.

---

## Failures that will happen, and what to say

| Symptom | Cause | Say this |
|---|---|---|
| "The MCP tool isn't there" | Session was already running when the server was added. **Servers load at session start.** | "Exit and restart `claude`. This is the single most common MCP moment; now you'll never lose an hour to it." |
| `copilot: not found` | Broken Node, not Copilot | "Check `node --version` first. The error won't tell you." |
| Deploy fails with an opaque `az` error | A missing GitHub secret expands to an **empty string** | "The preflight step names it. Read the red line." |
| **Job never starts; no logs at all** | **Org billing lock.** The message is in the check *annotation*, not the logs | "That's an account problem, not your code." Cost real time in rehearsal — look at the annotation first |
| `AADSTS700213` | Someone reused old OIDC instructions | "That's ADR-005, superseded by ADR-006 and then ADR-010. Run the command on screen." |
| An agent dies seconds after starting | It was on a first-run trust prompt; herdr reported it ready | "Approve the trust prompt, then re-send." |
| Deploy slow, no output | ACR build, ~70s | "That's the image building in the cloud. It dominates; nothing is stuck." |
| Two students deploy at once | **Untested at class scale.** They share one resource group; app names derive from the GitHub owner, so collision needs deliberate effort | Have them stagger if you see trouble, and tell them why |

---

## Demos that can fail — sequence them carefully

**Safe live:** `/init` and its critique · "implement ADR-001 and ADR-002" ·
push-to-deploy · Frank answering over MCP.

**Do NOT demo live:** *agent delegation by description.* It was tested with a
well-matched description and a natural prompt — **it did not fire**, and the
main agent did the review itself, taking 18 minutes. Agent selection is
model-mediated, not guaranteed dispatch.

**Instead:** demo delegation through the `/adr` command, which names the agent
explicitly and is deterministic. Pre-record the vague-vs-precise A/B and play
the clip. The lesson is *"descriptions are routing instructions to a
probabilistic model"* — not *"descriptions reliably fire agents."*

Same honesty on skills: their conventions live in the skill **and** `CLAUDE.md`
**and** the ADR, so correct output does not *prove* the skill fired. The
defensible line is: *"the skill supplied project-specific procedure the standing
architecture did not."*

---

## Closing sequence — protect the energy

Do **not** end on a process lecture after a green deploy.

1. **Poll, don't lecture:** *"Where did we wait today?"* They will say
   credentials, provider registration, review, debugging — **not typing code.**
   Their own day is the evidence.
2. **Bottleneck argument, 8–10 minutes**, built on their answers. Hedge it
   honestly: AI raises review and integration throughput too, and teams that cap
   WIP absorb demand as lower intake. The durable claim is that the scarce human
   resource moves from typing toward judgment and deciding what deserves to exist.
3. **Frank operating his own world** — deploy → observe → ask → decide. Peak
   here, not on slides.
4. **One Monday action.** Singular: one ADR, one review gate, or one observable
   signal.

---

## Same-day teardown

```bash
./instructor/teardown-class.sh --list      # always dry-run first
./instructor/teardown-class.sh --confirm
```

Deleting the app registration stops **new** token issuance, but already-issued
Azure tokens stay valid briefly — **deleting the resource group is the decisive
containment step.** The script does both, registrations first. Revocation was
verified in rehearsal: the published URL returns **404** afterwards.

Check for orphans: failed `containerapp up` attempts leave registries,
environments and Log Analytics workspaces behind. Two failed attempts left four
orphans in testing.

```bash
az group list --query "[?starts_with(name,'rg-frank')].name" -o tsv
```

---

## Say this out loud, once

The class credential is **deliberately public** — one client secret, Contributor
on one resource group, in a subscription used for nothing else, expiring in two
days and deleted the same afternoon.

ADR-005 wanted no deployable password anywhere. ADR-006 gave that up because
federated credentials must name an exact repo subject and you do not know
attendees in advance. **ADR-010 then stopped trying to keep the secret at all**,
which is what collapsed 120 Azure objects into four.

Two things to name rather than hide:

- **It is over-privileged for what Frank does.** It holds Contributor; Frank only
  reads. The read-only guarantee lives in ADR-002's tool surface, not in the
  credential. Say that plainly — implying the credential enforces it is the
  lie students will otherwise carry back to work.
- **This would be indefensible at work.** That is the lesson. A correct design
  nobody questions teaches less than a deliberately wrong one you can defend the
  boundaries of.

Doing that in front of the room *is* the architecture lesson: a decision met
reality, so you superseded it and stated what it cost.
