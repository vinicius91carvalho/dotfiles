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

  # Claude Code comes from the `claude-code` cask declared below, not from its
  # native installer. Only ever use one: the native installer puts a `claude`
  # in ~/.local/bin that shadows the cask's, and the two then update on
  # separate schedules and drift apart.
  #
  # Settings and history live in ~/.claude and ~/.claude.json, which are
  # independent of how the binary was installed and survive switching.

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
    taps = [
      {
        name = "basicmachines-co/basic-memory";
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
      # herdr is a client/server tool: the `herdr` command talks to a
      # background server over a socket in ~/.config/herdr, and fails with
      # "server did not become ready" if it is not running.
      #
      # start_service registers it to launch at login and starts it now;
      # restart_service = "changed" restarts it after an upgrade so the
      # running server matches the installed binary.
      {
        name = "herdr";
        start_service = true;
        restart_service = "changed";
      }
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
      "claude-code"
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
