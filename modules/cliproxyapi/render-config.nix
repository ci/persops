{ pkgs }:

pkgs.writeShellApplication {
  name = "cliproxyapi-render-config";
  runtimeInputs = with pkgs; [
    coreutils
    openssl
  ];
  text = ''
    auth_dir="$HOME/.cli-proxy-api"
    api_key_path="$auth_dir/api-key"
    config_path="$auth_dir/config.yaml"

    umask 077
    install -d -m 0700 "$auth_dir"
    if [ ! -s "$api_key_path" ]; then
      openssl rand -hex 32 >"$api_key_path"
    fi
    chmod 0600 "$api_key_path"

    IFS= read -r api_key <"$api_key_path"
    tmp_config="$(mktemp "$auth_dir/config.yaml.XXXXXX")"
    trap 'rm -f "$tmp_config"' EXIT
    while IFS= read -r line || [ -n "$line" ]; do
      if [ "$line" = '  - "@API_KEY@"' ]; then
        printf '  - "%s"\n' "$api_key"
      else
        printf '%s\n' "$line"
      fi
    done <${./config.yaml} >"$tmp_config"
    chmod 0600 "$tmp_config"
    mv -f "$tmp_config" "$config_path"
    trap - EXIT
  '';
}
