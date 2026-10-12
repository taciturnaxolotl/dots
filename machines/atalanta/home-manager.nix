{
  home-manager = {
    users = {
      # Import your home-manager configuration
      kierank = import ./home;
    };
  };
}
