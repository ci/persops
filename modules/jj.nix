{ ... }:
{
  # Preserve local jj history when a Git branch disappears after a squash merge.
  # Automatic abandonment can otherwise rebase unbookmarked descendants onto
  # the old base and manufacture conflicts before jjpr gets to reconcile them.
  xdg.configFile."jj/conf.d/50-persops-safety.toml".text = ''
    [git]
    abandon-unreachable-commits = false
  '';
}
