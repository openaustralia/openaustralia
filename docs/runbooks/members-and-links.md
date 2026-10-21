# Members, links, postcodes and photos

Four separate jobs keep the people data current. Only one of them is scheduled.

| Job | Script (in `openaustralia-parser`) | Scheduled? | What it does |
|---|---|---|---|
| Member list | `parse-members.rb` | **No.** Run it by hand after a data change | Reads `people.csv`, `representatives.csv`, `senators.csv`, `ministers.csv` and `shadow-ministers.csv`, checks them, writes five XML files into the members directory (`PWMEMBERS`, `shared/pwdata/members/`, which the data site publishes), then loads them with `xml2db.pl --members --all --force` |
| Member links | `parse-member-links.rb` | Daily, through `dailyupdate` (01:37, production only) | Collects websites (from morph.io), ABC election links and register-of-interests links, writes three XML files into the same directory, then runs `mpinfoin.pl links` |
| Postcodes | `postcodes.rb` | No. **Cannot currently run** | Would replace the whole `postcode_lookup` table from `data/postcodes.csv` |
| Photos | `member-images.rb` | No | Downloads official photos from APH into `images/mps`, `mpsL` and `mpsXL` |

After `parse-member-links.rb`, `dailyupdate` runs `mpinfoin.pl` with **no arguments**, and that does much more than links: see "Member information (`mpinfoin.pl`)" below.
Terms: [`CONTEXT.md`](../../CONTEXT.md). Logs: [Cron and monitoring](cron-and-monitoring.md).
To see when each job last wrote its output, run `ls -l /srv/www/<stage>/shared/pwdata/members/`. The five member XML files date from the last `parse-members.rb` run, and `websites.xml`, `links-abc-election.xml` and `links-register-of-interests.xml` from the last `dailyupdate`.

**`--no-load` is not read-only.** On `parse-members.rb` and `parse-member-links.rb` it skips only the database load. It still rewrites the XML files in the live members directory. To test without touching them, add `--output-dir=<scratch directory>`, which both scripts accept. The directory must be writable by the user running the script (`deploy` on the server), so a directory made by `mktemp` as root fails with `Permission denied`. On the server, a check that raises an error does so before any file is written, so the old XML stays.

Run the scripts with `./bin/run <script>` from `/srv/www/<stage>/current/openaustralia-parser`. `bundle exec ./script.rb` does nothing at all and exits 0, and `./bin/run rake <task>` fails (use `./bin/run <task>`).

## Symptom: a new member, a resignation or a party change is not on the site

