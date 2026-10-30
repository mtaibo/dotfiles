{ pkgs, ... }:
let
  # Charge limiter for Apple Silicon (nixpkgs doesn't ship it). The daemon
  # talks to the SMC as root; the `batt` CLI talks to the daemon.
  batt = pkgs.buildGoModule rec {
    pname = "batt";
    version = "0.8.0-unstable-2026-10-29";
    src = pkgs.fetchFromGitHub {
      owner = "charlie0129";
      repo = "batt";
      # v0.8.0 predates adapter mode, the only charge limit that works on
      # macOS 27 firmware (the SMC charge keys are gated there).
      rev = "2b9f8b579670b3d07365772f6f8e56b4f53912be";
      hash = "sha256-weKPm6GlRCQKFlxUVQuaLQKf2Zg+xa1kt//frYVKWCQ=";
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
