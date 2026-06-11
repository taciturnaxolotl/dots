{
  pkgs,
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation rec {
  pname = "zmx";
  version = "0.6.0";

  src = fetchurl {
    url =
      if stdenv.isLinux then
        (
          if stdenv.isAarch64 then
            "https://zmx.sh/a/zmx-${version}-linux-aarch64.tar.gz"
          else
            "https://zmx.sh/a/zmx-${version}-linux-x86_64.tar.gz"
        )
      else if stdenv.isDarwin then
        (
          if stdenv.isAarch64 then
            "https://zmx.sh/a/zmx-${version}-macos-aarch64.tar.gz"
          else
            "https://zmx.sh/a/zmx-${version}-macos-x86_64.tar.gz"
        )
      else
        throw "Unsupported platform";

    hash =
      if stdenv.isLinux && stdenv.isAarch64 then
        "sha256-27s990KLvmRcwm803We2GweVOozj2qbz5QHEnTknJPg="
      else if stdenv.isLinux then
        "sha256-fuSxIVDdDXNtJxuhywaUIkTBC4V4QaZjUXKXrGXHIN0="
      else if stdenv.isDarwin && stdenv.isAarch64 then
        "sha256-fx5Nln1B3qDfdrx8XdDVeV5+VP1lel8MdPv7LAaZOQ4="
      else
        "sha256-V2z4HNffU1SknzKNDzxXHVz2AeJX62+3lIkMecf7cT4=";
  };

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp zmx $out/bin/
    chmod +x $out/bin/zmx
    runHook postInstall
  '';

  meta = with lib; {
    description = "Session persistence for terminal processes";
    homepage = "https://zmx.sh";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
