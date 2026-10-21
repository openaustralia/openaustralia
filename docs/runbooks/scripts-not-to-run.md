# Scripts not to run

The repositories hold many scripts left over from the UK site this one was forked from, from old experiments, or from earlier infrastructure. Some are broken, and some would damage production data if run.
This page lists them so nobody finds one in a directory and runs it. If a script is not in a runbook or in the cron table in [Cron and monitoring](cron-and-monitoring.md), assume it is not safe to run.
Paths are in the `twfy` and `openaustralia-parser` repositories (submodules of this one).

## Broken: they fail when run

| Script | Why |
|---|---|
| `openaustralia-parser/postcodes.rb` | Fails with `ArgumentError: wrong number of arguments (given 0, expected 1)` on every direct run, so postcodes cannot be reloaded. See [Members, links, postcodes and photos](members-and-links.md#symptom-postcode-lookups-are-wrong-or-empty) |
| `openaustralia-parser/export-comments.rb`, `import-comments.rb` | Both `require "mysql"`, which is not in the `Gemfile` (only `mysql2` is), so they raise `LoadError`. They also need an environment variable `BE-DANGEROUS` that a shell cannot export, and `export-comments.rb` deletes comments after exporting. To move comments, use database snapshots or SQL |
| `openaustralia-parser/wikipedia.rb` | An empty file. The real Wikipedia import is `twfy/scripts/weeklyupdate` |
| `twfy/scripts/fawkesuser/handlemail` | Starts with `exit;` and is marked unfinished. Bounces are handled by the Postal webhook |
| `twfy/search/breaktest.sh` | Needs a `testindex.pl` that does not exist |

## Legacy or UK-era: do not run

| Script | What it is |
|---|---|
| `twfy/scripts/crontab`, `twfy/conf/crontab.ugly` | Old schedules for the `fawkes` user, with the wrong paths. The real cron is in the infrastructure repository. See [Cron and monitoring](cron-and-monitoring.md) |
| `twfy/scripts/update-hansard.pl`, `update-hansard-all.pl` | UK-era. They run `UPDATE hansard SET htime=?` from standard input or from `/home/fawkes/...`, and would overwrite times |
| `twfy/scripts/ukparse-morning-update-done.cgi` | Queues a script under `/home/fawkes/` |
| `twfy/scripts/lxml2bsv.pl`, `oral2rss.pl`, `iquangographer_xml.pl`, `alertgonemps.php` | UK data (Lords, oral questions), or a hard-coded old path. `alertgonemps.php` only prints |
| `twfy/scripts/edmmotions.py`, `wikipedia-backlinks.py` | One-off analysis scripts for Python 2 |
| `twfy/scripts/check-links.rb` | A developer tool. It makes many external requests and prints `sed -i` commands |
| `twfy/search/indexall.sh`, `search/search.pl` | `indexall.sh` loops over the UK years 1999 to 2007 and ends with `index.pl ... check`, which **deletes** index documents. `search.pl` is a development tool |
| `openaustralia-parser/parse-postcodes_2010.rb` and `data/pc-full_20100629.csv` | Scrapes an old AEC page for every postcode. Obsolete |
| `openaustralia-parser/register-split.rb` | Needs `pdftk` at a fixed path and PDFs that do not exist on the server. Nothing links its output. Leave `shared/regmem_scan` alone |
| `twfy/www/docs/regmem/index.php`, `www/docs/wikipedia/index.php`, `www/docs/gadget/*`, `mobile.php` | Legacy pages that read hard-coded UK paths or old IP lists |
| `make_rss.pl` functions `wms_rss`, `wrans_rss`, `pbc_rss` | Never called |

## Dangerous on production

Each of these works, and changes or removes data. Run them only as a step in a runbook that says so.

| Command | Risk |
|---|---|
| `index.pl <db> check` | **Deletes** Xapian documents that are not in MySQL, and takes the write lock. A mistyped database path with any action silently creates an empty index. See [Search index](search-index.md) |
| `index.pl <db> all`, or `sincefile` with no timestamp file | Re-indexes everything. Slow and memory-hungry |
| `compactsearchdb` | Runs `rm -fr` on `searchdb-compacted` and `searchdb-previous` with `$XAPIANDB` unquoted. Never run it with `XAPIANDB` blank, or from the wrong directory |
| `xml2db.pl ... --force` over a wide date range | Deletes database rows that are not in the XML, for every day in the range. It also runs a clean-up of `epobject` rows with no `hansard` row on every start. It stops only when comments, votes or edit-queue entries refer to a row |
| `xml2db.pl --members` | Wipes `moffice` and `constituency` first, with no transaction. See [Members, links, postcodes and photos](members-and-links.md) |
| `xml2db.pl` with `DB_HOST`, `DB_PORT`, `RAWDATA` or `PWMEMBERS` exported in your shell | The environment beats `conf/general` silently, so it can point at the wrong database or directory |
| `alertmailer.php --from=...` or `--to=...` without `--nomail` | Sends, and rewrites `alerts-lastsent`. See [Alerts and email](alerts-and-email.md) |
| `scripts/delete-alerts` | Soft-deletes alerts for every address on standard input, with no dry run |
| `scripts/import-suppressions.php` | A one-off bulk import of suppressions that handles personal data |
| `scripts/dumpallforbackup` | Writes a full dump of **all** databases, with personal data and password hashes, into `DBBACKUP`, and deletes old dumps. The password is on the command line. Not scheduled |
| `phinx rollback` | Some migrations drop or empty tables. See [Database and migrations](database-and-migrations.md) |
| Parser `rake db:fixtures:load` | Drops and refills `postcode_lookup`, `users`, `member`, `hansard` and `comments` in whatever database the configuration names. Never run it on the server |
| Parser `rake db:drop` | Refuses only when it believes it is on production (`APP_ENV`, or a working directory containing `/production/`). Staging and any other checkout are not protected |
| Parser `rake db:backup` | Writes `tmp/backup.sql` inside the release directory, which is not backed up and is pruned. The dump holds user data and the password is on the command line |
| Parser `rake db:validate_encoding` | Read-only, but the SQL it suggests rewrites whole tables with a collation that differs from `schema.sql`. Do not run that SQL without a review |
| Parser `regression-test/*.rb` | Write into the live members directory and into `scrapedxml` for every day of 2019. They need a reference checkout and macOS `opendiff` |
| Parser `parse-members.rb --no-load` or `parse-member-links.rb --no-load` on the server | Still rewrites the live XML files. Add `--output-dir=<scratch directory>` |
| `sitemap.rb` by hand while `morningupdate` runs | Two writers can corrupt `sitemap.xml`. Check `pgrep -fa morningupdate` first |
| `/admin/glossary.php` delete | Permanent |

Run the parser's Rake tasks as `./bin/run db:stats`, not `./bin/run rake db:stats`. `db:stats` and `db:validate_encoding` are read-only.
