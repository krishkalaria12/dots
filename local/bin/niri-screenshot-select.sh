#!/usr/bin/env bash

set -euo pipefail

dir="$HOME/Pictures/Screenshots"
file="$dir/Screenshot from $(date +'%Y-%m-%d %H-%M-%S').png"

mkdir -p "$dir"
grim -g "$(slurp)" - | tee "$file" | wl-copy
