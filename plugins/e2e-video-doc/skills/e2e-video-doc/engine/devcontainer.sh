#!/usr/bin/env bash
#
# Prints the name of the running devcontainer for a Compose service.
#
# Container names are not stable: Compose derives them from the project name, which
# differs between "Reopen in Container" and a manual `docker compose up`, and changes
# when the directory is renamed. A name hardcoded in a config or a comment goes stale
# without anyone noticing until the capture step fails.
#
# Usage:
#   bash devcontainer.sh <service> [repo-dir-name]
#   docker exec "$(bash devcontainer.sh web)" bin/rails test ...
#
# `repo-dir-name` defaults to the current repo's directory name; it disambiguates when
# several projects run a service with the same name.

set -euo pipefail

SERVICE="${1:?usage: devcontainer.sh <compose service> [repo-dir-name]}"
REPO="${2:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")}"

# Match on working_dir rather than the project name: the project name is what varies,
# the path on disk is what identifies the repo.
NAME="$(docker ps \
  --filter "label=com.docker.compose.service=$SERVICE" \
  --format '{{.Names}}	{{.Label "com.docker.compose.project.working_dir"}}' \
  | awk -F'\t' -v repo="$REPO" '$2 ~ "/" repo "(/|$)" { print $1; exit }')"

if [ -z "$NAME" ]; then
  echo "No running container for service '$SERVICE' in a project under '$REPO'." >&2
  echo "Running containers:" >&2
  docker ps --format '  {{.Names}}  ({{.Label "com.docker.compose.service"}})' >&2
  exit 1
fi

echo "$NAME"
