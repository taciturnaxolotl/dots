{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  git,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "drift";
  version = "0.0.11";

  src = fetchFromGitHub {
    owner = "aymanbagabas";
    repo = "drift";
    tag = "v${finalAttrs.version}";
    hash = "sha256-meUkiqvZypBcjmZvXopIqnGPo/vwXYjLfukfbZZtKyg=";
  };

  cargoHash = "sha256-7w+2K3aSHhNvjRyRRqo4Texm199mg9yFV38goxRGtmU=";

  nativeBuildInputs = [ makeWrapper ];

  doCheck = false;

  # drift shells out to git for every diff it renders.
  postInstall = ''
    wrapProgram $out/bin/drift --prefix PATH : ${lib.makeBinPath [ git ]}
  '';

  meta = {
    description = "Git diff pager that actually wants to be looked at";
    homepage = "https://github.com/aymanbagabas/drift";
    mainProgram = "drift";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
