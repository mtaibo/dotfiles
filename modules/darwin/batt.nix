{ pkgs, ... }:
let
  # Charge limiter for Apple Silicon (nixpkgs doesn't ship it). The daemon
  # talks to the SMC as root; the `batt` CLI talks to the daemon.
  batt = pkgs.buildGoModule rec {
    pname = "batt";
    version = "0.8.0";
    src = pkgs.fetchFromGitHub {
      owner = "charlie0129";
      repo = "batt";
      rev = "v${version}";
      hash = "sha256-Dvda1IImHc6n8JqTlExHRqjzscqoTitEFT7goqulPbI=";
    };
    vendorHash = "sha256-v3YSYAn+tL5ZfuPq8OD1QvDZKOWRD3T2ts2wPxuKMEc=";
    subPackages = [ "cmd/batt" ];
    ldflags = [ "-X github.com/charlie0129/batt/pkg/version.Version=v${version}" ];
  };
in {
  environment.systemPackages = [ batt ];

  launchd.daemons.batt.serviceConfig = {
    Label = "cc.chlc.batt";
    ProgramArguments = [ "${batt}/bin/batt" "daemon" "--always-allow-non-root-access" ];
    RunAtLoad = true;
    KeepAlive = true;
    # Interactive so macOS doesn't throttle it, which would break the limit.
    ProcessType = "Interactive";
    StandardOutPath = "/var/log/batt.log";
    StandardErrorPath = "/var/log/batt.log";
  };
}
