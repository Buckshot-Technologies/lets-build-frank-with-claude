# Instructor tooling

Everything needed to run the class, and nothing a student uses. Two scripts,
because [ADR-010](../docs/adr/ADR-010-one-open-credential.md) removed the rest.

## Before class

```bash
./publish-credential.sh create
```

Creates one resource group, a storage account, a **public** blob container with
an unguessable name, and one service principal — Contributor on that resource
group only, expiring in two days. Uploads the credential and prints the single
line you put on screen.

Then create the shared registry and Container Apps environment in the same
group. The pipeline **discovers** both, so their names do not matter:

```bash
RG=rg-frank-class
az acr create -g $RG -n frankclass$RANDOM --sku Basic --admin-enabled true
az containerapp env create -n frank-class-env -g $RG -l eastus   # ~90s, once
```

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
