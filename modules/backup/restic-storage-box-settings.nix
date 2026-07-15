rec {
  host = "u632268.your-storagebox.de";
  user = "u632268";
  port = 23;
  repository = "sftp:${user}@${host}:/home/restic/archive";
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
}
