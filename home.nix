{ pkgs, config, ... }:

{
  home.username = "vinicius91carvalho";
  home.homeDirectory = "/Users/vinicius91carvalho";

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

    # Patched font with programming ligatures and icon glyphs. LazyVim's UI
    # (file icons, statusline separators) needs a Nerd Font to render.
    nerd-fonts.hack
  ];

  # Links fonts from home.packages into ~/Library/Fonts and generates
  # fontconfig, so both macOS apps and CLI tools can see them.
  fonts.fontconfig.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
  };

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
      theme = "Dracula";
      command = "/bin/zsh";
      window-decoration = "none";
      # macos-titlebar-style = "hidden";
      font-family = "Hack Nerd Font";
      font-size = 15.0;
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
      # Claude Code installs itself to ~/.local/bin and is not managed by Nix.
      export PATH="$HOME/.local/bin:$PATH"

      # Ctrl-F accepts the inline autosuggestion.
      bindkey '^f' autosuggest-accept

      # Name $HOME as a zsh directory so `~home` works as a path anywhere:
      #   ls ~home   cp file ~home/   du -sh ~home/Downloads
      hash -d home=$HOME

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

    # Sign every commit and tag with the GPG key below. The key id is the long
    # form of the signing (sec) key; `signer` defaults to the gpg from
    # programs.gpg.package, so it does not depend on gpg being on $PATH.
    signing = {
      key = "EA380CFFC7FBC723";
      format = "openpgp";
      signByDefault = true;
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
  # Neovim + LazyVim
  #
  # The package comes from Nix (moved off Homebrew so the version is pinned
  # by flake.lock).
  #
  # The module always generates a small init.lua to disable the node/perl/ruby/
  # python providers, and would write it to ~/.config/nvim/init.lua — which
  # collides with the LazyVim directory linked below. `sideloadInitLua` passes
  # that Lua through the neovim wrapper instead of writing the file, leaving
  # the whole nvim config directory to LazyVim.
  ##########################################################################
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    sideloadInitLua = true;
  };

  # LazyVim lives as plain Lua in ./config/nvim, linked to ~/.config/nvim.
  #
  # `mkOutOfStoreSymlink` links to the working copy rather than to a read-only
  # copy in the Nix store. That matters: lazy.nvim writes lazy-lock.json (and
  # `:LazyExtras` writes lazyvim.json) into its own config directory, which a
  # store path would forbid. This way those files land back in this repo and
  # can be committed, which is what pins your plugin versions.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/config/nvim";
}
