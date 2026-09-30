# Oracle 19c on Apple Silicon

Runs Oracle Database 19c Enterprise Edition (19.19) natively on M1/M2/M3/M4 Macs, with no emulation. It uses Oracle's official ARM64 image.

## Quick start

You need [OrbStack](https://orbstack.dev) or Docker Desktop, installed and running.

```bash
git clone https://github.com/andreiusq/oracle19c-apple-silicon.git
cd oracle19c-apple-silicon
./start.sh
```

On the first run, the script walks you through a one-time Oracle login. Then it downloads about 3.2 GB and creates the database, which takes about 10 minutes. When it finishes, it prints your connection details. Running it again later just starts the database.

### The one-time Oracle login

Oracle requires everyone to accept its license, so each person needs their own free account. `start.sh` opens the right page and tells you what to do. In summary:

1. Create a free account at https://profile.oracle.com.
2. Sign in at https://container-registry.oracle.com, click **Database**, then **enterprise**, and accept the license terms.
3. Open your username menu (top right), go to **Auth Token**, click **Generate Secret Key**, and copy the key.
4. When the script asks, enter your Oracle email and paste the **auth token**. Don't use your account password.

## Connect

| Field    | Value                                |
|----------|--------------------------------------|
| Host     | `localhost`                          |
| Port     | `1521`                               |
| Service  | `ORCLPDB1` (service name, not SID)   |
| User     | `system` (or `sys` as SYSDBA)        |
| Password | `Oracle19c` (or your `ORACLE_PWD`)   |

Clients you can use: SQL Developer (has a macOS ARM build), the Oracle SQL Developer extension for VS Code, or DBeaver.

The database only accepts connections from your own Mac, not from other devices on the network.

## Everyday commands

```bash
./start.sh                 # start (or finish setting up)
docker compose stop        # stop; your data is kept
docker compose down -v     # delete the database and all its data
```

To use your own password, create a `.env` file next to `docker-compose.yml` containing `ORACLE_PWD=YourPass123`. Do this before the first run, because the password is only set when the database is created.

## Troubleshooting

- **`pull access denied` even after `Login Succeeded`**: you haven't accepted the license for the **enterprise** repository yet. Accept it with the same account your token came from, then run `./start.sh` again.
- **Download stops partway through**: check that OrbStack or Docker Desktop is still running, then run `./start.sh` again. Parts that already finished downloading are reused.
- **Anything else**: run `docker logs oracle19c`.

## Why the Oracle image isn't in this repo

Oracle's license lets each person download the software for their own use, but not pass it on to others. The image is also 3.4 GB, well over GitHub's file size limits. This repo only contains the setup, and each person downloads the image from Oracle.
