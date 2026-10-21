# Daily Hansard parse

`morningupdate` runs on weekday mornings (09:05, Australia/Sydney, production only).
It runs these steps, and stops at the first one that exits non-zero:

1. `openaustralia-parser/bin/run parse-speeches.rb previous-working-day`: fetches the day's Hansard XML from APH for both houses, writes it under `RAWDATA`, then runs `twfy/scripts/xml2db.pl` to load it into MySQL.
2. `twfy/search/index.pl` with `sincefile`: indexes what changed since the last run. Skipped, with a message, if `XAPIANDB` is blank.
3. `rssgenerate`, then `sitemap.rb`.

`alertmailer.php` runs at 10:00 and emails the alerts. See [Alerts and email](alerts-and-email.md).
`previous-working-day` ignores public holidays and parliamentary sitting days. A day that fails is **not retried** the next morning.

Terms: [`CONTEXT.md`](../../CONTEXT.md). Log and monitor locations: [Cron and monitoring](cron-and-monitoring.md).

## Symptom: a day is missing from the site, or the cron email shows an error

**Diagnose (READ-ONLY)**

1. Read the end of `/srv/www/<stage>/log/morningupdate.log` and the parser's own log, `/srv/www/<stage>/shared/pwdata/parser.log`. The parser's configuration names `/srv/www/<stage>/log/parser.log`, but that file does not exist on production. The cron email carries stdout, which holds the progress bar and the error.
2. Match the error text.

| Error text (search for it) | Meaning | Where it is raised |
|---|---|---|
| `Couldn't figure out who ... is in division` | A name in a division list matches nobody. This is the most common failure | `lib/hansard_parser.rb` |
| `Unknown speaker` or `Can't figure out which person the aph id ... belongs to` | A speaker or APH id is missing from the people data. **Never fatal**: the speech is kept, unlinked. The genuinely fatal speaker errors are `Could not find house speaker ... for date` and `More than one match for name` | `lib/hansard_parser.rb`, `lib/people.rb` |
| `Unrecognised party` | A party code in a members CSV has no mapping. It is raised when the CSV files load, so it **breaks every date**, not one | `lib/people_csv_reader.rb` |
| `Unexpected tag`, `Unexpected value for contents`, `Assertion failed!` | APH changed its XML. The parser rejects tags it does not know | `lib/hansard_day.rb`, `lib/hansard_speech.rb`, `lib/hansard_rewriter.rb` (the last raises only `Assertion failed!`) |
| `Link to XML download is missing` | The APH page had no "View/Save XML" link. **WARN level: it is in the parser log only, not the cron email, and the run exits 0.** See the cache warning below | `lib/hansard_parser.rb` |
| `Patch failed` | A hand patch in `data/patches/` no longer applies to the fresh XML | `lib/patch.rb` |
| `Could not determine division result` | A **tied House** division whose result text matches nothing the parser knows | `lib/hansard_division.rb` |
| `Not an even number of people in the pairs voting` | APH's pairs list has an odd number of names. Needs a patch | `lib/hansard_division.rb` |
| HTTP 403, 429, 502, 503 or 504 after five tries | APH is blocking or failing. Other codes (404, 500) and network errors are not retried and abort at once. The scraper uses a user agent APH allowlisted, so a persistent block can mean the allowlist changed | `lib/aph_mechanize_agent.rb` |

**For the fix itself, including patches and every error that needs a person, see [Parse failures and patches](parse-failures-and-patches.md).** This page only triages.

3. Confirm what loaded. A parse that aborts loads **nothing**, even for days that parsed before the failure, because the database load runs only after every day has parsed.
   The XML for good days is still on disk under `RAWDATA/scrapedxml/`.

