# Vite+ Issue #2849 Reproduction

Run the Vite+ 1.0.0 configuration command at the same time in two configured Git worktrees to check for Git config lock failures.

Issue: [voidzero-dev/vite-plus#2849](https://github.com/voidzero-dev/vite-plus/issues/2849)

## Run the reproduction

You need Node.js, Git, Bash, and pnpm. This reproduction was tested on macOS.

```sh
pnpm install --ignore-scripts
pnpm repro
```

To use an existing Vite+ installation, supply the path to its local CLI:

```sh
bash reproduce.sh "$HOME/.vite-plus/current/node_modules/vite-plus/bin/vp"
```

This command uses the version at the supplied path. Make sure that it is Vite+ 1.0.0.

## Read the results

The script creates a new repository and a linked worktree in a temporary directory. It completes the initial configuration in both worktrees, then runs two configuration commands at the same time for 20 rounds. It does not change existing repositories.

The temporary directory contains the logs, exit codes, Git config files before and after the test, and `summary.json`.

The script returns these exit codes:

- `0`: At least one Git config lock failure occurred, and the Git config content did not change.
- `2`: No Git config lock failure occurred.
- `1`: Another failure occurred, or the Git config content changed.

A lock failure produces this error:

```text
error: could not lock config file .git/config: File exists
```

The number of failures can change between runs because the failures depend on process timing.

The script starts the local CLI directly with `node <vite-plus/bin/vp> config --no-agent`. In this environment, 48 concurrent runs through the global `vp config` command produced no failures. The cause of this difference is unknown.

See [REPORT.md](REPORT.md) for the results and test scope. Saved logs are in [evidence/final-run](evidence/final-run) and [evidence/previous-run](evidence/previous-run).
