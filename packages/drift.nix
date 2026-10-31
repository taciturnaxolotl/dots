{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  git,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "drift";
  version = "0.0.14";

  src = fetchFromGitHub {
    owner = "aymanbagabas";
    repo = "drift";
    tag = "v${finalAttrs.version}";
    hash = "sha256-BqftFoNiwPZkB6VXeDjXbesd8JfWsc5xd4ueRTJS5f0=";
  };

  cargoHash = "sha256-+LVqftXPup2DpQdbhCJsJw5zopcxxX5lbDzATIm/1ZA=";

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
