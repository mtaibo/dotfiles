{ config, lib, pkgs, ... }:

{
  options.mySystem.ollama = {
    enable = lib.mkEnableOption "Ollama local LLM server";
    acceleration = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "cuda" "rocm" "metal" ]);
      default = null;
    };
    models = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  config = lib.mkIf config.mySystem.ollama.enable {
    services.ollama = {
      enable = true;
      acceleration = config.mySystem.ollama.acceleration;
    };

    systemd.services.ollama-pull-models = lib.mkIf (config.mySystem.ollama.models != []) {
      description = "Pull configured Ollama models";
      after = [ "ollama.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      requires = [ "ollama.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "${pkgs.bash}/bin/bash -c 'until ${pkgs.curl}/bin/curl -sf http://localhost:11434/api/tags > /dev/null; do sleep 2; done'";
        ExecStart = pkgs.writeShellScript "ollama-pull" (
          lib.concatMapStrings (m: ''
            echo "Pulling ${m}..."
            ${config.services.ollama.package}/bin/ollama pull ${lib.escapeShellArg m}
          '') config.mySystem.ollama.models
        );
      };
    };
  };
}