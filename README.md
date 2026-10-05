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

## Run the global CLI

Use an existing global Vite+ 1.0.0 installation:

```sh
bash reproduce.sh --global
```

The default global binary is `$HOME/.vite-plus/bin/vp`. To use another location:

```sh
bash reproduce.sh --global /path/to/global/vp
```

You can also run `pnpm repro:global`. The script uses the global binary path, so the package manager's local `vp` command does not replace it.

The script writes `.node-version` with `24.21.0` in both temporary worktrees before setup. To use another exact Node.js version:

```sh
REPRO_NODE_VERSION=22.18.0 bash reproduce.sh --global
```

The global CLI can download the selected runtime during setup if it is not installed. Local mode uses `node` from PATH; `.node-version` does not change that process's runtime.

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

Both local and global execution reproduced the lock failure. In the comparison test, the global CLI with Node.js pinned to `24.21.0` failed 14 of 40 times. Direct execution with the same Node.js binary also failed 14 of 40 times.

Earlier global tests without a Node.js pin produced no failures. In this environment, an expired version-index cache caused a network request that failed with a DNS error. This delayed CLI startup and changed the timing between commands. Pinning the installed Node.js version removed this lookup delay.

See [REPORT.md](REPORT.md) for the results and test scope. Saved logs are in [evidence/final-run](evidence/final-run), [evidence/previous-run](evidence/previous-run), and [evidence/global-comparison](evidence/global-comparison).
