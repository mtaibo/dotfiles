# Blender on the Mac, plus MCP for Blender so Claude Code can drive it.
# Home Manager module (imported from hosts/macbook/home.nix).
{ pkgs, pkgsUnstable, lib, ... }:
let
  version = "5.3.0";
  series = lib.versions.majorMinor version;

  # nixpkgs' blender is marked broken on darwin and unstable's isn't cached,
  # so this repackages the official signed build instead of compiling it.
  blender = pkgs.stdenvNoCC.mkDerivation {
    pname = "blender";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://download.blender.org/release/Blender${series}/blender-${version}-macos-arm64.dmg";
      hash = "sha256-LYArVHZnQeYSzq1QsD67yOtk2txx7akyVz0la4p4RyA=";
    };
    nativeBuildInputs = [ pkgs._7zz ];
    sourceRoot = ".";
    unpackPhase = "7zz x -snld $src";
    installPhase = ''
      mkdir -p $out/Applications
      cp -R Blender/Blender.app $out/Applications/
    '';
    dontFixup = true;
  };

  # The addon and the MCP server below come from the same release (2.3.1).
  mcpVersion = "2.3.1";
  addon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/ahujasid/blender-mcp/a5a8acf2c6ae44a73670e0caf34663f16456d645/addon.py";
    hash = "sha256-s2PltHZexTiVySvJjzQzUkIGWhZNlbZz8fhDMirE4Ds=";
  };

  blenderDir = "Library/Application Support/Blender/${series}";
  claude = "${pkgsUnstable.claude-code}/bin/claude";
in {
  home.packages = [ blender pkgs.uv ];

  home.file."${blenderDir}/scripts/addons/blender_mcp.py".source = addon;

  # Turns the addon on at every start, so there is nothing to tick in Preferences.
  home.file."${blenderDir}/scripts/startup/enable_blender_mcp.py".text = ''
    import addon_utils
    import bpy


    def _enable():
        if not addon_utils.check("blender_mcp")[1]:
            addon_utils.enable("blender_mcp", default_set=True, persistent=True)


    def register():
        # Startup scripts run before the addons folder is importable.
        bpy.app.timers.register(_enable, first_interval=0.1, persistent=True)


    def unregister():
        pass
  '';

  # Claude Code keeps user MCP servers in the mutable ~/.claude.json, so the
  # entry is rewritten on every switch. Telemetry is off.
  home.activation.blenderMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${claude} mcp remove --scope user blender >/dev/null 2>&1 || true
    $DRY_RUN_CMD ${claude} mcp add --scope user \
      --env DISABLE_TELEMETRY=true \
      blender -- ${pkgs.uv}/bin/uvx --from mcp-for-blender==${mcpVersion} mcp-for-blender \
      >/dev/null
  '';
}
