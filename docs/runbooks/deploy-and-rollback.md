# Deploy and rollback

Deploys use Capistrano 3 (`Capfile`, `config/deploy.rb`, `config/deploy/*.rb`).
They run from GitHub Actions or from your own machine with `make staging-deploy` and `make production-deploy`.
See the [README](../../README.md) for how to run each.

Every merge to `main` deploys to staging automatically (`.github/workflows/deploy-staging.yml`), so a merged documentation change still triggers a staging deploy.
Production is manual and needs a reviewer to approve the run.

What a deploy does, in order:

1. Finds the server by its EC2 tags and connects through AWS Session Manager.
2. `git:create_release` updates `shared/cached-copy` from GitHub (with submodules) and copies it into a new `releases/<timestamp>` directory.
3. `deploy:symlink_shared` links config, data and feeds from `shared` into the release, then `deploy:compile_lockfile` builds `twfy/scripts/run-with-lockfile` with `gcc`.
4. `composer:install`, then `deploy:migrate` (Phinx) and `deploy:npm_build_css` (`npm ci`, `npm run build:css`).
5. The `current` symlink flips to the new release, then `deploy:restart` runs `sudo /usr/sbin/apache2ctl restart`.
6. Tagging, release cleanup (keeps 5 releases) and `sentry:release`.

Note the order: **migrations run before the `current` symlink flips**. A failure in a later step leaves the database ahead of the live code.

## Symptom: the deploy fails before doing anything

**Diagnose (READ-ONLY)**

| Error or behaviour | Cause | Check |
|---|---|---|
| `Errno::ENOENT` for `openaustralia-parser/.ruby-version` on every `cap` command, even `cap -T` | The `openaustralia-parser` submodule is not initialised. `config/deploy.rb` reads its `.ruby-version` when it loads | `make init-submodules` (changes only your checkout) |
| `Unable to locate credentials`, an expired SSO session, or an SSM error | No active AWS session. Locally you need the `oaf` profile | `aws sts get-caller-identity --profile oaf` |
| No servers matched, or a deploy that does nothing | No running instance has `Application=openaustralia.org` | EC2 console, or ask whoever manages `openaustralia/infrastructure` |
| The same release lands twice | Two running instances carry the tag (for example during a server swap). Capistrano deploys to all of them | As above. The staging-branch workflow refuses more than one instance, the Make targets do not |
| `pathspec ... did not match` or `reset --hard origin/<name>` fails | `STAGING_BRANCH` or `PRODUCTION_BRANCH` is a tag or commit, not a branch. A first-time clone accepts a tag, an existing `cached-copy` does not | Use a branch name |
| Ref-lock error during `git submodule update` | A submodule branch was deleted and reused upstream. The task prunes stale refs first, so this means a different problem | Read the error, then the first block of `git:create_release` in `Capfile` |

**Escalate**: if you cannot get a session or find the server, tell the on-call engineer.

## Symptom: the deploy fails part-way through

**Diagnose (READ-ONLY)** Find the failing step in the output, then use the table.

| Failing step | Cause | Effect on the live site |
|---|---|---|
| `deploy:compile_lockfile` | `gcc` is missing on the server. UNVERIFIED: the infrastructure repository does not install it explicitly | None. The release is not live yet |
| `composer:install` | `composer` or the PHP extensions are missing, or Packagist is unreachable | None |
| `deploy:migrate` | A migration failed, or the database is unreachable | None yet. A migration that partly ran may have changed the schema. See [Database and migrations](database-and-migrations.md) |
| `deploy:npm_build_css` | Node or npm is missing, or the registry is unreachable | The migration has already run, but the old code is still live. Fix and re-deploy |
| `deploy:restart` | `deploy` cannot run `sudo /usr/sbin/apache2ctl restart` without a password (it is the only sudo rule) | **The new release is live on disk but Apache was not restarted.** Re-run the restart or the deploy |
| `sentry:release` or tagging | Sentry CLI not signed in, or `git push` of tags refused | None. Sentry failures only warn. UNVERIFIED: `capistrano-tagging3` tags `fetch(:revision)`, which the custom `git:create_release` never sets, so a tag may name your local `HEAD` and not the deployed commit |

**Fix (CHANGES PRODUCTION)** Fix the cause, then run the same deploy again. It is safe to repeat.
Check: the new release directory exists under `releases/`, `current` points at it, and the home page loads.
Undo: see "Rollback" below.

**Escalate**: if a migration partly ran, or the site shows errors after a restart, tell the on-call engineer, then the CEO if people see the site down for more than a few minutes.

## Rollback

**CHANGES PRODUCTION.** `bundle exec cap <stage> deploy:rollback` points `current` at the previous release.
`ROLLBACK_RELEASE=<timestamp>` picks a different one. Capistrano 3.20.1 runs `reverting`, `reverted`, `publishing` and `published`, so the Apache restart still fires.
`capistrano-composer` also reinstalls `vendor/` for the older release.

What rollback does **not** do:

- It does not reverse migrations. If a new migration changed the schema, the older code runs against the newer schema. Check that the old code tolerates it before rolling back, or write and ship a corrective migration instead. See [Database and migrations](database-and-migrations.md).
- It does not run `deploy:migrate` or `deploy:npm_build_css` again.
- `finishing_rollback` packs the rolled-back release into `rolled-back-release-<timestamp>.tar.gz` in the deploy directory, then deletes its directory. Keep the archive until you are sure you will not need it.

UNVERIFIED: this repository has never recorded a rehearsed rollback. Check Apache is serving the old release (`ls -l current` and load a page) before telling anyone it worked.

## Tags

`scripts/tag-prod.sh` and `scripts/tag-staging.sh` move the `PRODUCTION` and `STAGING` tags with `git push --force`.
They tag your **local** `HEAD`, not what is deployed, and if the local tag does not exist the move silently does nothing.
Treat them as a production action. Recent deploys are tagged by `capistrano-tagging3` instead (`production_<timestamp>` and `staging_<timestamp>`).

## Known gaps

- UNVERIFIED: `config/deploy.rb` links `searchdb` to `shared/shared/search/searchdb`, but the server config sets `XAPIANDB` to `shared/search/searchdb`. Check `ls -l current/searchdb` and `shared`. See [Search index](search-index.md).
- UNVERIFIED: the Capfile links both `debates/debates.rss` and `senate/senate.rss` to `shared/rss/senate.rss`. This looks like a copy-and-paste error.
- `deploy:setup_db` loads `db/schema.sql` into the `:db` role. No server has that role, so it does nothing. Do not use it.
