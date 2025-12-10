{ pkgs, lib, stdenv, fetchurl, autoPatchelfHook }:

stdenv.mkDerivation rec {
  pname = "zmx";
  version = "0.1.0";

  src = fetchurl {
    url = if stdenv.isLinux then
      (if stdenv.isAarch64 then
        "https://zmx.sh/a/zmx-${version}-linux-aarch64.tar.gz"
      else
        "https://zmx.sh/a/zmx-${version}-linux-x86_64.tar.gz")
    else if stdenv.isDarwin then
      (if stdenv.isAarch64 then
        "https://zmx.sh/a/zmx-${version}-macos-aarch64.tar.gz"
      else
        "https://zmx.sh/a/zmx-${version}-macos-x86_64.tar.gz")
    else throw "Unsupported platform";
    
    hash = if stdenv.isLinux && stdenv.isAarch64 then
      "sha256-sv83lR4DLJE+gsMtqCk6VCFdo5n4lhI0P1loxAf0iOg="
    else if stdenv.isLinux then
      "sha256-c+wCUcm7DEO55wXuHq0aP0Kn908jj1FM5Z+JQJnKE0M="
    else if stdenv.isDarwin && stdenv.isAarch64 then
      "sha256-dM6MFikdbpN+n8BK6fLbzyJfi88xetCWL9H5VfGB07o="
    else
      "sha256-B52NC8NEjVPDNSG11qPb0uRNExB66bllnK7ivXMJbHk=";
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
