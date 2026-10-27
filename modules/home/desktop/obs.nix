{ pkgs, ... }:
{
  # Screen recorder. On Wayland it captures through the PipeWire portal
  # ("Screen Capture (PipeWire)" source), which asks which screen to share.
  programs.obs-studio = {
    enable = true;
    plugins = [ pkgs.obs-studio-plugins.obs-pipewire-audio-capture ];
  };
}
