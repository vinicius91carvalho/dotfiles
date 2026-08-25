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

# The machine's unified memory in GB. local-llm.nix only installs the local
# model server above 32 GB, and nothing in the Nix language can read hardware,
# so it is measured here and handed to the flake like the two variables above.
DOTFILES_MEM_GB="${DOTFILES_MEM_GB:-$(( $(sysctl -n hw.memsize) / 1073741824 ))}"

# oMLX ships as a DMG, outside Nix and outside Homebrew, so nothing else would
# ever notice a new release. omlxctl checks and installs one, keeping the
# previous .app for `omlxctl rollback`. It exits quietly when already current.
#
# `command -v` first: omlxctl is declared in local-llm.nix, so on a fresh
# machine - or any machine with 32 GB or less - it does not exist yet. And `||
# true` because a GitHub outage must never be the reason a rebuild fails.
command -v omlxctl >/dev/null 2>&1 && omlxctl update || true

# Nix only sees files that git tracks, so a brand new .nix file is invisible
# until it is at least staged.
git -C "$DIR" add -AN . >/dev/null 2>&1 || true

# Refresh the lock as *your* user first. darwin-rebuild runs under sudo, and
# if it updates flake.lock itself, the lock file and .git objects end up owned
# by root, which breaks every later `nix` command you run as yourself.
nix flake lock "$DIR"

# sudo starts with a clean environment, so every variable has to be handed
# over explicitly. --impure is what lets the flake read them at all.
exec sudo DOTFILES_USER="$DOTFILES_USER" DOTFILES_GPG_KEY="$DOTFILES_GPG_KEY" \
  DOTFILES_MEM_GB="$DOTFILES_MEM_GB" \
  darwin-rebuild switch --impure --flake ~/.dotfiles#mac
