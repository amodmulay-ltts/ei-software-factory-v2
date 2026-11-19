# AGENTS.md

Right now this repo is just the factory itself — no application code yet.
Once real code lands here, keep this file current with:

- **Setup**: how to get a fresh checkout running (dependency installs, env
  files to copy).
- **Dev server**: how to start it and on what port, assuming the project
  has one.
- **Validation**: the exact commands that prove a change is sound — these
  should line up with `factory/checks.sh`, command for command.

## About the factory

`/factory run` works through whatever's filed in `factory/inbox/`, one job
per topic, carrying each through triage → spec → build → gate → review →
approve and landing approved work on the base branch. A line's `handoff`
setting (in `factory/config.json`) can pass a finished job on to another line
— `build` handing to `docs`, for instance — before it's actually done.

- State lives in `factory/jobs/<job-id>/` (gitignored).
- `factory/bin/job` is the only thing allowed to write that state.
- Checks: `factory/checks.sh` (plus whatever script other lines point to).
- Dashboard: `cd factory && python3 -m http.server`, then open
  `http://localhost:8000/dashboard.html`.

Every job gets its own git worktree — a full checkout at
`.worktrees/<job-id>` (gitignored). Any tool you run from the repo root that
doesn't respect `.gitignore` will also see those copies, so exclude
`.worktrees/` in its own config if that matters.

See [README.md](README.md) for the full picture and day-to-day usage, and
[DESIGN.md](DESIGN.md) for the reasoning behind how it's built.
