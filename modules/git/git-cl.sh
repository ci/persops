# `git cl`: `git clone`, but public GitHub repos given as SSH URLs fetch over
# HTTPS (no SSH agent / 1Password prompt) and keep the SSH URL for pushes.
# Anything else is passed to `git clone` unchanged.

args=("$@")
origin=origin
url_idx=-1
for i in "${!args[@]}"; do
  arg=${args[$i]}
  case $arg in
    -o | --origin) origin=${args[$((i + 1))]:-origin} ;;
    --origin=*) origin=${arg#--origin=} ;;
  esac
  if ((url_idx < 0)) && [[ $arg =~ ^(ssh://)?git@github\.com[:/]([^/]+/[^/]+)$ ]]; then
    url_idx=$i
    slug=${BASH_REMATCH[2]%.git}
  fi
done

if ((url_idx >= 0)); then
  https_url="https://github.com/$slug.git"
  # Anonymous probe: only succeeds for public repos. Never prompt for creds.
  if GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=false \
    git -c credential.helper= ls-remote "$https_url" HEAD >/dev/null 2>&1; then
    ssh_url=${args[$url_idx]}
    args[url_idx]=$https_url
    echo "git cl: $slug is public; fetch over HTTPS, push over SSH" >&2
    exec git clone --config "remote.$origin.pushurl=$ssh_url" "${args[@]}"
  fi
fi

exec git clone "${args[@]}"
