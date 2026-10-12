{
  lib,
  stdenvNoCC,
  zsh,
  src,
}:

# Kieran's fork of the pure zsh prompt. The flake input is just the repo, so
# this installs it like any zsh plugin and pre-compiles the instant prompt
# (zsh picks up a .zwc sitting next to the .zsh it sources).
stdenvNoCC.mkDerivation {
  pname = "impure";
  version = src.shortRev or "dirty";
  inherit src;

  nativeBuildInputs = [ zsh ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    dir=$out/share/zsh/plugins/impure
    install -Dm444 -t $dir async.zsh impure.zsh instant-prompt.zsh
    zsh -c 'zcompile "$1"' _ $dir/instant-prompt.zsh
    runHook postInstall
  '';

  meta = {
    description = "A pure zsh prompt fork with jj, zmx and transient prompt support";
    homepage = "https://github.com/taciturnaxolotl/impure";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
