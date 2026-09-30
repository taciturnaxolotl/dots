{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  git,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "drift";
  version = "0.0.10";

  src = fetchFromGitHub {
    owner = "aymanbagabas";
    repo = "drift";
    tag = "v${finalAttrs.version}";
    hash = "sha256-XVTBiP5aPGMJiiHfCoQ208sUVsf5DKoknby9ByWk6JM=";
  };

  cargoHash = "sha256-Yc5pRiibrvIaa2OhZrH5LS/iUM8i7wig1ZbrEF5NZ0Q=";

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
