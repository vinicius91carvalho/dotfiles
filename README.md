# dotfiles

My macOS setup as code: apps, CLI tools, keyboard shortcuts, trackpad
gestures, terminal and shell config. One command rebuilds a Mac to match this
repo.

Built with [nix-darwin](https://github.com/nix-darwin/nix-darwin) (system
settings), [home-manager](https://github.com/nix-community/home-manager)
(dotfiles) and [nix-homebrew](https://github.com/zhaofengli/nix-homebrew)
(Mac apps).

**Forking this?** Jump to [Make it yours](#make-it-yours) — there are about ten
values you must change before applying it, or you will get my locale and my git
identity. The username and the GPG key are not among them: they come from
`$DOTFILES_USER`, which `rebuild.sh` defaults to whoever runs it, and
`$DOTFILES_GPG_KEY`, which turns signing off when unset.

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
sudo DOTFILES_USER="$(id -un)" \
  nix run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --impure --flake .#mac
```

Every time after that, just:

```sh
./rebuild.sh
```

**7. Finish the manual bits** — the things that need a human to sign in:

- Sign in to the **App Store** (before step 6, ideally) so WhatsApp and Kindle
  install.
- Sign in to **Setapp**, then reinstall its apps from the Setapp client.
- Wire up **Basic Memory** — register the MCP server, create the projects, open
  the vault in Obsidian. See [Basic Memory](#basic-memory).
- Create your **SSH and GPG keys** — see [SSH and GPG keys](#ssh-and-gpg-keys).
- Run `nvim` once so lazy.nvim downloads the plugins, then `:Lazy restore` to
  pin them to the committed `lazy-lock.json`.
- Grant **Accessibility / Screen Recording** permissions when apps ask. Nix
  cannot set these.

---

## Try it before applying

Nothing here touches the machine. Work down the list; each step is slower and
catches more.

Every command that evaluates the flake needs `--impure` and `DOTFILES_USER`,
because the username is read from the environment. Export it once for the
session, along with the signing key if this machine holds it:

```sh
export DOTFILES_USER="$(id -un)"
export DOTFILES_GPG_KEY=EA380CFFC7FBC723   # omit to build with signing off
```

**1. Type-check the config** (seconds):

```sh
nix flake check --impure --no-build
```

**2. Build the whole system without activating it** (no `sudo`, no changes):

```sh
darwin-rebuild build --impure --flake .#mac
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
| `home.nix` | `settings.user.name`, `settings.user.email` | Your git identity |
| `configuration.nix` | `AppleLanguages`, `AppleLocale` | Your language and locale (mine is `en-BR`) |
| `configuration.nix` | `brews`, `casks`, `masApps` | Your apps — mine are just examples |

Two more worth knowing:

- **`keyboard-shortcuts.nix` is entirely mine.** It was captured from my Mac,
  including that I disable the built-in screenshot shortcuts because CleanShot
  X owns them. Delete the import in `configuration.nix` or regenerate it — see
  [Keyboard shortcuts](#keyboard-shortcuts).
- **`system.defaults`** (dock, finder, trackpad) are my preferences. They are
  harmless, but they are opinions, not defaults.

The username and the GPG key need no editing. `flake.nix` reads
`DOTFILES_USER` and `DOTFILES_GPG_KEY` from the environment and threads them
into `configuration.nix` and `home.nix`, so the same repo applies unchanged on
any account. They are the impure things in the config, which is why every
command carries `--impure`. An unset `DOTFILES_USER` fails with a clear
message; an unset `DOTFILES_GPG_KEY` just leaves commit signing off.

Find whatever else of mine is still hardcoded:

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
| `codex.nix` | Codex, and the MCP servers both it and Claude Code use |
| `local-llm.nix` | The local LLM server, on machines with more than 32 GB |
| `.config/` | Config directories, mirroring `~/.config` (nvim) |
| `rebuild.sh` | Applies everything |

How the pieces relate:

```
rebuild.sh → darwin-rebuild switch --impure --flake ~/.dotfiles#mac
               └── flake.nix → darwinConfigurations."mac"
                     ├── configuration.nix  → macOS settings + Homebrew
                     │     └── keyboard-shortcuts.nix
                     ├── nix-homebrew       → owns the Homebrew install
                     └── home-manager       → home.nix, my dotfiles
                           ├── codex.nix    → the coding agents
                           └── local-llm.nix
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
./rebuild.sh                          # apply the config
nix flake check --impure --no-build   # type-check only
nix flake update                      # update all inputs, then rebuild
nix flake update nixpkgs              # update one input
sudo darwin-rebuild --rollback
```

`rebuild.sh` links the repo to `~/.dotfiles`, stages new files (Nix only sees
files git knows about), updates `flake.lock` as your own user, then runs
`sudo darwin-rebuild switch --impure` with `DOTFILES_USER` set to your account
and `DOTFILES_GPG_KEY` passed through.

Every rebuild moves the lock, so every rebuild is also an update. That is safe
because every input points at a 26.05 release branch, not a rolling one: the
lock walks along patches and backports and cannot cross into the next major on
its own. When an update does break something, `git checkout flake.lock &&
./rebuild.sh` puts the old one back.

**A rebuild borrows your `gh` token.** GitHub allows 60 anonymous API calls an
hour per IP, and one rebuild spends five of them - one per flake input to
resolve its branch to a commit, plus `omlxctl`'s release check. Three rebuilds
in an hour and the budget is gone, and the failure is a quiet one: nix warns
`HTTP error 403`, keeps `using cached version`, and the build succeeds while
the lock silently stops moving. So `rebuild.sh` reads `gh auth token` at run
time and hands it to nix through `NIX_CONFIG`, which buys 5000 calls an hour.
The token is never written to the repo, to `flake.lock` or to the store, and it
is deliberately **not** passed through `sudo`, where it would sit in an argv
that anyone on the machine can read in `ps`. A machine where `gh` is not logged
in just falls back to anonymous calls and says so.

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
xdg.configFile."myapp".source = ./.config/myapp;
```

That copy is read-only. If the tool needs to write into its own config
directory, link the working copy instead:

```nix
xdg.configFile."myapp".source =
  config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/.config/myapp";
```

### Where files live in this repo

Paths mirror the home directory exactly, so you can always tell where
something lands:

| In this repo | Ends up at |
| --- | --- |
| `.config/nvim/` | `~/.config/nvim` |
| `.claude/` | `~/.claude` |

New config goes in the same place it would live at home — no translation,
no guessing.

---

## Neovim

Neovim comes from Nix, so its version is pinned by `flake.lock`. The config is
plain Lua in `.config/nvim/`, with [lazy.nvim](https://lazy.folke.io/) fetching
plugins at runtime.

The directory is linked to the working copy rather than copied into the Nix
store, because lazy.nvim writes `lazy-lock.json` next to its own config and a
store path is read-only:

```
~/.config/nvim → ~/.dotfiles/.config/nvim → this repo
```

Editing the Lua takes effect on the next `nvim` launch — no rebuild.
**`lazy-lock.json` pins plugin versions, so commit it.** It is lazy.nvim's
equivalent of `flake.lock`.

Layout:

| File | Holds |
| --- | --- |
| `init.lua` | Loads the three modules below, in order |
| `lua/vim_config.lua` | Options and the leader key |
| `lua/plugin.lua` | lazy.nvim bootstrap, loads every file in `lua/plugins/` |
| `lua/keys.lua` | Keymaps |
| `lua/plugins/*.lua` | One file per group — navigation, git, ui |

Order matters in `init.lua`: options come first because lazy.nvim resolves
`<leader>` when it registers each plugin's `keys` spec. Load them the other
way round and every `<leader>` binding silently attaches to backslash.

| Key | Does |
| --- | --- |
| `<leader>e` | Oil file browser |
| `<leader>f` / `<leader>s` / `<leader>b` | Files / grep / buffers |
| `<leader>g` | Neogit |
| `gd` | Goto definition (needs an LSP attached) |
| `<Esc>` | Save |
| `<C-a>` | Select all |

`:Lazy` opens the plugin UI; `:Lazy update` refreshes and rewrites the
lockfile; `:Lazy restore` returns to the committed commits.

One gotcha: `programs.neovim` always generates a small `init.lua` (it disables
the node/perl/ruby/python providers) and would write it into
`~/.config/nvim/init.lua`, colliding with the linked directory. Setting
`sideloadInitLua = true` passes that Lua through the neovim wrapper instead.
Without it the build fails with
`Error installing file '.config/nvim/init.lua' outside $HOME`.

---

## Orca

[Orca](https://onorca.dev) runs several coding agents side by side, each in its
own git worktree, from one desktop app. It took over from herdr, which did the
same job in the terminal as a client/server pair.

It comes from upstream's own tap, and the cask is written tap-qualified as
`stablyai/orca/orca`: homebrew-cask already has a different, deprecated `orca`,
so the bare name would install the wrong thing.

Nothing about it is declared here beyond the cask. Orca updates itself in place
(`auto_updates true`), so `brew upgrade` leaves it alone and the installed
version is whatever the app last pulled, not something `flake.lock` pins - the
same call this repo makes for Docker Desktop. Its worktrees and agent state live
in `~/.orca`, which it manages itself.

### The agents it runs

Orca finds an agent by looking for that agent's binary name on `PATH` - its
catalogue maps `omp` to OMP, `claude` to Claude Code, and so on. So an agent
gets "integrated" with Orca simply by being installed. Three are declared in
`configuration.nix`:

| Agent | Comes from | Binary |
| --- | --- | --- |
| Claude Code | `claude-code@latest` cask | `claude` |
| Codex | `codex` cask | `codex` |
| [OMP](https://omp.sh) | `can1357/tap` formula `omp` | `omp` |

All three are casks or formulae rather than Nix packages, and for the same
reason: they ship far faster than a nixpkgs release branch can follow.
`onActivation.upgrade` moves them on every rebuild.

---

## OMP

[OMP (Oh My Pi)](https://omp.sh) is a terminal coding agent with an LSP and a
real debugger wired in. It is the second agent Orca can drive here, next to
Claude Code.

Homebrew, from upstream's tap, because it is not in nixpkgs. The formula only
downloads the published `omp-darwin-arm64` release binary - nothing is built -
so `onActivation.upgrade` moves it to the current release on every rebuild.

Its config lives in `~/.omp` and is **not** managed here: model roles in
`agent/config.yml`, extra providers in `agent/models.yml`, both written by omp
itself. On the first run in a repo it imports the rules and skills already in
`~/.claude`, so `AGENTS.md` applies to it without any extra wiring.

One thing is per-machine and manual, because it is an account, not a config
file: **omp ships with no credentials.** Run `omp` once and use `/login` to add
an account, or `omp auth-broker login <provider>` from a shell - `omp
auth-broker list` prints the providers. Check what is stored with:

```sh
omp usage
```

Until then it will sit on its splash screen, in Orca or out of it.

---

## TurboFieldfare

[TurboFieldfare](https://github.com/drumih/turbo-fieldfare) runs Gemma 4 26B-A4B
in about 2 GB of RAM and exposes an OpenAI-compatible Chat Completions API on
`http://127.0.0.1:8080/v1`. PayCore Academy uses it for grading and tutoring.

Nix owns the **process** — a `launchd` agent in `home.nix` with its flags, its
restart policy and its log at `~/Library/Logs/turbo-fieldfare.log`. Nix does
*not* own the build: upstream ships source only, so a derivation would have to
run `swift build` against the macOS 26 SDK and the Metal 4 toolchain inside the
sandbox, and the model is a ~15 GB stream from a pinned Hugging Face revision.
The same call this repo makes for anything that updates itself in place.

Bootstrap it once per machine:

```bash
git clone https://github.com/drumih/turbo-fieldfare.git ~/.local/share/turbo-fieldfare
cd ~/.local/share/turbo-fieldfare
swift build -c release --product TurboFieldfareServer
swift run -c release TurboFieldfareRepack --output scratch/gemma4.gturbo --overwrite
```

The repack downloads roughly 15 GB and installs about 14.3 GB. Until both the
binary and `scratch/gemma4.gturbo` exist, the launchd agent logs one line and
exits cleanly rather than crash-looping, so a fresh machine is quiet.

Then start it without waiting for a logout:

```bash
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.turbo-fieldfare
curl -s http://127.0.0.1:8080/v1/models
```

Requires macOS 26+, Metal 4 and Apple Silicon. It binds loopback with no auth
and no TLS — never put it behind a proxy or a tunnel.

---

## oMLX and Qwen3.8-27B

[oMLX](https://github.com/jundot/omlx) serves
[Qwen3.8-27B](https://huggingface.co/True2456/Qwen3.8-27B-AWQ-5.0bpw) on
`http://127.0.0.1:1337`, speaking both the OpenAI (`/v1/chat/completions`) and
the Anthropic (`/v1/messages`) protocols, with an admin dashboard and a chat UI
at `/admin`. The model reads images as well as text.

Only on machines with **more than 32 GB** of unified memory. The weights are
17.4 GB and the KV cache grows on top of them; below that the server swaps from
the first prompt. The gate lives in `local-llm.nix`, which is a no-op on a
smaller Mac. `rebuild.sh` measures the memory and hands it to the flake as
`DOTFILES_MEM_GB`, the same way it hands over the username and the GPG key.

Nix owns the **process** — the launchd agent, its flags, and its log at
`~/Library/Logs/omlx.log`. Nix does *not* own the app or the weights, and that
is deliberate:

- Upstream ships a notarized `.dmg` whose ANE prefill kernels are already
  compiled. The Homebrew formula only builds them under
  `--with-custom-kernel`, which compiles `.metal` sources, which needs the
  Metal toolchain, which needs full Xcode — about 20 GB of build dependency to
  arrive at binaries the DMG already carries.
- `~/.omlx/settings.json` and `~/.omlx/model_settings.json` are written by oMLX
  itself, so they are left to it, like `~/.omp` and `~/.claude/settings.json`.

Bootstrap it once per machine — **and only on a machine with more than 32 GB**;
below that `local-llm.nix` is a no-op and the download would be wasted:

```bash
# 0. Check first. 32 or less: stop here, nothing below applies.
echo $(( $(sysctl -n hw.memsize) / 1073741824 ))GB

# 1. The app (pick the DMG matching your macOS major version)
open https://github.com/jundot/omlx/releases       # oMLX-<ver>-macos26-27.dmg
spctl -a -vv -t install /Volumes/oMLX/oMLX.app     # expect: accepted, Notarized
cp -R /Volumes/oMLX/oMLX.app /Applications/

# 2. The weights (17.4 GB)
uvx --from "huggingface_hub[cli]" hf download True2456/Qwen3.8-27B-AWQ-5.0bpw \
  --local-dir ~/tools/qwen3.8-27b/True2456/Qwen3.8-27B-AWQ-5.0bpw
```

Until both exist the launchd agent logs one line and exits cleanly rather than
crash-looping, so a fresh machine is quiet.

`local-llm.nix` also puts **`omlxctl`** on PATH — behind the same 32 GB gate, so
it does not exist on a machine that cannot run the model:

| Command | What it does |
| --- | --- |
| `omlxctl start` / `stop` / `restart` | `stop` uses `launchctl bootout`, never `kill`: `KeepAlive.SuccessfulExit = false` treats a SIGTERM as a crash and brings the server straight back |
| `omlxctl status` | version, model served, resident memory, swap, stored backup |
| `omlxctl logs` | follows `~/Library/Logs/omlx.log` |
| `omlxctl update` | checks the published release and installs it |
| `omlxctl rollback` | restores the previous `.app` |

`./rebuild.sh` runs `omlxctl update` before it hands over to `darwin-rebuild`.
oMLX ships as a DMG, outside both Nix and Homebrew, so nothing else would ever
notice a new release. The update verifies Gatekeeper before anything enters
`/Applications`, keeps the previous `.app` for `rollback`, and exits quietly
when already current. It follows whatever GitHub calls `latest`, **release
candidates included** — hence the backup.

That Gatekeeper check reads `spctl`'s **exit status**, and that detail is the
whole bug it once had. The guard used to grep the output for the word
*accepted*, but `spctl -a` prints nothing at all when it accepts - *accepted*
only appears under `-vv`. So the grep never matched, every update aborted, and
the message on screen blamed upstream. The Mac sat on `0.6.3rc3` while each
rebuild printed a Gatekeeper failure for a release that was properly notarized.
`-vv` is still used, but only on the failing branch, where its output is the
reason worth reading.

### Performance, as measured on this Mac

| Metric | Value |
| --- | --- |
| tg (generation) | **32.2 tok/s** |
| pp (prefill) at 4k | **158 tok/s** |
| pp (prefill) at 12.6k | **137 tok/s** |
| pp with a cached prefix | 4,143 tok/s effective (12.6k in 3.0 s) |
| Largest context accepted | 33.1k tokens, 24.7 GB peak |

### Driving it from OMP

`~/.omp/agent/models.yml` declares the provider and `config.yml` the roles and
compaction. Neither is managed by Nix — omp rewrites both.

The number that matters is `contextWindow: 30000`, **not** the `262144` the
server advertises. oMLX does not truncate, does not compact and has no context
shifting: past the window it returns `HTTP 400 "Prompt too long"`. Compaction is
the agent's job and omp only compacts if it knows the real window.

30000 and not less because omp's own floor is large: measured here, a one-line
question inside `find-best-job` already sends 22.3k–23.2k tokens of system
prompt, tool definitions and instruction files. It stays workable because that
floor is a stable prefix the SSD cache serves — `re-prefills 8892 of 23228
tokens`, turns of 20-26 s instead of the 139 s first cold run.

Roles carry a thinking level (`plan:xhigh`, `default:medium`, `smol:low`,
`commit:low`). The template accepts only `low`, `medium` and `xhigh`; oMLX
remaps the rest, so `off` does not disable thinking.

Then start it without waiting for a logout:

```bash
omlxctl start
curl -s http://127.0.0.1:1337/v1/models
```

The `5.0bpw` build and not the smaller `4.85bpw` one: the 4.85 build was
calibrated on text only, and its own model card calls the vision tower's
precision "a conservative guess rather than a measurement". 0.53 GB is a cheap
price for a vision tower that was actually measured.

Port 1337 because 8000 belongs to infoproduct's webapp and 8080 to
TurboFieldfare. It binds loopback with no auth and no TLS — never put it behind
a proxy or a tunnel.

Two settings were arrived at by measurement, not by taste, and both live in
`local-llm.nix` with the reasoning in a comment:

| Setting | Measured effect on this M3 Max |
| --- | --- |
| `--memory-guard-gb 27` (was 24) | a 12.6k-token prompt: **23 min → 92 s** |
| `mtp_enabled` (per-model) | generation: **17.2 → 32.2 tok/s** |

The first one is the counter-intuitive one. The prefill working set is ~10 MB
per token, so a 2048-token chunk wants 21 GB; a ceiling too low does not
protect anything, because `prefill_priority = "context"` shrinks the chunk to
its 32-token floor instead of refusing the prompt. 27 GB stays under Apple's
own Metal cap for this Mac (28.1 GB).

Generation is capped by memory bandwidth: 300 GB/s ÷ 17.4 GB ≈ 17 tok/s, which
is what B0 measured. MTP is what beats it, by verifying several drafted tokens
per weight read — 88% of drafts accepted here, and no quality cost, since
drafts are rejection-verified.

The Apple Neural Engine is deliberately **off**, and that is a measured call,
not a default left alone. Its prefill programs are compiled eagerly and stay
resident: the documented 64-MLP + 48-GDN layout took the model from 18.76 GB to
28.56 GB, past the guard ceiling, after which the server refused every prompt
including a 69-token one. The 16-layer subset that does fit (+1.15 GB) came out
*slower* where it should have helped - a 12.6k-token prefill went 137 → 129
tok/s - while swap went from 380 MB to 2.2 GB. Upstream's +13%/+57% figures put
all 64 layers on the ANE, which needs more than 36 GB. Worth revisiting on a
bigger machine, not here.

The expensive prefill has a root cause worth knowing: `head_dim = 256`, which
MLX's fused SDPA kernel does not cover (64, 80 and 128 only), so the unfused
path would materialise the whole score matrix - O(L²). oMLX's `sdpa256` patch
already routes around that on its own; forcing it with `OMLX_SDPA256_TILED=1`
changed nothing measurable.

Quality was checked against a hand-written fixture of 12 tasks taken from the
two repos this serves (`~/tools/qwen3.8-27b/eval/`): **12/12, images 4/4**.

There is a plain-language guide to every knob in
`~/Documents/qwen-local-guia.md`: quantization, KV cache, prefill vs decode,
MTP, and what the Apple Neural Engine does and does not buy.

---

## Coding agents

Two agents run on this machine - [Claude Code](https://claude.com/claude-code)
and [Codex](https://developers.openai.com/codex/cli) - and the point of
`codex.nix` is that they behave the same. One set of instructions, one list of
MCP servers, one set of skills. Which one I open should not change the answer I
get.

| The shared thing | Claude Code | Codex | Claude desktop app |
| --- | --- | --- | --- |
| Instructions | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | from the account |
| MCP servers | `~/.claude.json` | `~/.codex/config.toml` | `claude_desktop_config.json` |
| Skills | `~/.claude/skills/` | `~/.codex/skills/` | from the account |

The desktop app is half in and half out. Its MCP servers are managed here, and
its *local agent* sessions are Claude Code, so they read `~/.claude/skills` and
`AGENTS.md` like the CLI does. Its ordinary chat is not local at all: the
instructions and skills there belong to the claude.ai account, which syncs them
down into `~/Library/Application Support/Claude/` on its own. Nothing in this
repo can put a skill there.

Both instruction files are symlinks to this repo's `AGENTS.md`, so there is one
file to edit and no rebuild needed to change it.

The MCP servers are declared once, in `programs.mcp.servers`. home-manager
writes the neutral list to `~/.config/mcp/mcp.json`, and Codex's module
translates it into `[mcp_servers.*]` in `config.toml`. The two Claude clients
cannot be given them the same way, because each keeps its servers in a file it
also writes itself - `~/.claude.json` for Claude Code, which also holds project
history and trust decisions, and `claude_desktop_config.json` for the desktop
app, which also holds its app preferences. So an activation script merges the
declared servers into both and leaves everything else in them alone. Nix owns
the content, each app keeps its file. The declared side wins on a name
collision, which is what makes this repo the source of truth. The desktop app
only sees the change after a restart; Claude Code sees it in the next session.

Server commands are written as absolute paths for the desktop app's sake. A
GUI app is launched by launchd, not by a login shell, so the PATH it hands an
MCP server is whatever the app chooses to build - and when a bare name does not
resolve there, the only symptom is a server showing as failed.

Skills work the other way round. Claude Code gets one symlink for the whole
skills directory; Codex gets one symlink per skill, because it follows a linked
skill *directory* but not a linked `SKILL.md` inside one, and because leaving
`~/.codex/skills` a real directory is what lets the skills that arrive as a
Claude Code *plugin* be linked in beside them. Codex has no plugin system, but a
plugin's skills are plain `SKILL.md` directories, so a second activation script
links them out of `~/.claude/plugins/cache/` - a path whose version component
moves on every plugin update, which is why it is a script and not a `home.file`
entry. It only removes links it made itself, and never overwrites a
Nix-managed name.

**The `codex` binary comes from a Homebrew cask, not from Nix.** Same reason as
Claude Code: `pkgs.codex` on the 26.05 branch sat on 0.133.0 while upstream was
on 0.152.0. `programs.codex.package = null` keeps home-manager writing
`~/.codex/config.toml` without also installing a second, stale binary.

**The Codex desktop app is not declared.** Both casks for it were dead ends -
`codex-app` is deprecated and due to be disabled in July 2027, and `chatgpt`
replaces it - so neither is tracked here. `codex app` installs the GUI on
demand when it is wanted. It needs no configuration either way: it is the same
agent, it reads the same `$CODEX_HOME`, and it picks up the MCP servers and
whatever is in `~/.codex/skills` on first launch. One consequence:
`~/.codex/config.toml` is a read-only store symlink, so a setting changed in
the app's UI cannot be saved - change it in `codex.nix` instead.

**One manual step per machine**, because a login cannot be declarative:

```bash
codex login     # ChatGPT account or API key, or sign in inside the app
codex doctor    # config, auth, MCP servers, all in one report
```

Two things to know about the parity. A brand new skill needs a `./rebuild.sh`
before Codex lists it, while Claude Code sees it immediately - editing an
existing one needs no rebuild in either, since the links point at the working
copy. And a skill that drives Claude Code by name, or reaches for a Claude-only
MCP server, will not do the same thing under Codex: the knowledge in it travels,
the plumbing does not.

---

## Basic Memory

[Basic Memory](https://basicmemory.com) is the long-term knowledge store the AI
agents write to: plain markdown notes in `~/basic-memory`, a search index in
`~/.basic-memory`, and an MCP server every client can talk to. `AGENTS.md` tells
the agents *when* to use it; this section is the plumbing.

It is not in nixpkgs, so it comes from upstream's Homebrew tap, declared in
`configuration.nix` with `trusted = true` - Homebrew 6 refuses to load a formula
from an untrusted third-party tap, and that attribute is what puts
`trusted: true` in the Brewfile. `./rebuild.sh` installs it with no manual
`brew trust` step.

Registering the MCP server is not a manual step any more: it is declared in
`codex.nix`, which hands it to Codex and merges it into Claude Code's own
config on every `./rebuild.sh`. See [Coding agents](#coding-agents) below.
Check it landed with:

```bash
claude mcp get basic-memory   # should say Connected
codex mcp list                # should list basic-memory
tail ~/Library/Logs/Claude/mcp-server-basic-memory.log   # the desktop app
```

**Projects mirror `~/github`.** A repo at `~/github/<org>/<repo>` gets a Basic
Memory project named `<repo>`, stored in `~/basic-memory/<org>/<repo>`, so a work
machine cloning into `~/github/<org>/` lands its notes in `<org>/` with no
extra thought. `personal` is the default project for anything outside `~/github`.

The project list lives in `~/.basic-memory/config.json`, which is per machine and
not synced. Either add them by hand, or just start working — `AGENTS.md` tells the
agent to create a missing project at that path.

On its very first run basic-memory creates a project called `main` pointing at the
vault root, `~/basic-memory`. That one has to go: it contains every other project
as a subdirectory, so it indexes all their notes a second time. Set up `personal`
as the default and drop it.

```bash
bm project add personal ~/basic-memory/personal
bm project default personal
bm project remove main

bm project add <repo> ~/basic-memory/<org>/<repo>
bm project list
```

Always through `bm`, never by editing `config.json` - the project list is also
mirrored in `~/.basic-memory/memory.db`, and a project that exists in one and not
the other confuses `bm` into treating it as a cloud project it has no credentials
for. Recovering means putting the config entry back so `bm project remove` can
take it out of both.

**The vault.** `~/basic-memory` is an Obsidian vault: open it with *Open folder as
vault*. Its `app.json` sets shortest-path wikilinks so the `[[Note Title]]` links
Basic Memory writes resolve natively, and graph, backlinks and tags are core
plugins that are already on. Obsidian Sync (a paid subscription, signed in inside
the app) carries the markdown between machines; the index in `~/.basic-memory`
stays local and is rebuilt from the files on each machine.

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

Export the key id so git signs with it, and rebuild:

```sh
export DOTFILES_GPG_KEY=EA380CFFC7FBC723
./rebuild.sh
```

Nothing to edit: `flake.nix` reads the variable and threads it into
`programs.git.signing`. Put the `export` in a file zsh reads on login so it
survives new shells — `~/.zshenv.local` or your password manager's shell hook,
not `~/.zshrc`, which home-manager owns. On a machine whose keyring does not
hold the secret key, leave it unset: signing is then off, and commits are
unsigned rather than failing with *No secret key*.

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
| Claude Code's own version | The `claude-code@latest` cask tracks upstream's `latest` channel, so `./rebuild.sh` upgrades it; the binary is Nix-declared, its release is not |
| Codex's own version | Same story: the `codex` cask follows upstream's tarball and `./rebuild.sh` upgrades it. `programs.codex.package = null` so nothing installs a second, older one |
| Codex's and Claude Code's logins | Account credentials. `codex login`, and Claude Code's own sign-in, once per machine |
| The desktop app's chat skills | They come from the claude.ai account and sync themselves into `~/Library/Application Support/Claude/`. Only the *local agent* sessions inside the app read `~/.claude/skills` |
| `~/.claude.json` | Claude Code's own file - project history, trust decisions. `codex.nix` merges the declared MCP servers into it and touches nothing else |
| OMP's version and its `~/.omp` config | The tap formula tracks upstream's latest release, so `./rebuild.sh` upgrades it; omp writes its own config, and its logins are account credentials |
| Setapp's apps | Setapp installs and updates its own catalogue |
| Node / Bun / Go | `mise` handles per-project versions; Nix installs mise |
| Nix itself | Determinate owns the daemon |
| Neovim plugins | lazy.nvim manages them; `lazy-lock.json` pins them |
| SSH / GPG private keys | Secrets never belong in a public repo |
| Accessibility permissions | SIP-protected; no tool can write them |

---

## Troubleshooting

**`error: Path 'foo.nix' ... is not tracked by Git`** — Nix reads the flake
through git. `git add foo.nix`.

**`warning: Using 'builtins.derivation' to create a derivation named
'options.json' ... without a proper context`** — every rebuild prints this and
it is not this repo's bug. It is home-manager building its options manpage;
nix-darwin builds the same kind of file and stays quiet. Setting
`manual.manpages.enable = false` in `home.nix` makes it go away, and that was
deliberately **not** done: it removes the trigger, not the bug, and costs `man
home-configuration.nix`. `flake.lock` now moves on every rebuild, so upstream's
fix will arrive on its own. Nothing about the build is actually wrong - the
docs still generate.

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
nix eval --impure '.#darwinConfigurations.mac.config.system.defaults.dock.autohide'
```
