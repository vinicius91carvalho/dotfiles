#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

# Nix only sees files that git tracks, so a brand new .nix file is invisible
# until it is at least staged.
git -C "$DIR" add -AN . >/dev/null 2>&1 || true

# Refresh the lock as *your* user first. darwin-rebuild runs under sudo, and
# if it updates flake.lock itself, the lock file and .git objects end up owned
# by root, which breaks every later `nix` command you run as yourself.
nix flake lock "$DIR"

exec sudo darwin-rebuild switch --flake ~/.dotfiles#mac
