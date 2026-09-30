#!/usr/bin/env bash
# Oracle Database 19c on Apple Silicon Macs. One command, safe to re-run:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/andreiusq/oracle19c-apple-silicon/main/start.sh)"
set -euo pipefail

REGISTRY=container-registry.oracle.com
IMAGE=$REGISTRY/database/enterprise:19.19.0.0
LICENSE_PAGE=https://container-registry.oracle.com/ords/ocr/ba/database/enterprise
CONTAINER=oracle19c
VOLUME=oracle19c_oradata

say()   { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
fail()  { printf '\n\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }
pause() { read -rp "   Press Enter when done... " _ </dev/tty; }

[ "$(uname -m)" = arm64 ] || fail "This is for Apple Silicon (M1/M2/M3/M4) Macs only."

# --- Docker -----------------------------------------------------------------
export PATH="$PATH:$HOME/.orbstack/bin:/Applications/Docker.app/Contents/Resources/bin"

if ! command -v docker >/dev/null && [ ! -d /Applications/OrbStack.app ] && [ ! -d /Applications/Docker.app ]; then
  say "Installing OrbStack (runs Docker on your Mac)"
  if command -v brew >/dev/null; then
    brew install --cask orbstack
  else
    echo "   Opening https://orbstack.dev. Download it and drag it into Applications."
    open https://orbstack.dev
    pause
  fi
fi

if ! docker info >/dev/null 2>&1; then
  say "Starting Docker"
  if [ -d /Applications/OrbStack.app ]; then open -a OrbStack; elif [ -d /Applications/Docker.app ]; then open -a Docker; fi
  echo "   If a welcome window appears, click through it. Waiting..."
  for _ in $(seq 100); do docker info >/dev/null 2>&1 && break; sleep 3; done
  docker info >/dev/null 2>&1 || fail "Docker didn't start. Open OrbStack yourself, then run this again."
fi

# --- Oracle login (one time) --------------------------------------------------
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
  shown_steps=false
  while true; do
    case $(registry_access) in
      ok) break ;;
      login)
        if ! $shown_steps; then
          say "One-time Oracle setup (about 3 minutes)"
          cat <<EOF
   Oracle only gives out 19c to people with a free Oracle account.
   I'm opening the page you need.

   Step 1 of 2: click "Sign In" (top right).
                No account? Click "Create Account" on the sign-in page.
                Once signed in, on the right side choose a language,
                click "Continue", then "Accept".

   Step 2 of 2: click your name (top right) -> "Auth Token"
                -> "Generate Secret Key", and copy the key.
EOF
          open "$LICENSE_PAGE"
          shown_steps=true
        fi
        echo
        read -rp  "   Your Oracle account email: " email </dev/tty
        read -rsp "   Paste the auth token (it stays hidden): " token </dev/tty; echo
        printf '%s' "$token" | docker login "$REGISTRY" -u "$email" --password-stdin >/dev/null 2>&1 \
          || echo "   That email or token didn't work. Try again (generate a new token if needed)."
        ;;
      license)
        say "Almost there: accept Oracle's license"
        echo "   On the page I just opened, sign in with the same account,"
        echo "   choose a language on the right, click \"Continue\", then \"Accept\"."
        open "$LICENSE_PAGE"
        pause
        ;;
    esac
  done

  say "Downloading Oracle 19c (3.2 GB, one time only)"
  for attempt in 1 2 3 4 5; do
    docker pull "$IMAGE" && break
    [ "$attempt" = 5 ] && fail "Download keeps failing. Check your internet, then run this again."
    echo "   Download interrupted. Retrying (finished parts are kept)..."
    sleep 5
  done
fi

# --- Database -----------------------------------------------------------------
if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
  say "Starting the database"
  docker start "$CONTAINER" >/dev/null
else
  say "Creating the database (one time only, about 10 minutes)"
  docker run -d --name "$CONTAINER" --restart unless-stopped \
    -p 127.0.0.1:1521:1521 -p 127.0.0.1:5500:5500 \
    -e ORACLE_SID=ORCLCDB -e ORACLE_PDB=ORCLPDB1 \
    -e ORACLE_PWD="${ORACLE_PWD:-Oracle19c}" -e ORACLE_CHARACTERSET=AL32UTF8 \
    -v "$VOLUME":/opt/oracle/oradata \
    "$IMAGE" >/dev/null
fi

while true; do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER")" = healthy ] && break
  logs=$(docker logs "$CONTAINER" 2>&1 || true)
  [[ $logs == *"DATABASE SETUP WAS NOT SUCCESSFUL"* ]] && fail "Database setup failed. See: docker logs $CONTAINER"
  [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" = true ] || fail "The database stopped. See: docker logs $CONTAINER"
  progress=$(grep -o '[0-9]*% complete' <<<"$logs" | tail -1 || true)
  printf '\r   %-20s' "${progress:-starting...}"
  sleep 10
done

password=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$CONTAINER" | sed -n 's/^ORACLE_PWD=//p')

say "Oracle 19c is ready"
cat <<EOF

   Host      localhost
   Port      1521
   Service   ORCLPDB1   (service name, not SID)
   User      system
   Password  $password

   It starts on its own whenever OrbStack is running.
   Stop / start:  docker stop $CONTAINER   /   docker start $CONTAINER

EOF
