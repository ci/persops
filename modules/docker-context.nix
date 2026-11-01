{
  pkgs,
  lib,
  currentSystemName ? null,
  ...
}:
let
  docker = lib.getExe pkgs.docker;
in
{
  # aglaea keeps only the docker client; the daemon runs on amalthea so images,
  # volumes and build cache stay off the Mac disk. OrbStack stays installed as
  # a stopped fallback (`docker context use orbstack`); the next switch resets it.
  home.activation.dockerAmaltheaContext = lib.mkIf (currentSystemName == "aglaea") (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if ! ${docker} context inspect amalthea >/dev/null 2>&1; then
        run ${docker} context create amalthea --docker host=ssh://cat@amalthea >/dev/null
      fi
      run ${docker} context use amalthea >/dev/null
    ''
  );
}
