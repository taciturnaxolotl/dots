{
  lib,
  config,
  pkgs,
  ...
}:
{
  services.fprintd.enable = true;
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
}
