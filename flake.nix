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
    in {
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit username; };
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
            home-manager.extraSpecialArgs = { inherit username; };
            home-manager.users.${username} = import ./home.nix;
          }
        ];
      };
    };
}
