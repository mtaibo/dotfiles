{ pkgs, ... }:

{
  programs.chromium = {
    enable = true;
    package = pkgs.brave;

    # Force dark mode for web content
    commandLineArgs = [ "--force-dark-mode" ];

    extensions = [
      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; }  # uBlock Origin
      { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; }  # Dark Reader
    ];
  };
}
