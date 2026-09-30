# Oracle 19c on Apple Silicon

Oracle Database 19c (Enterprise Edition 19.19) for M1/M2/M3/M4 Macs. It runs natively in Docker, with no emulation.

## Install

Open **Terminal** and paste:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/andreiusq/oracle19c-apple-silicon/main/start.sh)"
```

The script does everything else:

1. **Docker**: installs and starts OrbStack if you don't have Docker yet.
2. **Oracle signup**: opens Oracle's page and tells you what to click. This is the only manual part and takes about 3 minutes (details below).
3. **Download and setup**: downloads Oracle 19c (3.2 GB) and creates your database, which takes about 10 minutes.
4. **Connection details**: prints what to enter in your SQL client when it's done.

### Why the Oracle signup?

Oracle only gives out 19c to people with a free Oracle account who accept its license. The download link from your professor requires this too. In the page the script opens:

1. Click **Sign In**. If you don't have an account, click **Create Account** on the sign-in page.
2. On the right, pick a language, click **Continue**, then click **Accept**.
3. Click your name (top right), go to **Auth Token**, click **Generate Secret Key**, and copy the key. Paste it into Terminal when the script asks.

## Connect

| Field    | Value                              |
|----------|------------------------------------|
| Host     | `localhost`                        |
| Port     | `1521`                             |
| Service  | `ORCLPDB1` (service name, not SID) |
| User     | `system`                           |
| Password | `Oracle19c`                        |

You can use SQL Developer (it has a macOS ARM build), the Oracle SQL Developer extension for VS Code, or DBeaver. Only your own Mac can connect, not other devices on the Wi-Fi.

## Afterwards

- The database starts on its own whenever OrbStack is running.
- `docker stop oracle19c` stops it and `docker start oracle19c` starts it again. Your data is kept.
- You can paste the install command again at any time. It skips anything that's already done.
- To delete everything: `docker rm -f oracle19c && docker volume rm oracle19c_oradata`

To use your own password, put `ORACLE_PWD=YourPass123` in front of the install command on the first install:
`ORACLE_PWD=YourPass123 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/andreiusq/oracle19c-apple-silicon/main/start.sh)"`

## If something goes wrong

- **"That email or token didn't work"**: generate a new auth token and paste it in. Don't use your account password.
- **"Almost there: accept Oracle's license"**: you're signed in but haven't clicked **Accept** yet. Follow the steps it shows.
- **The download stops partway through**: the script retries automatically. If it still fails, paste the install command again; finished parts are kept.
- **Anything else**: run `docker logs oracle19c`.
