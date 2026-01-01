{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule {
  pname = "bore-auth";
  version = "0.1.0";

  src = ../modules/nixos/services/bore/bore-auth;

  vendorHash = "sha256-5R3eEoKYR3f5/56V3lUlXV5jVEL9KO16N98SfNPzrhc=";

  meta = with lib; {
    description = "OAuth authentication proxy for bore tunnels";
    homepage = "https://bore.dunkirk.sh";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
