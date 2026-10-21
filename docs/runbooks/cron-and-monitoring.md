# Cron and monitoring

The production cron jobs, the log files and the Sentry monitors are set up by Ansible in the [infrastructure repository](https://gitlab.com/openaustralia/infrastructure) (`roles/internal/openaustralia/tasks/main.yml`).
Change them there, not on the server.

## The scheduled jobs

All run as the `deploy` user, from `/srv/www/<stage>/current/twfy/scripts`, and **production only**: Ansible removes them for staging.
Each is wrapped in `sentry monitor run`, which reports a check-in to a Sentry cron monitor around the job. The wrapper allows a 60 minute check-in margin and a 360 minute maximum runtime.

| Job | Schedule | Does | Runbook |
|---|---|---|---|
| `dailyupdate` | Every day, 01:37 | Member links (`parse-member-links.rb`), then `mpinfoin.pl` | [Members and links](members-and-links.md) |
| `weeklyupdate` | Sundays, 04:23 | Wikipedia titles import, then `compactsearchdb`. **Currently failing**, see "Known fault" below | [Search index](search-index.md) |
| `morningupdate` | Monday to Friday, 09:05 | Parse the previous working day, index, RSS, sitemap | [Daily Hansard parse](daily-hansard-parse.md) |
| `alertmailer` | Monday to Friday, 10:00 | Send alert emails | [Alerts and email](alerts-and-email.md) |

The server's own timezone is Australia/Sydney (checked with `timedatectl`), and the Sentry monitors use the same zone, so the times above are Sydney time.
The `deploy` crontab holds exactly these four jobs and the settings above them (`SENTRY_DSN` and `MAILTO`). It has no entries for staging. `/etc/cron.d` holds only `certbot`, `e2scrub_all`, `php` and the `restic` backup.

**Not scheduled**, although older docs say otherwise: `parse-members.rb`, `postcodes.rb`, `member-images.rb` and `scripts/dumpallforbackup`. The legacy files `twfy/scripts/crontab` and `twfy/conf/crontab.ugly` are not what runs.
The repository's cron file for file backups is separate (`restic`, nightly, as root). See [Backups and restore](backups-and-restore.md).

## Where the logs are

| What | Where |
|---|---|
| Each job's **stderr** | `/srv/www/<stage>/log/<job>.log` (`dailyupdate.log`, `weeklyupdate.log`, `morningupdate.log`, `alertmailer.log`) |
| Each job's **stdout** | Not logged to a file. It is emailed to the cron `MAILTO` list through the host mail agent |
| Parser log | `/srv/www/<stage>/shared/pwdata/parser.log` (appended to). The parser's configuration names `/srv/www/<stage>/log/parser.log`, but that file does not exist on production |
| Apache | `/srv/www/<stage>/log/`: `access.log` and `error.log` (PHP errors land in `error.log`), plus `default_redirect_*`, `blog_*` and `data_*` logs for the other virtual hosts. `bot_access.log` is empty and has not been written since May |
| Data site | `/srv/www/production/log/data_*.log`. The site serves `shared/pwdata` directly, so there is no sync job to check |
| Logrotate | Daily, 30 kept, compressed, for `/srv/www/<stage>/log/*.log` |
| Shipped off the server | The Apache `error.log`, syslog and the restic log go to CloudWatch (see the infrastructure repository) |

`morningupdate` runs with `VERBOSE=true`, so its progress is in the stdout email, and `rssgenerate` runs inline. Without `VERBOSE=true` it would be queued with `at`, which is not installed on the server.
PHP's `error_log` is not set on the server (`log_errors` is on and `display_errors` is off), so PHP errors go to Apache's `error.log`. Checked on the server, where `PHP Fatal error` lines appear in it.

## How you find out something failed

- **Sentry cron monitors** raise an issue if a job misses its check-in or fails, and Sentry sends it to the team's alert channel. A newly added monitor needs its detector attached to a workflow by hand, or its failures alert nobody (`docs/monitoring.md` in the infrastructure repository explains how).
- **Sentry errors** from the PHP site and the parser (`SENTRY_DSN` in `conf/general` and the parser configuration).
- **An uptime monitor** on the home page.
- **Host alerts** from New Relic for CPU, memory, disk and a host that stops reporting.
- **The cron email**, which carries stdout.

**A job that exits 0 is not proof it worked.** The parse scripts ignore the exit status of the database load. See [Daily Hansard parse](daily-hansard-parse.md#the-database-load-can-fail-without-anyone-noticing).

`error_handler` in `twfy/www/includes/utility.php` does **not** email anyone, despite what its comment and the on-page message say. It writes to the error log. `init.php` initialises Sentry after installing the handler and says it chains to it, so warnings and uncaught exceptions probably reach Sentry when `SENTRY_DSN` is set. UNVERIFIED.

## Which exit statuses to trust

Each job's stderr log ends with a `time -v` summary that includes `Exit status`, and the Sentry monitor reports the same status. **For several jobs it cannot show a failure.**

`morningupdate`, `rssgenerate` and `compactsearchdb` re-run themselves through `scripts/run-with-lockfile`. That program returns the raw wait status of the job it runs, and the operating system keeps only its low eight bits, so **a failed job comes back as exit 0**. Only 100 (busy) and 101 (lock error) survive. This was tested by compiling the program: an inner `exit 1` and an inner `exit 3` both returned 0.

| Job | Is `Exit status` reliable? |
|---|---|
| `morningupdate` | **No.** A failed parse still logs `Exit status: 0` and reports success to Sentry. See the fault below |
| `rssgenerate` | **No**, and it has no `set -e`: its status is only that of `mprss.php`, so a `make_rss.pl` failure is hidden too |
| `compactsearchdb` | **No** for a failed compaction. If the lock is busy it exits 100 at once, without printing a message (it runs under `set -e`) |
| `weeklyupdate` | Yes for everything before its last step. A failed compaction is hidden |
| `dailyupdate` | Only partly. It has no `set -e`, so its status is that of its last command, `mpinfoin.pl`. A failure in `parse-member-links.rb` does not fail the job |
| `alertmailer` | Yes |

So "31 clean runs" of `morningupdate` in the logs proves nothing. To check the morning run, use the elapsed time, the stderr log, the data and Sentry's exceptions (below).

## Known fault: a failed `morningupdate` reports success

Observed 2026-10-21. The run on 2026-10-13 aborted in the parser with `Not an even number of people in the pairs voting` (the Senate day of 2026-10-12, issue #996). Its log shows the backtrace, an elapsed time of **18 seconds**, and `Exit status: 0`.
A normal run takes about an hour and a half, because of the search indexing. The Senate day of 2026-10-12 has no `scrapedxml` file.

How to spot a failed morning run:

- **Elapsed time.** In `morningupdate.log`, a run that finishes in seconds or a few minutes did not index.
- **The stderr log.** A Ruby backtrace from `parse-speeches.rb`.
- **The data.** A day with a **non-empty** `origxml` file and no `scrapedxml` file. About half of all `origxml` files are empty on purpose, so list only the non-empty ones: `P=/srv/www/<stage>/shared/pwdata; for h in representatives_debates senate_debates; do find $P/origxml/$h -name '*.xml' -size +0 -mtime -400 -printf '%f\n' | sed 's/.xml//' | sort | while read d; do [ -s $P/scrapedxml/$h/$d.xml ] || echo "$h $d"; done; done`. On 2026-10-21 this printed one line, `senate_debates 2026-10-12`.
- **Sentry**, which receives the parser's exception (`Configuration.report_errors`) even when the cron monitor stays green.
- **The cron email**, which carries the `ERROR While processing` line.

## Known fault: `weeklyupdate` has failed every Sunday since late July

Observed 2026-10-21. Across the retained logs, `weeklyupdate` shows `Exit status: 1` for the 13 most recent runs (since the Sunday of 26 July) and 0 for the 11 before. `dailyupdate` and `alertmailer` show 0 for all of their 30 days.

The log shows only `Command exited with non-zero status 1`, with no message, because the script stops silently. The cause and the effects are described under "Known fault" in [Search index](search-index.md): the Wikipedia titles refresh and the index compaction have both stopped.
This should have raised a Sentry cron-monitor issue every week. UNVERIFIED: whether it did, and whether anyone saw it. Check the monitor in Sentry before relying on this alert path.
To spot this kind of fault in future, check each job's last `Exit status` (`grep 'Exit status' /srv/www/<stage>/log/<job>.log*`).

## Symptom: a Sentry cron monitor failed or missed

**Diagnose (READ-ONLY)**

1. Open the Sentry issue and note the job and the time.
2. Read the end of `/srv/www/<stage>/log/<job>.log`, then the stdout email for that run.
3. Find the job's runbook in the table above.
4. Check that cron ran at all: `grep CRON /var/log/syslog | grep <job>` (root or `adm` access needed). It shows each start, for example `CRON[...] ... sentry monitor run morningupdate`.

A "missed" check-in with no error usually means the job was **already running** and skipped, or the server was down. Check `uptime` and `pgrep -fa 'morningupdate|weeklyupdate|alertmailer|dailyupdate'`.

## Symptom: `Another copy of ... is already running`

`morningupdate` and `rssgenerate` take a lock with `scripts/run-with-lockfile`. `compactsearchdb` shares `morningupdate`'s lock.

| Exit code | Meaning |
|---|---|
| 100 | Another copy holds the lock. `morningupdate` prints the message above. `compactsearchdb` exits 100 without printing anything |
| 101 | Could not get the lock for some other reason: a usage error, or a missing file |
| 0 | Success, **or a failed job** (see "Which exit statuses to trust") |

**Diagnose (READ-ONLY)** `pgrep -fa 'morningupdate|compactsearchdb'`. The lock is an `fcntl` lock, so it is released when the process exits, even after a crash. The lock file itself (`morningupdate-lockfile`) is created in `twfy/scripts` of the release that started the run, so it can be left behind and is harmless. A run started before a deploy and one started after it use different lock files.
`dailyupdate`, `weeklyupdate` and `alertmailer` take **no** lock.
If `run-with-lockfile` is missing, the deploy did not build it. See `deploy:compile_lockfile` in [Deploy and rollback](deploy-and-rollback.md).

**Fix (CHANGES PRODUCTION)** If a job is truly stuck (no progress, no CPU), stop it: `kill <pid>`. Undo: start it again by hand from the runbook for that job. Do not `kill -9` a parse or an index run unless it will not stop, because it can leave a half-written index.

## Symptom: the host is down, or slow

Follow `docs/monitoring.md` in the infrastructure repository. It has generic runbooks for "site down" and "CPU alert".
The index job can use around 1.6 GB of memory, so the server has swap (a 1 GB swap file, with about 100 MB in use when checked). Memory alerts during indexing are not necessarily a fault.
The server has two disks, `/` (61% used) and `/data` (73% used). Check `df -h` first on a disk alert.

**Escalate**: tell the on-call engineer. An outage people can see is public-facing, and the CEO signs off any status notice.
