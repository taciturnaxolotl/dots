{ inputs, lib }:
final: prev:
let
  # A flake input's package for whatever system is being evaluated.
  fromInput = name: inputs.${name}.packages.${prev.stdenv.hostPlatform.system}.default;
in
{
  unstable = import inputs.nixpkgs-unstable {
    system = final.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };

  zmx-binary = prev.callPackage ../packages/zmx.nix { };

  # Not `drift`: nixpkgs already has an unrelated package by that name.
  drift-diff = prev.callPackage ../packages/drift.nix { };
}
// lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  bore-auth = prev.callPackage ../packages/bore-auth.nix { };
  pear = fromInput "pear";
  herald = fromInput "herald";
  potluck = fromInput "potluck";
  lard = fromInput "lard";
  tangle-of-trust = fromInput "tangle-of-trust";

  # nix 2.34 aborts the daemon whenever a substituter is unreachable. A failing
  # narinfo worker sets the thread pool's quit flag, the next worker logs its own
  # error through TunnelLogger, and that write throws Interrupted from inside a
  # catch block, unwinding out of the worker thread. The client just sees "Nix
  # daemon disconnected unexpectedly". NixOS/nix#3768 (open since 2020) and
  # NixOS/nix#12871. Drop this once upstream lands a fix.
  nixVersions = prev.nixVersions.extend (
    _finalNix: prevNix: {
      nixComponents_2_34 = prevNix.nixComponents_2_34.appendPatches [
        ../patches/nix-2.34-daemon-no-interrupt-on-client-write.patch
      ];
    }
  );
}
// lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  # direnv fish tests are killed (SIGKILL) in the Nix sandbox on Darwin since
  # the libarchive 3.8.4->3.8.6 bump; skip until upstream fixes it.
  # https://github.com/NixOS/nixpkgs/issues/507531
  direnv = prev.direnv.overrideAttrs (_: {
    doCheck = false;
  });

  # Upstream yabai has no macOS 27 support, so space switching silently does
  # nothing there. Built on unstable's yabai, which compiles from source and so
  # can take a different revision. See packages/yabai.nix.
  yabai = prev.callPackage ../packages/yabai.nix {
    inherit (final.unstable) yabai;
  };
}
