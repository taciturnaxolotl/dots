{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # git config
  programs.git = {
    enable = true;
    userName = "Kieran Klukas";
    userEmail = "me@dunkirk.sh";
    aliases = {
      c = "commit";
      p = "push";
      ch = "checkout";
      pushfwl = "push --force-with-lease --force-if-includes";
    };
    extraConfig = {
      branch.sort = "-committerdate";
      pager.branch = false;
      column.ui = "auto";
      commit.gpgsign = true;
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowedSigners";
      user.signingKey = "~/.ssh/id_rsa.pub";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
}
