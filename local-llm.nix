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

lib.mkIf (memGb > 32) {

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
