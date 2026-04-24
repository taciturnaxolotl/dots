{ lib, buildGoModule, fetchFromGitHub, go_1_26 }:

buildGoModule.override { go = go_1_26; } {
  pname = "pear";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "taciturnaxolotl";
    repo = "pear";
    rev = "8507e224db392fe1b82cfb62eff90048534b4c56";
    hash = "sha256-jpS7aSmqnxJi62d5/7iKne1QABqdN3nk+uP35m7bxcc=";
  };

  vendorHash = "sha256-qnvBWpHLZZq0R8QEhDJeclVlHEbnru6v2RkPnKIGMAY=";

  ldflags = [ "-X main.gitHash=${src.rev}" ];

  meta = with lib; {
    description = "Nice recipes — strip any recipe URL down to what matters";
    homepage = "https://pear.dunkirk.sh";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
