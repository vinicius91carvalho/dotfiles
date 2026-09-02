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

# A GitHub token, borrowed from gh for the length of this script.
#
# GitHub allows 60 anonymous API calls an hour per IP address, and one rebuild
# spends five of them: one per flake input to resolve its branch to a commit,
# plus omlxctl's release check. Three rebuilds in an hour and the budget is
# gone. The failure is quiet and expensive: nix prints `HTTP error 403` and
# keeps `using cached version`, so the build still succeeds while the lock
# stops moving - which is exactly the staleness ./rebuild.sh is here to avoid.
#
# gh already holds a token in the login keyring, and authenticated calls get
# 5000 an hour. It is read at run time and never written anywhere: not into the
# repo, not into flake.lock, not into the store. A machine where gh is not
# logged in simply falls back to anonymous calls, which is where this started.
#
# Only the calls on this side of the `sudo` need it. `nix flake update` fetches
# each input into the store, so the darwin-rebuild that follows finds them
# there and asks GitHub nothing - which is why the token is deliberately NOT
# handed to sudo below, where it would sit in the argv of a process anyone on
# the machine can see in `ps`.
GITHUB_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-$(gh auth token 2>/dev/null || true)}}"
if [ -n "$GITHUB_TOKEN" ]; then
  export GITHUB_TOKEN
  export NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN"
else
  echo "gh nao tem token; chamadas ao GitHub vao anonimas (60/h)" >&2
fi

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
#
# `update`, not `lock`. This line used to be `nix flake lock`, which only fills
# in inputs that have no entry yet and leaves the ones already there alone - so
# after the first commit the lock never moved again, and five weeks later every
# package from nixpkgs was still the July build. `update` re-resolves all four
# inputs, which is what "refresh the lock" was always meant to say.
#
# Safe to do on every rebuild because every input in flake.nix points at a 26.05
# release branch, not at a rolling one: this moves along patches and backports,
# it cannot walk onto the next major on its own. When it does break, flake.lock
# is in git and `git checkout flake.lock && ./rebuild.sh` puts it back.
nix flake update --flake "$DIR"

# sudo starts with a clean environment, so every variable has to be handed
# over explicitly. --impure is what lets the flake read them at all.
exec sudo DOTFILES_USER="$DOTFILES_USER" DOTFILES_GPG_KEY="$DOTFILES_GPG_KEY" \
  DOTFILES_MEM_GB="$DOTFILES_MEM_GB" \
  darwin-rebuild switch --impure --flake ~/.dotfiles#mac
