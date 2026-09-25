{
  fetchFromGitHub,
  yabai,
}:

# Upstream v7.1.25 has no macOS 27 support: the scripting addition loads, fails
# its version check, and skips patching the Dock entirely, so every space
# command exits 0 and does nothing. This fork carries the macOS 27 Dock offsets,
# all seven verified against this machine's Dock before adopting it.
# https://github.com/koekeishiya/yabai/issues/2802
yabai.overrideAttrs (old: {
  version = "7.1.25-goldengate";

  src = fetchFromGitHub {
    owner = "AhsanFazal";
    repo = "yabai";
    rev = "ad0a12d63f639534a296a1d065b0d04979f1b4db";
    hash = "sha256-CFC9KuBw7oyOjL5t8D+JIdk6/cdSh91J/K/8XA3v3aE=";
  };

  # dyld refuses to dlopen a Mach-O without LC_UUID, and nixpkgs strips it for
  # reproducibility, so the addition could never load into the Dock.
  # https://github.com/NixOS/nixpkgs/issues/547323
  postPatch = (old.postPatch or "") + ''
    substituteInPlace makefile --replace-fail " -Wl,-no_uuid" ""
  '';

  # The fork tracks a branch, so the binary still reports the upstream tag.
  doInstallCheck = false;

  meta = old.meta // {
    homepage = "https://github.com/AhsanFazal/yabai";
    platforms = [ "aarch64-darwin" ];
  };
})
