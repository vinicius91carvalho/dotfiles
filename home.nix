{ pkgs, config, username, signingKey, ... }:

{
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # Leave at the release this config was first written against. It pins
  # backwards-compatible defaults; it is not a version to keep bumping.
  home.stateVersion = "26.05";

  ##########################################################################
  # Command-line tools
  #
  # Two ways to add one:
  #
  #   1. If home-manager has a `programs.<name>` module, prefer it. You get the
  #      package AND its config file AND its shell integration, all declarative.
  #      Search: https://home-manager-options.extranix.com/
  #
  #   2. Otherwise drop the package name into `home.packages` below.
  #      Search: nix search nixpkgs <name>
  ##########################################################################

  # Tools with no dedicated module — just the binary on PATH.
  home.packages = with pkgs; [
    tree
    wget

    # Patched font with icon glyphs. The nvim UI (file icons, statusline
    # separators) and starship both need a Nerd Font to render properly.
    nerd-fonts.hack
  ];

  # Links fonts from home.packages into ~/Library/Fonts and generates
  # fontconfig, so both macOS apps and CLI tools can see them.
  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  ##########################################################################
  # nova - internal platform CLI
  #
  # Deliberately NOT a Nix package. The console serves one unversioned URL per
  # platform (.../install/nova-darwin-arm64), so a pinned fetchurl would break
  # on every internal release and no rebuild would work off the tailnet. nova
  # also updates itself in place, which a read-only store path cannot do, and
  # its installer wires up far more than a binary: ~/.config/nova-cli, the
  # nova-tray app and its LaunchAgent, and nova's MCP tools in
  # ~/.claude/settings.json - the same file this config already leaves to
  # Claude Code, for the same reason.
  #
  # Install and update it with the vendor one-liner, on the tailnet:
  #   curl -fsSL https://platform-nova-cli-console.tail180518.ts.net/install | bash
  #
  # What Nix owns is the PATH. nova installs into ~/.local/bin and the
  # installer appends an export to ~/.zshrc - a read-only store symlink, so
  # that step only warns and gives up, leaving `nova` uncallable by name.
  # sessionPath puts the directory on PATH declaratively instead.
  #
  # One thing to watch on the first install: the installer also runs
  # `nova github credential-helper --install`, which rewrites the global git
  # config. ~/.config/git/config is a store symlink, and a `git config` write
  # replaces it with a regular file rather than writing through it - the same
  # failure this repo hit with Claude Code's settings.json. The fix is to copy
  # the helper it wrote into programs.git.settings below, delete the detached
  # file, and switch again; after that the helper is declarative and the
  # installer finds it already configured and leaves it alone.
  ##########################################################################
  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.ripgrep = {
    enable = true;
    arguments = [
      "--smart-case"
      "--hidden"
      "--glob=!.git/*"
    ];
  };

  programs.fd = {
    enable = true;
    hidden = true;
    ignores = [ ".git/" "node_modules/" ];
  };

  programs.jq.enable = true;

  programs.fzf = {
    enable = true;
    # Adds Ctrl-R history search and Ctrl-T file search to zsh.
    enableZshIntegration = true;
    # Use fd for fzf's file listing so both honour the same ignore rules.
    defaultCommand = "fd --type f";
  };

  ##########################################################################
  # Ghostty
  #
  # The app itself comes from the Homebrew cask declared in configuration.nix
  # (ghostty has no darwin build in nixpkgs), so `package = null` tells
  # home-manager to manage only ~/.config/ghostty/config.
  ##########################################################################
  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      background-opacity = 0.8;
      # Blur whatever shows through the transparent background. Only has a
      # visible effect while background-opacity is below 1.
      background-blur = 50;
      theme = "Dracula";
      command = "/bin/zsh";
      #window-decoration = "none";
      macos-titlebar-style = "hidden";
      # Must be the "Mono" variant. Ghostty only accepts strictly monospaced
      # families, and the plain "Hack Nerd Font" has double-width icon glyphs
      # that disqualify it — it silently falls back to the default font.
      # Check what is actually available with:
      #   ghostty +list-fonts | grep Hack
      font-family = "Hack Nerd Font Mono";
      font-size = 15.0;

      # Breathing room between the text and the window edge. The default is
      # 2px, which sits almost flush. Raise or lower to taste.
      window-padding-x = 10;
      window-padding-y = 10;
    };
  };

  ##########################################################################
  # mise — manages the node and bun toolchains, writes ~/.config/mise/config.toml
  ##########################################################################
  programs.mise = {
    enable = true;
    enableZshIntegration = true; # replaces the `mise activate zsh` line in .zshrc
    globalConfig = {
      tools = {
        node = "latest";
        bun = "latest";
      };
    };
  };

  ##########################################################################
  # zsh — writes ~/.zshrc and ~/.zprofile
  ##########################################################################
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    # ~/.zshrc
    initContent = ''
      # Ctrl-F accepts the inline autosuggestion.
      bindkey '^f' autosuggest-accept

      # Name this repo as a zsh directory, so `~home` is a path anywhere:
      #   nvim ~home/home.nix     ls ~home/config     git -C ~home status
      # Tab completion works after the `~`, e.g. `nvim ~home/<TAB>`.
      hash -d home=$HOME/.dotfiles

      # ...and let `cd home` work without the tilde. cdablevars only applies
      # when the argument is not already a real directory, so a local ./home
      # still wins and nothing is shadowed.
      setopt cdablevars
    '';

    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude --dangerously-skip-permissions";
    };

    # ~/.zprofile — Homebrew's prefix needs to be on PATH for login shells.
    profileExtra = ''
      eval "$(/opt/homebrew/bin/brew shellenv zsh)"
    '';
  };

  ##########################################################################
  # starship — shell prompt
  ##########################################################################
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        # Parentheses are syntax in starship format strings, so a literal one
        # must be escaped. In Nix "\\)" produces the \) that starship wants.
        success_symbol = "[\\)](purple)";
        error_symbol = "[›](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  ##########################################################################
  # git — identity and commit signing
  ##########################################################################
  programs.git = {
    enable = true;

    # Sign every commit and tag with $DOTFILES_GPG_KEY, the long form of the
    # signing (sec) key. `signer` defaults to the gpg from programs.gpg.package,
    # so it does not depend on gpg being on $PATH.
    #
    # Signing is only turned on when the variable is set. A machine without the
    # secret key in its keyring cannot sign, and leaving signByDefault on there
    # fails every `git commit` with "No secret key" instead of just producing
    # unsigned commits. Export the id (`gpg --list-secret-keys --keyid-format=long`)
    # before ./rebuild.sh on any machine that holds the key.
    signing = {
      key = if signingKey != "" then signingKey else null;
      format = "openpgp";
      signByDefault = signingKey != "";
    };

    settings = {
      user.name = "Vinicius Carvalho";
      user.email = "vinicius91carvalho@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  # Installs gnupg and manages ~/.gnupg/gpg.conf. `mutableKeys` defaults to
  # true, so keys generated with `gpg --generate-key` are left alone rather
  # than being managed declaratively.
  programs.gpg.enable = true;

  ##########################################################################
  # GitHub CLI
  #
  # This manages ~/.config/gh/config.yml only. The login itself lives in
  # ~/.config/gh/hosts.yml, which is NOT managed here and NOT in this repo —
  # it holds an OAuth token. Authenticate once per machine with:
  #   gh auth login
  ##########################################################################
  programs.gh = {
    enable = true;
    settings = {
      # Clone and push over SSH, reusing the key configured above, rather
      # than HTTPS + a stored token.
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };

  ##########################################################################
  # ssh
  ##########################################################################
  programs.ssh = {
    enable = true;
    # The module's implicit "*" defaults are deprecated upstream, so opt out
    # and state what we actually want.
    enableDefaultConfig = false;

    # Attribute names are Host patterns; keys are upstream ssh_config(5)
    # directive names.
    settings."github.com" = {
      HostName = "github.com";
      User = "git";
      IdentityFile = "${config.home.homeDirectory}/.ssh/id_ed25519";
      # Offer only this key, rather than every key the agent holds.
      IdentitiesOnly = true;
      AddKeysToAgent = "yes";
    };
  };

  ##########################################################################
  # Neovim
  #
  # The package comes from Nix (moved off Homebrew so the version is pinned
  # by flake.lock).
  #
  # The module always generates a small init.lua to disable the node/perl/ruby/
  # python providers, and would write it to ~/.config/nvim/init.lua — which
  # collides with the config directory linked below. `sideloadInitLua` passes
  # that Lua through the neovim wrapper instead of writing the file, leaving
  # the whole nvim config directory to lazy.nvim.
  ##########################################################################
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    sideloadInitLua = true;
  };

  # The nvim config lives as plain Lua in ./.config/nvim.
  #
  # `mkOutOfStoreSymlink` links to the working copy rather than to a read-only
  # copy in the Nix store. That matters: lazy.nvim writes lazy-lock.json into
  # its own config directory, which a store path would forbid. This way the
  # lockfile lands back in this repo and can be committed, which is what pins
  # the plugin versions.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/.config/nvim";
  xdg.configFile."herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/.config/herdr";
  ##########################################################################
  # Claude Code
  #
  # `home.file`, not `xdg.configFile`: Claude Code reads ~/.claude, and
  # xdg.configFile is rooted at ~/.config — it would land these in
  # ~/.config/.claude, which nothing ever reads.
  #
  # Individual files, not the whole directory: ~/.claude also holds history,
  # caches, project transcripts and credentials. Linking the directory would
  # drag all of that into this public repo.
  #
  # CLAUDE.md points at AGENTS.md so the repo keeps one canonical set of
  # agent instructions, whatever tool happens to read it.
  #
  # settings.json is deliberately NOT managed here. Claude Code rewrites it
  # itself (/config, theme changes, statusline setup) by writing a temp file
  # and rename()ing it into place, which replaces the symlink with a regular
  # file instead of writing through it. Nix loses that race every time: the
  # file silently detaches from the repo, and the next activation aborts
  # because the backup from the previous activation is already there.
  #
  # ./.claude/settings.json stays in the repo as the seed to copy onto a new
  # machine, but ~/.claude/settings.json belongs to Claude Code.
  ##########################################################################
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/AGENTS.md";

}


