{ lib
, rustPlatform
, pkg-config
, openssl
, deno
, nodejs
, buildNpmPackage
}:
let
  toml = (lib.importTOML ../tranquil-pds-src/Cargo.toml).package;
  
  frontend = buildNpmPackage {
    pname = "tranquil-pds-frontend";
    inherit (toml) version;
    
    src = ../tranquil-pds-src/frontend;
    
    npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will need to update
    
    buildPhase = ''
      runHook preBuild
      npm run build
      runHook postBuild
    '';
    
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage {
  pname = "tranquil-pds";
  inherit (toml) version;

  src = lib.fileset.toSource {
    root = ../tranquil-pds-src;
    fileset = lib.fileset.intersection 
      (lib.fileset.fromSource (lib.sources.cleanSource ../tranquil-pds-src))
      (lib.fileset.unions [
        ../tranquil-pds-src/Cargo.toml
        ../tranquil-pds-src/Cargo.lock
        ../tranquil-pds-src/src
        ../tranquil-pds-src/.sqlx
        ../tranquil-pds-src/migrations
      ]);
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  cargoLock.lockFile = ../tranquil-pds-src/Cargo.lock;

  doCheck = false;

  # Install frontend alongside binary
  postInstall = ''
    mkdir -p $out/share/tranquil-pds
    cp -r ${frontend} $out/share/tranquil-pds/frontend
  '';

  meta = {
    license = lib.licenses.agpl3Plus;
  };
}
