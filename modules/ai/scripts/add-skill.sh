#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
    "Usage: modules/ai/scripts/add-skill.sh [--profile all|coding|claw] [--keep-temp] <github-source> [skills-add args...]" \
    "" \
    "Examples:" \
    "  modules/ai/scripts/add-skill.sh shadcn/ui" \
    "  modules/ai/scripts/add-skill.sh --profile coding vercel-labs/agent-skills" \
    "  modules/ai/scripts/add-skill.sh --profile claw owner/repo" \
    "  modules/ai/scripts/add-skill.sh https://github.com/vercel-labs/skills --skill find-skills" \
    "  modules/ai/scripts/add-skill.sh https://github.com/openai/skills/blob/main/skills/.curated/playwright-interactive"
}

profile="all"
keep_temp=0
source_repo=""
source_input=""
normalized_source=""
inferred_skill=""
upstream_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || {
        printf 'Missing value for %s\n' "$1" >&2
        exit 1
      }
      profile="$2"
      shift 2
      ;;
    --keep-temp)
      keep_temp=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      if [[ -n "$source_repo" ]]; then
        upstream_args+=("$@")
        break
      fi
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$source_repo" ]]; then
        upstream_args+=("$@")
        break
      fi
      source_repo="$1"
      shift
      if [[ $# -gt 0 ]]; then
        upstream_args+=("$@")
        break
      fi
      ;;
  esac
done

[[ -n "$source_repo" ]] || {
  usage >&2
  exit 1
}

source_input="$source_repo"
normalized_source="$source_repo"

if [[ "$source_repo" =~ ^https://github\.com/([^/]+/[^/]+)/(blob|tree)/[^/]+/(.+)$ ]]; then
  normalized_source="https://github.com/${BASH_REMATCH[1]}"
  source_subpath="${BASH_REMATCH[3]%/}"
  inferred_skill="$(basename "$source_subpath")"
  if [[ "$inferred_skill" == "SKILL.md" ]]; then
    inferred_skill="$(basename "$(dirname "$source_subpath")")"
  fi
fi

case "$profile" in
  all|coding|claw) ;;
  *)
    printf 'Unsupported profile: %s\n' "$profile" >&2
    exit 1
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"
ai_dir="$repo_root/modules/ai"
skills_dir="$ai_dir/skills"
overrides_file="$ai_dir/skill-overrides.json"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/persops-skill-add-XXXXXX")"

cleanup() {
  if [[ "$keep_temp" -eq 0 ]]; then
    rm -rf "$tmp_dir"
  fi
}

trap cleanup EXIT

has_upstream_flag() {
  local exact="$1"
  local prefix="$2"
  local arg
  for arg in "${upstream_args[@]}"; do
    if [[ "$arg" == "$exact" || ( -n "$prefix" && "$arg" == "$prefix"* ) ]]; then
      return 0
    fi
  done
  return 1
}

join_shell_words() {
  local out=""
  local arg quoted
  for arg in "$@"; do
    printf -v quoted '%q' "$arg"
    out+="${quoted} "
  done
  printf '%s' "${out% }"
}

update_profile_override() {
  local skill_name="$1"
  local skill_profile="$2"
  local tmp_json

  tmp_json="$(mktemp "${TMPDIR:-/tmp}/persops-skill-overrides-XXXXXX")"

  if [[ "$skill_profile" == "all" ]]; then
    jq --arg name "$skill_name" '
      del(.[$name].profile)
      | if .[$name] == {} then del(.[$name]) else . end
    ' "$overrides_file" >"$tmp_json"
  else
    jq --arg name "$skill_name" --arg profile "$skill_profile" '
      .[$name] = ((.[$name] // {}) + {profile: $profile})
    ' "$overrides_file" >"$tmp_json"
  fi

  mv "$tmp_json" "$overrides_file"
}

effective_upstream_args=()

if has_upstream_flag "--all" ""; then
  :
else
  if ! has_upstream_flag "--skill" "--skill=" && ! has_upstream_flag "-s" ""; then
    effective_upstream_args+=(--skill "${inferred_skill:-*}")
  fi
  if ! has_upstream_flag "--agent" "--agent=" && ! has_upstream_flag "-a" ""; then
    effective_upstream_args+=(--agent "*")
  fi
  if ! has_upstream_flag "--yes" "" && ! has_upstream_flag "-y" ""; then
    effective_upstream_args+=(--yes)
  fi
fi

if ! has_upstream_flag "--copy" ""; then
  effective_upstream_args+=(--copy)
fi

effective_upstream_args+=("${upstream_args[@]}")
via_command="$(join_shell_words bunx --bun skills add "$normalized_source" "${effective_upstream_args[@]}")"

(
  cd "$tmp_dir"
  bunx --bun skills add "$normalized_source" "${effective_upstream_args[@]}"
)

[[ -d "$tmp_dir/skills" ]] || {
  printf 'skills add did not create %s\n' "$tmp_dir/skills" >&2
  exit 1
}

[[ -f "$tmp_dir/skills-lock.json" ]] || {
  printf 'skills add did not create %s\n' "$tmp_dir/skills-lock.json" >&2
  exit 1
}

shopt -s nullglob
skill_paths=("$tmp_dir"/skills/*)
shopt -u nullglob

[[ ${#skill_paths[@]} -gt 0 ]] || {
  printf 'No skills found in %s\n' "$tmp_dir/skills" >&2
  exit 1
}

imported=()

for skill_path in "${skill_paths[@]}"; do
  [[ -d "$skill_path" ]] || continue

  skill_name="$(basename "$skill_path")"
  target_path="$skills_dir/$skill_name"

  [[ ! -e "$target_path" ]] || {
    printf 'Target already exists: %s\n' "$target_path" >&2
    exit 1
  }

  cp -R "$skill_path" "$target_path"

  upstream_source="$(jq -r --arg name "$skill_name" '.skills[$name].source // empty' "$tmp_dir/skills-lock.json")"
  upstream_source_type="$(jq -r --arg name "$skill_name" '.skills[$name].sourceType // empty' "$tmp_dir/skills-lock.json")"
  upstream_hash="$(jq -r --arg name "$skill_name" '.skills[$name].computedHash // empty' "$tmp_dir/skills-lock.json")"
  installed_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  {
    printf 'source = %s\n' "${upstream_source:-$source_repo}"
    printf 'source_type = %s\n' "${upstream_source_type:-unknown}"
    printf 'profile = %s\n' "$profile"
    printf 'installed_at = %s\n' "$installed_at"
    if [[ "$source_input" != "$normalized_source" ]]; then
      printf 'requested_source = %s\n' "$source_input"
    fi
    printf 'via = %s\n' "$via_command"
    if [[ -n "$upstream_hash" ]]; then
      printf 'computed_hash = %s\n' "$upstream_hash"
    fi
  } >"$target_path/UPSTREAM.txt"

  update_profile_override "$skill_name" "$profile"
  imported+=("$skill_name")
done

printf 'Imported %s skill(s): %s\n' "${#imported[@]}" "${imported[*]}"
printf 'Repo source of truth: %s\n' "$skills_dir"
if [[ "$keep_temp" -eq 1 ]]; then
  printf 'Temp dir kept: %s\n' "$tmp_dir"
fi
