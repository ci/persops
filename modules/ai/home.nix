{
  pkgs,
  inputs,
  lib,
  currentSystemName ? null,
  ...
}:
let
  hostSystem = pkgs.stdenv.hostPlatform.system;
  llmAgents = inputs.llm-agents.packages.${hostSystem};
  summarizePackage = pkgs.callPackage ./summarize.nix {
    nodejs = pkgs.nodejs_22 or pkgs.nodejs;
    pnpm = pkgs.pnpm_10 or pkgs.pnpm;
    inherit pkgs;
  };
  gifgrepPackage = pkgs.callPackage ./gifgrep.nix { };
  osgrepPackage = pkgs.callPackage ./osgrep.nix { };
  spogoPackage = pkgs.callPackage ./spogo.nix { };
  cudaPkgs =
    if isLinux && hostSystem == "x86_64-linux" then
      pkgs.cudaPackages_12.overrideScope (
        _: prev: {
          cuda_compat = pkgs.stdenvNoCC.mkDerivation {
            pname = "cuda_compat";
            version = "disabled";
            dontUnpack = true;
            dontBuild = true;
            installPhase = "mkdir -p $out";
            meta = (prev.cuda_compat.meta or { }) // {
              available = false;
            };
          };
        }
      )
    else
      null;
  sherpaOnnxOfflinePackage =
    if cudaPkgs == null then
      null
    else
      pkgs.callPackage ./sherpa-onnx-offline.nix {
        cudaPackages = cudaPkgs;
      };
  isLinux = pkgs.stdenv.isLinux;
  summarizeEnabled = true;
  skillBaseProfiles = {
    all = [
      ".claude/skills"
      ".agents/skills"
      ".openclaw/skills"
      ".pi/agent/skills"
    ];
    coding = [
      ".claude/skills"
      ".agents/skills"
      ".pi/agent/skills"
    ];
    claw = [
      ".openclaw/skills"
    ];
    codex = [
      ".agents/skills"
    ];
  };
  localSkillOverrides = builtins.fromJSON (builtins.readFile ./skill-overrides.json);
  localSkillDirs = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./skills);
  mkLocalSkill =
    name:
    let
      override = localSkillOverrides.${name} or { };
      profile = override.profile or "all";
    in
    {
      inherit name;
      source = ./skills + "/${name}";
      recursive = override.recursive or false;
      bases =
        if builtins.hasAttr profile skillBaseProfiles then
          skillBaseProfiles.${profile}
        else
          throw "Unknown AI skill profile '${profile}' for ${name}";
    };
  localSkillTargets = map mkLocalSkill (builtins.attrNames localSkillDirs);
  workAgentsText = ''
    ## Work Machine

    - `AGENTS.md` changes usually mean `~/p/persops/modules/ai/AGENTS.md`. Use root `~/p/persops/AGENTS.md` only when the user specifically says persops repo AGENTS, or the note is explicitly about doing work inside persops.
    - PostHog monorepo, SDKs, and other work repos usually live in `~/p/`.
    - Unless already working from a different path, create new worktrees under `~/p/worktrees/{original-repo}-plus-some-specific-name` so they stay distinguishable.
    - Local development credentials for localhost dev (API token, project token, host) are in `~/p/local-dev-creds`; safe to read for local testing. Make sure `hogli` is running before relying on them.
  '';
  agentsText =
    (builtins.readFile ./AGENTS.md)
    + lib.optionalString (currentSystemName == "work") ("\n\n" + workAgentsText);
  agentsFile = pkgs.writeText "AGENTS.md" agentsText;
  piAgentsFile = pkgs.writeText "pi-AGENTS.md" (
    agentsText + "\n\n" + (builtins.readFile ./pi/AGENTS.extra.md)
  );
  skillTargets = localSkillTargets ++ [
    {
      name = "summarize";
      source = "${inputs.nix-steipete-tools}/tools/summarize/skills/summarize";
    }
    {
      name = "openhue";
      source = ./openhue;
    }
  ];
  agentSkillTargets = lib.filter (
    skill: builtins.elem ".agents/skills" (skill.bases or skillBaseProfiles.all)
  ) skillTargets;
  managedAgentSkillNames = lib.concatStringsSep "\n" (
    lib.unique (map (skill: skill.name) agentSkillTargets)
  );
