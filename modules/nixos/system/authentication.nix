{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.atelier.authentication;
in
{
  options.atelier.authentication.enable = lib.mkEnableOption "Enable authentication stack (polkit, keyring, PAM with fprintd)";

  config = lib.mkIf cfg.enable {
    services.fprintd.enable = true;
    security.polkit.enable = true;
    services.gnome.gnome-keyring.enable = true;
    programs.dconf.enable = true;

    environment.systemPackages = [
      pkgs.polkit_gnome
      pkgs.fprintd
    ];

    systemd.user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

    security.pam.services.hyprlock = lib.mkIf (config.services.fprintd.enable) {
      text = ''
        # Account management.
        account required pam_unix.so # unix (order 10900)

        # Authentication management.
        auth sufficient pam_unix.so try_first_pass likeauth nullok
        auth sufficient ${pkgs.fprintd}/lib/security/pam_fprintd.so
        auth required pam_deny.so # deny

        # Password management.
        password sufficient pam_unix.so nullok yescrypt # unix

        # Session management.
        session required pam_env.so conffile=/etc/pam/environment readenv=0 # env (order 10100)
        session required pam_unix.so # unix (order 10200)
      '';
    };

    security.pam.services.sudo = lib.mkIf (config.services.fprintd.enable) {
      text = ''
        # Account management.
        account required pam_unix.so # unix (order 10900)

        # Authentication management.
        auth sufficient pam_unix.so try_first_pass likeauth nullok
        auth sufficient ${pkgs.fprintd}/lib/security/pam_fprintd.so
        auth required pam_deny.so # deny

        # Password management.
        password sufficient pam_unix.so nullok yescrypt # unix

        # Session management.
        session required pam_env.so conffile=/etc/pam/environment readenv=0 # env (order 10100)
        session required pam_unix.so # unix (order 10200)
      '';
    };

    security.pam.services.su = lib.mkIf (config.services.fprintd.enable) {
      text = ''
        # Account management.
        account required pam_unix.so # unix (order 10900)

        # Authentication management.
        auth sufficient pam_rootok.so # rootok (order 10200)
        auth required pam_faillock.so # faillock (order 10400)
        auth sufficient pam_unix.so try_first_pass likeauth nullok
        auth sufficient ${pkgs.fprintd}/lib/security/pam_fprintd.so
        auth required pam_deny.so # deny

        # Password management.
        password sufficient pam_unix.so nullok yescrypt # unix

        # Session management.
        session required pam_env.so conffile=/etc/pam/environment readenv=0 # env (order 10100)
        session required pam_unix.so # unix (order 10200)
        session required pam_unix.so # unix (order 10200)
        session optional pam_xauth.so systemuser=99 xauthpath=${pkgs.xorg.xauth}/bin/xauth # xauth (order 12100)
      '';
    };
  };
}
