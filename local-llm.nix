{ lib, pkgs, config, memGb, ... }:

##############################################################################
# Local LLM - Qwen3.8-27B served by oMLX, for machines with more than 32 GB
#
# This whole file is gated on `memGb`, the machine's unified memory, read from
# DOTFILES_MEM_GB by rebuild.sh (see flake.nix). The model's weights alone are
# 17.4 GB and its KV cache grows with the conversation; on a 16 or 24 GB Mac
# the server would swap from the first prompt and make the machine unusable.
# Unset means 0 means off, which is the right default on an unknown machine.
#
# oMLX itself is NOT installed here, for the same reason turbo-fieldfare is
# not: what upstream ships is a notarized .dmg, and the ANE prefill kernels
# inside it are precompiled. Building the equivalent from the Homebrew formula
# needs `--with-custom-kernel`, which compiles .metal sources, which needs the
# Metal toolchain, which needs full Xcode - about 20 GB of dependency to end up
# with the same binaries the DMG already carries.
#
# Bootstrap once, by hand (see README.md):
#   1. Install oMLX.app from https://github.com/jundot/omlx/releases
#      (the macos26-27 .dmg on macOS 26; verify with `spctl -a -t install`).
#   2. Download the checkpoint:
#      uvx --from "huggingface_hub[cli]" hf download \
#        True2456/Qwen3.8-27B-AWQ-5.0bpw \
#        --local-dir ~/tools/qwen3.8-27b/True2456/Qwen3.8-27B-AWQ-5.0bpw
#
# What Nix owns is the process: its flags, its lifecycle and its logs. Those
# are the parts worth having identical on every machine, and the parts that are
# easy to get subtly wrong by hand - binding beyond loopback, or letting the
# memory guard default to a ceiling this machine cannot honour.
#
# The CLI is taken from inside the app bundle rather than from the ~/.omlx/bin
# shim the app writes on first launch: the bundle path exists the moment the
# app is copied into /Applications, so the agent does not depend on anyone
# having opened the GUI first.
##############################################################################

