#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

# The account the config is applied to. Defaults to whoever runs this script,
# so a new machine needs no edit; override by exporting DOTFILES_USER.
DOTFILES_USER="${DOTFILES_USER:-$(id -un)}"

# The GPG key git signs with. There is nothing to default it to, so leaving it
# unset is how a machine that does not hold the key says "do not sign".
DOTFILES_GPG_KEY="${DOTFILES_GPG_KEY:-}"

# Nix only sees files that git tracks, so a brand new .nix file is invisible
# until it is at least staged.
git -C "$DIR" add -AN . >/dev/null 2>&1 || true

# Refresh the lock as *your* user first. darwin-rebuild runs under sudo, and
# if it updates flake.lock itself, the lock file and .git objects end up owned
# by root, which breaks every later `nix` command you run as yourself.
nix flake lock "$DIR"

# sudo starts with a clean environment, so both variables have to be handed
# over explicitly. --impure is what lets the flake read them at all.
exec sudo DOTFILES_USER="$DOTFILES_USER" DOTFILES_GPG_KEY="$DOTFILES_GPG_KEY" \
  darwin-rebuild switch --impure --flake ~/.dotfiles#mac
