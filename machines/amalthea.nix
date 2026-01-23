{ pkgs, ... }:

let
  parakeetModel = "nvidia/parakeet-tdt-0.6b-v3";
  cudaPkgs = pkgs.cudaPackages_12.overrideScope (final: prev: {
    cuda_compat = pkgs.stdenvNoCC.mkDerivation {
      pname = "cuda_compat";
      version = "disabled";
      dontUnpack = true;
      dontBuild = true;
      installPhase = "mkdir -p $out";
      meta = (prev.cuda_compat.meta or { }) // { available = false; };
    };
  });
  transcribe = pkgs.writeShellScriptBin "transcribe" ''
    set -euo pipefail

    export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib:${pkgs.stdenv.cc.cc.lib}/lib''${LD_LIBRARY_PATH:+:''${LD_LIBRARY_PATH}}"

    venv_root="''${PARAKEET_VENV:-''${XDG_DATA_HOME:-$HOME/.local/share}/parakeet-venv-py312}"
    python_bin="$venv_root/bin/python"
    needs_install=0

    if [ ! -x "$python_bin" ]; then
      mkdir -p "$venv_root"
      ${pkgs.uv}/bin/uv venv "$venv_root" --python ${pkgs.python312}/bin/python
      needs_install=1
    fi

    if [ "$needs_install" -eq 0 ]; then
      if ! "$python_bin" - <<'PY' >/dev/null 2>&1
import torch  # noqa: F401
import nemo.collections.asr  # noqa: F401
PY
      then
        needs_install=1
      fi
    fi

    if [ "$needs_install" -eq 1 ]; then
      ${pkgs.uv}/bin/uv pip install --python "$python_bin" --index-url https://download.pytorch.org/whl/cu121 torch torchaudio
      ${pkgs.uv}/bin/uv pip install --python "$python_bin" 'nemo_toolkit[asr]'
    fi

    exec "$python_bin" - "$@" <<'PY'
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

os.environ.setdefault("NEMO_LOG_LEVEL", "ERROR")
os.environ.setdefault("TRANSFORMERS_VERBOSITY", "error")
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
os.environ.setdefault("PYTHONWARNINGS", "ignore")

quiet = os.environ.get("PARAKEET_QUIET", "1") != "0"
if quiet:
    class StreamFilter:
        def __init__(self, underlying):
            self._underlying = underlying
            self._suppress_block = False

        def write(self, data):
            if not data:
                return
            for line in data.splitlines(True):
                if self._suppress_block:
                    if line.strip() == "":
                        self._suppress_block = False
                    continue
                if line.startswith("[NeMo"):
                    continue
                if line.startswith("OneLogger:") or line.startswith("No exporters were provided."):
                    continue
                if line.strip().startswith("Train config") or line.strip().startswith("Validation config"):
                    self._suppress_block = True
                    continue
                if line.lstrip().startswith("Loss tdt_kwargs"):
                    continue
                if "Transcribing:" in line:
                    continue
                self._underlying.write(line)

        def flush(self):
            self._underlying.flush()

    sys.stderr = StreamFilter(sys.stderr)
    sys.__stderr__ = sys.stderr
    sys.stdout = StreamFilter(sys.stdout)
    sys.__stdout__ = sys.stdout

import logging
import torch
import nemo.collections.asr as nemo_asr
try:
    import nemo.utils.logging as nemo_logging
except Exception:  # pragma: no cover - optional
    nemo_logging = None

logging.getLogger().setLevel(logging.ERROR)
if nemo_logging is not None:
    try:
        nemo_logging.set_verbosity(logging.ERROR)
    except Exception:
        pass


