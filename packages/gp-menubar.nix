# Native menu bar applet for the GlobalProtect → Tailscale gateway.
# Polls the receiver's /status and offers Reauth (which opens the login in the
# browser, where the Chrome extension captures the cookie). Auth stays in the
# browser for speed; this is just a nice native status pill.
{
  stdenv,
  swift,
  apple-sdk_14 ? null,
  lib,
}:

stdenv.mkDerivation {
  pname = "gp-menubar";
  version = "1.0";

  src = ./gp-menubar;

  nativeBuildInputs = [ swift ];
  buildInputs = lib.optional (apple-sdk_14 != null) apple-sdk_14;

  buildPhase = ''
    runHook preBuild
    swiftc -O main.swift -o gp-menubar \
      -framework AppKit -framework Foundation
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    app="$out/Applications/GP Relay.app"
    mkdir -p "$app/Contents/MacOS"
    cp gp-menubar "$app/Contents/MacOS/gp-menubar"

    cat > "$app/Contents/Info.plist" <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleName</key><string>GP Relay</string>
      <key>CFBundleDisplayName</key><string>GP Relay</string>
      <key>CFBundleIdentifier</key><string>sh.dunkirk.gp-relay</string>
      <key>CFBundleVersion</key><string>1.0</string>
      <key>CFBundleShortVersionString</key><string>1.0</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>CFBundleExecutable</key><string>gp-menubar</string>
      <key>LSUIElement</key><true/>
      <key>LSMinimumSystemVersion</key><string>11.0</string>
      <key>NSAppTransportSecurity</key>
      <dict><key>NSAllowsArbitraryLoads</key><true/></dict>
    </dict>
    </plist>
    EOF

    # Ad-hoc sign so launchd/Gatekeeper accept the locally-built bundle.
    /usr/bin/codesign --force --deep -i sh.dunkirk.gp-relay --sign - "$app" 2>/dev/null || true

    # Convenience launcher on PATH.
    mkdir -p "$out/bin"
    ln -s "$app/Contents/MacOS/gp-menubar" "$out/bin/gp-menubar"
    runHook postInstall
  '';

  postFixup = ''
    /usr/bin/codesign --force --deep -i sh.dunkirk.gp-relay --sign - "$out/Applications/GP Relay.app" 2>/dev/null || true
  '';

  meta = {
    description = "Native macOS menu bar status for the GlobalProtect Tailscale gateway";
    platforms = lib.platforms.darwin;
  };
}
