{ config, pkgs, ... }:

let
  pgpkg = pkgs.postgresql_15;
  pgdir = "/var/lib/postgresql/${pgpkg.psqlSchema}";

in

{
  # need to use nix-darwin instead of home-manager on OSX
  # for the service functionality (through launchctl), since
  # home-manager doesn't do that
  #
  # also, .dev version is used for packages installed through
  # mise or externally that require the pg client libs
  environment.systemPackages = [ pgpkg.dev ];

  # necessary for https://github.com/LnL7/nix-darwin/issues/339
  system.activationScripts.preActivation = {
    enable = true;
    text = ''
      if [ ! -d "${pgdir}" ]; then
        echo "creating PostgreSQL data directory..."
        sudo mkdir -m 750 -p ${pgdir}
        chown -R cat:staff ${pgdir}
      fi
    '';
  };

  services.postgresql = {
    enable = true; # set to false when upgrading
    package = pgpkg;
    dataDir = pgdir;
    initdbArgs = ["-U cat" "--encoding=UTF8"];
    extraPlugins = with pgpkg.pkgs; [
      postgis
      pgvector
    ];
    # replication for pg_basebackup
    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser  auth-method
      local all,replication       all     trust
      host all       all 127.0.0.1/32    trust
    '';
  };
}
