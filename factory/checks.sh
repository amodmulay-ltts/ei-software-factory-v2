#!/usr/bin/env bash
# This project's checks. Exit 0 only when the branch is fit to review.
#
# The gate runs this from the main checkout's copy of this file, with a job's
# worktree as the working directory. Keep it fast, deterministic and
# non-interactive: no watch modes, no prompts, nothing that rewrites files.
#
# Fill this in with the project's real lint, typecheck, test and build
# commands once the project has code, e.g.:
#
#   npm ci --prefer-offline
#   npm run lint
#   npm run typecheck
#   npm test -- --run
#   npm run build
set -euo pipefail

echo "factory/checks.sh has no checks yet. Add this project's test, lint, typecheck and build commands." >&2
exit 1
