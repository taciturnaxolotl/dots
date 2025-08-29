{
  inputs,
  outputs,
  ...
}:
{
  imports = [
    # Import home-manager's Darwin module
    inputs.home-manager.darwinModules.home-manager
  ];

  home-manager = {
    extraSpecialArgs = {
      inherit inputs outputs;
    };
    users = {
      # Import your home-manager configuration
      kierank = import ./home;
    };
  };
}
