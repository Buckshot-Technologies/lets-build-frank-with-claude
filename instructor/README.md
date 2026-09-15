# Instructor tooling

Everything needed to run the class, and nothing a student uses.
[ADR-010](../docs/adr/ADR-010-one-open-credential.md) removed the rest: students
run **no setup commands at all**, so there is no line to put on screen.

## Before class, in order

```bash
./provision-class.sh                  # group + registry + environment
./provision-service.sh                # the credential service; prints the URL
CLASS_RG=rg-frank-class VAULT=<printed above> ./publish-credential.sh
APP=<printed above> ./ops.sh open 8
APP=<printed above> ./ops.sh status   # expect "students can deploy"
```

`provision-class.sh` creates the group, a registry with the admin user enabled,
and the shared Container Apps environment. The pipeline **discovers** the last
two by listing them, so their names do not matter — only that one of each exists.

> **Regions run out of Container Apps capacity without warning.** `eastus` had
> none on 2026-09-15 and failed with
> `ManagedEnvironmentNoAvailableCapacityInRegion`. The script falls back through
> `eastus2 westus2 centralus westus3` automatically; the environment does not
> have to share a region with the group or the registry.

`provision-service.sh` stands up the Function App and Key Vault that serve the
credential, and prints **the URL**. Paste it into `CREDENTIAL_URL` in
`.github/workflows/deploy.yml` on `main`. **That one line is what makes every
student's pipeline work** — it is the single easiest thing to forget.

`publish-credential.sh` mints the service principal and stores it in Key Vault,
base64-encoded. The value is never written to disk and never printed.

## On the day

```bash
APP=<app> ./ops.sh warm      # consumption plans cold-start; do this first
APP=<app> ./ops.sh status    # "students can deploy" / "students CANNOT deploy"
APP=<app> ./ops.sh close     # or let OPEN_UNTIL close it for you
```

> **You cannot debug this in a browser.** Closed, expired, wrong cohort and
> missing value all return an identical empty `404` — that is deliberate, so a
> prober learns nothing. It also means a correct URL and a wrong one look the
> same. `ops.sh status` is the only thing that tells them apart.

**Register the resource providers a week ahead** — on a fresh subscription they
are all unregistered and take tens of minutes:

```bash
for p in Microsoft.App Microsoft.OperationalInsights Microsoft.ContainerRegistry; do
  az provider register -n "$p"
done
```

**Set a subscription budget.** The realistic abuse of a public credential here is
not data theft — Contributor on a resource group means *create container apps*,
and container apps run arbitrary containers. A scraped credential mines
cryptocurrency on your card. The budget is the mitigation that matters.

## Tell them this before they push — it has no error message

**GitHub disables Actions on forks by default.** After forking, a student must
open the **Actions** tab and click *"I understand my workflows, go ahead and
enable them."* Until they do, `git push` runs nothing at all — no failure, no
log, no red X. Nothing.

It is worse than a broken build because there is nothing to diagnose. Put it on
screen next to the credential line.

**Nobody needs a paid GitHub plan.** Actions is free and unmetered on public
repositories, and a fork of a public repo is public. A full class day billed
zero minutes in testing. The only exception is a student who makes their fork
*private* — they then spend their own free-tier minutes, and even then a deploy
is under three minutes against a 2,000/month allowance.

## What a student does

Two commands, from the URL on your screen:

```bash
gh secret set AZURE_CREDENTIALS --body "$(curl -s <url>)"
git push origin main
```

No card, no setup script, no repository variables. Their container app is named
after their GitHub account, so nobody collides.

## After class

```bash
./teardown-class.sh --confirm
```

Revokes the credential and deletes the resource group. Deleting the app
registration stops *new* tokens; already-issued Azure tokens stay valid briefly,
so deleting the resource group is the decisive step — it is the only thing the
credential could ever reach.
