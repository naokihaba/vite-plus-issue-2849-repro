#!/usr/bin/env bash
set -eu

script_dir=$(cd "$(dirname "$0")" && pwd)
cd "$script_dir"
mode=local
if [ "${1:-}" = --global ]; then
  mode=global
  cli="${2:-$HOME/.vite-plus/bin/vp}"
else
  cli="${1:-}"
  if [ -z "$cli" ]; then
    cli=$(node -p 'require("node:path").resolve(require("node:path").dirname(require.resolve("vite-plus")), "../bin/vp")')
  fi
fi
if [ ! -f "$cli" ]; then
  echo "CLI file not found: $cli" >&2
  exit 1
fi
cli=$(cd "$(dirname "$cli")" && pwd)/$(basename "$cli")
if [ "$mode" = global ]; then
  cli_command=("$cli")
else
  cli_command=(node "$cli")
fi
node_version="${REPRO_NODE_VERSION:-24.21.0}"
if [[ ! "$node_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "REPRO_NODE_VERSION must be an exact version, such as 24.21.0." >&2
  exit 1
fi

repro_dir=$(mktemp -d "${TMPDIR:-/tmp}/vp-2849-rerun.XXXXXX")
echo "Logs: $repro_dir"
git init -q "$repro_dir/repo"
git -C "$repro_dir/repo" -c user.name=Repro -c user.email=repro@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q --allow-empty -m init
git -C "$repro_dir/repo" -c core.hooksPath=/dev/null worktree add -q --detach "$repro_dir/worktree" HEAD
# An exact version avoids version-index requests before global CLI delegation.
printf '%s\n' "$node_version" > "$repro_dir/repo/.node-version"
printf '%s\n' "$node_version" > "$repro_dir/worktree/.node-version"
echo "Mode: $mode; .node-version: $node_version"
(cd "$repro_dir/repo" && "${cli_command[@]}" config --no-agent)
(cd "$repro_dir/worktree" && "${cli_command[@]}" config --no-agent)
cp "$repro_dir/repo/.git/config" "$repro_dir/config-before.txt"

run_config() {
  local tree="$1" round="$2" code=0
  (cd "$repro_dir/$tree" && "${cli_command[@]}" config --no-agent) > "$repro_dir/$tree-$round.log" 2>&1 || code=$?
  echo "$code" > "$repro_dir/$tree-$round.status"
}

for ((i=1; i<=20; i++)); do
  run_config repo "$i" &
  run_config worktree "$i" &
  wait
done

failed=0
lock_failed=0
for result in "$repro_dir"/*.status; do
  if [ "$(cat "$result")" != 0 ]; then
    failed=$((failed + 1))
    if grep -q 'could not lock config file' "${result%.status}.log"; then
      lock_failed=$((lock_failed + 1))
    fi
    cat "${result%.status}.log"
  fi
done
cp "$repro_dir/repo/.git/config" "$repro_dir/config-after.txt"
unchanged=false
if cmp -s "$repro_dir/config-before.txt" "$repro_dir/config-after.txt"; then
  unchanged=true
fi
printf '{"runs":40,"failures":%s,"lock_failures":%s,"config_unchanged":%s}\n' "$failed" "$lock_failed" "$unchanged" > "$repro_dir/summary.json"
cat "$repro_dir/summary.json"
if [ "$failed" -ne "$lock_failed" ]; then
  echo "A run failed for a reason other than a Git config lock." >&2
  exit 1
fi
if [ "$unchanged" != true ]; then
  echo "Git config changed during the run." >&2
  exit 1
fi
if [ "$lock_failed" -eq 0 ]; then
  echo "No lock failure occurred. Run the script again." >&2
  exit 2
fi