let
  # omlxctl - the day-to-day control surface for the local model server.
  #
  # It lives here, behind the same `memGb > 32` gate as the agent, so it is not
  # on PATH at all on a machine that cannot run the model. A loose script in
  # ~/.local/bin would outlive the gate.
  omlxctl = pkgs.writeShellScriptBin "omlxctl" ''
    set -euo pipefail

    AGENT="gui/$(/usr/bin/id -u)/org.nix-community.home.omlx"
    PLIST="$HOME/Library/LaunchAgents/org.nix-community.home.omlx.plist"
    APP="/Applications/oMLX.app"
    BACKUP_DIR="$HOME/.local/share/omlx/backup"
    URL="http://127.0.0.1:1337"
    API="https://api.github.com/repos/jundot/omlx/releases/latest"

    up() { ${pkgs.curl}/bin/curl -fsS -m 4 "$URL/v1/models" >/dev/null 2>&1; }

    wait_up() {
      for _ in $(seq 90); do up && return 0; sleep 2; done
      echo "servidor nao respondeu em 3 min" >&2; return 1
    }

    wait_down() {
      for _ in $(seq 60); do up || return 0; sleep 1; done
      echo "servidor continua de pe" >&2; return 1
    }

    installed_version() {
      /usr/bin/defaults read "$APP/Contents/Info.plist" \
        CFBundleShortVersionString 2>/dev/null || echo "none"
    }

    cmd_start() {
      up && { echo "ja esta de pe"; return 0; }
      /bin/launchctl bootstrap "gui/$(/usr/bin/id -u)" "$PLIST" 2>/dev/null || true
      wait_up && echo "de pe em $URL"
    }

    # `bootout`, never `kill`: KeepAlive.SuccessfulExit = false treats a SIGTERM
    # as a crash and brings the server straight back.
    cmd_stop() {
      /bin/launchctl bootout "$AGENT" 2>/dev/null || true
      wait_down && echo "parado"
    }

    cmd_restart() {
      /bin/launchctl kickstart -k "$AGENT" 2>/dev/null || { cmd_start; return; }
      wait_up && echo "reiniciado"
    }

    cmd_status() {
      printf 'versao instalada : %s\n' "$(installed_version)"
      if up; then
        printf 'servidor         : de pe em %s\n' "$URL"
        printf 'modelo servido   : %s\n' \
          "$(${pkgs.curl}/bin/curl -fsS -m 4 "$URL/v1/models" \
             | ${pkgs.jq}/bin/jq -r '.data[0].id // "nenhum"')"
        pid=$(/usr/sbin/lsof -nP -iTCP:1337 -sTCP:LISTEN -t 2>/dev/null | head -1 || true)
        if [ -n "$pid" ]; then
          printf 'memoria residente: %s GB\n' \
            "$(/bin/ps -o rss= -p "$pid" | ${pkgs.gawk}/bin/awk '{printf "%.1f", $1/1048576}')"
        fi
      else
        printf 'servidor         : fora\n'
      fi
      printf 'swap             : %s\n' "$(/usr/sbin/sysctl -n vm.swapusage)"
      if [ -d "$BACKUP_DIR" ]; then
        printf 'backup guardado  : %s\n' "$(ls "$BACKUP_DIR" 2>/dev/null | tr '\n' ' ')"
      fi
    }

    cmd_logs() { exec tail -f "$HOME/Library/Logs/omlx.log"; }

    # Upstream ships DMGs, so there is no `brew upgrade` to lean on. This does
    # the same job: check the published release and only touch anything when it
    # differs from what is installed.
    #
    # It follows whatever GitHub calls "latest", release candidates included -
    # a deliberate choice. That is why the previous .app is kept: `omlxctl
    # rollback` puts it back when an rc regresses.
    cmd_update() {
      have="$(installed_version)"
      if [ "$have" = "none" ]; then
        echo "oMLX nao esta instalado; veja o README"; return 0
      fi

      json="$(${pkgs.curl}/bin/curl -fsS -m 20 "$API" 2>/dev/null || true)"
      if [ -z "$json" ]; then
        echo "oMLX: nao consegui consultar o GitHub, seguindo"; return 0
      fi

      want="$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r '.tag_name // empty' | sed 's/^v//')"
      if [ -z "$want" ]; then
        echo "oMLX: resposta do GitHub sem tag, seguindo"; return 0
      fi
      if [ "$want" = "$have" ]; then
        echo "oMLX $have esta atual"; return 0
      fi

      # The DMG name carries the macOS major it targets (macos26-27,
      # macos15-sequoia), so pick by this machine's major instead of guessing.
      major="$(/usr/bin/sw_vers -productVersion | cut -d. -f1)"
      dmg_url="$(printf '%s' "$json" | ${pkgs.jq}/bin/jq -r \
        --arg m "macos$major" \
        '.assets[] | select(.name | endswith(".dmg")) | select(.name | contains($m))
         | .browser_download_url' | head -1)"
      if [ -z "$dmg_url" ]; then
        echo "oMLX $want nao publica DMG para macOS $major; nada a fazer"; return 0
      fi

      echo "oMLX: $have -> $want, baixando..."
      tmp="$(mktemp -d)"
      mnt="$tmp/mnt"
      trap '/usr/bin/hdiutil detach "$mnt" -quiet 2>/dev/null || true; rm -rf "$tmp"' EXIT
      ${pkgs.curl}/bin/curl -fsSL -o "$tmp/omlx.dmg" "$dmg_url"
      /usr/bin/hdiutil attach "$tmp/omlx.dmg" -nobrowse -readonly -mountpoint "$mnt" >/dev/null

      # Never install what Gatekeeper will not vouch for. Upstream notarizes
      # every release, so an unsigned one means something is wrong upstream or
      # in transit - either way it is not going into /Applications.
      if ! /usr/sbin/spctl -a -t install "$mnt/oMLX.app" 2>&1 | grep -q accepted; then
        echo "oMLX $want NAO passou no Gatekeeper; abortando e mantendo $have" >&2
        return 1
      fi

      cmd_stop || true
      mkdir -p "$BACKUP_DIR"
      rm -rf "''${BACKUP_DIR:?}"/*
      mv "$APP" "$BACKUP_DIR/oMLX-$have.app"
      cp -R "$mnt/oMLX.app" "$APP"
      /usr/bin/xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
      cmd_start
      echo "oMLX atualizado para $want (anterior em $BACKUP_DIR)"
    }

    cmd_rollback() {
      old="$(ls -d "$BACKUP_DIR"/oMLX-*.app 2>/dev/null | head -1 || true)"
      if [ -z "$old" ]; then
        echo "sem backup para voltar" >&2; return 1
      fi
      cmd_stop || true
      rm -rf "$APP"
      mv "$old" "$APP"
      cmd_start
      echo "voltou para $(installed_version)"
    }

    case "''${1:-status}" in
      start)    cmd_start ;;
      stop)     cmd_stop ;;
      restart)  cmd_restart ;;
      status)   cmd_status ;;
      logs)     cmd_logs ;;
      update)   cmd_update ;;
      rollback) cmd_rollback ;;
      *)
        echo "uso: omlxctl {start|stop|restart|status|logs|update|rollback}" >&2
        exit 2 ;;
    esac
  '';
in
lib.mkIf (memGb > 32) {

  home.packages = [ omlxctl ];

  launchd.agents.omlx = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.writeShellScript "omlx-server" ''
          # The 32 GB gate again, at runtime. The `lib.mkIf` below decides
          # whether this agent is ever WRITTEN; this decides whether it RUNS.
          # They are not the same guarantee: a plist survives on disk until the
          # next activation, so a machine that shrank between rebuilds - a
          # restored backup, a swapped logic board - would otherwise start
          # loading 17 GB of weights it cannot hold.
          mem_gb=$(( $(/usr/sbin/sysctl -n hw.memsize) / 1073741824 ))
          if [ "$mem_gb" -le 32 ]; then
            echo "This machine has ''${mem_gb}GB; the local LLM needs more than 32GB." \
                 "Not starting."
            exit 0
          fi

          cli="/Applications/oMLX.app/Contents/MacOS/omlx-cli"
          models="$HOME/tools/qwen3.8-27b"
          checkpoint="$models/True2456/Qwen3.8-27B-AWQ-5.0bpw/config.json"

          if [ ! -x "$cli" ] || [ ! -e "$checkpoint" ]; then
            echo "oMLX is not bootstrapped ($cli / $checkpoint missing);" \
                 "see dotfiles/README.md. Not starting."
            exit 0
          fi

          # Port 1337, not oMLX's own CLI default of 8000: infoproduct's webapp
          # already answers on 8000, and turbo-fieldfare holds 8080. The server
          # binds 127.0.0.1 with no auth or TLS, so it must never be put behind
          # a proxy or tunnel.
          #
          # --memory-guard-gb 27, arrived at by measurement, not by taste.
          #
          # The ceiling is not the prefill budget. oMLX derives the prefill cap
          # as ceiling * soft_threshold (0.85), and the resident model is
          # 18.76 GB, so a 24 GB ceiling left 24 * 0.98 * 0.85 = 20.0 GB of cap
          # and only ~1.2 GB of room for the prefill working set. With
          # `prefill_priority = "context"` (the default) the scheduler does not
          # refuse a prompt that does not fit - it shrinks the step down to
          # `prefill_min_chunk_tokens` (32) and grinds. Measured on this
          # machine: a 12.6k-token prompt took 23 MINUTES at 9 tok/s, and a
          # 33k one was refused outright.
          #
          # 27 GB puts the cap near 22.5 GB, tripling that headroom, and stays
          # under Apple's own Metal cap for this Mac (28.1 GB,
          # max_recommended_working_set_size) so nothing spills.
          #
          # --max-concurrent-requests 2 rather than the default 8: every extra
          # in-flight request carries its own KV cache, and eight of them do not
          # fit next to 17.4 GB of weights.
          #
          # The SSD cache is the whole reason to run oMLX instead of plain
          # mlx-lm for coding agents: it persists the KV cache of repeated
          # prompt prefixes, which is what turns a 30-90 s time-to-first-token
          # on a large repo into 1-3 s.
          exec "$cli" serve \
            --model-dir "$models" \
            --host 127.0.0.1 \
            --port 1337 \
            --memory-guard-gb 27 \
            --max-concurrent-requests 2 \
            --hot-cache-max-size 2GB \
            --paged-ssd-cache-dir "$HOME/.omlx/ssd-cache" \
            --paged-ssd-cache-max-size 60GB
        ''}"
      ];
      RunAtLoad = true;
      # "missing bootstrap -> stay quiet" (the wrapper exits 0), while a real
      # crash of a running server still gets restarted.
      KeepAlive = { SuccessfulExit = false; };
      # A crash loop that reloads a 17 GB checkpoint would thrash the disk.
      ThrottleInterval = 30;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/omlx.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/omlx.log";
    };
  };
}
