{
  inputs,
  ...
}:
{
  imports = [
    # Import home-manager's Darwin module
    inputs.home-manager.darwinModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    extraSpecialArgs = {
      inherit inputs;
    };
    users = {
      # Import your home-manager configuration
      kierank = import ./home;
    };
  };
}
