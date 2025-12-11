# xfce (X11)
{ pkgs, ... }: {
  specialisation.xfce.configuration = {
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = "*";
    };

    services.xrdp.defaultWindowManager = "startxfce4";

    services.xserver = {
      enable = true;

      desktopManager.xfce.enable = true;

      displayManager = {
        lightdm.enable = true;
      };
    };

    services.displayManager.defaultSession = "xfce";
  };
}
