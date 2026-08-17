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
      # The `docker` formula is the CLI only - it ships no engine, so on its
      # own the socket never exists and every command fails with "cannot
      # connect to the Docker daemon". colima below is what provides one.
      "docker"
      # `docker-compose`, the standalone v1-style binary, as opposed to the
      # `docker compose` subcommand that ships as a CLI plugin. Both exist and
      # they are not interchangeable: a Makefile written against the hyphenated
      # name needs this formula to put that exact name on PATH. The caveat it
      # prints about ~/.docker/config.json and cliPluginsExtraDirs is for the
      # plugin form and can be ignored here.
      "docker-compose"
      # The Docker engine, as a Lima VM. Docker Desktop and OrbStack are the
      # alternatives and both are paid for commercial use; colima is Apache-2.0
      # and speaks to the same `docker` CLI above.
      #
      # start_service boots the VM at login, so `docker` works straight from a
      # fresh boot the way it would under Docker Desktop. It is also the
      # expensive half of this: the VM holds its memory for as long as it runs.
      # Drop start_service and run `colima start` by hand to get that back.
      #
      # NEVER restart this one - not `brew services restart colima`, and not
      # the restart_service that every other formula here uses. The plist runs
      # `colima start -f`, but the VM itself is a separate limactl process
      # tree that does NOT die with it. Restarting SIGTERMs the foreground
      # process, leaves the VM orphaned, and the relaunch then exits
      # "already running, ignoring" on a loop.
      #
      # What that leaves is a machine that looks fine and works for nothing:
      # `colima status` says running, docker.sock exists, and every ssh port
      # forward through it is dead - docker refuses connections, every
      # published port closed, no error printed anywhere. A hand-run
      # `colima start`/`colima delete` alongside the service lands in exactly
      # the same state, for the same reason: two owners of one VM.
      #
      # Stop, force the orphan down, then start. This is the only sequence
      # that recovers it, and the only one that safely applies a colima
      # upgrade:
      #
      #   brew services stop colima && colima stop -f && brew services start colima
      #
      # After any VM restart the containers on it are stopped but intact.
      {
        name = "colima";
        start_service = true;
      }
      # docker-buildx and uv were already installed by hand but declared
      # nowhere, so `cleanup = "zap"` was about to uninstall both. buildx is
      # the docker CLI's build plugin; uv installs and runs Python tools.
      "docker-buildx"
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
