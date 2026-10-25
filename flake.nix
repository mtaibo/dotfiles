{
  description = "dotfiles";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-desktop = {
      url = "github:poeck/claude-desktop-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.firefox-gnome-theme.follows = "firefox-gnome-theme";
    };
    # Tagged per Firefox release; bump the tag when Firefox's major version changes.
    firefox-gnome-theme = {
      url = "github:rafaelmardojai/firefox-gnome-theme/v150";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nix-darwin, ... }: {
    homeConfigurations = {
      migueltaibo = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        extraSpecialArgs = { inherit inputs; };
        modules = [ ./hosts/macbook/home.nix ];
      };
      tphome = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-linux;
        extraSpecialArgs = {
          inherit inputs;
          pkgsUnstable = import inputs.nixpkgs-unstable {
            system = "aarch64-linux";
            config.allowUnfree = true;
          };
        };
        modules = [ ./hosts/tphome/home.nix ];
      };
    };
    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/desktop/default.nix
        inputs.claude-desktop.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit inputs;
            pkgsUnstable = import inputs.nixpkgs-unstable {
              system = "x86_64-linux";
              config.allowUnfree = true;
            };
          };
        }
      ];
    };
    darwinConfigurations.macbook = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/macbook/default.nix
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.migueltaibo = import ./hosts/macbook/home.nix;
          home-manager.extraSpecialArgs = {
            inherit inputs;
            pkgsUnstable = import inputs.nixpkgs-unstable {
              system = "aarch64-darwin";
              config.allowUnfree = true;
            };
          };
          home-manager.backupFileExtension = "backup";
        }
      ];
    };
  };
}