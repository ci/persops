#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define ARRAY_LEN(x) (int)(sizeof(x) / sizeof((x)[0]))

// Native wrapper to avoid shell-based launchd jobs and FDA prompts for /bin/bash.
static int file_exists(const char *path) {
  return access(path, R_OK) == 0;
}

static char *trim_whitespace(char *s) {
  char *end;
  while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') {
    s++;
  }
  if (*s == 0) {
    return s;
  }
  end = s + strlen(s) - 1;
  while (end > s && (*end == ' ' || *end == '\t' || *end == '\n' || *end == '\r')) {
    *end = 0;
    end--;
  }
  return s;
}

static char *read_trimmed(const char *path) {
  FILE *fp = fopen(path, "r");
  if (!fp) {
    return NULL;
  }
  char *line = NULL;
  size_t cap = 0;
  ssize_t n = getline(&line, &cap, fp);
  fclose(fp);
  if (n < 0) {
    free(line);
    return NULL;
  }
  char *trimmed = trim_whitespace(line);
  char *out = strdup(trimmed);
  free(line);
  return out;
}

static int load_env(const char *path) {
  FILE *fp = fopen(path, "r");
  if (!fp) {
    return -1;
  }
  char *line = NULL;
  size_t cap = 0;
  while (getline(&line, &cap, fp) >= 0) {
    char *cur = trim_whitespace(line);
    if (*cur == 0 || *cur == '#') {
      continue;
    }
    if (strncmp(cur, "export ", 7) == 0) {
      cur += 7;
      cur = trim_whitespace(cur);
    }
    int in_single = 0;
    int in_double = 0;
    for (char *p = cur; *p; p++) {
      if (*p == '\'' && !in_double) {
        in_single = !in_single;
        continue;
      }
      if (*p == '"' && !in_single) {
        in_double = !in_double;
        continue;
      }
      if (*p == '#' && !in_single && !in_double) {
        *p = 0;
        break;
      }
    }
    cur = trim_whitespace(cur);
    if (*cur == 0) {
      continue;
    }
    char *eq = strchr(cur, '=');
    if (!eq) {
      continue;
    }
    *eq = 0;
    char *key = trim_whitespace(cur);
    char *val = trim_whitespace(eq + 1);
    size_t len = strlen(val);
    if (len >= 2 && ((val[0] == '"' && val[len - 1] == '"') || (val[0] == '\'' && val[len - 1] == '\''))) {
      val[len - 1] = 0;
      val++;
    }
    if (*key == 0) {
      continue;
    }
    if (setenv(key, val, 1) != 0) {
      fclose(fp);
      free(line);
      return -1;
    }
  }
  fclose(fp);
  free(line);
  return 0;
}

static char *join_path(const char *home, const char *suffix) {
  size_t len = strlen(home) + 1 + strlen(suffix) + 1;
  char *out = malloc(len);
  if (!out) {
    return NULL;
  }
  snprintf(out, len, "%s/%s", home, suffix);
  return out;
}

static const char *basename_const(const char *path) {
  const char *slash = strrchr(path, '/');
  return slash ? slash + 1 : path;
}

typedef enum {
  MODE_UNKNOWN = 0,
  MODE_BACKUP,
  MODE_PRUNE,
  MODE_CHECK,
} restic_mode_t;

static restic_mode_t detect_mode(int argc, char **argv, int *arg_start) {
  const char *name = basename_const(argv[0]);
  if (strcmp(name, "restic-backup") == 0) {
    *arg_start = 1;
    return MODE_BACKUP;
  }
  if (strcmp(name, "restic-prune") == 0) {
    *arg_start = 1;
    return MODE_PRUNE;
  }
  if (strcmp(name, "restic-check") == 0) {
    *arg_start = 1;
    return MODE_CHECK;
  }
  if (argc > 1) {
    if (strcmp(argv[1], "backup") == 0) {
      *arg_start = 2;
      return MODE_BACKUP;
    }
    if (strcmp(argv[1], "prune") == 0) {
      *arg_start = 2;
      return MODE_PRUNE;
    }
    if (strcmp(argv[1], "check") == 0) {
      *arg_start = 2;
      return MODE_CHECK;
    }
  }
  return MODE_UNKNOWN;
}

static void add_arg(char **args, int *idx, const char *value) {
  args[(*idx)++] = (char *)value;
}

static void add_exclude(char **args, int *idx, const char *home, const char *suffix) {
  char *path = join_path(home, suffix);
  if (!path) {
    fprintf(stderr, "Failed to allocate exclude path for %s\n", suffix);
    exit(1);
  }
  add_arg(args, idx, "--exclude");
  add_arg(args, idx, path);
}

