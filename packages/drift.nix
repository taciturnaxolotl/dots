{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  git,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "drift";
  version = "0.0.12";

  src = fetchFromGitHub {
    owner = "aymanbagabas";
    repo = "drift";
    tag = "v${finalAttrs.version}";
    hash = "sha256-8q26qYXup4Kh7/Xp1ZJeADqcPq5MTjXo05ofIFsYHh4=";
  };

  cargoHash = "sha256-bUp46uzHAACS6QyurLGkyPQMDB1ZtapHjbgw54bRM9A=";

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