in
{
  imports = [
    ./herdr.nix
  ];

  xdg.configFile = {
    # OpenCode configuration
    "opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      keybinds = {
        leader = "ctrl+x";
        messages_half_page_up = "ctrl+u";
        messages_half_page_down = "ctrl+d";
      };
    };

    # Oh My OpenCode configuration
    "opencode/oh-my-opencode.json".text = builtins.toJSON {
      "$schema" =
        "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
      agents = {
        explore = {
          model = "anthropic/claude-haiku-4-5";
        };
      };
    };

    # OpenCode commands
    "opencode/command/commit.md".source = ./commands/commit.md;
    "opencode/command/rmslop.md".source = ./commands/rmslop.md;

    # Global agent instructions for Claude Code, Codex, and OpenCode.
    # Pi gets a generated mutable copy with pi-specific notes below.
    "opencode/AGENTS.md".source = agentsFile;
  };

  home = {
    # AI agent packages
    packages =
      with pkgs;
      [
        llmAgents.amp
        codex
        claude-code
        llmAgents.claude-plugins
        # llmAgents.copilot-cli
        llmAgents.cursor-agent
        # llmAgents.gemini-cli # disabled: stale vs Homebrew package
        llmAgents.hunk
        llmAgents.mcporter
        llmAgents.opencode
        llmAgents.pi
        llmAgents.qmd
        llmAgents.rtk
        yt-dlp
        gifgrepPackage
        osgrepPackage
        spogoPackage
        # llm
      ]
      ++ lib.optionals (summarizeEnabled && isLinux && hostSystem == "x86_64-linux") [
        summarizePackage
      ]
      ++ lib.optionals (sherpaOnnxOfflinePackage != null) [
        sherpaOnnxOfflinePackage
      ];

    # Skills for agents
    file =
      let
        baseFiles = {
          ".claude/CLAUDE.md".source = agentsFile;
          ".codex/AGENTS.md".source = agentsFile;
          ".summarize/config.json".text = builtins.toJSON {
            model = {
              mode = "auto";
              rules = [
                {
                  when = [ "video" ];
                  candidates = [ "google/gemini-3-flash-preview" ];
                }
                {
                  candidates = [ "cli/codex/gpt-5.2" ];
                }
              ];
            };
            media = {
              videoMode = "auto";
            };
          };
        };
        mkSkillEntry = base: skill: {
          name = "${base}/${skill.name}";
          value = {
            inherit (skill) source;
            recursive = skill.recursive or false;
          };
        };
      in
      baseFiles
      // builtins.listToAttrs (
        builtins.concatMap (
          skill: map (base: mkSkillEntry base skill) (skill.bases or skillBaseProfiles.all)
        ) skillTargets
      );

    # Move pre-existing mutable ~/.agents/skills entries out of the way before
    # Home Manager checks link targets. Only repo-managed skill names are touched.
    activation.prepareAgentSkillLinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      agents_dir="$HOME/.agents/skills"
      backup_dir=""

      ensure_backup_dir() {
        if [ -z "$backup_dir" ]; then
          backup_dir="$agents_dir/backups/$(date -u +%Y%m%dT%H%M%SZ)"
          install -d "$backup_dir"
          echo "Backing up existing ~/.agents/skills entries under $backup_dir" >&2
        fi
      }

      backup_agent_skill() {
        path="$1"
        name="$2"
        ensure_backup_dir
        if [ -e "$backup_dir/$name" ] || [ -L "$backup_dir/$name" ]; then
          name="$name.$(date -u +%s)"
        fi
        mv "$path" "$backup_dir/$name"
        echo "Backed up $path -> $backup_dir/$name" >&2
      }

      install -d "$agents_dir"

      while IFS= read -r name; do
        [ -n "$name" ] || continue
        path="$agents_dir/$name"
        [ -e "$path" ] || [ -L "$path" ] || continue

        if [ -L "$path" ]; then
          target="$(readlink "$path" || true)"
          case "$target" in
            /nix/store/*) rm -f "$path" ;;
            *) backup_agent_skill "$path" "$name" ;;
          esac
        else
          backup_agent_skill "$path" "$name"
        fi
      done <<'EOF'
      ${managedAgentSkillNames}
      EOF
    '';

    # Remove stale Home Manager symlinks from the old Codex skill location.
    # Non-symlinks and symlinks outside /nix/store are left alone.
    activation.cleanupOldCodexSkillLinks = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      old_dir="$HOME/.codex/skills"

      if [ -d "$old_dir" ]; then
        while IFS= read -r name; do
          [ -n "$name" ] || continue
          path="$old_dir/$name"
          [ -L "$path" ] || continue

          target="$(readlink "$path" || true)"
          case "$target" in
            /nix/store/*)
              rm -f "$path"
              echo "Removed old Home Manager Codex skill link $path" >&2
              ;;
          esac
        done <<'EOF'
      ${managedAgentSkillNames}
      EOF

        rmdir "$old_dir" 2>/dev/null || true
      fi
    '';

    # Pi config files are copied, not symlinked, so /settings and /reload workflows can write to them.
    # Source of truth stays in modules/ai/pi; make local overwrites generated copies after backing up drift.
    activation.installPiAgentConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      pi_dir="$HOME/.pi/agent"
      pi_backup_dir=""

      install -d "$pi_dir"

      ensure_pi_backup_dir() {
        if [ -z "$pi_backup_dir" ]; then
          pi_backup_dir="$pi_dir/backups/$(date -u +%Y%m%dT%H%M%SZ)"
          install -d "$pi_backup_dir"
          echo "Backing up differing mutable Pi config under $pi_backup_dir" >&2
        fi
      }

      backup_pi_path() {
        path="$1"
        rel="''${path#$pi_dir/}"
        ensure_pi_backup_dir
        install -d "$pi_backup_dir/$(dirname "$rel")"
        cp -pR "$path" "$pi_backup_dir/$rel"
        echo "Backed up $path -> $pi_backup_dir/$rel" >&2
      }

      ensure_mutable_dir() {
        dst="$1"
        if [ -L "$dst" ]; then
          rm -f "$dst"
        fi
        install -d "$dst"
      }

      backup_file_if_different() {
        src="$1"
        dst="$2"
        if [ -e "$dst" ] && [ ! -L "$dst" ] && { [ ! -f "$dst" ] || ! cmp -s "$src" "$dst"; }; then
          backup_pi_path "$dst"
        fi
      }

      install_mutable_file() {
        src="$1"
        dst="$2"
        if [ -L "$dst" ]; then
          rm -f "$dst"
        fi
        backup_file_if_different "$src" "$dst"
        install -m 0644 "$src" "$dst"
      }

      backup_tree_drift() {
        src="$1"
        dst="$2"
        if [ -d "$src" ]; then
          while IFS= read -r rel; do
            src_file="$src/$rel"
            dst_file="$dst/$rel"
            if [ -e "$dst_file" ] && [ ! -L "$dst_file" ] && { [ ! -f "$dst_file" ] || ! cmp -s "$src_file" "$dst_file"; }; then
              backup_pi_path "$dst_file"
            fi
          done < <(cd "$src" && find . -type f ! -name '.gitkeep' -print | sed 's#^./##')
        fi
      }

      copy_mutable_tree() {
        src="$1"
        dst="$2"
        ensure_mutable_dir "$dst"
        backup_tree_drift "$src" "$dst"
        if [ -d "$src" ]; then
          ${pkgs.rsync}/bin/rsync -a --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r --exclude '.gitkeep' "$src/" "$dst/"
        fi
      }

      install_mutable_file "${./pi/settings.json}" "$pi_dir/settings.json"
      install_mutable_file "${piAgentsFile}" "$pi_dir/AGENTS.md"
      copy_mutable_tree "${./pi/extensions}" "$pi_dir/extensions"
      copy_mutable_tree "${./pi/prompts}" "$pi_dir/prompts"
      copy_mutable_tree "${./pi/themes}" "$pi_dir/themes"
      copy_mutable_tree "${./pi/skills}" "$pi_dir/skills"
      copy_mutable_tree "${./pi/agents}" "$pi_dir/agents"
      copy_mutable_tree "${./pi/compound-engineering}" "$pi_dir/compound-engineering"
    '';
  };

}