int main(int argc, char **argv) {
  const char *home = getenv("HOME");
  if (!home || *home == 0) {
    fprintf(stderr, "HOME is not set\n");
    return 1;
  }

  char env_path[PATH_MAX];
  char password_path[PATH_MAX];
  char repo_path[PATH_MAX];
  char restic_path[PATH_MAX];

  snprintf(env_path, sizeof(env_path), "%s/.config/restic/s3.env", home);
  snprintf(password_path, sizeof(password_path), "%s/.config/restic/password", home);
  snprintf(repo_path, sizeof(repo_path), "%s/.config/restic/repository", home);

  if (!file_exists(env_path)) {
    fprintf(stderr, "Missing %s\n", env_path);
    return 1;
  }
  if (!file_exists(password_path)) {
    fprintf(stderr, "Missing %s\n", password_path);
    return 1;
  }
  if (!file_exists(repo_path)) {
    fprintf(stderr, "Missing %s\n", repo_path);
    return 1;
  }

  if (load_env(env_path) != 0) {
    fprintf(stderr, "Failed loading %s\n", env_path);
    return 1;
  }

  char *repo = read_trimmed(repo_path);
  if (!repo || *repo == 0) {
    fprintf(stderr, "Empty repository in %s\n", repo_path);
    free(repo);
    return 1;
  }

  const char *restic_bin_env = getenv("RESTIC_BIN");
  if (restic_bin_env && *restic_bin_env) {
    snprintf(restic_path, sizeof(restic_path), "%s", restic_bin_env);
  } else {
    snprintf(restic_path, sizeof(restic_path), "%s/.local/libexec/restic", home);
  }

  if (access(restic_path, X_OK) != 0) {
    fprintf(stderr, "Missing restic binary at %s\n", restic_path);
    free(repo);
    return 1;
  }

  int arg_start = 1;
  restic_mode_t mode = detect_mode(argc, argv, &arg_start);
  if (mode == MODE_UNKNOWN) {
    fprintf(stderr, "Usage: restic-backup|restic-prune|restic-check [args...]\n");
    fprintf(stderr, "   or: restic-wrapper backup|prune|check [args...]\n");
    free(repo);
    return 1;
  }

  const char *host_env = getenv("RESTIC_HOST");
  const char *tag_env = getenv("RESTIC_TAG");
  char host_buf[256];
  const char *host = host_env && *host_env ? host_env : host_buf;
  const char *tag = tag_env && *tag_env ? tag_env : host;
  if (host == host_buf) {
    if (gethostname(host_buf, sizeof(host_buf)) != 0) {
      snprintf(host_buf, sizeof(host_buf), "unknown");
    } else {
      host_buf[sizeof(host_buf) - 1] = 0;
      char *dot = strchr(host_buf, '.');
      if (dot) {
        *dot = 0;
      }
    }
    if (!tag_env || !*tag_env) {
      tag = host_buf;
    }
  }

  char *args[256];
  int idx = 0;
  add_arg(args, &idx, restic_path);
  add_arg(args, &idx, "--repo");
  add_arg(args, &idx, repo);
  add_arg(args, &idx, "--password-file");
  add_arg(args, &idx, password_path);

  if (mode == MODE_BACKUP) {
    add_arg(args, &idx, "backup");
    add_arg(args, &idx, "--host");
    add_arg(args, &idx, host);
    add_arg(args, &idx, "--tag");
    add_arg(args, &idx, tag);
    add_arg(args, &idx, "--exclude-caches");
    add_arg(args, &idx, "--exclude-if-present");
    add_arg(args, &idx, ".nobackup");
    add_arg(args, &idx, "--one-file-system");
    add_arg(args, &idx, "--compression");
    add_arg(args, &idx, "auto");

    const char *excludes[] = {
      "Library/Caches",
      "Library/Logs",
      "Library/Group Containers",
      "Library/Containers/*/Data/Library/Caches",
      "Library/CloudStorage",
      "Library/Mobile Documents",
      "Library/Application Support/Spotify/PersistentCache",
      "Library/Application Support/FileProvider",
      "Library/Google/GoogleSoftwareUpdate",
      "Library/Developer/Xcode",
      "Library/Android",
      "Documents/Adobe",
      "Documents",
      "Desktop",
      ".BurpSuite",
      ".android",
      ".asdf",
      ".bun",
      ".cache",
      ".Trash",
      ".local/share/mise",
      ".local/share/nvim",
      ".dartServer",
      ".rustup/toolchains",
      ".tldrc",
      ".vscode-insiders",
      ".windsurf",
      "p/foss",
      "**/node_modules",
    };

    for (int i = 0; i < ARRAY_LEN(excludes); i++) {
      add_exclude(args, &idx, home, excludes[i]);
    }

    for (int i = arg_start; i < argc; i++) {
      add_arg(args, &idx, argv[i]);
    }

    add_arg(args, &idx, home);
  } else if (mode == MODE_PRUNE) {
    add_arg(args, &idx, "forget");
    add_arg(args, &idx, "--prune");
    add_arg(args, &idx, "--host");
    add_arg(args, &idx, host);
    add_arg(args, &idx, "--keep-hourly");
    add_arg(args, &idx, "24");
    add_arg(args, &idx, "--keep-daily");
    add_arg(args, &idx, "30");
    add_arg(args, &idx, "--keep-weekly");
    add_arg(args, &idx, "8");
    add_arg(args, &idx, "--keep-monthly");
    add_arg(args, &idx, "12");

    for (int i = arg_start; i < argc; i++) {
      add_arg(args, &idx, argv[i]);
    }
  } else if (mode == MODE_CHECK) {
    add_arg(args, &idx, "check");
    add_arg(args, &idx, "--read-data-subset=5%");

    for (int i = arg_start; i < argc; i++) {
      add_arg(args, &idx, argv[i]);
    }
  }

  args[idx] = NULL;
  execv(restic_path, args);

  fprintf(stderr, "Failed to exec %s: %s\n", restic_path, strerror(errno));
  free(repo);
  return 1;
}
