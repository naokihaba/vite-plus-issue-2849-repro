# Reproduction Results for Issue #2849

Both the local and global Vite+ 1.0.0 CLI failed with Git config lock errors when they ran at the same time in two Git worktrees. Both worktrees had completed their initial configuration before the test.

## Test environment

| Item | Value |
| --- | --- |
| OS | macOS 27.0, arm64 |
| Git | 2.55.0 |
| Node.js | v24.20.0 in the initial local tests; v24.21.0 in the comparison tests |
| Vite+ | 1.0.0 |
| Commands | Direct Node.js execution and global `vp config --no-agent` |
| Concurrent runs | Main worktree and linked worktree, two commands per round, 20 rounds |

## Reproduction steps

1. Create a repository with an empty commit and a linked worktree.
2. Write an exact Node.js version to `.node-version` in both worktrees for the global test, then run the configuration command once in each worktree.
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

## Global and local comparison

The global CLI also reproduced the failure after Node.js was pinned to an installed exact version. The direct comparison used the same Node.js v24.21.0 binary and the same Vite+ `dist/bin.js` entry point as the global CLI.

| Execution | Commands | Lock failures | Mean time per command |
| --- | ---: | ---: | ---: |
| Global CLI, no Node.js pin | 20 | 0 | About 5–7 seconds |
| Global CLI, `.node-version` set to `24.21.0` | 40 | 14 | 0.159 seconds |
| Direct execution with the same Node.js v24.21.0 | 40 | 14 | 0.152 seconds |

An earlier global test without a Node.js pin also produced no failures in 48 commands. These results do not show that the global CLI is safe from this bug.

The comparison summaries and command logs are in [evidence/global-comparison](evidence/global-comparison). No manual Git config lock was used in these tests.

The updated script was also tested in both modes. Global mode failed 14 of 40 times, and local mode with Node.js v24.20.0 from PATH failed 13 of 40 times. All failures were config lock failures, and Git config stayed unchanged in both tests. See [global-script-run](evidence/global-script-run) and [local-script-run](evidence/local-script-run).

## Why the earlier global test produced no failures

The global CLI resolves a Node.js runtime before it delegates to the JavaScript CLI. The debug log showed that the Node.js version-index cache had expired. The global CLI tried to fetch `https://nodejs.org/dist/index.json`, failed with a DNS error, then used the expired cache.

In one measured run, this path took 6.105 seconds. With `.node-version` set to the installed exact version `24.21.0`, the global CLI used the cached runtime without a version-index request and completed in 0.154 seconds.

A trace of two unpinned global commands showed that their JavaScript processes started about 0.884 seconds apart. The first process completed its Git config commands before the second began them. The trace also confirmed that both processes wrote the existing config values again.

These observations support a timing explanation: runtime lookup delays prevented the config writes from overlapping in the earlier tests. Removing the lookup delay made the global CLI reproduce the failure. This is specific to the observed test environment; startup timing and network conditions can differ elsewhere. The tests do not establish a Node.js version defect or a Git config lock that protects the global execution path.

See [global-unpinned-debug.log](evidence/global-comparison/global-unpinned-debug.log), [global-pinned-debug.log](evidence/global-comparison/global-pinned-debug.log), and [global-trace.jsonl](evidence/global-comparison/global-trace.jsonl). Home-directory paths in these diagnostic files were replaced with `$HOME` before publication.

## Check for writes when the configuration is unchanged

A separate test temporarily created `config.lock` in the configured test repository, then ran the configuration command in the linked worktree. The command returned exit code 1. With `GIT_TRACE=1`, the log showed an attempt to set the existing value again:

```text
trace: built-in: git config core.hooksPath .vite-hooks/_
error: could not lock config file /private/tmp/vp-2849.46FCKG/repo/.git/config: File exists
```

The config content did not change during the failed run. After the test lock was removed, the command returned exit code 0. See [evidence/controlled-lock.log](evidence/controlled-lock.log).

This separate test used a manually created lock. The concurrent tests in the preceding section did not use a manual lock.

## Test scope

These tests confirm Git config lock failures and configuration command failures. They do not test pnpm installation failures through a `prepare` script or the proposed fix in the issue.

The script supports local and global modes. Its Bash syntax and the CLI path lookup from the public package entry were also checked. A fresh dependency installation was not tested.

See [voidzero-dev/vite-plus#2849](https://github.com/voidzero-dev/vite-plus/issues/2849) for the original report.
