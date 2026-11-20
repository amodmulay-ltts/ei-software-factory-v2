# ei software factory

A Claude-Code-driven pipeline that takes a plain-language request and carries
it all the way to reviewed, working code on your base branch — without
needing CI, a hosted issue tracker, or anything running unattended.

Drop a request into an **inbox** folder. The factory's first agent decides
whether it's worth doing, how big and risky it is, and which **line** should
handle it, then runs that line start to finish: write a spec, write the code,
run your own checks against it, get it reviewed by the right set of
reviewers, and land it. If one line is configured to hand off to another —
say, a `build` line finishing and passing the baton to a `docs` line — the
job just keeps moving instead of stopping there.

Nothing here runs on a timer or inside CI. You kick it off yourself with
`/factory run`, in Claude Code, in your own repository.

## Install

This repo is the factory itself — there's nothing to pull in here. To bring
it into a different project, open Claude Code there and paste:

```text
Install this software factory in this project, following its own install
instructions:

https://github.com/amodmulay-ltts/ei-software-factory-v2
```

Your agent reads [`INSTALL.md`](INSTALL.md), copies the skill, the agents,
the scripts, the dashboard and the playbook templates, fills in
`factory/checks.sh` and the playbooks with that project's real commands and
real boundaries, tailors the reviewers to its stack, and verifies
`factory/checks.sh` passes on its base branch before handing the install back
to you to commit.

## The shape of it

```
          ┌─────────┐
  topics  │  inbox   │   factory/inbox/<topic>.md — one file per request
 ───────▶ └────┬────┘
               │
               ▼
          ┌─────────┐
          │  triage  │   accept (+ scope, risk, surfaces, which line) | needs-info | reject
          └────┬────┘
               │ ACCEPT
               ▼
      ┌─────────────────┐
      │  a factory line: │   spec → build → gate → review → approve
      │     "build"      │   (its own checks, its own reviewer set)
      └────────┬─────────┘
               │ approved
               ▼
         configured to hand off? ──yes──▶  the next line's pass begins (e.g. "docs")
               │
               no
               ▼
         landed on the base branch — job done
```

| Term | What it means in this project |
|---|---|
| **Inbox** | `factory/inbox/*.md`. Anyone with write access to the repo files a request by adding one file — by hand, or automatically: `factory/bin/pull` pulls in every open GitHub issue labeled `factory` as its own inbox file, so an issue and a hand-filed topic join the same queue and nothing downstream treats them differently. |
| **Triage** | The first agent any topic meets. Decides accept / ask-a-question / reject, scores risk and UI/security surfaces, and names which line should build it. |
| **Factory line** | One configured stage of the pipeline (`factory/config.json` → `lines`). Each has its own checks and, optionally, a `handoff` naming the line after it. Shipped with two: `build` (the code) and `docs` (keep docs matching what shipped). |
| **Playbook** | `factory/playbooks/_global.md` plus one `factory/playbooks/<line>.md` per line. Written policy — what the factory is for, what no line may ever do, what must always go to a human — that triage, the builder and the approver all read and treat as binding. Not mechanically enforced like a gate; editable without touching any agent's prompt. |
| **Job** | One topic's entire run through the factory. A job may make several **passes** — one per line it visits — each kept in its own numbered subfolder. |
| **Agent roles** | One Claude Code subagent per responsibility: `triage`, `spec-writer`, `builder`, the four reviewers, `approver`. Each reads what it needs, writes exactly one file, and reports back in a single line. |
| **Job state** | `factory/jobs/<job-id>/` — every file that job's agents produced. Gitignored; lives only on the machine actually running the factory. |
| **Control scripts** | `factory/bin/job`, `gate`, `route`, `pull` — deterministic. `job` is the only thing allowed to write `job.json`, and it refuses any move that isn't legal. |
| **Checks** | Each line's own check script (`factory/checks.sh` for `build`). The gate runs it before a reviewer ever sees the diff, and again right before landing. |

Three layers do three different jobs, and it's worth keeping them straight:
**playbooks** are policy (what's allowed, what never is, what always needs a
human — written down, not buried in a prompt); **lines** are where the actual
judgment and execution happens; **gates** are the one mechanical checkpoint
that doesn't take anyone's word for it — a check script either exits 0 or it
doesn't.

