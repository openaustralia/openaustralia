# Cron and monitoring

The production cron jobs, the log files and the Sentry monitors are set up by Ansible in the [infrastructure repository](https://gitlab.com/openaustralia/infrastructure) (`roles/internal/openaustralia/tasks/main.yml`).
Change them there, not on the server.

## The scheduled jobs

All run as the `deploy` user, from `/srv/www/<stage>/current/twfy/scripts`, and **production only**: Ansible removes them for staging.
Each is wrapped in `sentry monitor run`, which reports a check-in to a Sentry cron monitor around the job. The wrapper allows a 60 minute check-in margin and a 360 minute maximum runtime.

| Job | Schedule | Does | Runbook |
|---|---|---|---|
| `dailyupdate` | Every day, 01:37 | Member links (`parse-member-links.rb`), then `mpinfoin.pl` | [Members and links](members-and-links.md) |
| `weeklyupdate` | Sundays, 04:23 | Wikipedia titles import, then `compactsearchdb` | [Search index](search-index.md) |
| `morningupdate` | Monday to Friday, 09:05 | Parse the previous working day, index, RSS, sitemap | [Daily Hansard parse](daily-hansard-parse.md) |
| `alertmailer` | Monday to Friday, 10:00 | Send alert emails | [Alerts and email](alerts-and-email.md) |

The Sentry monitors are defined for Australia/Sydney. UNVERIFIED: the host's own timezone, which `roles/internal/base-server` sets. Check `date` on the server before quoting a time to anyone.

**Not scheduled**, although older docs say otherwise: `parse-members.rb`, `postcodes.rb`, `member-images.rb` and `scripts/dumpallforbackup`. The legacy files `twfy/scripts/crontab` and `twfy/conf/crontab.ugly` are not what runs.
The repository's cron file for file backups is separate (`restic`, nightly, as root). See [Backups and restore](backups-and-restore.md).

## Where the logs are

| What | Where |
|---|---|
| Each job's **stderr** | `/srv/www/<stage>/log/<job>.log` (`dailyupdate.log`, `weeklyupdate.log`, `morningupdate.log`, `alertmailer.log`) |
| Each job's **stdout** | Not logged to a file. It is emailed to the cron `MAILTO` list through the host mail agent |
| Parser log | `/srv/www/<stage>/log/parser.log` (appended to) |
| Apache | `/srv/www/<stage>/log/` as `access.log`, `bot_access.log`, `internal_access.log`, `error.log` and `redirect_*.log` |
| Data site | `/srv/www/production/log/data_*.log` |
| Logrotate | Daily, 30 kept, compressed, for `/srv/www/<stage>/log/*.log` |
| Shipped off the server | The Apache `error.log`, syslog and the restic log go to CloudWatch (see the infrastructure repository) |

`morningupdate` runs with `VERBOSE=true`, so its progress is in the stdout email.
UNVERIFIED: the PHP error log path on the server. The `php_admin_value error_log` setting in the repository is only for the Docker image, so on the server it presumably falls through to Apache's `error.log`.

## How you find out something failed

- **Sentry cron monitors** raise an issue if a job misses its check-in or fails, and Sentry sends it to the team's alert channel. A newly added monitor needs its detector attached to a workflow by hand, or its failures alert nobody (`docs/monitoring.md` in the infrastructure repository explains how).
- **Sentry errors** from the PHP site and the parser (`SENTRY_DSN` in `conf/general` and the parser configuration).
- **An uptime monitor** on the home page.
- **Host alerts** from New Relic for CPU, memory, disk and a host that stops reporting.
- **The cron email**, which carries stdout.

**A job that exits 0 is not proof it worked.** The parse scripts ignore the exit status of the database load. See [Daily Hansard parse](daily-hansard-parse.md#the-database-load-can-fail-without-anyone-noticing).

`twfy/www/includes/easyparliament/utility.php`'s `error_handler` does **not** email anyone, despite what its comment and the on-page message say. It writes to the error log. UNVERIFIED: whether it forwards errors to Sentry, which is configured only when `SENTRY_DSN` is set.

## Symptom: a Sentry cron monitor failed or missed

**Diagnose (READ-ONLY)**

1. Open the Sentry issue and note the job and the time.
2. Read the end of `/srv/www/<stage>/log/<job>.log`, then the stdout email for that run.
3. Find the job's runbook in the table above.
4. Check that cron ran at all: `grep CRON /var/log/syslog | tail`. UNVERIFIED: the log location on this server image.

A "missed" check-in with no error usually means the job was **already running** and skipped, or the server was down. Check `uptime` and `pgrep -fa 'morningupdate|weeklyupdate|alertmailer|dailyupdate'`.

## Symptom: `Another copy of ... is already running`

`morningupdate` and `rssgenerate` take a lock with `scripts/run-with-lockfile`. `compactsearchdb` shares `morningupdate`'s lock.

| Exit code | Meaning |
|---|---|
| 100 | Another copy holds the lock. This is normal if a run is still going |
| 101 | Could not get the lock for some other reason: a usage error, or a missing file |

**Diagnose (READ-ONLY)** `pgrep -fa 'morningupdate|compactsearchdb'`. The lock is an `fcntl` lock, so it is released when the process exits, even after a crash. There is no stale lock file to remove.
`dailyupdate`, `weeklyupdate` and `alertmailer` take **no** lock.
If `run-with-lockfile` is missing, the deploy did not build it. See `deploy:compile_lockfile` in [Deploy and rollback](deploy-and-rollback.md).

**Fix (CHANGES PRODUCTION)** If a job is truly stuck (no progress, no CPU), stop it: `kill <pid>`. Undo: start it again by hand from the runbook for that job. Do not `kill -9` a parse or an index run unless it will not stop, because it can leave a half-written index.

## Symptom: the host is down, or slow

Follow `docs/monitoring.md` in the infrastructure repository. It has generic runbooks for "site down" and "CPU alert".
The index job can use around 1.6 GB of memory, so the server has swap. Memory alerts during indexing are not necessarily a fault.

**Escalate**: tell the on-call engineer. An outage people can see is public-facing, and the CEO signs off any status notice.
