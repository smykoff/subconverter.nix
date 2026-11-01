#!/usr/bin/env bash
# Refresh sources.json from the latest upstream GitHub release.
set -euo pipefail
cd "$(dirname "$0")/.."

repo="tindy2013/subconverter"

auth=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

tag=$(curl -fsSL -H 'Accept: application/vnd.github+json' ${auth[@]+"${auth[@]}"} \
  "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)
latest=${tag#v}

current=$(jq -r .version sources.json 2>/dev/null || echo none)

if [ "$latest" = "$current" ]; then
  echo "up to date: $current"
  exit 0
fi

# Ordered so that sources.json keeps a stable layout.
systems=(x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin)
declare -A files=(
  [x86_64-linux]="subconverter_linux64.tar.gz"
  [aarch64-linux]="subconverter_aarch64.tar.gz"
  [x86_64-darwin]="subconverter_darwin64.tar.gz"
  [aarch64-darwin]="subconverter_darwinarm.tar.gz"
)
base="https://github.com/$repo/releases/download/v$latest"

json=$(jq -n --arg v "$latest" '{version: $v}')
for sys in "${systems[@]}"; do
  url="$base/${files[$sys]}"
  hash=$(nix store prefetch-file --json "$url" | jq -r .hash)
  json=$(jq --arg s "$sys" --arg u "$url" --arg h "$hash" \
    '.[$s] = {url: $u, hash: $h}' <<<"$json")
done

jq . <<<"$json" > sources.json
echo "updated: $current -> $latest"
echo "version=$latest" >> "${GITHUB_OUTPUT:-/dev/null}"
