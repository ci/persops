set -euo pipefail

umask 077

identity="${PHEME_SSH_IDENTITY}"
known_hosts="${PHEME_KNOWN_HOSTS}"
host="${PHEME_SSH_HOST}"
user="${PHEME_SSH_USER}"
remote_dir="${PHEME_MATRIX_DIR}"
dest="${PHEME_ARCHIVE_DIR}"
keep_dumps="${PHEME_KEEP_DUMPS}"
ssh_bin="${PHEME_SSH_BIN:-ssh}"
rsync_bin="${PHEME_RSYNC_BIN:-rsync}"
date_bin="${PHEME_DATE_BIN:-date}"
install_bin="${PHEME_INSTALL_BIN:-install}"
find_bin="${PHEME_FIND_BIN:-find}"
ln_bin="${PHEME_LN_BIN:-ln}"
chmod_bin="${PHEME_CHMOD_BIN:-chmod}"
mv_bin="${PHEME_MV_BIN:-mv}"
rm_bin="${PHEME_RM_BIN:-rm}"
mktemp_bin="${PHEME_MKTEMP_BIN:-mktemp}"
wc_bin="${PHEME_WC_BIN:-wc}"

ssh_base=(
  "${ssh_bin}"
  -o BatchMode=yes
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=yes
  -o GlobalKnownHostsFile=/dev/null
  -o UserKnownHostsFile="${known_hosts}"
  -o ConnectTimeout=10
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=6
  -i "${identity}"
  -l "${user}"
)

ssh_cmd() {
  "${ssh_base[@]}" "${host}" "$@"
}

# Distinguish a missing remote path (test exits 1) from SSH/transport failure.
remote_dir_exists() {
  local path="$1"
  local rc=0
  ssh_cmd "test -d $(printf '%q' "${path}")" || rc=$?
  if [ "$rc" -eq 0 ]; then
    return 0
  fi
  if [ "$rc" -eq 1 ]; then
    return 1
  fi
  echo "pheme-matrix-archive: ssh failed probing ${path} (rc=${rc})" >&2
  exit "${rc}"
}

rsync_ssh() {
  # rsync -e takes a single shell string; keep identity/host options explicit.
  printf '%s -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=%q -o ConnectTimeout=10 -i %q -l %q' \
    "${ssh_bin}" "${known_hosts}" "${identity}" "${user}"
}

if [ ! -r "${identity}" ]; then
  echo "pheme-matrix-archive: missing SSH identity ${identity}" >&2
  exit 1
fi
if [ ! -r "${known_hosts}" ]; then
  echo "pheme-matrix-archive: missing known_hosts ${known_hosts}" >&2
  exit 1
fi

if [ ! -d "$(dirname "${dest}")" ]; then
  echo "pheme-matrix-archive: parent of ${dest} is missing" >&2
  exit 1
fi

"${install_bin}" -d -m 0750 "${dest}" "${dest}/dumps"

stamp="$("${date_bin}" -u +%Y%m%dT%H%M%SZ)"
dump_path="${dest}/dumps/synapse-${stamp}.dump"
staging="$("${mktemp_bin}" -d "${dest}/.staging.XXXXXX")"
cleanup() {
  "${rm_bin}" -rf "${staging}"
}
trap cleanup EXIT

echo "pheme-matrix-archive: dumping postgres on ${host}"
ssh_cmd "cd $(printf '%q' "${remote_dir}") && sudo -n docker compose exec -T db pg_dump -U synapse -Fc --exclude-table-data=e2e_one_time_keys_json synapse" \
  >"${staging}/synapse.dump"

if [ ! -s "${staging}/synapse.dump" ]; then
  echo "pheme-matrix-archive: empty postgres dump" >&2
  exit 1
fi

echo "pheme-matrix-archive: copying config"
"${install_bin}" -d -m 0750 "${staging}/config" "${staging}/media" "${staging}/media/local_content" "${staging}/media/local_thumbnails"
"${rsync_bin}" -a --chmod=D0750,F0600 -e "$(rsync_ssh)" \
  "${host}:${remote_dir}/docker-compose.yml" \
  "${host}:${remote_dir}/.env" \
  "${host}:${remote_dir}/caddy/Caddyfile" \
  "${host}:${remote_dir}/coturn/turnserver.conf" \
  "${host}:${remote_dir}/synapse/homeserver.yaml" \
  "${host}:${remote_dir}/synapse/ca7.ir.signing.key" \
  "${host}:${remote_dir}/synapse/ca7.ir.log.config" \
  "${staging}/config/"

echo "pheme-matrix-archive: copying local media"
if remote_dir_exists "${remote_dir}/synapse/media_store/local_content"; then
  "${rsync_bin}" -a --delete --chmod=D0750,F0600 -e "$(rsync_ssh)" \
    "${host}:${remote_dir}/synapse/media_store/local_content/" \
    "${staging}/media/local_content/"
fi
if remote_dir_exists "${remote_dir}/synapse/media_store/local_thumbnails"; then
  "${rsync_bin}" -a --delete --chmod=D0750,F0600 -e "$(rsync_ssh)" \
    "${host}:${remote_dir}/synapse/media_store/local_thumbnails/" \
    "${staging}/media/local_thumbnails/"
fi

"${chmod_bin}" 0600 "${staging}/synapse.dump"
"${mv_bin}" "${staging}/synapse.dump" "${dump_path}"
"${ln_bin}" -sfn "$(basename "${dump_path}")" "${dest}/dumps/synapse-latest.dump"

if [ -e "${dest}/config" ]; then
  "${mv_bin}" "${dest}/config" "${staging}/config.prev"
fi
"${mv_bin}" "${staging}/config" "${dest}/config"

if [ -e "${dest}/media" ]; then
  "${mv_bin}" "${dest}/media" "${staging}/media.prev"
fi
"${mv_bin}" "${staging}/media" "${dest}/media"

echo "pheme-matrix-archive: pruning dumps older than ${keep_dumps} days"
"${find_bin}" "${dest}/dumps" -type f -name 'synapse-*.dump' -mtime "+${keep_dumps}" -delete

echo "pheme-matrix-archive: done ${dump_path} ($("${wc_bin}" -c <"${dump_path}") bytes)"
