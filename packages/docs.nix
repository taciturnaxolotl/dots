{
  stdenvNoCC,
  lib,
  mdbook,
  nixdoc,
  fetchurl,
  simple-http-server,
  writeShellApplication,
  jq,
  # Injected from flake.nix
  servicesManifest,
  self,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  name = "dunkirk-docs";
  src = self + /docs;

  nativeBuildInputs = [ mdbook nixdoc jq ];

  buildPhase = ''
    # Set up catppuccin theme
    mkdir -p theme
    cp ${finalAttrs.passthru.catppuccin-mdbook} theme/catppuccin.css

    # Generate lib docs via nixdoc
    mkdir -p src/lib
    nixdoc -c services -d "Service utility functions" \
      -p "" \
      -f ${self + /lib/services.nix} > src/lib/services.md

    # Build the lib index for SUMMARY.md injection
    echo '- [services](lib/services.md)' > src/lib/index.md

    # Inject libdoc entries into SUMMARY.md
    substituteInPlace src/SUMMARY.md \
      --replace-fail "libdoc" "$(cat src/lib/index.md)"

    # Build the book
    mdbook build
  '';

  installPhase = ''
    cp -r ./dist $out

    # Place services.json alongside the book
    echo '${builtins.toJSON servicesManifest}' | jq . > $out/services.json
  '';

  passthru.catppuccin-mdbook = fetchurl {
    url = "https://github.com/catppuccin/mdBook/releases/download/v4.0.0/catppuccin.css";
    hash = "sha256-4IvmqQrfOSKcx6PAhGD5G7I44UN2596HECCFzzr/p/8=";
  };

  passthru.serve = writeShellApplication {
    name = "docs-serve";
    runtimeInputs = [ simple-http-server ];
    text = ''
      echo "Serving docs at http://localhost:8000"
      simple-http-server -i -p 8000 -- ${finalAttrs.finalPackage}
    '';
  };
})
