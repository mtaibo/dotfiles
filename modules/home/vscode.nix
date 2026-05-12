{ pkgs, ... }: {
  programs.vscode = {
    enable = true;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      adpyke.codesnap
      bbenoist.nix
      bradlc.vscode-tailwindcss
      donjayamanne.githistory
      emmanuelbeziat.vscode-great-icons
      jdinhlife.gruvbox
      ms-azuretools.vscode-containers
      ms-python.python
      ms-python.debugpy
      ms-python.vscode-pylance
      ms-toolsai.jupyter
      ms-toolsai.jupyter-keymap
      ms-toolsai.jupyter-renderers
      ms-toolsai.vscode-jupyter-cell-tags
      ms-toolsai.vscode-jupyter-slideshow
      ms-vscode-remote.remote-containers
      ms-vscode.cmake-tools
      ms-vscode.cpptools
      ms-vscode.cpptools-extension-pack
      ms-vscode.makefile-tools
      ms-vscode-remote.remote-wsl
      platformio.platformio-vscode-ide
      tomoki1207.pdf
      vscodevim.vim
      vue.volar
      yzhang.markdown-all-in-one
    ];

    profiles.default.userSettings = {
      "editor.fontSize" = 18;
      "editor.fontFamily" = "Hack Nerd Font";
      "editor.detectIndentation" = false;

      "workbench.colorTheme" = "Gruvbox Dark Soft";
      "workbench.iconTheme" = "vscode-great-icons";
      "workbench.secondarySideBar.defaultVisibility" = "hidden";
      "workbench.settings.applyToAllProfiles" = [ "editor.fontFamily" ];
      "workbench.editor.empty.hint" = "hidden";

      "terminal.integrated.fontFamily" = "Hack Nerd Font Mono";
      "terminal.integrated.fontSize" = 12;

      "explorer.confirmDelete" = false;
      "explorer.confirmDragAndDrop" = false;

      "git.openRepositoryInParentFolders" = "always";

      "codesnap.backgroundColor" = "0";
      "codesnap.boxShadow" = "0";

      "github.copilot.enable" = {
        "*" = false;
        "plaintext" = false;
        "markdown" = false;
        "scminput" = false;
        "c" = false;
      };

      "python.defaultInterpreterPath" = "/Users/migueltaibo/workspace/test/venv";

      "jupyter.askForKernelRestart" = false;

      "C_Cpp.clang_format_fallbackStyle" = "{ BasedOnStyle: Google, IndentWidth: 4, ColumnLimit: 0 }";

      "cmake.configureOnOpen" = false;

      "makefile.configureOnOpen" = true;

      "http.systemCertificatesNode" = true;

      "sqldeveloper.sqlHistory.historyLimit" = 500;
      "sqldeveloper.telemetry.enabled" = false;
      "sqldeveloper.datagrid.fontFamily" = "Menlo, Monaco, 'Courier New', monospace";

      "claudeCode.preferredLocation" = "panel";

      "files.associations" = {
        "Caddyfile" = "plaintext";
      };
      "liveServer.settings.donotShowInfoMsg" = true;
      "[toml]" = {};
    };
  };
}