**Fix: people and names (CHANGES PRODUCTION)**
Add the person, or an alternative name, to the parser data files and ship the change.
The file formats and the procedure are in [`docs/data-updates.md`](https://github.com/openaustralia/openaustralia-parser/blob/main/docs/data-updates.md) in the parser repository.
A change goes live when the pointer is bumped here and deployed. See [Deploy and rollback](deploy-and-rollback.md).
Then re-run the day (below).

**Fix: poisoned cache (CHANGES PRODUCTION)**
The parser keeps each fetched day in `RAWDATA/origxml/<house>_debates/<date>.xml` and **treats an empty file as "parliament did not sit" for ever**.
If APH had a bad moment and the link was missing, the parser wrote an empty file, and later runs trust it.

1. Confirm the file is empty (`ls -l /srv/www/<stage>/shared/pwdata/origxml/representatives_debates/<date>.xml`), **and that the house sat that day**.
   About half of the files are empty on purpose: on production, 1,288 of 2,539 House files and 1,299 of 2,339 Senate files were empty when checked on 2026-10-21, because parliament did not sit. An empty file alone proves nothing. Check the day against the parliamentary sitting calendar first.
2. Delete that one file (and the matching `senate_debates` one if needed). Undo: not possible, but the next run fetches it again from APH.
3. Re-run the day.

If the XML is non-empty but wrong, delete the same `origxml` file. `rewritexml` is regenerated, and `scrapedxml` is overwritten.

**Re-run a day (CHANGES PRODUCTION)**
Run as the `deploy` user on the server:

```
cd /srv/www/<stage>/current/openaustralia-parser
./bin/run parse-speeches.rb <yyyy-mm-dd> [<yyyy-mm-dd>]
```

Add `--force` to make `xml2db.pl` delete database rows for that day that are not in the XML. `--interactive` asks Retry, Patch, Continue or Quit per failure. Its Patch option does not help, so read the options table in [Parse failures and patches](parse-failures-and-patches.md#parse-speechesrb-options) first.
`--no-load` skips the database load, but it **still writes** `origxml`, `rewritexml` and `scrapedxml` under `RAWDATA`. For a clean test add `--output-dir=<scratch directory>`.

**Verify** (the database load can fail silently, see below)

- The day appears on the debates calendar for that year, for example `https://www.openaustralia.org.au/debates/?y=2017` (the parser README uses this to spot a missing day).
- Check rows directly with the `mysql` client on the server, using the `DB_*` values in `shared/general`, for example the `hansard` table for that date. Never paste the password into a ticket or chat.
- Then re-index (next section), and skip duplicate alerts if you loaded old days.

## The database load can fail without anyone noticing

`parse-speeches.rb`, `parse-members.rb` and `parse-member-links.rb` call `xml2db.pl` or `mpinfoin.pl` with `system(...)` and do not check the exit status.
If the load fails (database down, bad XML), the Ruby script still exits 0, so `morningupdate` carries on to indexing and the Sentry cron check-in reports success.
After any parse that touched the database, check the rows or the site, not just the exit code.

**`xml2db.pl` is not transactional.** It loads days in ascending date order, the House (`--debates`) completely before the Senate (`--lordsdebates`). If it stops part-way on a House day (`speech without (sub)heading <id>`, `Got gid <g> twice`, a database error, or XML that is cut short), the days before it **are** loaded and the Senate is not loaded at all. So "an aborted parse loads nothing" is true only when the Ruby parser aborts, before the load starts.
It also deletes `epobject` rows that have no `hansard` row each time it starts, and prints `Fixing up lonely epobjects`. A message like `strange, missing epobject <id> for gid <g> - part of db unexpectedly missing` followed by `deleting hansard object <g> and rebuilding` is it repairing a row, not an error.
Its exit status is non-zero on a `die`, and the Ruby script ignores it. With none of `--date`, `--from` or `--to`, or no data type flag, it prints its usage and exits 0.

## Re-index after a backfill

`morningupdate` indexes only what changed since its last run. Days you load by hand are picked up the next morning only if they changed in the database.
To index a date range explicitly, as the `deploy` user (the action name and the two dates are separate arguments):

```
cd /srv/www/<stage>/current/twfy
export XAPIANDB=/srv/www/<stage>/shared/search/searchdb
./search/index.pl "$XAPIANDB" daterange 2018-06-25 2018-08-17
```
`index.pl` takes the index path as its first argument and does not read `XAPIANDB` from `conf/general`, and a fresh SSH session has no `XAPIANDB`, so set it as shown (and check with `ls` that the path exists).

See [Search index](search-index.md).
The parser README has a worked example with its spacing wrong (`daterange2018-06-25`).

## Stop alert emails for old days you reloaded

Reloading old days can email people about debates they already saw.
Do the reload and re-index after the 10:00 run has finished and before the next 09:05 `morningupdate`, then bump the two lines in `alerts-lastsent` to the current time and the highest batch number. The timing matters, because a bump also skips genuine batches. See [Alerts and email](alerts-and-email.md).

## Known gaps

- `previous-working-day` uses the server's date and skips weekends only.
- APH selectors in `lib/hansard_rewriter.rb` are brittle. A new APH layout usually shows up as `Unexpected tag`. See [Parse failures and patches](parse-failures-and-patches.md#aph-changed-its-xml).

**Escalate**: tell the on-call engineer. If a sitting day is missing from the public site by the next working day, the CEO decides whether a notice is needed, and signs off any wording.

## Sitemap

The last step of `morningupdate` runs `openaustralia-parser/bin/run sitemap.rb`, after the index and the RSS files. It writes `shared/sitemap.xml` and the `sitemaps/*.gz` files, which the site serves.
A sitemap failure stops the rest of `morningupdate`, but, like a parse failure, **it is masked**: the run goes through the lock wrapper, so it still logs `Exit status: 0` and the Sentry monitor stays green (see [Cron and monitoring](cron-and-monitoring.md#which-exit-statuses-to-trust)). The parse, index and RSS steps have already succeeded by then. Check `sitemap.xml` and the `.gz` files as below, and re-run the sitemap by hand.

- **A failed run leaves a broken file.** `sitemap.xml` is opened for writing at the start, so a failed or still-running job leaves an unterminated index, and a truncated `.gz` is possible. Check with `tail -c 100 shared/sitemap.xml`, which should end with `</sitemapindex>`, and `gzip -t shared/sitemaps/*.gz`. Old higher-numbered `.gz` files are not removed.
- **Do not run it while `morningupdate` runs.** There is no lock, and two writers can corrupt the file. Check `pgrep -fa morningupdate` first.
- **The news step runs PHP.** It runs `twfy/www/docs/news/editme.php` relative to the working directory. Errors are `unable to locate PHP binary` or `<php>: failed status ...`. A PHP notice on standard output misaligns the output and gives an `ArgumentError` from `Time.parse`. `EXCLUDE_NEWS=1` skips the news step, but UNVERIFIED: it may then fail with `undefined method 'utc' for nil` if the last file holds only member URLs.
- It reads every `hansard` row one at a time, so it is slow and heavy on the database. On an empty database it raises.
- `--output-dir` must end with `/`, and its help text wrongly mentions postcodes.