Member data is edited by hand in the parser's CSV files.
The file formats and the workflow for each type of change are in [`docs/data-updates.md`](https://github.com/openaustralia/openaustralia-parser/blob/main/docs/data-updates.md). For what to do around an election, see [After an election, and yearly tasks](after-an-election-and-yearly-tasks.md).

**Fix (CHANGES PRODUCTION)**

1. Merge the data change in the parser repository, bump the pointer here and deploy. See [Deploy and rollback](deploy-and-rollback.md).
2. Load it: `make production-parse-members` (or `make staging-parse-members`). This runs `cap <stage> parse:members`, which runs `parse-members.rb` on the server. It has no lock, no Sentry monitor and no log file, and **its exit status cannot be trusted**, because the database load result is ignored.
3. Check the output for `Adding new member with identifier <id>` and `Replacing existing member with new data for <id>`, then check the member's page and a recent division.

**What the load does, and does not do.**

- Member rows are inserted or replaced by member id. **They are never deleted.** If you revert a CSV row, the member row stays and `xml2db.pl` prints `Member <id> in DB, not in XML`. Removing a wrongly added member needs SQL by hand.
- Before it parses `divisions.xml`, the load runs `DELETE FROM constituency`, and before the ministers it runs `DELETE FROM moffice`. Nothing is in a transaction. If the load stops part-way (for example `mp <id> <name> has no person`, `Unknown house`, or an XML parse error), `moffice` (ministerial offices) and `constituency` are left empty or partial, while the Ruby script still exits 0. After any failed members load, count rows in those two tables, fix the data, and run the load again.
- `--all` and `--force` have no effect on this path.

Members and the debates share names, so a missing member usually also shows up as `Couldn't figure out who ...` in [Daily Hansard parse](daily-hansard-parse.md). [Parse failures and patches](parse-failures-and-patches.md) explains how names are matched and how to fix each case.

## Symptom: `parse-members.rb` stops with an error

**Diagnose (READ-ONLY)** On your own machine, or on the server with `--output-dir=<scratch directory>`, run `./bin/run parse-members.rb --no-load`. It checks the data without loading it.

| Error text | Meaning |
|---|---|
| `From and To date the wrong way round` | A House stint's start is not before its end (equal dates also fail). The message has no name, so search the CSV |
| `Members X and Y both in at the same time` | Two members hold the same seat over the same days. **House only** |
| `X has two periods that overlap` | One person has overlapping stints. This check covers the House and the Senate |
| `WARNING: No current member for <division>` | A House division has no sitting member. Check whether a by-election result is missing. It only warns |
| `Can't find <name> for date <date>` | A name in `ministers.csv` or `shadow-ministers.csv` matches no person current on that date. The likeliest failure after an election |
| `Unrecognised party`, `Couldn't find person`, `More than one match for name`, `State ... is not a valid`, `Division is undefined`, `Birthday ... not valid` | A data file error. See [Parse failures and patches](parse-failures-and-patches.md#data-file-errors-at-startup) |
| `NoMethodError: undefined method '[]' for nil` in `parse_date` | An unparseable date |

Dates in the members CSVs are `d.m.yyyy` and in `ministers.csv` are `dd/mm/yyyy`, but the parser only splits on any character, so what really breaks is a two-digit year (read as the literal year) or the wrong order.

**Reasons are silently changed.** `lib/people_xml_writer.rb` turns any start or end reason that is not on a fixed list into `unknown`, with no error. For example `defeated` (268 stints in `representatives.csv`) and `elected_elsewhere` are not valid end reasons, and `section_15`, `recount`, `high_court` and `declared_elected` are not valid start reasons, although `docs/data-updates.md` lists some of them. They reach the database as `unknown`.

**New or abolished electorates do not need a code change.** Division names come from `representatives.csv`. The hard-coded `old_divisions` list in `parse-members.rb` only silences the `No current member` warning, and it is already out of date (`Fraser` is in it and has a sitting member).

## Symptom: `dailyupdate` fails, or member links are missing

`dailyupdate` has no `set -e`. It runs `parse-member-links.rb`, then `mpinfoin.pl` whatever happened, and **its exit status is `mpinfoin.pl`'s alone**.
So a failure in `parse-member-links.rb` does not fail the job or the Sentry monitor when `mpinfoin.pl` then succeeds. The signs are a Ruby backtrace in `dailyupdate.log`, the parser's own Sentry exception, and the cron email.

`parse-member-links.rb` opens each of its three XML files for writing at the start of its step, so a failure part-way through leaves a truncated file. A truncated `websites.xml` or `links-abc-election.xml` then makes `mpinfoin.pl links` fail, and the job goes red.
The register-of-interests file is only opened after both register scrapes succeed, so a failure there leaves yesterday's file.

**Failure shapes (read the backtrace):**

| Shape | Meaning and fix |
|---|---|
| `WARNING: morph_api_key is not set in configuration.yml! The api call will fail!` | The key is missing or still the `XXXX` placeholder. Fix it in `shared/parser_configuration.yml` through the infrastructure repository |
| `Mechanize::ResponseCodeError ... 401 ... api.morph.io/...?key=<KEY>` | The morph.io key is invalid or revoked. **The error text contains the key**, so it reaches stderr, logs and Sentry. Do not paste that log anywhere, and rotate the key |
| `NoMethodError: undefined method 'id' for nil` | A morph.io row's `aph_id` is not in `people.csv`, so **a new member without an `aph id` row breaks this step every night**. The match is case-sensitive, and every id in `people.csv` is upper case. `undefined method 'upcase' for nil` means the scraper's `aph_id` is empty |
| `Couldn't find <name> (Unable to find by name, Try appending alt name: ...)` | Fatal. A name on the representatives register page matches nobody. Add an alternative name to `data/people.csv` |
| `Couldn't find <name> (Found one person by name, but BAD DATA: last period ...)` | Fatal. The person's last stint ends in the future or more than three years ago. Fix the dates |
| `Couldn't find <name> (Found too many people with that name that are current today)` | Fatal. Disambiguate in the data |
| `WARNING: Couldn't find <name> (... not current, last period ...)` | Not fatal. The person is skipped (recently retired or defeated) |
| `NoMethodError undefined method '[]' for nil` on the register page | APH changed the page layout. If the table selector matches nothing there is no error, only no links |
| `JSON::ParserError`, `NoMethodError`, or `RuntimeError: unhandled exception` on the Senate step | The Senate interests API changed or failed. The bare `raise if senator.nil?` has no name in it, so compare the API's names with `people.csv`. The URL prefix `298839` is hard-coded, and there is no retry or status check |
| `OpenURI::HTTPError: 404 Not Found` or `Mechanize::ResponseCodeError` on the ABC step | An ABC election page moved. A dead page can also be silent: the 2007 and 2010 pages redirect to a generic page and yield no links, so treat an ABC step that "succeeds" as unproven |
| `Errno::ENOENT ... configuration.yml` | The parser configuration file is missing. `Loading config from: ...` on its own is normal |

`--limit=N` caps only the morph.io rows. Every other scrape still runs.

**Fix**: nothing in the job is time-critical. Fix the cause and let tomorrow's run catch up, or run it by hand (CHANGES PRODUCTION): `cd /srv/www/<stage>/current/openaustralia-parser && ./bin/run parse-member-links.rb`.

### Member information (`mpinfoin.pl`)

With no arguments, as `dailyupdate` runs it, it does every action: `pw`, `expenses`, `regmem`, `links`, `wtt` and `rankings`.
`pw` fetches `/feeds/mp-info.xml` for each house and then `mpdream-info.xml` for ids 1 to 276 from `PUBLICWHIP_HOST`, **278 requests every night with no retry**. It parses everything before it writes, so one failing URL means nothing is loaded and the job exits non-zero. It runs with `PERL_LWP_SSL_VERIFY_HOSTNAME=0` (a long-standing FIXME).
It only adds or updates `memberinfo`, `personinfo` and `consinfo`, and **never removes** old values, so stale links stay. `regmem` finds a file it never parses.
`rankings` prints `Failed to find any MPs for rankings, change General Election date here if you are near one` and skips when no House member has a future `left_house` date, for example during a dissolution. Rankings then stop refreshing. An unknown action prints `Action '<x>' not known` and exits 0.
To run one action by hand (CHANGES PRODUCTION): `cd /srv/www/<stage>/current/twfy/scripts && ./mpinfoin.pl links`.

## Symptom: every parser script fails reading the configuration

The parser reads database settings from its own `configuration.yml` if all four database fields are set. Otherwise `rblib/config.rb` starts PHP to read `twfy/conf/general`.
**Any output from PHP before the options are read, such as a deprecation warning, makes that read raise** `failed to read options`. This was reproduced on PHP 8.3.
Other messages: `unable to locate PHP binary`, `bad option output from subprocess`, `end of file reached` (PHP wrote nothing, or failed with errors hidden), and `No value for '<KEY>' ... and no default specified` (a key missing from `shared/general`).
**Diagnose (READ-ONLY)** Run `php -r "require '/srv/www/<stage>/shared/general';"` as `deploy`, and read what it prints. See [Deploy and rollback](deploy-and-rollback.md#library-errors) for the full list.

## Symptom: a member photo is missing

The downloader (`PeopleImageDownloader`) does not use any cache. It skips a person only if **all three** files exist: `images/mps/<person id>.jpg`, `mpsL/<person id>.jpg` and `mpsXL/<person id>.jpg`. The old advice to clear `html_cache/member_images` does nothing, because nothing reads `html_cache` any more.

**Fix (CHANGES PRODUCTION)**

1. Delete that person's three jpg files under `/srv/www/<stage>/shared/images/` (`mps`, `mpsL` and `mpsXL`). Undo: not possible, but the next run downloads them again.
2. Run `cd /srv/www/<stage>/current/openaustralia-parser && ./bin/run member-images.rb`. `--limit=N` counts photos actually downloaded, and `--output-dir=<scratch directory>` tests without touching the live images.
3. Check the member's page. The photo reaches They Vote For You the next day.

**The run can abort part-way.** People are processed in surname order, and only a 403 response is retried (up to ten times, with growing delays). Any other failure prints `Unable to retrieve response_code N` and aborts, so **one new member whose photo is not published yet can stop everyone after them**. A body that is not an image raises `Magick::ImageMagickError`. People with a blank `aph id` and no photo take an old bio-page route, and if no page is found, a bug in `lib/people_image_downloader.rb` (a name used before it is set) raises `NoMethodError` and aborts. `people.csv` has about 120 such rows.
UNVERIFIED: what APH returns when a person has no photo yet.
To see how many are missing: compare `ls /srv/www/<stage>/shared/images/mps | wc -l` with the number of people in `people.csv`.

## Symptom: postcode lookups are wrong or empty

`postcodes.rb` **cannot run**: `Postcodes.new.run` is called with no arguments, but `initialize` needs one, so every direct run fails with `ArgumentError: wrong number of arguments (given 0, expected 1)`. Its spec only passes because it supplies the argument itself. Do not rely on any instruction to "re-run `postcodes.rb`" until that is fixed.
If it did run, it would `DELETE FROM postcode_lookup` and then insert everything in one statement with no transaction, so a failed load would leave the table empty, and an empty table means every postcode lookup returns nothing.

`parse-postcodes.rb` rebuilds `data/postcodes.csv` from the third-party morph.io scraper `drzax/morph-division-postcode-correspondence`. It writes only after a 200 and a non-empty body, so a bad key keeps the old file. Run it locally and ship the new CSV by pull request, because on the server it writes inside the release directory. `HTTP ERROR ... check your morph.io API key` can only appear for a 200 with an odd body: a rejected key shows as `Mechanize::ResponseCodeError 401`, and that text contains the key.
The load checks that every CSV electorate exists in `representatives.csv` (`Constituency <name> not found`). It checks names in any period, so rows for abolished divisions still pass.

**Diagnose (READ-ONLY)** Count rows in `postcode_lookup`, and group by electorate: `SELECT name, COUNT(*) FROM postcode_lookup GROUP BY name`. About 569 postcodes map to more than one electorate, and the PHP returns the list. For what is out of date, see [After an election, and yearly tasks](after-an-election-and-yearly-tasks.md).

## Known gaps

- A `parse-members.rb` run that fails its database load exits 0. See [Daily Hansard parse](daily-hansard-parse.md#the-database-load-can-fail-without-anyone-noticing).
- UNVERIFIED: whether a missing member row stops the day parse or only degrades what the site shows. The day parse reads the CSV files from the deployed checkout, so it needs only the deploy.
- UNVERIFIED: the production value of `PUBLICWHIP_HOST`.

**Escalate**: tell the on-call engineer. Wrong party, wrong seat or a missing sitting member on a public page is wrong public data. The CEO signs off any correction notice.
