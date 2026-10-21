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

1. Read the end of `/srv/www/<stage>/log/morningupdate.log` and the parser's own log, `/srv/www/<stage>/log/parser.log`. The cron email carries stdout, which holds the progress bar and the error.
2. Match the error text.

| Error text (search for it) | Meaning | Where it is raised |
|---|---|---|
| `Couldn't figure out who ... is in division` | A name in a division list matches nobody. This is the most common failure | `lib/hansard_parser.rb` |
| `Unknown speaker` or `Can't figure out which person the aph id ... belongs to` | A speaker or APH id is missing from the people data. Logged as a warning, not always fatal | `lib/hansard_parser.rb` |
| `Unrecognised party` | A party code in a members CSV has no mapping | `lib/people_csv_reader.rb` |
| `Unexpected tag`, `Unexpected value for contents` | APH changed its XML. The parser rejects tags it does not know | `lib/hansard_rewriter.rb`, `lib/hansard_day.rb`, `lib/hansard_speech.rb` |
| `Link to XML download is missing` | The APH page had no "View/Save XML" link. See the cache warning below | `lib/hansard_parser.rb` |
| `Patch failed` | A hand patch in `data/patches/` no longer applies to the fresh XML | `lib/patch.rb` |
| `Could not determine division result` | A division has no result APH can resolve | `lib/hansard_division.rb` |
| HTTP 403 or 429 after retries | APH is blocking the scraper. It uses a user agent APH allowlisted, so a block can mean the allowlist changed | `lib/aph_mechanize_agent.rb` |

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

1. Confirm the file is empty: `ls -l /srv/www/<stage>/shared/pwdata/origxml/representatives_debates/<date>.xml`.
2. Delete that one file (and the matching `senate_debates` one if needed). Undo: not possible, but the next run fetches it again from APH.
3. Re-run the day.

If the XML is non-empty but wrong, delete the same `origxml` file. `rewritexml` is regenerated, and `scrapedxml` is overwritten.

**Re-run a day (CHANGES PRODUCTION)**
Run as the `deploy` user on the server:

```
cd /srv/www/<stage>/current/openaustralia-parser
./bin/run parse-speeches.rb <yyyy-mm-dd> [<yyyy-mm-dd>]
```

Add `--force` to make `xml2db.pl` delete database rows for that day that are not in the XML. Use `--interactive` to choose Retry, Patch or Continue per failure.
`--no-load` parses without touching the database, which is a safe way to test a fix.

**Verify** (the database load can fail silently, see below)

- The day appears on the debates calendar for that year, for example `https://www.openaustralia.org.au/debates/?y=2017` (the parser README uses this to spot a missing day).
- Check rows directly with read access to the database, for example the `hansard` table for that date. UNVERIFIED: the infrastructure repository gives the read-only account to Metabase only.
- Then re-index (next section), and skip duplicate alerts if you loaded old days.

## The database load can fail without anyone noticing

`parse-speeches.rb`, `parse-members.rb` and `parse-member-links.rb` call `xml2db.pl` or `mpinfoin.pl` with `system(...)` and do not check the exit status.
If the load fails (database down, bad XML), the Ruby script still exits 0, so `morningupdate` carries on to indexing and the Sentry cron check-in reports success.
After any parse that touched the database, check the rows or the site, not just the exit code.

## Re-index after a backfill

`morningupdate` indexes only what changed since its last run. Days you load by hand are picked up the next morning only if they changed in the database.
To index a date range explicitly, as the `deploy` user (the action name and the two dates are separate arguments):

```
cd /srv/www/<stage>/current/twfy
./search/index.pl "$XAPIANDB" daterange 2018-06-25 2018-08-17
```

Set `XAPIANDB` to the server's `searchdb` path first. See [Search index](search-index.md).
The parser README has a worked example with its spacing wrong (`daterange2018-06-25`).

## Stop alert emails for old days you reloaded

Reloading old days can email people about debates they already saw.
Do the reload and re-index after the 10:00 run has finished and before the next 09:05 `morningupdate`, then bump the two lines in `alerts-lastsent` to the current time and the highest batch number. The timing matters, because a bump also skips genuine batches. See [Alerts and email](alerts-and-email.md).

## Known gaps

- `previous-working-day` uses the server's date and skips weekends only.
- APH selectors in `lib/hansard_rewriter.rb` are brittle. A new APH layout usually shows up as `Unexpected tag`.

**Escalate**: tell the on-call engineer. If a sitting day is missing from the public site by the next working day, the CEO decides whether a notice is needed, and signs off any wording.
