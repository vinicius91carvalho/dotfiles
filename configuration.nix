{ username, ... }:

{
  imports = [ ./keyboard-shortcuts.nix ];

  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = username;
  system.stateVersion = 6;

  users.users.${username}.home = "/Users/${username}";

  # Claude Code comes from the `claude-code@latest` cask declared below, not
  # from its native installer. Only ever use one: the native installer puts a
  # `claude` in ~/.local/bin that shadows the cask's, and the two then update
  # on separate schedules and drift apart.
  #
  # `@latest`, not the plain `claude-code` cask, on purpose. Upstream publishes
  # two release channels and there is one cask per channel: `claude-code`
  # follows `stable`, which trails the current release by a week or more (it
  # sat on 2.1.228 while 2.1.238 was out), and `claude-code@latest` follows
  # `latest`. They declare `conflicts_with` each other, so exactly one can be
  # installed. New features and fixes are the point of this tool, so track
  # `latest` and take the occasional rough release.
  #
  # Settings and history live in ~/.claude and ~/.claude.json, which are
  # independent of how the binary was installed and survive switching.
  #
  # Swapping between the two casks by hand needs care: their `zap` stanza
  # trashes ~/.claude.json* (project history, MCP servers, onboarding state),
  # and `onActivation.cleanup = "zap"` below means dropping a cask from this
  # list is a zap, not a plain uninstall. Back that file up, `brew uninstall
  # --cask` the old one WITHOUT `--zap`, install the new one, then rebuild —
  # so activation finds the desired state already in place and zaps nothing.

  ############################################################################
  # Homebrew. nix-homebrew installs and owns the Homebrew prefix itself;
  # the `homebrew` block below declares what is installed into it.
  ############################################################################
  nix-homebrew = {
    enable = true;
    user = username;

    # This Mac already had Homebrew installed the normal way, and nix-homebrew
    # refuses to take over an existing prefix unless told to. Migration deletes
    # Homebrew's own repository files (replaced by the Nix-provided brew) while
    # keeping everything in Cellar and Caskroom, i.e. the installed packages.
    #
    # Safe to leave on: on a machine with no Homebrew it simply does nothing.
    autoMigrate = true;
  };

  homebrew = {
    enable = true;

    # "zap" uninstalls anything not declared below AND removes its config
    # files. Everything you want kept must be listed here.
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;

    # Third-party taps. Homebrew 6 refuses to load a formula from one until the
    # tap is trusted, so every tap here is declared as an attrset with
    # `trusted = true` - that emits `tap "…", trusted: true` into the Brewfile
    # and activation trusts it for you. A bare string leaves it untrusted and
    # the first rebuild on a new machine stops on that tap. (Brews are trusted
    # by default; only taps need saying.)
    #
    # basicmachines-co/basic-memory is upstream's tap for basic-memory, which is
    # not in nixpkgs.
    #
    # can1357/tap is upstream's tap for omp (Oh My Pi), which is not in nixpkgs
    # either.
    #
    # stablyai/orca is upstream's tap for the Orca cask. It has to be a tap:
    # homebrew-cask already owns the name `orca` for an unrelated, deprecated
    # plotly tool, so the cask below is written tap-qualified.
    taps = [
      {
        name = "basicmachines-co/basic-memory";
        trusted = true;
      }
      {
        name = "can1357/tap";
        trusted = true;
      }
      {
        name = "stablyai/orca";
        trusted = true;
      }
    ];

    brews = [
      "git"
      "zsh"
      "awscli"
      # The `docker`, `docker-compose` and `docker-buildx` formulas are
      # deliberately NOT here. Everything Docker comes from the docker-desktop
      # cask below - one vendor, one version - and Homebrew's own copies would
      # sit at /opt/homebrew/bin, which is earlier on PATH than the
      # /usr/local/bin the cask links into, so they would shadow the engine's
      # own CLI with a separately-versioned one.
      "uv"
      # Basic Memory — the MCP knowledge store behind ~/basic-memory. Not in
      # nixpkgs; upstream ships this tap. Notes are plain markdown in the
      # vault, its index and project list live in ~/.basic-memory.
      "basic-memory"
      # omp (Oh My Pi) — a terminal coding agent, and one of the CLIs Orca can
      # drive. Orca finds an agent by looking for its binary name on PATH, so
      # installing `omp` here is the whole integration: it then shows up in
      # Orca's agent picker with the auto-setup, hooks and status line Orca
      # already ships for it.
      #
      # From upstream's tap because it is not in nixpkgs. The formula downloads
      # the published `omp-darwin-arm64` release binary rather than building
      # anything, so `onActivation.upgrade` moves it to the current release on
      # every rebuild.
      #
      # Its own config lives in ~/.omp (model roles in agent/config.yml,
      # providers in agent/models.yml) and is not managed here — omp writes it
      # itself, and on first run in a repo it imports the rules and skills
      # already in ~/.claude.
      "omp"
      # neovim intentionally not here — it comes from Nix via home.nix, so its
      # version is pinned by flake.lock rather than tracking Homebrew.
    ];

    casks = [
      "ghostty"
      # Docker's own engine and CLI for macOS - the app, the VM it runs the
      # daemon in, and the `docker` binary, buildx and compose that talk to it.
      # It replaces colima, which provided the engine while the CLI came from a
      # separate Homebrew formula.
      #
      # Docker Desktop is free only for personal use and small companies; a
      # commercial machine needs a paid subscription. That is the price of the
      # first-party build - colima and OrbStack are the alternatives.
      #
      # The app is not a `brew services` daemon: it starts from Login Items,
      # which its own installer sets up on first launch, so open it once after
      # a fresh install and accept the licence and the privileged-helper
      # prompt. `docker` fails with "cannot connect to the Docker daemon"
      # until it has run at least once.
      #
      # `auto_updates` on the cask means Docker updates itself in place and
      # `brew upgrade` leaves it alone; the version here is whatever the app
      # last pulled, not something flake.lock pins.
      "docker-desktop"
      "claude" # Claude desktop app (distinct from the Claude Code CLI)
      "claude-code@latest" # see the Claude Code note at the top of this file
      # The codex CLI, for the same reason Claude Code comes from a cask: the
      # nixpkgs package tracks far behind upstream. codex ships a release most
      # days, and pinning it to flake.lock on the 26.05 branch left this Mac on
      # 0.133.0 while 0.152.0 was out - six weeks of fixes missed, in the tool
      # that is meant to be current. The cask follows upstream's tarball within
      # a day, and `onActivation.upgrade` above moves it on every rebuild.
      #
      # So codex.nix sets `programs.codex.package = null`: home-manager still
      # writes ~/.codex/config.toml, it just does not also install a second
      # binary. That matters here - /opt/homebrew/bin comes before the Nix
      # profile on PATH, so two installs would not even be a visible conflict,
      # only a stale `codex` that never runs and a version that drifts.
      #
      # Its `zap` is `rmdir "~/.codex"`, which only removes that directory when
      # it is empty. AGENTS.md, config.toml and skills live there, so dropping
      # this cask cannot take the config with it the way claude-code's zap can.
      "codex"
      # No Codex desktop app here on purpose. There were two casks for it and
      # neither was worth declaring: `codex-app` is marked deprecated and
      # discontinued and is set to be disabled on 2027-07-12, and its pinned
      # Codex.app (26.623.141536) is months behind the `chatgpt` cask that
      # Homebrew names as the replacement. Both carry bundle id
      # `com.openai.codex` and both zap `~/.codex`, so keeping either one meant
      # tracking a cask that is on its way out.
      #
      # The terminal is where this agent is actually used, and `codex` above is
      # current. When a GUI is wanted, `codex app` downloads and installs the
      # same bundle on demand - it reads the same $CODEX_HOME, so codex.nix's
      # MCP servers and skills are already its own with nothing to configure.
      # Orca - a desktop app for running several coding agents side by side,
      # each in its own git worktree. It replaces herdr, which did the same
      # job from the terminal as a client/server pair.
      #
      # Tap-qualified because homebrew-cask has a different, deprecated
      # `orca`; the bare name would install that one instead.
      #
      # The cask is `auto_updates true`: Orca swaps its own app bundle in
      # place, so `brew upgrade` leaves it alone and the installed version is
      # whatever the app last pulled, not something flake.lock pins. It also
      # links a small `orca` CLI onto PATH, and keeps its worktrees and agent
      # state in ~/.orca.
      "stablyai/orca/orca"
      "google-chrome"
      "visual-studio-code"
      "dbeaver-community"
      "slack"
      "tailscale-app"
      # Setapp is a subscription launcher: it installs and updates its own
      # apps into /Applications/Setapp, so Nix can only declare Setapp
      # itself. After signing in on a fresh machine, re-install from Setapp:
      #   Archiver, CleanMyMac, CleanShot X, ClearVPN, iStat Menus,
      #   Kerlig, Lasso, Numi, Paste, Permute
      "setapp"
    ];

    # Mac App Store apps are NOT declared here, and `mas` is deliberately not
    # in `brews`. Homebrew 6.0.13's bundle cannot detect mas 7.0.0 — it runs
    # its lookup in a scrubbed environment, decides mas is missing, and aborts
    # activation with "Unable to install <app> app. mas installation failed."
    # even though `mas list` works and reports both apps correctly.
    #
    # Install these from the App Store by hand, then check back later whether
    # upstream has fixed it:
    #   WhatsApp       id 310633997
    #   Amazon Kindle  id 302584613
    #
    # To retry, add `"mas"` to brews above and restore:
    #   masApps = { "WhatsApp" = 310633997; "Amazon Kindle" = 302584613; };
  };

  ############################################################################
  # macOS system settings, captured from this machine on 2026-08-03.
  ############################################################################
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      AppleShowAllExtensions = true;
      KeyRepeat = 2; # fast key repeat
      InitialKeyRepeat = 15; # short delay before repeat
      _HIHideMenuBar = true; # auto-hide the menu bar
      NSAutomaticCapitalizationEnabled = true;
      NSAutomaticPeriodSubstitutionEnabled = true;
    };

    dock = {
      autohide = true;
      magnification = true;
      tilesize = 57;
      largesize = 101;
      mineffect = "genie";
      expose-group-apps = true; # group windows by app in Mission Control
      wvous-bl-corner = 4; # bottom-left hot corner: Desktop
      wvous-br-corner = 14; # bottom-right hot corner: Quick Note
      # Dock contents are still macOS defaults, so they are not pinned here.
      # To make them declarative, set `persistent-apps = [ "/Applications/..." ];`
    };

    finder = {
      FXPreferredViewStyle = "Nlsv"; # list view by default
      CreateDesktop = false; # clean desktop
      ShowPathbar = true;
      ShowStatusBar = true;
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = false;
      ShowRemovableMediaOnDesktop = true;
    };

    # Trackpad gestures. nix-darwin writes each of these to both the built-in
    # trackpad and the Magic Trackpad domains.
    #
    # Gesture value meanings: 0 = off, 2 = swipe with four fingers (or the
    # gesture's default multi-finger form), 3 = swipe with two fingers.
    trackpad = {
      Clicking = true; # tap to click
      Dragging = false; # no tap-to-drag
      DragLock = false;
      TrackpadRightClick = true;
      TrackpadCornerSecondaryClick = 0; # right-click by two-finger click, not corner
      TrackpadThreeFingerDrag = true;

      # Three-finger gestures are off because three-finger drag owns them.
      TrackpadThreeFingerTapGesture = 0;
      TrackpadThreeFingerHorizSwipeGesture = 0;
      TrackpadThreeFingerVertSwipeGesture = 0;

      # Four-finger: swipe between spaces, Mission Control, App Expose.
      TrackpadFourFingerHorizSwipeGesture = 2;
      TrackpadFourFingerVertSwipeGesture = 2;
      TrackpadFourFingerPinchGesture = 2; # pinch to Launchpad / show desktop

      TrackpadTwoFingerDoubleTapGesture = true; # smart zoom
      TrackpadTwoFingerFromRightEdgeSwipeGesture = 3; # swipe in Notification Centre

      TrackpadPinch = true; # pinch to zoom
      TrackpadRotate = true;
      TrackpadMomentumScroll = true;

      ActuateDetents = true; # force-touch feedback
      ForceSuppressed = false;
      FirstClickThreshold = 1; # medium click pressure
      SecondClickThreshold = 1;
    };

    # Settings with no dedicated nix-darwin option, written to their raw
    # preference domains. Keyboard shortcuts live in ./keyboard-shortcuts.nix.
    CustomUserPreferences = {
      NSGlobalDomain = {
        AppleActionOnDoubleClick = "Minimize"; # double-click title bar minimises
        AppleMiniaturizeOnDoubleClick = false;
        AppleLanguages = [ "en-BR" "pt-BR" ];
        AppleLocale = "en_BR";

        # Text replacements (System Settings > Keyboard > Text Replacements)
        NSUserDictionaryReplacementItems = [
          { on = 1; replace = "omw"; "with" = "On my way!"; }
          { on = 1; replace = "eac"; "with" = "Estou a caminho!"; }
        ];
      };

      # Trackpad keys that nix-darwin has no typed option for.
      "com.apple.AppleMultitouchTrackpad" = {
        TrackpadFiveFingerPinchGesture = 2; # pinch with thumb to show desktop
        TrackpadHandResting = 1;
        TrackpadHorizScroll = 1;
        TrackpadScroll = 1;
        USBMouseStopsTrackpad = 0;
      };
      "com.apple.driver.AppleBluetoothMultitouch.trackpad" = {
        TrackpadFiveFingerPinchGesture = 2;
        TrackpadHandResting = 1;
        TrackpadHorizScroll = 1;
        TrackpadScroll = 1;
        USBMouseStopsTrackpad = 0;
      };
    };
  };
}
