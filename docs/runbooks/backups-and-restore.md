# Backups and restore

**No restore has been rehearsed.** The infrastructure repository says so for the file backups, and this repository has no database restore procedure at all.
Treat every step on this page as unproven until someone has done a drill, and record the result here.

What is backed up, from the [infrastructure repository](https://gitlab.com/openaustralia/infrastructure). Its README has a Backups section, and `roles/internal/oaf.restic` and `terraform/database.tf` hold the settings.

| Data | How | Where it lives |
|---|---|---|
| The database (members, debates, alerts, users, suppressions) | Automated daily snapshots on the managed database server, plus point-in-time restore. Kept for 32 days when checked on 2026-10-21, with the newest snapshot under a day old | Not on the web server. Retention is set in `terraform/database.tf` |
| Files under `/data` on the server | `restic` backs up all of `/data` nightly at 03:00 to offsite object storage (the cron entry is in `/etc/cron.d/restic-openaustralia_data`, and the log is `/var/log/restic/openaustralia_data.log`). The 2026-10-21 run completed, saving about 14,600 files (13 GiB). Retention and an integrity check run on Sundays | `/data/<stage>/` holds `pwdata`, `images`, `search`, `html_cache`, `regmem_scan` and `alerts-lastsent`. The profile covers the whole of `/data`, so staging's directories are included |
| Code | Git (`openaustralia/openaustralia` and the submodule repositories) | GitHub |

What is **not** backed up:

- **`shared/backup/`**: `twfy/scripts/dumpallforbackup` writes `mysqldump` files there (`DBBACKUP` in `shared/general` is `/srv/www/<stage>/shared/backup/`), keeping 14 plus one per month. Checked on the server: the directory does not exist on either stage, nothing in the `deploy` crontab or `/etc/cron.d` runs the script, and `shared/backup` is not under `/data`. So there are no `mysqldump` files.
- **Archives from before December 2025**: an earlier backup tool's archives cannot be recovered (see ADR 0004 in the infrastructure repository).

Terms: [`CONTEXT.md`](../../CONTEXT.md).

## What you can rebuild instead of restoring

| Lost | How to rebuild |
|---|---|
| Debates in the database | Re-run the parse for those days. The XML is kept in `RAWDATA/scrapedxml`. See [Daily Hansard parse](daily-hansard-parse.md) |
| The Xapian index | Re-index with `index.pl ... daterange`. See [Search index](search-index.md) |
| The RSS and sitemap files | `rssgenerate` and `sitemap.rb` |
| Members | `make production-parse-members`, after checking the CSV files |
| A release | Deploy from `main` |

What you **cannot** rebuild: user accounts, alert subscriptions, comments, `email_suppressions` and `alerts-lastsent`. They exist only in the database or under `/data`.

## Restore files from restic (CHANGES PRODUCTION)

Follow the Backups section of the infrastructure repository's README. It lists the `restic snapshots`, `restic restore` and `restic mount` commands.
It needs root on the server and an environment file that holds credentials. The path and the credentials are deliberately not copied here.

1. Restore to a scratch directory, never straight over `/data`.
2. Compare the restored files with what is there.
3. Copy back only what you need. Check ownership: the `deploy` user owns the files.

Undo: keep the originals until you have confirmed the site works.

## Restore the database (CHANGES PRODUCTION)

UNVERIFIED: this has no written procedure. The shape of one is: restore a snapshot to a new database server instance and check it. Pointing the site at it is then a change in the infrastructure repository, not an edit on the server: Ansible writes `shared/general` and looks up the database host itself, so a hand edit would be reverted by the next provisioning run.
Do not overwrite the live database.
Before doing it, ask whoever manages the infrastructure repository, and write the result into this page.

## A drill worth doing

A small rehearsal would settle the unknowns above.
Restore one file from the nightly backup to a scratch directory, and restore one database snapshot to a throwaway instance, then record the steps and timings here.

**Escalate**: data loss is a public-facing incident. Tell the on-call engineer at once. The CEO signs off any notice to subscribers, and it should state only what was lost and what has been restored.
