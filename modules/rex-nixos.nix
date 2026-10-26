{ inputs, user, ... }:
{
  imports = [ inputs.rex.nixosModules.default ];

  services.rex.loginServer = {
    enable = true;
    accounts.${user}.principals = [ "tailscale:catalin.irimie@gmail.com" ];
    defaults."tailscale:catalin.irimie@gmail.com" = user;
    tailscaleServe = {
      enable = true;
      httpsPort = 443;
    };
  };
}
