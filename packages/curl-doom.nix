{ pkgs, lib, buildNpmPackage, fetchFromGitHub, fetchurl }:

buildNpmPackage rec {
  pname = "curl-doom";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "xsawyerx";
    repo = "curl-doom";
    rev = "6f9398b49103a3ddfc05d241d4fce2b71d7247c3";
    hash = "sha256-le/J//tmJUcLpxHWTd0vXIqrwZsb6Mx11Va7xPGTNYk=";
  };

  npmDepsHash = "sha256-5yIRv1cKtc4NftQSG8Avir0x2x+YIay0EuzN7ecB06Y=";

  doomWad = fetchurl {
    url = "https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad";
    hash = "sha256-HX1DvlAeZ9kn5BXguPPinDvzMHXoWXIYFvZSpSbKx3E=";
  };

  doomGenericSrc = fetchFromGitHub {
    owner = "ozkl";
    repo = "doomgeneric";
    rev = "dcb7a8dbc7a16ce3dda29382ac9aae9d77d21284";
    hash = "sha256-PmPRPE7fOK6dGzb1BJdpt+Z78TOMhogR0YliPBJU5hU=";
  };

  preBuild = ''
    cp ${doomWad} doom1.wad
    mkdir -p doomgeneric/doomgeneric
    cp -r --no-preserve=mode ${doomGenericSrc}/* doomgeneric/doomgeneric/
    make -C doomgeneric -f Makefile.server
  '';

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/lib/curl-doom
    cp -r index.js doom.sh doom1.wad doomgeneric/doomgeneric_server package.json node_modules $out/lib/curl-doom/
    
    mkdir -p $out/bin
    cat << EOF > $out/bin/curl-doom
    #!${pkgs.bash}/bin/bash
    cd $out/lib/curl-doom
    exec node index.js "\$@"
    EOF
    chmod +x $out/bin/curl-doom
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Play Doom via curl";
    homepage = "https://github.com/xsawyerx/curl-doom";
    license = licenses.mit;
    maintainers = [ ];
  };
}
