{
  config,
  lib,
  pkgs,
  ...
}:

##############################################################################
# Codex - OpenAI's terminal coding agent, second seat next to Claude Code
#
# The point of this file is parity: both agents read the same instructions,
# reach the same MCP servers and load the same skills, so which one I happen
# to open does not change the answer I get.
#
# The three pieces of that, and where each lives:
#
#   instructions  ~/.codex/AGENTS.md -> this repo's AGENTS.md, exactly as
#                 home.nix links ~/.claude/CLAUDE.md to the same file.
#
#   MCP servers   declared once in `programs.mcp.servers` below. Codex picks
#                 them up through `enableMcpIntegration`, which puts them in
#                 ~/.codex/config.toml as [mcp_servers.<name>] - merged into
#                 that file rather than linked over it, for the reason the
#                 "merged, not linked" section below gives. Claude Code and
#                 the Claude desktop app cannot be given them declaratively -
#                 see that same section - so the generated list is merged into
#                 each of their own config files too.
#
#   skills        ~/.codex/skills/<name>/SKILL.md, one entry per skill.
#                 Codex only follows a symlink of the skill *directory*, not
#                 of the SKILL.md inside it, so every entry is a directory
#                 link. The work-machine overlay flake.nix picks up adds its
#                 own skills there; the ones that arrive as a Claude Code
#                 plugin are linked by the second activation script below.
#
# The binary itself is not installed here. `programs.codex.package = null`
# below, and the `codex` cask in configuration.nix provides it, because nixpkgs
# tracks weeks behind a tool that ships almost daily. This file owns the
# config; that cask owns the binary.
#
# The desktop app is not declared at all - see the note where `codex-app` used
# to be in configuration.nix. `codex app` installs it on demand, and it is the
# same agent behind a GUI reading the same $CODEX_HOME, so it needs nothing of
# its own: it picks up the config.toml and the skills below on first launch.
#
# Not declarative and cannot be: the login. Once per machine, `codex login`,
# or sign in inside the desktop app.
##############################################################################

let
  # The exact file programs.mcp generates for ~/.config/mcp/mcp.json. Reusing
  # it rather than rebuilding the JSON keeps Claude Code's copy and Codex's
  # copy from drifting apart.
  declaredMcpServers = config.xdg.configFile."mcp/mcp.json".source;

  # The config.toml home-manager's codex module generates, read back out of
  # the option instead of rebuilt here, so `programs.mcp.servers` and
  # `programs.codex.settings` stay the only place any of it is written down.
  # The file itself is not linked into place - see "merged, not linked".
  declaredCodexConfig = config.home.file.".codex/config.toml".source;
