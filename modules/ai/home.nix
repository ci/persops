{ pkgs, inputs, lib, ... }:
let
  llmAgents = inputs.llm-agents.packages.${pkgs.system};
  summarizePackage = pkgs.callPackage ./summarize.nix {
    nodejs = if pkgs ? nodejs_22 then pkgs.nodejs_22 else pkgs.nodejs;
    pnpm = if pkgs ? pnpm_10 then pkgs.pnpm_10 else pkgs.pnpm;
    pkgs = pkgs;
  };
  gifgrepPackage = pkgs.callPackage ./gifgrep.nix { };
  osgrepPackage = pkgs.callPackage ./osgrep.nix { };
  spogoPackage = pkgs.callPackage ./spogo.nix { };
  cudaPkgs =
    if isLinux && pkgs.system == "x86_64-linux" then
      pkgs.cudaPackages_12.overrideScope (final: prev: {
        cuda_compat = pkgs.stdenvNoCC.mkDerivation {
          pname = "cuda_compat";
          version = "disabled";
          dontUnpack = true;
          dontBuild = true;
          installPhase = "mkdir -p $out";
          meta = (prev.cuda_compat.meta or { }) // { available = false; };
        };
      })
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
      ".codex/skills"
      ".openclaw/skills"
      ".pi/agent/skills"
    ];
    coding = [
      ".claude/skills"
      ".codex/skills"
      ".pi/agent/skills"
    ];
    claw = [
      ".openclaw/skills"
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
  piAgentsFile = pkgs.writeText "pi-AGENTS.md" (
    (builtins.readFile ./AGENTS.md) + "\n\n" + (builtins.readFile ./pi/AGENTS.extra.md)
  );
in {

  # AI agent packages
  home.packages = with pkgs; [
    llmAgents.amp
    codex
    claude-code
    llmAgents.claude-code-acp
    llmAgents.claude-plugins
    llmAgents.codex-acp
    # llmAgents.copilot-cli
    llmAgents.cursor-agent
    # llmAgents.gemini-cli # disabled: stale vs Homebrew package
    llmAgents.mcporter
    llmAgents.opencode
    llmAgents.pi
    llmAgents.qmd
    yt-dlp
    gifgrepPackage
    osgrepPackage
    spogoPackage
    # llm
  ] ++ lib.optionals (summarizeEnabled && isLinux && pkgs.system == "x86_64-linux") [
    summarizePackage
  ] ++ lib.optionals (sherpaOnnxOfflinePackage != null) [
    sherpaOnnxOfflinePackage
  ];

  # OpenCode configuration
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    keybinds = {
      leader = "ctrl+x";
      messages_half_page_up = "ctrl+u";
      messages_half_page_down = "ctrl+d";
    };
  };

  # Oh My OpenCode configuration
  xdg.configFile."opencode/oh-my-opencode.json".text = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
    agents = {
      explore = { model = "anthropic/claude-haiku-4-5"; };
    };
  };

  # OpenCode commands
  xdg.configFile."opencode/command/commit.md".source = ./commands/commit.md;
  xdg.configFile."opencode/command/rmslop.md".source = ./commands/rmslop.md;

  # Global agent instructions for Claude Code, Codex, and OpenCode.
  # Pi gets a generated mutable copy with pi-specific notes below.
  xdg.configFile."opencode/AGENTS.md".source = ./AGENTS.md;

  # Skills for agents
  home.file =
    let
      baseFiles = {
        ".claude/CLAUDE.md".source = ./AGENTS.md;
        ".codex/AGENTS.md".source = ./AGENTS.md;
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
          media = { videoMode = "auto"; };
        };
      };
      skillTargets =
        localSkillTargets
        ++ [
          { name = "summarize"; source = "${inputs.nix-steipete-tools}/tools/summarize/skills/summarize"; }
          { name = "openhue"; source = ./openhue; }
        ];
      mkSkillEntry = base: skill: {
        name = "${base}/${skill.name}";
        value = {
          source = skill.source;
          recursive = skill.recursive or false;
        };
      };
    in
    baseFiles
    // builtins.listToAttrs (
      builtins.concatMap
        (skill: map (base: mkSkillEntry base skill) (skill.bases or skillBaseProfiles.all))
        skillTargets
    );

  # Pi config files are copied, not symlinked, so /settings and /reload workflows can write to them.
  # Source of truth stays in modules/ai/pi; make local overwrites generated copies after backing up drift.
  home.activation.installPiAgentConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
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
  '';

}
