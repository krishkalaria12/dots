#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'repo: %s\n' "$repo_root"
printf 'milestone 1 only: files are curated here, not applied automatically yet.\n'
