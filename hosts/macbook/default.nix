{ pkgs, inputs, ... }: {
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.stateVersion = 5;

  networking.hostName = "macbook";

  nix.enable = false;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "lima-full-1.2.2"
    "lima-additional-guestagents-1.2.2"
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.hack
  ];

  environment.systemPackages = with pkgs; [
    neovim
    git
    gh
    colima
    docker-client
    (ollama.overrideAttrs (oldAttrs: {
      patchPhase = "true";
      doCheck = false; 
      buildPhase = ''
        go build -ldflags "-X github.com/ollama/ollama/version.Version=0.21.1" -o ollama .
      '';
      installPhase = ''
        mkdir -p $out/bin
        cp ollama $out/bin/
      ''; 
    }))
  ];

  programs.nix-index.enable = true;
}
