{ inputs, outputs, ... }:
{
  imports = [
    # Import home-manager's NixOS module
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    extraSpecialArgs = {
      inherit inputs outputs;
    };
    users = {
      # Import your home-manager configuration
      kierank = import ../../../home-manager/machines/moonlark;
    };
  };
}