## The pipeline, step by step

```
triage (fable)     → ACCEPT (scope maybe narrowed, line chosen) | NEEDS-INFO | REJECT
route (script)     → picks reviewers + their models from risk/surfaces, via config.json
worktree           → factory/<job-id>, a fresh branch cut from the base branch
spec-writer (opus) → writes spec.md
builder (opus)     → commits the change; writes build.md
gate (script)      → runs the line's checks; FAIL sends the log back to the builder, no reviewer runs
reviewers (routed) → launched together, WAIT FOR ALL; any CHANGES loops back: builder → gate → reviewers
approver (opus)    → APPROVE: resync with base, gate once more, land it (or hand it to the next line)
                     ESCALATE: a decision is written up for a human, job marked needs-human
```

A pass gets at most `max_rounds` build-review cycles before the factory
stops and asks a human to weigh in. What risk level and which surfaces
(`ui`/`security`) triage assigns is what decides which reviewers run and on
which model — a small, low-risk, no-UI change pulls in one Haiku reviewer; a
risky one touching auth also pulls in the security reviewer on Opus. All of
that routing lives in `factory/config.json`, never baked into a prompt.

## Using it day to day

### 1. File something

Three equally valid ways to get a topic into the inbox:

```bash
# by hand, from the command line
echo "Users should be able to export their data as CSV from the account page." \
  | factory/bin/job add "Add CSV export to the account page"

# or just create the file yourself — its title is whatever its first
# `# ` line says, everything after that is the body

# or label a GitHub issue `factory` and let the factory notice it:
gh issue create --label factory --title "Add CSV export to the account page" \
  --body "Users should be able to export their data as CSV from the account page."
