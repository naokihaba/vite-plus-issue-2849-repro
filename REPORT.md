# Reproduction Results for Issue #2849

The Vite+ 1.0.0 local CLI failed with Git config lock errors when it ran at the same time in two Git worktrees. Both worktrees had completed their initial configuration before the test.

## Test environment

| Item | Value |
| --- | --- |
| OS | macOS 27.0, arm64 |
| Git | 2.55.0 |
| Node.js | v24.20.0 |
| Vite+ | 1.0.0 |
| Command | `node <vite-plus/bin/vp> config --no-agent` |
| Concurrent runs | Main worktree and linked worktree, two commands per round, 20 rounds |

## Reproduction steps

1. Create a repository with an empty commit and a linked worktree.
2. Run the configuration command once in each worktree.
3. Run the command at the same time in both worktrees for 20 rounds.
4. Check the exit code and log for each command.

Use [reproduce.sh](reproduce.sh) to run these steps. See [README.md](README.md) for dependency installation instructions.

## Results

The final reproduction script was tested with the existing Vite+ 1.0.0 installation. Of 40 commands, 15 failed. All 15 failures were Git config lock failures. The Git config content was the same before and after the test. The evidence is in [evidence/final-run](evidence/final-run).

```json
{"runs":40,"failures":15,"lock_failures":15,"config_unchanged":true}
```

In the preceding test, 18 of 40 commands failed. All 18 failure logs contained `could not lock config file`. The evidence is in [evidence/previous-run](evidence/previous-run).

```text
error: could not lock config file .git/config: File exists
```

Commands in the linked worktree also produced errors that named the shared config file in the main repository:

```text
error: could not lock config file /private/tmp/vp-2849-rerun.clDRK7/repo/.git/config: File exists
```

Two other tests produced 18 and 19 failures out of 40 commands. These are individual test results. They do not establish a fixed failure rate.

## Check for writes when the configuration is unchanged

A separate test temporarily created `config.lock` in the configured test repository, then ran the configuration command in the linked worktree. The command returned exit code 1. With `GIT_TRACE=1`, the log showed an attempt to set the existing value again:

```text
trace: built-in: git config core.hooksPath .vite-hooks/_
error: could not lock config file /private/tmp/vp-2849.46FCKG/repo/.git/config: File exists
```

The config content did not change during the failed run. After the test lock was removed, the command returned exit code 0. See [evidence/controlled-lock.log](evidence/controlled-lock.log).

This separate test used a manually created lock. The concurrent tests in the preceding section did not use a manual lock.

## Test scope

The global `vp config` command produced no failures in 48 concurrent runs. The reproduction script therefore starts the local CLI directly. The cause of the difference between global and local execution was not investigated.

These tests confirm Git config lock failures and configuration command failures. They do not test pnpm installation failures through a `prepare` script or the proposed fix in the issue.

The Bash syntax and the CLI path lookup from the public package entry were also checked. A fresh dependency installation was not tested.

See [voidzero-dev/vite-plus#2849](https://github.com/voidzero-dev/vite-plus/issues/2849) for the original report.
