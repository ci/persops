# i3 (X11)
{ lib, pkgs, ... }: {
  specialisation.i3.configuration = {
    services.xserver = {
      enable = true;
      desktopManager.xfce.enable = lib.mkForce false;

      displayManager = {
        lightdm.enable = true;
      };

      windowManager = {
        i3.enable = true;
      };
    };

    services.displayManager.defaultSession = lib.mkForce "none+i3";
  };
}
