{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.atelier.editor;

  # getExe throws unless the package declares meta.mainProgram, so the binary
  # name comes from the derivation rather than from a string that can drift.
  command = baseNameOf (lib.getExe cfg.package);
in
{
  options.atelier.editor = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.evil-helix;
      defaultText = lib.literalExpression "pkgs.evil-helix";
      description = "Editor installed system-wide and used for EDITOR, VISUAL and SYSTEMD_EDITOR.";
    };
  };

  config = {
    # Installed here so the name in EDITOR is always on PATH, root included.
    environment.systemPackages = [ cfg.package ];

    environment.variables = {
      EDITOR = command;
      VISUAL = command;
      SYSTEMD_EDITOR = command;
    };
  };
}
