#!/usr/bin/env bash
# One-command setup for Oracle Database 19c on Apple Silicon Macs.
# Safe to re-run: it skips whatever is already done.
set -euo pipefail
cd "$(dirname "$0")"

REGISTRY=container-registry.oracle.com
IMAGE=$REGISTRY/database/enterprise:19.19.0.0
REPO_PAGE=https://container-registry.oracle.com/ords/ocr/ba/database/enterprise
CONTAINER=oracle19c

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname -m)" = arm64 ] || fail "This setup is for Apple Silicon (M1/M2/M3/M4) Macs only."
command -v docker >/dev/null || fail "Docker isn't installed. Install OrbStack (https://orbstack.dev) or Docker Desktop first."
docker info >/dev/null 2>&1 || fail "Docker isn't running. Start OrbStack or Docker Desktop, then run ./start.sh again."

# Prints: ok | login | license
registry_access() {
  local out
  if out=$(docker manifest inspect "$IMAGE" 2>&1); then echo ok
  elif [[ $out == *denied* ]]; then echo license
  elif [[ $out == *unauthorized* ]]; then echo login
  else fail "Can't reach Oracle's registry: $out"
  fi
}

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  while true; do
    case $(registry_access) in
      ok) break ;;
      login)
        say "Log in to Oracle's container registry (one time only)"
        cat <<EOF
   1. Sign in at $REGISTRY with a free Oracle account
      (create one at https://profile.oracle.com if you don't have one).
   2. Click Database -> enterprise and accept the license terms.
   3. Click your username (top right) -> Auth Token -> Generate Secret Key. Copy it.

   Then below, enter your Oracle email as the username and paste the
   AUTH TOKEN (not your account password) as the password.
EOF
        open "$REPO_PAGE" 2>/dev/null || true
        docker login "$REGISTRY" || true
        ;;
      license)
        say "Accept Oracle's license for the 'enterprise' repository"
        echo "   Opening $REPO_PAGE"
        echo "   Sign in with the same account, accept the terms, then come back here."
        open "$REPO_PAGE" 2>/dev/null || true
        read -rp "   Press Enter once you've accepted... " _
        ;;
    esac
  done

  say "Downloading Oracle 19c (about 3.2 GB, one time only)"
  docker compose pull || fail "Download interrupted. Run ./start.sh again; finished parts are reused."
fi

say "Starting the database"
docker compose up -d

say "Waiting for the database to be ready (first run creates it: about 10 minutes)"
while true; do
  status=$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo missing)
  [ "$status" = healthy ] && break
  logs=$(docker logs "$CONTAINER" 2>&1 || true)
  [[ $logs == *"DATABASE SETUP WAS NOT SUCCESSFUL"* ]] && fail "Database setup failed. See: docker logs $CONTAINER"
  [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" = true ] \
    || fail "The container stopped. See: docker logs $CONTAINER"
  progress=$(grep -o '[0-9]*% complete' <<<"$logs" | tail -1 || true)
  printf '\r   %-20s' "${progress:-starting...}"
  sleep 10
done

password=$(grep -E '^ORACLE_PWD=' .env 2>/dev/null | cut -d= -f2- || true)
password=${password:-Oracle19c}

say "Oracle 19c is ready"
cat <<EOF

   Host      localhost
   Port      1521
   Service   ORCLPDB1   (service name, not SID)
   User      system
   Password  $password

   Quick test:  docker exec -it $CONTAINER sqlplus system/$password@ORCLPDB1
   Stop:        docker compose stop      (your data is kept)

EOF
