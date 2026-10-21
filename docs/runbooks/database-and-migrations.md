# Database and migrations

The site uses MySQL 8.4 on a managed database server (RDS), not on the web server. Production and staging use separate databases on it.
The connection settings are in `twfy/conf/general` (`DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`), which is linked in from `shared`.
The database server, its users and its backups are defined in the [infrastructure repository](https://gitlab.com/openaustralia/infrastructure) (`terraform/database.tf`).

Schema changes are [Phinx](https://phinx.org/) migrations in `twfy/db/migrations/`. The current schema is also dumped to `twfy/db/schema.sql`.
Two data layers coexist in the PHP code: the old `parlDBQuery()` helpers and Eloquent models in `twfy/www/includes/Models/`.

## How migrations reach production

`cap <stage> deploy` runs `vendor/bin/phinx migrate -c phinx.php` inside `releases/<timestamp>/twfy` after `composer:install` and **before the `current` symlink flips**.
Nothing else runs migrations. `phinx.php` reads the `DB_*` settings from `conf/general`, and environment variables of the same names override them. `DB_HOST` may be `host:port`.

Consequences:

- A migration that fails aborts the deploy. The old release stays live, but the migration may have partly run.
- A migration that succeeds, followed by a failing later step, leaves the database ahead of the live code.
- A rollback of the code (see [Deploy and rollback](deploy-and-rollback.md)) does not undo any migration.

## Symptom: `deploy:migrate` fails

**Diagnose (READ-ONLY)**

1. Read the Phinx error in the deploy output. Note the migration version (a 14-digit timestamp).
2. On the server, as `deploy`, run `vendor/bin/phinx status -c phinx.php` from the new release's `twfy` directory under `releases/`. It shows which migrations ran. (`current` is still the old release if the deploy aborted.)
   For the live release: `sudo -u deploy bash -c 'cd /srv/www/production/current/twfy && vendor/bin/phinx status -c phinx.php'`. This works on the server and is read-only.
3. Compare the database with what the migration was trying to do (`SHOW CREATE TABLE ...`). If the migration changed some of it, work out what.

**Fix (CHANGES PRODUCTION)**

- If the migration failed before changing anything, fix it in `twfy`, merge, bump the pointer here, and deploy again.
- If it partly ran, do not run it again blindly. Fix by hand to the state the migration expects, or write a new migration that tolerates both states. Ask the on-call engineer before touching production data.
- To step back one migration (only if the migration has a working `down`), run `vendor/bin/phinx rollback -c phinx.php`, and add `-t <version>` for a specific target.
  Check `status` afterwards. Undo: `vendor/bin/phinx migrate -c phinx.php`.

**Escalate**: tell the on-call engineer before changing a production table. If people cannot use the site while this is open, the CEO decides whether to post a notice and signs off the wording.

## Symptom: CI `schema-check` fails

The twfy `schema-check` job starts a fresh `mysql:8.4`, applies every migration, dumps the result and compares it with `db/schema.sql`. Any drift fails it.

- Cause 1: a migration was added but `db/schema.sql` was not updated. `make docker-db-migrate` in `twfy` runs the migrations and dumps the schema in one step. Commit both.
- Cause 2: a different MySQL version formats the dump differently. Use 8.4.

## Do not import `db/schema.sql` into an existing database

It is for a fresh install. For an existing database, mark the first migration as already applied instead: insert a row into `phinxlog` for version `20260530000000`, name `InitialSchema`.
`twfy/INSTALL.txt` has the exact statement. Most of that file is out of date, but its Phinx section is current.

## Backups

The database server (MySQL 8.4, with a standby in a second zone) takes automated snapshots, keeps them for 32 days and supports point-in-time restore. That was the setting when checked on 2026-10-21. It is set in `terraform/database.tf` in the infrastructure repository.
`scripts/dumpallforbackup` in `twfy` is not scheduled on the server. See [Backups and restore](backups-and-restore.md).

## Local development

`twfy/README.md` is the guide for working on the web application. The short version, from `twfy/`:

```
make dependencies
make docker
make docker-db-migrate     # applies migrations and dumps db/schema.sql
make docker-db-seed
make docker-run
```

`make docker-db-migrate-down` rolls back one migration (or to `MIGRATION_TARGET`) and dumps the schema.
Tests run against `test_twfy`. `make docker-test-db-create` and `make docker-test-db-migrate` set it up.
`twfy/README.md` mentions `make test-docker` and `make lint-ci`, which do not exist. Use `make test-coverage-docker`, and `make lint-php-ci` or `make lint-perl-ci`.

## Known gaps

- To open a database session from the server, use the `mysql` client (installed) with the `DB_*` values in `shared/general`. The `deploy` user can read that file, and Phinx already uses it. Take care: it is the live read-write account. UNVERIFIED: whether a read-only account exists for people, rather than for Metabase.
- There is no seeder for production data. Seeders are for development.
