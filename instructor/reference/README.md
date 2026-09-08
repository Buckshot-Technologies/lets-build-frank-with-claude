# Reference answers — spoilers

**Do not open this before the 3:10 block, and do not put it on screen.**

Students derive `list_resources` from [ADR-002](../../docs/adr/ADR-002-mcp-tool-conventions.md)
and the ADR-009 they write themselves. Deriving it *is* the exercise — the
point of the block is that four sentences of prompt produce nine conventions
nobody typed, because the architecture already said them.

This directory exists for one situation: it is 4:30, someone is stuck, and the
closing demo needs a working tool. Read it, understand it, and help them get
there — don't paste it.

| File | Answers |
|---|---|
| `list-resources.ts` | ADR-009 — Frank reads his own resource group |

`list-resources.ts` was written by an agent from the ADRs alone in the rehearsal
run, then deployed to a live Container App and verified answering from real
Azure state. It is a real answer, not an idealized one.

**What to look for when reviewing a student's version.** The prompt states four
constraints. A good answer obeys about nine, all inherited: `verb_noun` from the
closed verb set, a strict `zod` schema, `summary` plus typed details, `isError`
with a plain-language message, one module per tool, registered in `index.ts`,
and a test. Ask the room where the other five came from.

**The interesting failure:** an agent may invent a `resourceGroup` parameter.
ADR-002 does not forbid it — the *prompt* did. Which of the two should own that
rule? That question is worth more than the code.
