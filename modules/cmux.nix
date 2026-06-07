_:
let
  # Chord prefix used by every binding below. Change this one string to
  # rebind everything. ctrl+space keeps C-a free for readline beginning-of-line.
  prefix = "ctrl+space";

  settings = {
    "$schema" = "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json";
    schemaVersion = 1;

    shortcuts = {
      # Prefixless smart pane focus. cmux passes these through to Vim/Nvim;
      # smart-splits calls `cmux select-pane -L/-D/-U/-R` at Vim split edges.
      focusLeft = "ctrl+h";
      focusDown = "ctrl+j";
      focusUp = "ctrl+k";
      focusRight = "ctrl+l";

      # Shift+h/l = prev/next surface (horizontal tabs within a pane).
      prevSurface = [
        prefix
        "shift+h"
      ];
      nextSurface = [
        prefix
        "shift+l"
      ];

      # Shift+j/k = next/prev workspace (vertical sidebar tabs).
      nextSidebarTab = [
        prefix
        "shift+j"
      ];
      prevSidebarTab = [
        prefix
        "shift+k"
      ];

      # tmux-flavored single-letter chords.
      reloadConfiguration = [
        prefix
        "r"
      ]; # C-a r
      toggleSplitZoom = [
        prefix
        "z"
      ]; # C-a z
      splitDown = [
        prefix
        "-"
      ]; # tmux C-a " (horizontal divider)
      splitRight = [
        prefix
        "shift+\\"
      ]; # tmux C-a | (vertical divider)
      newTab = [
        prefix
        "c"
      ]; # C-a c (new workspace)
      closeTab = [
        prefix
        "x"
      ]; # C-a x (kill surface)
      renameWorkspace = [
        prefix
        ","
      ]; # C-a , (rename)
      toggleTerminalCopyMode = [
        prefix
        "["
      ]; # C-a [ (copy mode)
      toggleSidebar = [
        prefix
        "b"
      ]; # C-a b (sidebar)
      find = [
        prefix
        "f"
      ]; # C-a f (find in terminal)
      commandPalette = [
        prefix
        "p"
      ]; # C-a p (palette)
      showNotifications = [
        prefix
        "i"
      ]; # C-a i (inbox)
      jumpToUnread = [
        prefix
        "u"
      ]; # C-a u (jump unread)
      newSurface = [
        prefix
        "t"
      ]; # C-a t (new surface/tab)
    };
  };
in
{
  # Primary path for current cmux. Keep the legacy settings.json in sync for old builds.
  xdg.configFile."cmux/cmux.json" = {
    force = true;
    text = builtins.toJSON settings + "\n";
  };

  xdg.configFile."cmux/settings.json".text =
    builtins.toJSON (
      settings
      // {
        "$schema" =
          "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux-settings.schema.json";
      }
    )
    + "\n";
}
