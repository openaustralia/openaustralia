# Members, links, postcodes and photos

Four separate jobs keep the people data current. Only one of them is scheduled.

| Job | Script (in `openaustralia-parser`) | Scheduled? | What it does |
|---|---|---|---|
| Member list | `parse-members.rb` | **No.** Run it by hand after a data change | Reads the CSV files in `data/`, checks them, writes `people.xml`, `representatives.xml`, `senators.xml`, `ministers.xml` and `divisions.xml`, then loads them with `xml2db.pl --members --all --force` |
| Member links | `parse-member-links.rb` | Daily, through `dailyupdate` (01:37, production only) | Collects websites, ABC election links and register-of-interests links, writes XML, then runs `mpinfoin.pl links` |
| Postcodes | `postcodes.rb` | No | Replaces the whole `postcode_lookup` table from `data/postcodes.csv` |
| Photos | `member-images.rb` | No | Downloads official photos from APH into the `images/mps`, `mpsL` and `mpsXL` directories |

`dailyupdate` then runs `mpinfoin.pl`, which loads extra member information from other sites.
Terms: [`CONTEXT.md`](../../CONTEXT.md). Logs: [Cron and monitoring](cron-and-monitoring.md).
To see when each job last wrote its output, run `ls -l /srv/www/<stage>/shared/pwdata/members/`. The member XML files date from the last `parse-members.rb` run, and the two `links-*.xml` files from the last `dailyupdate`.

## Symptom: a new member, a resignation or a party change is not on the site

Member data is edited by hand in the parser's CSV files.
The file formats and the workflow for each type of change are in [`docs/data-updates.md`](https://github.com/openaustralia/openaustralia-parser/blob/main/docs/data-updates.md).

**Fix (CHANGES PRODUCTION)**

1. Merge the data change in the parser repository, bump the pointer here and deploy. See [Deploy and rollback](deploy-and-rollback.md).
2. Load it: `make production-parse-members` (or `make staging-parse-members`). This runs `cap <stage> parse:members`, which runs `parse-members.rb` on the server and replaces all member rows (`--force`).
3. Check the member's page and a recent division.
   Undo: revert the CSV change, deploy and run the load again. There is no database undo for the load itself.

Members and the debates share names, so a missing member usually also shows up as `Couldn't figure out who ...` in [Daily Hansard parse](daily-hansard-parse.md).

## Symptom: `parse-members.rb` stops with an error

**Diagnose (READ-ONLY)** Run `./bin/run parse-members.rb --no-load` from the parser directory. It checks the data without writing to the database.

| Error text | Meaning |
|---|---|
| `From and To date the wrong way round` | A stint's end date is before its start date. Dates in the members CSVs use `d.m.yyyy` and `ministers.csv` uses `dd/mm/yyyy`. Use four-digit years. A two-digit year such as `18` is accepted silently as the year 18 |
| `Members X and Y both in at the same time` | Two members hold the same seat over the same days |
| `X has two periods that overlap` | One person has overlapping stints |
| `WARNING: No current member for <division>` | A division has no sitting member. Check whether a by-election result is missing |
| `Unrecognised party` | A party code has no mapping. Adding one needs a code change in `lib/people_csv_reader.rb` |

New or abolished electorates need a code change: the list of old divisions is hard-coded in `parse-members.rb`.

## Symptom: `dailyupdate` fails on member links

`parse-member-links.rb` scrapes the ABC election pages, the APH Register of Members' Interests and a Senate interests API, and reads morph.io.
Only the speeches path retries. These scrapes have no retry, so any change on those sites, or a morph.io outage, aborts the whole job.

**Diagnose (READ-ONLY)** Read the end of `/srv/www/<stage>/log/dailyupdate.log`. Common causes:

- A site changed its layout (the ABC selectors are brittle) or an address moved.
- The morph.io API key in the parser's configuration has expired or been revoked.
- `Couldn't find <name>`: a person on a source page does not match the people data.

**Fix**: nothing in the job is time-critical. Fix the cause and let tomorrow's run catch up, or run it by hand (CHANGES PRODUCTION):
`cd /srv/www/<stage>/current/openaustralia-parser && ./bin/run parse-member-links.rb`.
If `mpinfoin.pl` fails afterwards, the extra member information it loads is stale until the next run.

## Symptom: every parser script fails reading the configuration

The parser reads database settings from its own `configuration.yml` if all four database fields are set.
Otherwise `rblib/config.rb` starts PHP to read `twfy/conf/general`.
**Any output from PHP before the options are read, such as a deprecation warning, makes that read raise** `failed to read options`.
Also check `unable to locate PHP binary` and `bad option output from subprocess`.

**Diagnose (READ-ONLY)** Run any parser script with `--no-load` and read the first error. If it names PHP, check what PHP prints when it loads `twfy/conf/general` (a warning or deprecation notice is enough), and check the PHP version on the server.
UNVERIFIED: the unconditional `raise` was read in `rblib/config.rb` but not reproduced.

## Symptom: a member photo is missing

APH often publishes a profile page before its photo is ready, and the parser caches the photoless page.

**Fix (CHANGES PRODUCTION)**

1. List the cached pages for that person: `ls /srv/www/<stage>/shared/html_cache/member_images/*<surname>*`.
2. Delete the ones you are sure belong to that person.
3. Run `cd /srv/www/<stage>/current/openaustralia-parser && ./bin/run member-images.rb`. It accepts `--limit=N` to cap the number of people.
4. Check the member's page. The photo reaches They Vote For You the next day.

## Symptom: postcode lookups are wrong or empty

`postcodes.rb` runs `DELETE FROM postcode_lookup` and then bulk-inserts `data/postcodes.csv`, so a failed load leaves the table empty.
`parse-postcodes.rb` rebuilds the CSV from the morph.io division-postcode scraper. `HTTP ERROR ... check your morph.io API key` comes from this script.

**Diagnose (READ-ONLY)** Count rows in `postcode_lookup` and compare with the CSV line count.
**Fix (CHANGES PRODUCTION)** Re-run `postcodes.rb`. Use `--no-load` first to confirm it parses.

## Known gaps

- `lib/people_image_downloader.rb` uses a name before it is set on one path, which would raise `NoMethodError`. Read in the code, not reproduced.
- A `parse-members.rb` run that fails the database load exits 0. See [Daily Hansard parse](daily-hansard-parse.md#the-database-load-can-fail-without-anyone-noticing).

**Escalate**: tell the on-call engineer. Wrong party, wrong seat or a missing sitting member on a public page is wrong public data. The CEO signs off any correction notice.
