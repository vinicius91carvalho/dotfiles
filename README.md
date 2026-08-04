# dotfiles

My macOS setup as code: apps, CLI tools, keyboard shortcuts, trackpad
gestures, terminal and shell config. One command rebuilds a Mac to match this
repo.

Built with [nix-darwin](https://github.com/nix-darwin/nix-darwin) (system
settings), [home-manager](https://github.com/nix-community/home-manager)
(dotfiles) and [nix-homebrew](https://github.com/zhaofengli/nix-homebrew)
(Mac apps).

**Forking this?** Jump to [Make it yours](#make-it-yours) — there are about ten
values you must change before applying it, or you will get my username, my
locale and my GPG key.

---

## Install on a new Mac

**1. Xcode Command Line Tools** — git and Homebrew need them.

```sh
xcode-select --install
```

**2. Nix**, via the Determinate installer. Open a new terminal afterwards so
`nix` is on `PATH`.

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
```

**3. Clone the repo.**

```sh
git clone https://github.com/vinicius91carvalho/dotfiles ~/github/vinicius91carvalho/dotfiles
cd ~/github/vinicius91carvalho/dotfiles
```

**4. Change the values in [Make it yours](#make-it-yours)** if this is not my
machine.

**5. Test it** — see the next section. Do not skip this.

**6. Apply it.** `darwin-rebuild` does not exist yet on a fresh machine, so
fetch it once with `nix run`:

```sh
sudo nix run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake .#mac
```

Every time after that, just:

```sh
./rebuild.sh
```

**7. Finish the manual bits** — the things that need a human to sign in:

- Sign in to the **App Store** (before step 6, ideally) so WhatsApp and Kindle
  install.
- Sign in to **Setapp**, then reinstall its apps from the Setapp client.
- Install **Claude Code**: `curl -fsSL https://claude.ai/install.sh | bash`
- Create your **SSH and GPG keys** — see [SSH and GPG keys](#ssh-and-gpg-keys).
- Run `nvim` once so lazy.nvim downloads the plugins, then `:Lazy restore` to
  pin them to the committed `lazy-lock.json`.
- Grant **Accessibility / Screen Recording** permissions when apps ask. Nix
  cannot set these.

---

## Try it before applying

Nothing here touches the machine. Work down the list; each step is slower and
catches more.

**1. Type-check the config** (seconds):

```sh
nix flake check --no-build
```

**2. Build the whole system without activating it** (no `sudo`, no changes):

```sh
darwin-rebuild build --flake .#mac
```

This leaves a `./result` symlink. If it fails, nothing has happened to your
Mac.

**3. See exactly what would change** — compare the built system against the
running one:

```sh
nix store diff-closures /run/current-system ./result
```

You get a package-by-package list of what gets added, removed or upgraded.
This is the closest thing to a dry run.

**4. Check what Homebrew would remove.** My config uses
`onActivation.cleanup = "zap"`, which uninstalls any brew package not declared
in `configuration.nix` — and deletes its config files too. Confirm the list is
empty before applying:

```sh
brew bundle cleanup --file="$(nix-store -qR ./result | grep -m1 Brewfile)"
```

No output means nothing would be removed. (Without `--force` it only reports.)

**5. If a switch goes wrong**, every previous generation is still on disk:

```sh
sudo darwin-rebuild --rollback
sudo darwin-rebuild --list-generations
```

> Note: `darwin-rebuild switch --dry-run` is *not* a safe preview — the flag
> only reaches the build step and activation still runs. Use `build` +
> `diff-closures` above.

---

## Make it yours

Copy the repo, then change these. Everything else is portable.

| File | Value | Change to |
| --- | --- | --- |
| `configuration.nix` | `nixpkgs.hostPlatform = "aarch64-darwin"` | `"x86_64-darwin"` on an Intel Mac |
| `configuration.nix` | `system.primaryUser` | Your macOS username |
| `configuration.nix` | `nix-homebrew.user` | Your macOS username |
| `configuration.nix` | `users.users.vinicius91carvalho.home` | Your username and home path |
| `flake.nix` | `home-manager.users.vinicius91carvalho` | Your macOS username |
| `home.nix` | `home.username`, `home.homeDirectory` | Your username and home path |
| `home.nix` | `settings.user.name`, `settings.user.email` | Your git identity |
| `home.nix` | `signing.key` | Your GPG key id, or delete the `signing` block |
| `configuration.nix` | `AppleLanguages`, `AppleLocale` | Your language and locale (mine is `en-BR`) |
| `configuration.nix` | `brews`, `casks`, `masApps` | Your apps — mine are just examples |

Two more worth knowing:

- **`keyboard-shortcuts.nix` is entirely mine.** It was captured from my Mac,
  including that I disable the built-in screenshot shortcuts because CleanShot
  X owns them. Delete the import in `configuration.nix` or regenerate it — see
  [Keyboard shortcuts](#keyboard-shortcuts).
- **`system.defaults`** (dock, finder, trackpad) are my preferences. They are
  harmless, but they are opinions, not defaults.

Find every place my username appears:

```sh
grep -rn "vinicius91carvalho" --include="*.nix" .
```

---

## What's in here

| File | Holds |
| --- | --- |
| `flake.nix` | Inputs, and the wiring of the three modules |
| `flake.lock` | Exact pinned version of every input |
| `configuration.nix` | System: Homebrew apps, dock, finder, trackpad, locale |
| `keyboard-shortcuts.nix` | macOS keyboard shortcuts |
| `home.nix` | User: shell, git, ghostty, neovim, CLI tools, fonts, ssh |
| `config/nvim/` | LazyVim config, linked to `~/.config/nvim` |
| `rebuild.sh` | Applies everything |

How the pieces relate:

```
rebuild.sh → darwin-rebuild switch --flake ~/.dotfiles#mac
               └── flake.nix → darwinConfigurations."mac"
                     ├── configuration.nix  → macOS settings + Homebrew
                     │     └── keyboard-shortcuts.nix
                     ├── nix-homebrew       → owns the Homebrew install
                     └── home-manager       → home.nix, my dotfiles
```

`mac` is a config name, not a hostname, so this works on any Mac.

### Why both Nix and Homebrew

Nix is great at CLI tools and bad at Mac `.app` bundles. So:

| Kind | Managed by |
| --- | --- |
| GUI apps | Homebrew casks |
| App Store apps | `mas`, driven by Homebrew |
| CLI tools and dotfiles | Nix / home-manager |

Nix itself is installed by Determinate, which manages the daemon — that is why
`configuration.nix` sets `nix.enable = false`, so nix-darwin does not fight it.

### Nix syntax, in ten seconds

```nix
{
  enable = true;                   # boolean
  tilesize = 57;                   # number
  theme = "Dracula";               # string, double quotes
  casks = [ "ghostty" "claude" ];  # list — spaces, no commas
  dock.autohide = true;            # nested attribute
}
```

Every line ends in a semicolon. `#` is a comment. `with`, `let`, `in`,
`inherit`, `import` are reserved words — quote a setting that collides with
one: `"with" = "On my way!";`.

---

## Everyday use

```sh
./rebuild.sh                 # apply the config
nix flake check --no-build   # type-check only
nix flake update             # update all inputs, then rebuild
nix flake update nixpkgs     # update one input
sudo darwin-rebuild --rollback
```

`rebuild.sh` links the repo to `~/.dotfiles`, stages new files (Nix only sees
files git knows about), refreshes `flake.lock` as your own user, then runs
`sudo darwin-rebuild switch`.

I commit only after a rebuild works, so the git history is a history of
configs that actually ran.

---

## Adding things

### CLI tools

In `home.nix`. If home-manager has a module for it, use that — you get the
config file and shell integration too:

```nix
programs.fzf = {
  enable = true;
  enableZshIntegration = true;
};
```

Otherwise just the package:

```nix
home.packages = with pkgs; [ tree wget ];
```

Search: `nix search nixpkgs <name>` and
<https://home-manager-options.extranix.com/>.

### Mac apps

Add the cask to `configuration.nix`:

```nix
casks = [ "ghostty" "claude" "rectangle" ];
```

Find the name with `brew search --cask <name>`. If the app is **already
installed by hand**, Homebrew refuses to overwrite it — adopt it once:

```sh
brew install --cask --adopt <name>
```

### App Store apps

By numeric id, not name:

```nix
masApps = {
  "WhatsApp" = 310633997;
};
```

Find ids with `mas list` (installed) or `mas search "<name>"`.

### macOS settings

Change it in System Settings, then find the key by diffing:

```sh
defaults read > /tmp/before.txt
# ...change the setting...
defaults read > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt
```

If nix-darwin has a typed option for it
(<https://nix-darwin.github.io/nix-darwin/manual/>), use it:

```nix
system.defaults.dock.show-recents = false;
```

Careful: `defaults read` prints booleans as `0`/`1`, but nix-darwin usually
wants real `true`/`false`. The build tells you if you get it wrong.

If there is no typed option, write the raw key:

```nix
system.defaults.CustomUserPreferences."com.apple.Safari" = {
  ShowFullURLInSmartSearchField = true;
};
```

Some settings only apply after `killall Dock`, `killall Finder`, or a logout.

### Keyboard shortcuts

macOS stores these as undocumented numeric ids, so I generated
`keyboard-shortcuts.nix` from the live plist rather than writing it by hand:

```sh
plutil -convert xml1 -o - ~/Library/Preferences/com.apple.symbolichotkeys.plist
```

`parameters` is `[ ascii keyCode modifierMask ]`, where the mask sums:
Shift `131072`, Control `262144`, Option `524288`, Command `1048576`,
Fn `8388608`.

### Config files

Prefer a home-manager module. Note the `package = null` trick I use for
ghostty: the app comes from a cask, but home-manager still owns its config
file.

```nix
programs.ghostty = {
  enable = true;
  package = null;          # installed via Homebrew, not Nix
  settings.theme = "Dracula";
};
```

For a whole directory:

```nix
xdg.configFile."myapp".source = ./config/myapp;
```

That copy is read-only. If the tool needs to write into its own config
directory, link the working copy instead:

```nix
xdg.configFile."myapp".source =
  config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/config/myapp";
```

---

## Neovim and LazyVim

Neovim comes from Nix, so its version is pinned. [LazyVim](https://www.lazyvim.org/)
does not — it is plain Lua in `config/nvim/`, and lazy.nvim downloads plugins
at runtime.

That is on purpose: lazy.nvim writes `lazy-lock.json` into its own config
directory, which a read-only Nix store path forbids. So the directory is
linked to the working copy:

```
~/.config/nvim → ~/.dotfiles/config/nvim → this repo
```

Editing the Lua takes effect immediately, no rebuild. **`lazy-lock.json` is
what pins plugin versions — commit it.** It is LazyVim's equivalent of
`flake.lock`.

| Command | Does |
| --- | --- |
| `:Lazy` | Plugin UI — install, update, profile |
| `:Lazy update` | Update plugins, rewrite `lazy-lock.json` |
| `:Lazy restore` | Roll back to the committed `lazy-lock.json` |
| `:LazyExtras` | Enable language packs |
| `:checkhealth` | Find missing dependencies |

Options, keymaps and autocmds go in `config/nvim/lua/config/`; plugins in
`config/nvim/lua/plugins/`.

One gotcha: `programs.neovim` always generates a small `init.lua` (it disables
the node/perl/ruby/python providers) and would write it into
`~/.config/nvim/init.lua`, colliding with the linked directory. Setting
`sideloadInitLua = true` passes that Lua through the neovim wrapper instead.
Without it the build fails with
`Error installing file '.config/nvim/init.lua' outside $HOME`.

---

## SSH and GPG keys

**No private keys are in this repo, and none should ever be.** Only the config
that points at them is declarative:

- `programs.ssh.settings."github.com"` → writes `~/.ssh/config`
- `programs.git.signing` → signs every commit and tag
- `programs.gpg.enable` → installs gnupg, leaves my keys alone

Both of my keys are ed25519 with **no passphrase**. That is a deliberate
trade-off: convenient, but anything that can read the files can act as me on
GitHub. Add passphrases if that is not an acceptable risk for you — see the
bottom of this section.

### Generating them

**SSH:**

```sh
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "you@example.com" -f ~/.ssh/id_ed25519 -N ""
```

- `-t ed25519` — modern, short key. GitHub recommends it over RSA.
- `-C` — a comment, conventionally your email, to identify the key.
- `-f` — output path.
- `-N ""` — empty passphrase. **Drop this flag** to be prompted for one.

**GPG**, non-interactively with a batch file:

```sh
cat > /tmp/gpg-batch <<'EOF'
%no-protection
Key-Type: EDDSA
Key-Curve: ed25519
Key-Usage: sign
Subkey-Type: ECDH
Subkey-Curve: cv25519
Subkey-Usage: encrypt
Name-Real: Your Name
Name-Email: you@example.com
Expire-Date: 0
%commit
EOF

gpg --batch --generate-key /tmp/gpg-batch && rm /tmp/gpg-batch
```

- `%no-protection` — no passphrase. **Remove this line** to be prompted.
- `Key-Usage: sign` plus an `encrypt` subkey — the standard pair; GitHub only
  needs the signing half.
- `Expire-Date: 0` — never expires.

If gnupg is not installed yet, run it through Nix without installing anything:

```sh
nix shell nixpkgs#gnupg -c gpg --batch --generate-key /tmp/gpg-batch
```

Prefer answering prompts instead? `gpg --full-generate-key`, then choose
*ECC (sign and encrypt)* and *Curve 25519*.

### Adding them to GitHub

> `gpg` only lands on your `PATH` after the first `./rebuild.sh`, since
> `programs.gpg.enable` is what installs it. Before that, prefix any `gpg`
> command below with `nix shell nixpkgs#gnupg -c`, e.g.
> `nix shell nixpkgs#gnupg -c gpg --armor --export <KEY_ID> | pbcopy`.

Get your GPG key id — the part after the slash on the `sec` line:

```sh
gpg --list-secret-keys --keyid-format=long
# sec   ed25519/EA380CFFC7FBC723 2026-08-04 [SC]
#                ^^^^^^^^^^^^^^^^ this
```

Copy each public key to the clipboard, then paste it into GitHub:

```sh
# SSH → https://github.com/settings/ssh/new   (type: Authentication Key)
pbcopy < ~/.ssh/id_ed25519.pub

# GPG → https://github.com/settings/gpg/new
gpg --armor --export EA380CFFC7FBC723 | pbcopy
```

Put the key id in `home.nix` so git signs with it:

```nix
programs.git.signing = {
  key = "EA380CFFC7FBC723";
  format = "openpgp";
  signByDefault = true;
};
```

The email on the GPG key must match `settings.user.email`, or GitHub shows
commits as *Unverified*.

### Verifying

```sh
ssh -T git@github.com          # "Hi <user>! You've successfully authenticated"
git commit --allow-empty -m test && git log --show-signature -1
```

### Adding a passphrase later

```sh
ssh-keygen -p -f ~/.ssh/id_ed25519
gpg --edit-key <KEY_ID> passwd
```

Then add `UseKeychain yes` to the SSH host block in `home.nix`, and install
`pinentry_mac` so gpg can prompt you.

GPG also wrote a **revocation certificate** to `~/.gnupg/openpgp-revocs.d/`.
Keep it somewhere safe and outside this repo — it is how you revoke the key if
the private half ever leaks.

---

## Not managed here

| Thing | Why |
| --- | --- |
| Claude Code | Self-updating native installer; Nix would keep reverting it |
| Setapp's apps | Setapp installs and updates its own catalogue |
| Node / Bun | `mise` handles per-project versions; Nix installs mise |
| Nix itself | Determinate owns the daemon |
| Neovim plugins | lazy.nvim manages them; `lazy-lock.json` pins them |
| SSH / GPG private keys | Secrets never belong in a public repo |
| Accessibility permissions | SIP-protected; no tool can write them |

---

## Troubleshooting

**`error: Path 'foo.nix' ... is not tracked by Git`** — Nix reads the flake
through git. `git add foo.nix`.

**`error: undefined variable 'x'` in `flake.nix`** — an input is in `inputs`
but missing from the `outputs` argument list. It must be in both.

**`error: opening file 'flake.lock': Permission denied`** — a `sudo` rebuild
updated the lock and left it owned by root:

```sh
sudo chown -R "$(id -un):staff" flake.lock .git
```

**`It seems there is already an App at '/Applications/X.app'`** — installed by
hand. `brew install --cask --adopt <name>`.

**`is not of type 'null or boolean'`** — you wrote `1` where nix-darwin wants
`true`.

**`syntax error, unexpected 'with'`** — a setting name collided with a Nix
keyword. Quote it: `"with" = ...`.

**A setting applied but nothing changed** — `killall Dock`, `killall Finder`,
or log out.

**A brew package disappeared** — it was not declared, and `cleanup = "zap"`
removed it. Add it to `brews` or `casks`.

---

## Credits

I built this while following
[this video](https://www.youtube.com/watch?v=5N-okeDdIuI) — a good starting
point if you are new to nix-darwin and want the reasoning behind the setup
rather than just the files.

---

## Links

- [nix-darwin options](https://nix-darwin.github.io/nix-darwin/manual/) — also `man configuration.nix`
- [home-manager options](https://home-manager-options.extranix.com/)
- [Nix packages](https://search.nixos.org/packages)
- [Homebrew formulae and casks](https://formulae.brew.sh/)
- [Nix language basics](https://nix.dev/tutorials/nix-language)
- [Determinate Nix docs](https://docs.determinate.systems/)

To read back what an option actually resolves to:

```sh
nix eval '.#darwinConfigurations.mac.config.system.defaults.dock.autohide'
```
