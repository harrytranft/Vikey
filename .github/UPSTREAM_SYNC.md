# Vikey upstream sync monitor

This repository is a personal fork of `tonyminibot/Vikey` with personal Text Expansion changes.

## What the monitor does

- Runs every day at 02:17 UTC (09:17 Vietnam time).
- Can also be started manually from Actions → Upstream Monitor → Run workflow.
- Fetches `main` from `https://github.com/tonyminibot/Vikey`.
- Counts upstream commits not yet included in this fork.
- If there are new commits, creates/updates the automation-owned branch `automation/upstream-sync` by merging upstream into the current personal `main`.
- Stops if Git cannot merge cleanly.
- Runs the Windows Engine/Text Expansion test suite, a Windows Personal Build, and a macOS universal Personal Build.
- Creates or updates a Pull Request against `main` only after all validation jobs pass.
- Never merges the PR automatically and never changes the personal `main` branch itself.

## Required repository setting

For the workflow to open a PR using `GITHUB_TOKEN`, check:

1. Repository → Settings → Actions → General.
2. Under **Workflow permissions**, select **Read and write permissions**.
3. Enable **Allow GitHub Actions to create and approve pull requests**.
4. Save the settings.

The workflow declares the minimum job-level permissions it needs (`contents: write` for its automation branch and `pull-requests: write` for the PR).

## How to use it

- Automatic: no action needed; it checks daily.
- Manual: open the Actions tab, select **Upstream Monitor**, then **Run workflow**.
- Review: inspect the generated PR and its commits before merging it into `main`.
- Conflict: if the workflow fails during the merge step, inspect the failed run logs and resolve the conflict manually. No PR is opened from a conflicted merge.
- Test failure: the sync branch is left available for inspection, but no PR is opened until all validations pass on a later successful run.

## Important safeguards

- The monitor only syncs source code; it does not install or update Vikey on your computer.
- Personal Windows builds must keep `VIKEY_PERSONAL_BUILD=ON`.
- Personal macOS builds must keep Sparkle automatic update checks disabled and remove the upstream feed/public key.
- Text Expansion unit tests run before a sync PR can be opened.
- The sync branch is automation-owned and may be force-updated from the latest personal `main` plus current upstream `main` on each run.
