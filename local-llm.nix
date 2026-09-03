{
  lib,
  pkgs,
  config,
  memGb,
  ...
}:

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
  modelId = "Qwen3.8-27B-AWQ-5.0bpw";

  dailyOmlxPatch = pkgs.writeText "omlx-daily-settings.json" (
    builtins.toJSON {
      model.hide_helper_models = true;
      memory = {
        prefill_memory_guard = true;
        memory_guard_tier = "custom";
        memory_guard_custom_ceiling_gb = 27.0;
        soft_threshold = 0.85;
        hard_threshold = 0.95;
        prefill_safe_zone_ratio = 0.8;
        prefill_min_chunk_tokens = 32;
      };
      scheduler = {
        max_concurrent_requests = 1;
        embedding_batch_size = 1;
        chunked_prefill = false;
        prefill_priority = "context";
      };
      cache = {
        enabled = true;
        hot_cache_only = false;
        gdn_ssd_split_enabled = true;
        gdn_snapshot_storage = "auto";
        gdn_ssd_pending_max_size = "512MB";
        gdn_sidecar_precision = "fp32";
        ssd_cache_dir = "${config.home.homeDirectory}/.omlx/ssd-cache";
        ssd_cache_max_size = "60GB";
        hot_cache_max_size = "2GB";
        initial_cache_blocks = 256;
      };
      sampling.max_context_window = 262144;
    }
  );

  scan64OmlxPatch = pkgs.writeText "omlx-scan64-settings.json" (
    builtins.toJSON {
      model.hide_helper_models = true;
      memory = {
        prefill_memory_guard = true;
        memory_guard_tier = "custom";
        memory_guard_custom_ceiling_gb = 28.0;
        soft_threshold = 0.9;
        hard_threshold = 0.99;
        prefill_safe_zone_ratio = 0.9;
        prefill_min_chunk_tokens = 32;
      };
      scheduler = {
        max_concurrent_requests = 1;
        embedding_batch_size = 1;
        chunked_prefill = true;
        prefill_priority = "context";
      };
      cache = {
        enabled = true;
        hot_cache_only = false;
        gdn_ssd_split_enabled = true;
        gdn_snapshot_storage = "auto";
        gdn_ssd_pending_max_size = "512MB";
        gdn_sidecar_precision = "fp32";
        ssd_cache_dir = "${config.home.homeDirectory}/.omlx/ssd-cache";
        ssd_cache_max_size = "60GB";
        hot_cache_max_size = "0GB";
        initial_cache_blocks = 64;
      };
      sampling.max_context_window = 262144;
    }
  );

  dailyModelSettings = pkgs.writeText "omlx-daily-model-settings.json" (
    builtins.toJSON {
      version = 1;
      models.${modelId} = {
        max_context_window = 262144;
        turboquant_kv_enabled = true;
        turboquant_kv_bits = 3.5;
        mtp_enabled = true;
        specprefill_enabled = false;
      };
    }
  );

  scan64ModelSettings = pkgs.writeText "omlx-scan64-model-settings.json" (
    builtins.toJSON {
      version = 1;
      models.${modelId} = {
        max_context_window = 262144;
        turboquant_kv_enabled = true;
        turboquant_kv_bits = 3.5;
        mtp_enabled = true;
        specprefill_enabled = true;
        specprefill_draft_model = "${config.home.homeDirectory}/tools/qwen3.8-27b/mlx-community/Qwen3.5-0.8B-MLX-bf16";
        specprefill_keep_pct = 0.2;
        specprefill_threshold = 8192;
      };
    }
  );

  dailyOmpModels = pkgs.writeText "omp-daily-models.yml" ''
    providers:
      omlx:
        baseUrl: http://127.0.0.1:1337/v1
        api: openai-completions
        auth: none
        models:
          - id: ${modelId}
            name: Qwen3.8 27B local - daily exact
            reasoning: true
            input: [text, image]
            contextWindow: 30000
            maxTokens: 4096
            compat:
              replayReasoningContent: false
              qwenPreserveThinking: false
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
  '';

  scan64OmpModels = pkgs.writeText "omp-scan64-models.yml" ''
    providers:
      omlx:
        baseUrl: http://127.0.0.1:1337/v1
        api: openai-completions
        auth: none
        models:
          - id: ${modelId}
            name: Qwen3.8 27B local - 64K scan
            reasoning: true
            input: [text]
            contextWindow: 65536
            maxTokens: 4096
            compat:
              replayReasoningContent: false
              qwenPreserveThinking: false
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
  '';

  ompConfig =
    name: threshold: idleThreshold:
    pkgs.writeText "omp-${name}-config.yml" ''
      modelRoles:
        plan: omlx/${modelId}:xhigh
        default: omlx/${modelId}:low
        vision: omlx/${modelId}:medium
        smol: omlx/${modelId}:low
        commit: omlx/${modelId}:low
      promptProfile: compact
      personality: none
      includeModelInPrompt: false
      tools:
        xdevForceMount:
          - hub
          - eval
          - task
          - todo
          - web_search
        xdevDocs: catalog
      compaction:
        thresholdTokens: ${toString threshold}
        keepRecentTokens: 3000
        reserveTokens: 2500
        idleEnabled: true
        idleThresholdTokens: ${toString idleThreshold}
        idleTimeoutSeconds: 120
      defaultThinkingLevel: low
      thinkingBudgets:
        xhigh: 6000
        max: 6000
        high: 6000
        medium: 3000
        low: 1500
        minimal: 800
      symbolPreset: nerd
      composer:
        shape: pi
      theme:
        dark: dark-dracula
        light: light-catppuccin
      setupVersion: 2
      statusLine:
        preset: default
        transparent: true
        compactThinkingLevel: true
      terminal:
        showProgress: true
      tui:
        textSizing: true
      display:
        shimmer: classic
        showTokenUsage: true
      readLineNumbers: true
    '';

  dailyOmpConfig = ompConfig "daily" 25000 24000;
  scan64OmpConfig = ompConfig "scan64" 60000 55000;

  # Writes only performance settings. oMLX's auth secret stays in its existing
  # file and OMP's account vault is never touched. The active name is mutable
  # state so a later Nix rebuild reapplies the user's last choice.
  applyLocalLlmProfile = pkgs.writeShellScript "apply-local-llm-profile" ''
    set -euo pipefail

    name="''${1:-daily}"
    case "$name" in
      daily)
        settings_patch=${dailyOmlxPatch}
        model_patch=${dailyModelSettings}
        omp_models=${dailyOmpModels}
        omp_config=${dailyOmpConfig}
        ;;
      scan64)
        settings_patch=${scan64OmlxPatch}
        model_patch=${scan64ModelSettings}
        omp_models=${scan64OmpModels}
        omp_config=${scan64OmpConfig}
        ;;
      *)
        echo "perfil desconhecido: $name (use daily ou scan64)" >&2
        exit 2
        ;;
    esac

    omlx_dir="$HOME/.omlx"
    omp_dir="$HOME/.omp/agent"
    state_dir="$HOME/.local/state/omlx"
    mkdir -p "$omlx_dir" "$omp_dir" "$state_dir"

    settings="$omlx_dir/settings.json"
    model_settings="$omlx_dir/model_settings.json"
    settings_tmp="$omlx_dir/.settings.json.$$"
    model_tmp="$omlx_dir/.model_settings.json.$$"
    omp_models_tmp="$omp_dir/.models.yml.$$"
    omp_config_tmp="$omp_dir/.config.yml.$$"
    trap 'rm -f "$settings_tmp" "$model_tmp" "$omp_models_tmp" "$omp_config_tmp"' EXIT

    if [ -f "$settings" ]; then
      ${pkgs.jq}/bin/jq --slurpfile profile "$settings_patch" '. * $profile[0]' \
        "$settings" > "$settings_tmp"
    else
      ${pkgs.jq}/bin/jq -n --slurpfile profile "$settings_patch" '$profile[0]' \
        > "$settings_tmp"
    fi

    if [ -f "$model_settings" ]; then
      ${pkgs.jq}/bin/jq --slurpfile profile "$model_patch" \
        '.version = 1 | .models = ((.models // {}) + $profile[0].models)' \
        "$model_settings" > "$model_tmp"
    else
      ${pkgs.jq}/bin/jq -n --slurpfile profile "$model_patch" '$profile[0]' \
        > "$model_tmp"
    fi

    cp "$omp_models" "$omp_models_tmp"
    cp "$omp_config" "$omp_config_tmp"
    chmod 600 "$settings_tmp" "$model_tmp" "$omp_models_tmp" "$omp_config_tmp"
    mv "$settings_tmp" "$settings"
    mv "$model_tmp" "$model_settings"
    mv "$omp_models_tmp" "$omp_dir/models.yml"
    mv "$omp_config_tmp" "$omp_dir/config.yml"
    printf '%s\n' "$name" > "$state_dir/profile"
  '';

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
    PROFILE_STATE="$HOME/.local/state/omlx/profile"
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

    wait_unloaded() {
      for _ in $(seq 40); do
        /bin/launchctl print "$AGENT" >/dev/null 2>&1 || return 0
        sleep 0.25
      done
      echo "servico launchd ainda registrado" >&2; return 1
    }

    installed_version() {
      /usr/bin/defaults read "$APP/Contents/Info.plist" \
        CFBundleShortVersionString 2>/dev/null || echo "none"
    }

    cmd_start() {
      up && { echo "ja esta de pe"; return 0; }
      if ! /bin/launchctl bootstrap "gui/$(/usr/bin/id -u)" "$PLIST"; then
        echo "nao consegui registrar o servico launchd" >&2
        return 1
      fi
      wait_up && echo "de pe em $URL"
    }

    # `bootout`, never `kill`: KeepAlive.SuccessfulExit = false treats a SIGTERM
    # as a crash and brings the server straight back.
    cmd_stop() {
      /bin/launchctl bootout "$AGENT" 2>/dev/null || true
      wait_down
      wait_unloaded
      echo "parado"
    }

    cmd_restart() {
      /bin/launchctl kickstart -k "$AGENT" 2>/dev/null || { cmd_start; return; }
      wait_up && echo "reiniciado"
    }

    cmd_status() {
      printf 'versao instalada : %s\n' "$(installed_version)"
      printf 'perfil ativo     : %s\n' "$(cat "$PROFILE_STATE" 2>/dev/null || echo daily)"
      if up; then
        printf 'servidor         : de pe em %s\n' "$URL"
        printf 'modelo servido   : %s\n' \
          "$(${pkgs.curl}/bin/curl -fsS -m 4 "$URL/health" \
             | ${pkgs.jq}/bin/jq -r '.default_model // "nenhum"')"
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

    cmd_profile_check() {
      profile="$(cat "$PROFILE_STATE" 2>/dev/null || true)"
      settings="$HOME/.omlx/settings.json"
      model_settings="$HOME/.omlx/model_settings.json"
      omp_models="$HOME/.omp/agent/models.yml"
      omp_config="$HOME/.omp/agent/config.yml"

      case "$profile" in
        daily)
          context=30000; compact=25000; ceiling=27; chunked=false; hot=2GB; spec=false ;;
        scan64)
          context=65536; compact=60000; ceiling=28; chunked=true; hot=0GB; spec=true ;;
        *)
          echo "perfil salvo invalido: ''${profile:-nenhum}" >&2; return 1 ;;
      esac

      ${pkgs.jq}/bin/jq -e \
        --argjson ceiling "$ceiling" --argjson chunked "$chunked" --arg hot "$hot" \
        '.memory.memory_guard_custom_ceiling_gb == $ceiling and
         .scheduler.max_concurrent_requests == 1 and
         .scheduler.chunked_prefill == $chunked and
         .cache.enabled == true and
         .cache.hot_cache_max_size == $hot' "$settings" >/dev/null
      ${pkgs.jq}/bin/jq -e --arg model "${modelId}" --argjson spec "$spec" \
        '.models[$model].turboquant_kv_bits == 3.5 and
         .models[$model].mtp_enabled == true and
         .models[$model].specprefill_enabled == $spec' "$model_settings" >/dev/null
      ${pkgs.gnugrep}/bin/grep -Eq "^[[:space:]]*contextWindow: $context$" "$omp_models"
      ${pkgs.gnugrep}/bin/grep -Eq "^[[:space:]]*thresholdTokens: $compact$" "$omp_config"
      ${pkgs.gnugrep}/bin/grep -Eq '^[[:space:]]*replayReasoningContent: false$' "$omp_models"
      ${pkgs.gnugrep}/bin/grep -Eq "^[[:space:]]*default: omlx/${modelId}:low$" "$omp_config"
      echo "perfil $profile confere"
    }

    cmd_profile() {
      case "''${1:-status}" in
        status)
          printf 'ativo     : %s\n' "$(cat "$PROFILE_STATE" 2>/dev/null || echo daily)"
          printf 'disponiveis: daily scan64\n'
          ;;
        check)
          cmd_profile_check
          ;;
        daily|scan64)
          wanted="$1"
          was_up=false
          if up; then was_up=true; cmd_stop; fi
          if ! ${applyLocalLlmProfile} "$wanted"; then
            $was_up && cmd_start
            return 1
          fi
          if $was_up; then cmd_start; fi
          cmd_profile_check
          echo "abra uma sessao OMP nova para usar o perfil $wanted"
          ;;
        *)
          echo "uso: omlxctl profile {daily|scan64|status|check}" >&2
          return 2
          ;;
      esac
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

      # Authenticated if a token is to be had, anonymous if not. GitHub gives
      # an IP 60 anonymous API calls an hour, and a rebuild spends five of
      # them, so on a busy afternoon this check is simply refused and the
      # update never happens - the message below is what a 403 looks like from
      # here. rebuild.sh exports GITHUB_TOKEN for exactly this; `gh auth token`
      # is the fallback that makes `omlxctl update` work on its own too.
      # The token goes in through `--config -`, i.e. curl's stdin, and not
      # through `-H`. A command line is public: anyone on the machine can read
      # it out of `ps` while the request is in flight. Nothing is written to
      # disk either way.
      token="''${GITHUB_TOKEN:-''${GH_TOKEN:-$(${pkgs.gh}/bin/gh auth token 2>/dev/null || true)}}"
      if [ -n "$token" ]; then
        json="$(printf 'header = "Authorization: Bearer %s"\n' "$token" \
          | ${pkgs.curl}/bin/curl -fsS -m 20 --config - "$API" 2>/dev/null || true)"
      else
        json="$(${pkgs.curl}/bin/curl -fsS -m 20 "$API" 2>/dev/null || true)"
      fi
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
      #
      # The verdict is the exit status, not the output. This guard used to be
      # `spctl ... 2>&1 | grep -q accepted`, and `spctl -a` prints NOTHING when
      # it accepts - the word "accepted" only appears under -vv. So the grep
      # never matched, every update aborted, and the message on screen blamed
      # upstream for a bug that was here: the Mac sat on 0.6.3rc3 while each
      # rebuild printed a Gatekeeper failure for a properly notarized release.
      #
      # -vv is kept for the failing branch only, where its output is the reason
      # the app was refused and the thing worth reading.
      if ! /usr/sbin/spctl -a -t install "$mnt/oMLX.app" 2>/dev/null; then
        echo "oMLX $want NAO passou no Gatekeeper; abortando e mantendo $have" >&2
        /usr/sbin/spctl -a -t install -vv "$mnt/oMLX.app" >&2 || true
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
      profile)  cmd_profile "''${2:-status}" ;;
      *)
        echo "uso: omlxctl {start|stop|restart|status|logs|update|rollback|profile}" >&2
        exit 2 ;;
    esac
  '';
in
lib.mkIf (memGb > 32) {

  home.packages = [ omlxctl ];

  # Reapply the last selected profile on every rebuild. The profile name is
  # state, while every value it selects lives above in this Nix file.
  home.activation.localLlmProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    profile_state="$HOME/.local/state/omlx/profile"
    profile="$(cat "$profile_state" 2>/dev/null || echo daily)"
    case "$profile" in daily|scan64) ;; *) profile=daily ;; esac
    ${applyLocalLlmProfile} "$profile"
  '';

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
          # Memory, cache and concurrency are selected by `omlxctl profile`.
          # They live in settings.json because daily and scan64 need different
          # limits. Host, port and model directory do not vary, so they remain
          # process flags here.
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
          # Both profiles use one concurrent request: every extra
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
            --port 1337
        ''}"
      ];
      RunAtLoad = true;
      # "missing bootstrap -> stay quiet" (the wrapper exits 0), while a real
      # crash of a running server still gets restarted.
      KeepAlive = {
        SuccessfulExit = false;
      };
      # A crash loop that reloads a 17 GB checkpoint would thrash the disk.
      ThrottleInterval = 30;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/omlx.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/omlx.log";
    };
  };
}