```

`factory/bin/job add` writes `factory/inbox/add-csv-export-to-the-account-page.md`
and prints the slug. A GitHub issue doesn't need that step at all — the next
`/factory run` pulls every open issue labeled `factory` into its own inbox
file automatically (via `factory/bin/pull`), marked with the issue number it
came from. Either way, everything from here on treats the two identically.

### 2. Run it

From the repo root, inside Claude Code:

```
/factory run
```

This first pulls in any new GitHub issues labeled `factory`, then works
through the whole inbox, `concurrency` topics at a time (3 by default), and
also picks back up anything that was mid-flight when a previous session
ended — state is files, not memory tied to a session. If `gh` isn't
installed or authenticated, the pull step just says so and the run continues
with whatever's already filed locally.

To run just one topic:

```
/factory run add-csv-export-to-the-account-page
```

### 3. Respond to what comes back

- **Finished and landed**: nothing for you to do. If the topic came from a
  GitHub issue, the factory closes it for you (best-effort — it won't fail
  the job if `gh` isn't set up).
- **`needs-info`**: triage had a question only you can answer. Tell the
  factory directly:

  ```
  /factory the export should only cover the last 90 days, not the full history
  ```

- **`needs-human`**: something escalated — either the approver wasn't
  confident, or the round budget ran out. Read
  `factory/jobs/<id>/<pass>/decision.md`, then either give feedback to send
  it back to the builder, or reject it outright:

  ```
  /factory reject add-csv-export: we're retiring the account page next quarter
  ```

- **Just checking in**: ask anything — `/factory what's the status on
  add-csv-export?`, `/factory how much has this run cost so far?`

### 4. Watch it happen

```bash
cd factory && python3 -m http.server
```

Open <http://localhost:8000/dashboard.html>. Each job shows as a card with a
row of gate/review chips per round, its risk, its current line, its cost and
how long it's been running. Click into a card to read every file it's
produced — each one opens with a short summary at the top so you can skim
before deciding whether to dig in.

## Wiring it up for your own project

The rest of this section is the same adaptation `INSTALL.md` walks an agent
through — useful as a quick checklist if you're finishing the setup
yourself, or re-tuning it later.

1. Fill in `factory/checks.sh` (and any other line's check script) with this
   project's actual lint, typecheck, test and build commands. It has to be
   non-interactive and exit non-zero on failure — the gate always runs it
   against a clean worktree.
2. Write the real boundaries into `factory/playbooks/_global.md` and each
   `factory/playbooks/<line>.md`: what this project actually is, what no
   line should ever touch, and what must always land in front of a human.
   These start as templates — the factory is only as safe as what's
   actually written in them.
3. Edit `factory/config.json`:
   - `base_branch`: your real default branch.
   - `lines`: add, remove, or rewire lines as needed. Every line needs a
     `checks` script; `handoff` names whichever line should run next (or
     `null` if it's the end of the road).
   - `protected_paths`: anything no job should ever be able to touch (keep
     the factory's own config and scripts listed here).
   - `concurrency` / `max_rounds`: how many jobs run side by side, and how
     many build-review cycles a pass gets before it escalates.
   - `github.issue_label`: the label `factory/bin/pull` looks for. Leave it
     as `factory` unless the repo already uses that label for something
     else. Pulling issues in is optional — skip this entirely if the inbox
     should only ever be filed locally.
4. Tune `.claude/agents/reviewer-security.md`, `reviewer-ui.md` and
   `reviewer-ux.md` to this project's real hot spots, design system and user
   base.
5. Keep `AGENTS.md` (or `CLAUDE.md`) current with how to set up a fresh
   checkout and what the real validation commands are — they should match
   `factory/checks.sh` exactly, since every agent reads this file first.

## What stays off-limits

- A topic's text reaches every agent only as quoted material in `topic.md` —
  never as part of a prompt, so it can't steer an agent's tools, files, or
  verdict.
- Agents only ever work inside their own job's git worktree and branch.
  Landing on the base branch happens exclusively through
  `factory/bin/job merge`. The factory never deploys anything anywhere.
- One branch per job (a fresh one for each pass after a handoff), capped at
  `max_rounds` rounds per pass before a human gets pulled in.
- Start with `concurrency: 1` and actually read what a few jobs produce
  before turning it up.

## What's in here

```
.claude/
  skills/factory/SKILL.md     the orchestrator: inbox, concurrency, the pipeline
  agents/
    triage.md                 fable    worth doing? what scope, what risk, which line?
    spec-writer.md            opus     writes spec.md
    builder.md                opus     code, commits, build.md
    reviewer-code.md          routed   correctness, simplicity, tests
    reviewer-security.md      opus     only when triage flags `security`
    reviewer-ux.md            sonnet   only when triage flags `ui`
    reviewer-ui.md            haiku    only when triage flags `ui`
    approver.md               opus     APPROVE or ESCALATE
factory/
  inbox/                       filed topics, one .md per request
  playbooks/
    _global.md                 boundaries every line and every agent must respect
    <line>.md                  one line's scope and its own escalate list
  config.json                  concurrency, round limits, lines, routing, protected paths, prices
  checks.sh                    the build line's checks
  bin/job                      the only writer of job.json; refuses illegal moves; lands changes
  bin/gate                     runs a line's checks in a job's worktree → round-N/checks.md
  bin/route                    turns risk + surfaces into the job's reviewer set
  bin/pull                     pulls open `factory`-labeled GitHub issues into the inbox
  dashboard.html                the board
INSTALL.md                      how an agent installs this into another project
DESIGN.md                        why it's built this way
```

## Why files instead of a database

Everything the orchestrator needs to keep going lives under
`factory/jobs/`. If the session running `/factory run` dies, gets
compacted, or is just closed, the next `/factory run` reads the inbox and
every job's saved state and resumes exactly where things stopped — no job
quietly disappears, and nothing needs a server kept alive in the background.

## Credit

The core pipeline shape here — triage, then route, then spec → build → gate
→ review → approve, files as the only durable state, small scripts as the
only things that can change it, agents that read files and write back
exactly one — was worked out by studying ZazenCodes'
[software-factory-claude-code-v2](https://github.com/zazencodes/zazencodes-season-3/tree/main/src/software-factory-claude-code-v2)
as a reference design. This version reshapes that pipeline around a local
inbox instead of a GitHub-issues queue, lands work directly on a branch
instead of opening and merging a hosted pull request, and generalizes the
single pipeline into a configurable chain of lines a job can pass through.
