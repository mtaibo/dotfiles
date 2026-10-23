{ lib, ... }:
let
  # Language/tool modules: nerd-font symbol, all in the same quiet grey and
  # pushed to the right of the prompt.
  quiet = symbol: {
    inherit symbol;
    style = "bright-black";
    format = "[$symbol($version)]($style) ";
  };
  languages = lib.mapAttrs (_: quiet) {
    aws = " ";
    buf = " ";
    bun = " ";
    c = " ";
    cpp = " ";
    cmake = " ";
    conda = " ";
    crystal = " ";
    dart = " ";
    deno = " ";
    docker_context = " ";
    elixir = " ";
    elm = " ";
    fennel = " ";
    fortran = " ";
    gcloud = " ";
    golang = " ";
    gradle = " ";
    guix_shell = " ";
    haskell = " ";
    haxe = " ";
    java = " ";
    julia = " ";
    kotlin = " ";
    lua = " ";
    meson = "󰔷 ";
    nim = "󰆥 ";
    nodejs = " ";
    ocaml = " ";
    package = "󰏗 ";
    perl = " ";
    php = " ";
    pixi = "󰏗 ";
    python = " ";
    rlang = "󰟔 ";
    ruby = " ";
    rust = "󱘗 ";
    scala = " ";
    swift = " ";
    xmake = " ";
    zig = " ";
  };
in {
  # Uses the terminal's named colours; on the desktop Stylix maps them to its
  # palette, elsewhere they come from the terminal theme.
  programs.starship = {
    enable = true;
    settings = languages // {
      add_newline = true;

      # Line 1: os, host (SSH only), path, git … right side: tools, duration.
      # Line 2: just the prompt character.
      format = lib.concatStrings [
        "$os"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_state"
        "$git_status"
        "$fill"
        "$all"
        "$nix_shell"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      fill.symbol = " ";

      os = {
        disabled = false;
        style = "white";
        format = "[$symbol]($style)";
        symbols = {
          NixOS = " ";
          Macos = " ";
          Raspbian = " ";
          Debian = " ";
          Linux = " ";
          Unknown = " ";
        };
      };

      hostname = {
        ssh_symbol = " ";
        style = "bright-black";
        format = "[$ssh_symbol$hostname]($style) ";
      };

      directory = {
        style = "bold white";
        truncation_length = 3;
        truncation_symbol = "";
        read_only = " 󰌾";
        read_only_style = "red";
        format = "[$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        symbol = " ";
        style = "bright-black";
        format = "[$symbol$branch]($style) ";
      };

      git_commit.tag_symbol = "  ";

      git_state = {
        style = "yellow";
        format = "[$state( $progress_current/$progress_total)]($style) ";
      };

      git_status = {
        style = "blue";
        format = "([$all_status$ahead_behind]($style) )";
      };

      nix_shell = {
        symbol = " ";
        style = "blue";
        format = "[$symbol$state]($style) ";
      };

      cmd_duration = {
        min_time = 2000;
        style = "bright-black";
        format = "[󱎫 $duration]($style)";
      };

      character = {
        success_symbol = "[❯](white)";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](white)";
      };

      fossil_branch.symbol = " ";
      hg_branch.symbol = " ";
      pijul_channel.symbol = " ";
      memory_usage.symbol = "󰍛 ";
      status.symbol = " ";
    };
  };
}
