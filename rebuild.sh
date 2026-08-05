#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

# The account the config is applied to. Defaults to whoever runs this script,
# so a new machine needs no edit; override by exporting DOTFILES_USER.
DOTFILES_USER="${DOTFILES_USER:-$(id -un)}"

# Nix only sees files that git tracks, so a brand new .nix file is invisible
# until it is at least staged.
git -C "$DIR" add -AN . >/dev/null 2>&1 || true

# Refresh the lock as *your* user first. darwin-rebuild runs under sudo, and
# if it updates flake.lock itself, the lock file and .git objects end up owned
# by root, which breaks every later `nix` command you run as yourself.
nix flake lock "$DIR"

# sudo starts with a clean environment, so DOTFILES_USER has to be handed over
# explicitly. --impure is what lets the flake read it at all.
exec sudo DOTFILES_USER="$DOTFILES_USER" \
  darwin-rebuild switch --impure --flake ~/.dotfiles#mac