def convert_audio(input_path: str) -> str:
    tmpdir = tempfile.mkdtemp(prefix="parakeet-")
    output_path = os.path.join(tmpdir, "audio.wav")
    cmd = [
        "ffmpeg",
        "-nostdin",
        "-y",
        "-i",
        input_path,
        "-ac",
        "1",
        "-ar",
        "16000",
        "-f",
        "wav",
        output_path,
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return output_path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Transcribe audio with NVIDIA Parakeet (NeMo)."
    )
    parser.add_argument("input", help="Path to audio file (.ogg/.wav/etc).")
    parser.add_argument(
        "--model",
        default=os.environ.get("PARAKEET_MODEL", "${parakeetModel}"),
        help="NeMo/HF model name or .nemo path.",
    )
    parser.add_argument(
        "--device",
        default="auto",
        choices=["auto", "cpu", "cuda"],
        help="Device to run on.",
    )
    parser.add_argument(
        "--output",
        help="Write transcript to file instead of stdout.",
    )
    args = parser.parse_args()

    if args.device == "auto":
        device = "cuda" if torch.cuda.is_available() else "cpu"
    else:
        device = args.device

    wav_path = None
    try:
        wav_path = convert_audio(args.input)
        model = nemo_asr.models.ASRModel.from_pretrained(model_name=args.model)
        if device != "cpu":
            model = model.to(device)
        texts = model.transcribe([wav_path], batch_size=1)
        if isinstance(texts, tuple):
            texts = texts[0]
        if isinstance(texts, list) and texts and isinstance(texts[0], list):
            texts = texts[0]
        if texts:
            item = texts[0]
            if isinstance(item, str):
                transcript = item
            elif hasattr(item, "text"):
                transcript = item.text
            elif isinstance(item, dict) and "text" in item:
                transcript = item["text"]
            else:
                transcript = str(item)
        else:
            transcript = ""
        if args.output:
            with open(args.output, "w", encoding="utf-8") as handle:
                handle.write(transcript)
                handle.write("\n")
        else:
            sys.stdout.write(transcript + "\n")
    finally:
        if wav_path:
            shutil.rmtree(os.path.dirname(wav_path), ignore_errors=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
  '';
in

{
  imports = [
    ./hardware/amalthea.nix
    ../modules/specialization/i3.nix
    ../modules/backup/restic-nixos.nix
  ];

  nix = {
    package = pkgs.nixVersions.latest;

    settings = {
      # We need to enable flakes
      experimental-features = "nix-command flakes";
      substituters = [
        "https://cache.nixos-cuda.org"
      ];
      trusted-public-keys = [
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      ];
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnsupportedSystem = true;
    cudaForwardCompat = false;
  };

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    kernelPackages = pkgs.linuxPackages_latest;
    # Ensure stage1 brings up networking even though NetworkManager
    # disables networking.useDHCP in stage2.
    kernelParams = [
      "ip=192.168.42.231::192.168.42.1:255.255.255.0:amalthea:enp2s0:none"
    ];

    # Remote unlock over SSH in initrd. Keep this out of the generated
    # hardware file so it doesn't get clobbered.
    initrd = {
      verbose = true;
      # Realtek RTL8125 (enp2s0) needs r8169 in stage1 for networking/SSH.
      availableKernelModules = [ "r8169" ];
      kernelModules = [ "r8169" ];

      network = {
        enable = true;

        ssh = {
          enable = true;
          port = 2222; # separate from normal sshd

          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFP05x9Bg50efrFPX0NXfV45RwcsYmgpKUKTnR2Ee7LA cat"
          ];

          hostKeys = [
            "/etc/secrets/initrd/ssh_host_ed25519_key"
          ];
        };

        flushBeforeStage2 = true;

        postCommands = ''
      cat > /root/.profile <<'EOF'
      echo
      echo "To unlock root, run:"
      echo "  cryptsetup luksOpen /dev/disk/by-uuid/e12696b1-da5d-4aa3-8cda-ac2f90745068 luks-e12696b1-da5d-4aa3-8cda-ac2f90745068"
      echo
      exec /bin/sh
      EOF
      '';
      };
    };
  };

  boot.blacklistedKernelModules = [ "nouveau" ];

  networking.hostName = "amalthea";
  networking.networkmanager.enable = true;
  networking.networkmanager.settings.main.no-auto-default = "enp2s0";
  networking.networkmanager.ensureProfiles.profiles = {
    enp2s0 = {
      connection = {
        id = "enp2s0";
        type = "ethernet";
        interface-name = "enp2s0";
        autoconnect = "true";
        autoconnect-priority = "100";
        permissions = "";
      };
      ipv4 = {
        method = "manual";
        address1 = "192.168.42.231/24,192.168.42.1";
        dns = "192.168.42.1;1.1.1.1";
        dns-search = "";
      };
      ipv6 = {
        method = "ignore";
      };
    };
  };

  # Enable Wake-on-LAN on the wired NIC so the machine can be woken
  # from sleep/soft-off (S3/S5) via a magic packet.
  networking.interfaces.enp2s0.wakeOnLan = {
    enable = true;
    policy = [ "magic" ];
  };

  fileSystems."/srv/timemachine" = {
    device = "/dev/disk/by-label/timemachine";
    fsType = "ext4";
    options = [
      "noatime"
      "nofail"
      "x-systemd.device-timeout=10"
    ];
  };

  users.groups.timemachine = {};
  users.users.timemachine = {
    isSystemUser = true;
    group = "timemachine";
    home = "/srv/timemachine";
  };

  systemd.tmpfiles.rules = [
    "d /srv/timemachine 0750 timemachine timemachine -"
    "d /srv/timemachine/aglaea 0750 timemachine timemachine -"
  ];

  services.samba = {
    enable = true;
    openFirewall = false;
    settings = {
      global = {
        "security" = "user";
        "min protocol" = "SMB2";
        "ea support" = "yes";
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:metadata" = "stream";
        "fruit:model" = "MacSamba";
        "fruit:nfs_aces" = "no";
        "server multi channel support" = "no";
        "smb ports" = "445";
        "disable netbios" = "yes";
        "smb3 directory leases" = "no";
        "strict rename" = "no";
        "log level" = "3";
        "keepalive" = "60";
        "deadtime" = "0";
      };

      "tm_aglaea" = {
        "path" = "/srv/timemachine/aglaea";
        "valid users" = "timemachine";
        "force user" = "timemachine";
        "browseable" = "no";
        "read only" = "no";
        "fruit:time machine" = "yes";
        "strict sync" = "yes";
        "sync always" = "no";
      };
    };
  };

  networking.firewall.enable = true;
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 445 ];
  networking.firewall.interfaces."enp2s0".allowedTCPPorts = [ 445 ];
  networking.firewall.interfaces."wlp4s0".allowedTCPPorts = [ 445 ];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
  };

  environment.systemPackages = with pkgs; [
    cudaPkgs.cudatoolkit
    cudaPkgs.cudnn
    ffmpeg
    transcribe
    python312
    uv
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