in
{
  ##########################################################################
  # MCP servers, declared once for every agent that wants them.
  #
  # `programs.mcp` is home-manager's client-agnostic list. It writes
  # ~/.config/mcp/mcp.json and each agent's module translates it into
  # whatever shape that agent reads.
  #
  # The work-machine overlay adds its own servers to this same attribute set.
  ##########################################################################
  programs.mcp = {
    enable = true;

    servers.basic-memory = {
      # The absolute path, not the bare name. basic-memory is a Homebrew
      # formula (see configuration.nix), and `/opt/homebrew` is the fixed
      # prefix on Apple silicon, so this is not a guess.
      #
      # Absolute because of the Claude desktop app. A GUI app on macOS is
      # launched by launchd, not by a login shell, so the PATH it hands an MCP
      # server is whatever the app decides to build. This version builds a
      # good one - its own log shows /opt/homebrew/bin in it, and a bare name
      # would have resolved - but that is the app's choice and not a contract,
      # and the failure it would cause is a silent one: the server just shows
      # as failed. An absolute path does not depend on the choice.
      command = "/opt/homebrew/bin/basic-memory";
      args = [ "mcp" ];
    };
  };

  programs.codex = {
    enable = true;

    # No package: the binary is the `codex` cask in configuration.nix, which
    # tracks upstream within a day, while pkgs.codex on the 26.05 branch sat
    # six weeks behind. `enable` here is only about the config below - with
    # `package = null` home-manager writes ~/.codex/config.toml and skips
    # home.packages, which is exactly the split we want.
    package = null;

    # Translate programs.mcp.servers above into [mcp_servers.*] in
    # ~/.codex/config.toml.
    enableMcpIntegration = true;

    settings = {
      # Load ~/.codex/skills. Stated rather than left to the default so that
      # a default flip upstream cannot quietly turn the skills off.
      skills.enabled = true;
    };
  };

  # The instructions file, linked to the repo's working copy rather than
  # copied into the store, for the reason home.nix gives for CLAUDE.md:
  # editing AGENTS.md takes effect in the next session with no rebuild.
  #
  # `programs.codex.context` would write this file too, but only from a
  # string or a store path - neither can be an out-of-store link.
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/AGENTS.md";

  ##########################################################################
  # ~/.codex/config.toml: merged, not linked
  #
  # Codex writes this file itself, and not only for preferences. Trusting a
  # folder - the question the TUI asks the first time you open a project - is
  # stored in it too. A read-only store symlink makes every one of those
  # writes fail: codex saves atomically, so it resolves the link, tries to
  # create a temp file beside the target, lands in /nix/store and is denied.
  #
  #   failed to persist config at /nix/store/...-codex-config
  #   Caused by: Permission denied (os error 13) at path "/nix/store/.tmpXXXX"
  #
  # The TUI then cannot get past its own trust prompt, so from the outside
  # codex simply does not start. That is what this section exists to prevent.
  #
  # The deal is the same one the two Claude clients get below: Nix owns the
  # content, the app keeps the file. `enable = false` drops home-manager's
  # link, and the script merges the generated settings into the real file on
  # every activation. The declared side wins on a key collision; everything
  # codex put there - trusted projects, model, UI preferences - survives.
  #
  # The one thing a merge cannot do is remove. Drop a server from
  # `programs.mcp.servers` and it stays in config.toml until it is deleted
  # there as well.
  ##########################################################################
  home.file.".codex/config.toml".enable = false;

  home.activation.codexConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    codexConfig="$HOME/.codex/config.toml"

    if [ -n "''${DRY_RUN_CMD:-}" ]; then
      echo "Would merge the declared Codex settings into $codexConfig"
    else
      mkdir -p "$(dirname "$codexConfig")"

      # Left behind by a generation that did link this file. Nothing in it is
      # worth keeping - it holds the same generated content, and being a link
      # is exactly what broke codex.
      if [ -L "$codexConfig" ]; then
        rm -f "$codexConfig"
      fi

      work="$(${pkgs.coreutils}/bin/mktemp -d)"
      ${pkgs.yj}/bin/yj -tj < ${declaredCodexConfig} > "$work/declared.json"

      if [ -e "$codexConfig" ] &&
         ! ${pkgs.yj}/bin/yj -tj < "$codexConfig" > "$work/existing.json" 2>/dev/null; then
        echo "warning: $codexConfig is not valid TOML; left it alone." \
             "Its MCP servers and skills were not updated." >&2
      else
        [ -e "$work/existing.json" ] || echo '{}' > "$work/existing.json"

        if ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
             "$work/existing.json" "$work/declared.json" > "$work/merged.json" &&
           ${pkgs.yj}/bin/yj -jt < "$work/merged.json" > "$work/merged.toml"; then
          ${pkgs.coreutils}/bin/install -m 600 "$work/merged.toml" "$codexConfig"
        fi
      fi

      rm -rf "$work"
    fi
  '';

  ##########################################################################
  # The MCP servers of the two Claude clients
  #
  # A merge, not a link, and that is deliberate. Both clients keep their MCP
  # servers in a file they also write themselves:
  #
  #   ~/.claude.json                     Claude Code. Also holds project
  #                                      history, onboarding state and the
  #                                      trust decisions.
  #   ~/Library/Application Support/     the Claude desktop app. Also holds
  #   Claude/claude_desktop_config.json  its own app preferences.
  #
  # Linking either would lose the race the way settings.json does (see
  # home.nix), and would drag unrelated mutable state into this repo.
  #
  # So Nix owns the *content* and each app keeps its *file*: on every
  # activation the declared servers are merged in, and everything else in
  # there is left untouched. The declared side wins on a name collision,
  # which is what makes this repo the source of truth for it.
  #
  # The desktop app only picks the change up on restart - it reads the file at
  # launch. Claude Code picks it up in the next session.
  ##########################################################################
  home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mergeMcpServers() {
      local target="$1"

      # A file the app has never written yet: start it as an empty object
      # rather than skipping, so a fresh machine gets the servers.
      if [ ! -e "$target" ]; then
        mkdir -p "$(dirname "$target")"
        (umask 077 && echo '{}' > "$target")
      fi

      if ${pkgs.jq}/bin/jq -e 'type == "object"' "$target" >/dev/null 2>&1; then
        local merged tmp
        if merged="$(${pkgs.jq}/bin/jq \
             --slurpfile declared ${declaredMcpServers} \
             '.mcpServers = ((.mcpServers // {}) + $declared[0].mcpServers)' \
             "$target")"; then
          tmp="$(${pkgs.coreutils}/bin/mktemp "$target.hm.XXXXXX")"
          printf '%s\n' "$merged" > "$tmp"
          chmod 600 "$tmp"
          mv "$tmp" "$target"
        fi
      else
        echo "warning: $target is not a JSON object; left it alone." \
             "Its MCP servers were not updated." >&2
      fi
    }

    if [ -n "''${DRY_RUN_CMD:-}" ]; then
      echo "Would merge the declared MCP servers into Claude Code's and the Claude desktop app's config"
    else
      mergeMcpServers "$HOME/.claude.json"
      mergeMcpServers "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    fi
  '';

  ##########################################################################
  # The skills that arrive as a Claude Code plugin
  #
  # Codex has no plugin system, but the skills inside a Claude Code plugin are
  # plain SKILL.md directories, so they can simply be linked in.
  #
  # A script and not `home.file` because the paths are not knowable at build
  # time: a plugin lives under ~/.claude/plugins/cache/<marketplace>/<plugin>/
  # <version>/, and the version moves every time the plugin updates. The
  # script re-links on every activation, so an update is picked up by the next
  # ./rebuild.sh.
  #
  # Which directories are skills comes from the plugin's own manifest, not
  # from a glob. A plugin ships more SKILL.md files than it publishes - the
  # one this machine has keeps deprecated and half-finished skills in the same
  # tree - and the `skills` array in .claude-plugin/plugin.json is the list
  # Claude Code itself loads. A plugin with no such array falls back to a
  # glob, which is the shape of a plugin that publishes everything it has.
  #
  # It only ever removes links it made itself - the ones pointing into the
  # plugin cache - so the Nix-managed skill entries beside them survive, and a
  # name already taken by one of those is skipped rather than clobbered.
  ##########################################################################
  home.activation.codexPluginSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    codexSkills="$HOME/.codex/skills"
    pluginCache="$HOME/.claude/plugins/cache"

    linkCodexSkill() {
      local skillDir="$1"
      local name
      [ -f "$skillDir/SKILL.md" ] || return 0
      name="$(basename "$skillDir")"
      [ -e "$codexSkills/$name" ] || ln -s "$skillDir" "$codexSkills/$name"
    }

    if [ -n "''${DRY_RUN_CMD:-}" ]; then
      echo "Would link the Claude Code plugin skills into $codexSkills"
    elif [ -d "$pluginCache" ]; then
      mkdir -p "$codexSkills"

      for link in "$codexSkills"/*; do
        if [ -L "$link" ]; then
          case "$(readlink "$link")" in
            "$pluginCache"/*) rm -f "$link" ;;
          esac
        fi
      done

      for manifest in "$pluginCache"/*/*/*/.claude-plugin/plugin.json; do
        if [ -f "$manifest" ]; then
          pluginRoot="$(dirname "$(dirname "$manifest")")"

          declared="$(${pkgs.jq}/bin/jq -r '(.skills // []) | .[]' "$manifest" 2>/dev/null)"

          if [ -n "$declared" ]; then
            while IFS= read -r relative; do
              linkCodexSkill "$pluginRoot/''${relative#./}"
            done <<< "$declared"
          else
            for skillFile in "$pluginRoot"/skills/*/SKILL.md "$pluginRoot"/skills/*/*/SKILL.md; do
              if [ -f "$skillFile" ]; then
                linkCodexSkill "$(dirname "$skillFile")"
              fi
            done
          fi
        fi
      done
    fi
  '';
}
