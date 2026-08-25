{
  description = "dotfiles";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-26.05-darwin` to use Nixpkgs 26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Use `github:nix-darwin/nix-darwin/nix-darwin-26.05` to use Nixpkgs 26.05.
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager }:
    let
      # The macOS account this config is applied to. Read from the environment
      # so a new Mac needs no edit here, only `./rebuild.sh`.
      #
      # `builtins.getEnv` is impure, so every command that evaluates this flake
      # needs `--impure` and `DOTFILES_USER` set. rebuild.sh does both.
      username =
        let fromEnv = builtins.getEnv "DOTFILES_USER";
        in if fromEnv != "" then fromEnv
        else throw ''
          DOTFILES_USER is not set.

          Run ./rebuild.sh, or set it yourself for a one-off command:
            DOTFILES_USER="$(id -un)" darwin-rebuild build --impure --flake .#mac
        '';

      # The GPG key git signs commits and tags with, as a long key id. Unlike
      # the username there is nothing sensible to derive this from, and a
      # machine that does not hold the secret key cannot sign at all - so an
      # unset DOTFILES_GPG_KEY means "do not sign here" rather than an error.
      signingKey = builtins.getEnv "DOTFILES_GPG_KEY";

      # The machine's unified memory in GB, used to gate ./local-llm.nix: a
      # 17.4 GB model plus its KV cache only makes sense above 32 GB. rebuild.sh
      # computes it from `sysctl -n hw.memsize` and hands it over like the two
      # variables above. Unset means 0 means "no local LLM here", which is the
      # right answer on a machine this config has never seen.
      memGb =
        let fromEnv = builtins.getEnv "DOTFILES_MEM_GB";
        in if fromEnv != "" then nixpkgs.lib.toInt fromEnv else 0;
    in {
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit username signingKey; };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Rename any pre-existing dotfile home-manager wants to own, rather
            # than failing activation.
            home-manager.backupFileExtension = "before-nix";
            home-manager.extraSpecialArgs = { inherit username signingKey memGb; };
            home-manager.users.${username} = import ./home.nix;
          }
        ]
        # An optional work-machine overlay: extra Homebrew packages and the
        # toolchains for the repos I am paid to work on. It is the one directory
        # this repo does not publish, so on a clone without it - which is what
        # the public remote has - the config is just the personal setup and none
        # of it is missed.
        #
        # Nix only sees files that git tracks, so an untracked ./nova is invisible
        # here too, the same way a brand new .nix file is (see rebuild.sh).
        ++ nixpkgs.lib.optional (builtins.pathExists ./nova) ./nova;
      };
    };
}
