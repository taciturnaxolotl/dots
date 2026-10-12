{
  home-manager = {
    users = {
      kierank = import ./home;
      duncan = import ./home/duncan.nix;
    };
  };
}
