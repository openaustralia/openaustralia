# Parse failures and patches

What to do when `openaustralia-parser` cannot parse a day of Hansard, or parses it wrongly, and a person has to step in.
It covers the day-parse path, `parse-speeches.rb`, which `morningupdate` runs. Start with [Daily Hansard parse](daily-hansard-parse.md) to triage a failed morning, then come here for the fix.
Terms: [`CONTEXT.md`](../../CONTEXT.md). Worked examples: #973 (Senate 2026-09-10) and #996 (Senate 2026-10-12), both `Not an even number of people in the pairs voting`.

Run parser scripts with `./bin/run <script>` from `/srv/www/<stage>/current/openaustralia-parser`. `bundle exec ./script.rb` can silently do nothing, because each script only runs when it is the main program.

## How a failure shows up

| Kind | What happens | Where you see it |
|---|---|---|
| **Abort** | `parse_with_retry` prints `ERROR While processing <house> <date>:` and re-raises. The script exits non-zero and Sentry gets the exception. **Nothing is loaded into the database**, including days that parsed fine, and `morningupdate` stops (no index, RSS or sitemap) | stdout (the cron email), `morningupdate.log`, Sentry |
| **Log-only, ERROR** | The parse carries on. The line goes to stdout and the parser log | The cron email and the parser log |
| **Log-only, WARN or INFO** | The parse carries on. The line goes **only** to the parser log, never to the cron email | `/srv/www/<stage>/shared/pwdata/parser.log` |
| **Silent** | No message at all, and the exit status is 0 | Nowhere. See "Cache and fetch problems" |

The loop runs from the latest date back to the earliest, House first and then Senate for each date. On an abort, XML for that house and day is not written. XML for the other house, or for later days, may already be on disk but not loaded.
`parse-speeches.rb` with the wrong number of dates prints `Need to supply one or two dates` and exits 0.

## Find your error

| Error text | Section |
|---|---|
| `Couldn't figure out who <name> is in division (...)` | [Names and speakers](#names-and-speakers) |
| `Unknown speaker "<name>"`, `Can't figure out which person the aph id`, `Found person (...) but not both in the right period and house` | [Names and speakers](#names-and-speakers) |
| `Could not find house speaker`, `Could not find senate president`, `Could not find deputy ... for date`, `More than one match for name`, `speakername can not be nil` | [Names and speakers](#names-and-speakers) |
| `Unrecognised party`, `Couldn't find person`, `State ... is not a valid`, `Division is undefined`, `Birthday ... not valid`, or any error before the first date is parsed | [Data file errors at startup](#data-file-errors-at-startup) |
| `Not an even number of people in the pairs voting` | [Patches](#patches) |
| `Could not determine division result`, `Speaker not found` | [Patches](#patches) and [Names and speakers](#names-and-speakers) |
| `Unexpected tag`, `Unexpected attributes`, `Unexpected value for contents`, `Front title is to short`, `Assertion failed!` | [APH changed its XML](#aph-changed-its-xml) |
| `Patch failed` | [Patches](#patches) |
| A day is missing and there is **no error** | [Cache and fetch problems](#cache-and-fetch-problems) |
| `aph.gov.au returned 403 ... retrying` | [Cache and fetch problems](#cache-and-fetch-problems) |

## Names and speakers

### Divisions (the most common failure)

The message is `<date> <house>: Couldn't figure out who <text> is in division (<where>) <name hash> <details>`. It aborts.
`<where>` is `voting yes`, `voting no`, `voting yes and teller`, `voting no and teller` or `in a pair`.
Read the original `<text>` that comes before "is in division". The hash after it leaves out initials.

The `<details>` tell you which fix applies:

| Details | Meaning | Fix |
|---|---|---|
| `not found (looking in <house>)` | Nobody has that last name or alternative name | Add the person, or an alternative name, to `data/people.csv` |
| `not sitting in <house> - <person> aph_id=... [<house>: <member id> (<from> to <to>), ...]`, with `, NOT <house>` on a stint in the other house | The person exists, but no stint in that house covers the date. Both end dates are inclusive | Correct the dates or the house in `data/representatives.csv` or `data/senators.csv`. A stint that was closed too early is the usual cause |

How a name is matched (`HansardParser#lookup_speaker`, `People#find_people_by_name`, `Name#matches?`):

1. **By APH id first.** The id comes from the speaker's link in the XML, is upper-cased, and is compared with `people.csv`. Each person holds **one** APH id. The ids `10000` and `1000` mean a presiding officer and are ignored.
2. **By title**, for "The Speaker", "The Deputy Speaker", "The President", "The Chairman" and "The Deputy President", through the `SPK`, `CWM`, `PRES` and `DPRES` stints.
3. **By name.** If only one person has that last name (or alternative name), it matches regardless of first name or initials. Otherwise title, first name or initial, middle name and post-nominal must all be compatible, and the person must have a stint in that house on that date.

Some name shapes need a **code change** in `lib/name.rb`, not a data fix:

- Double-barrelled last names are a fixed list: Stott Despoja, Van Manen, Di Natale, Nampijinpa Price.
- Post-nominals are a fixed list (`AM SC AO MBE QC KC OBE KSJ JP MP AC RFD OAM MC CSC`). An unknown one is absorbed into the name, and then it fails to match.
- Recognised titles are the Rt Hon., the Hon., Hon., Dr, Mr, Mrs, Ms, Miss, Senator, Sen and Lady.

### Speakers

| Message | Fatal? | Meaning and fix |
|---|---|---|
| `Unknown speaker "<name>"` | No | The speech is kept, shown on the site without a link (speaker 0). It is ERROR level, so it reaches the cron email, except for eight named offices ("The ACTING DEPUTY PRESIDENT", "The TEMPORARY CHAIRMAN", "The ACTING SPEAKER", "The Clerk", "The ACTING PRESIDENT", "DEPUTY SPEAKER, The", "DEPUTY CHAIR", "TEMPORARY CHAIRMAN, The"), which go to the log only. Add the person or an alternative name to `data/people.csv`, or fix their stint dates, then re-run. **The cache is still valid. Do not delete it** |
| `Can't figure out which person the aph id <id> belongs to` | No | The id is not in `people.csv`, or it is a second id for a person who already has one. The parser falls back to the name |
| `Found person (<name>) but not both in the right period and house` | No | The person exists, but no stint covers that date in that house. Fix the CSV dates |
| `Could not find house speaker`, `... senate president`, `... deputy senate president`, `... deputy house speaker for date <d>` | **Yes** | No `SPK`, `CWM`, `PRES` or `DPRES` stint covers that date. This follows a change of presiding officer. Add or close the pseudo-party stints in `data/representatives.csv` or `data/senators.csv`. See `docs/data-updates.md` in the parser |
| `More than one match for name <name> found` | **Yes** | Initials cannot choose between two people. Add a more specific name or alternative name |
| `speakername can not be nil in lookup_speaker` | **Yes** | A speech has an APH id that does not resolve and no speaker name. Likely an APH data fault. Look at that day's XML, and patch it if needed |
| `The Speaker is not expected in the Senate` (and similar) | No | Logged, and the speaker is not resolved |

### Fixing a names or dates problem (CHANGES PRODUCTION)

1. Edit the CSV files in the `openaustralia-parser` repository. The formats, conventions and one-PR-per-event workflow are in [`docs/data-updates.md`](https://github.com/openaustralia/openaustralia-parser/blob/main/docs/data-updates.md). Make the person row and the stint row in the same PR. Cite your source (the APH profile page, for example).
2. On your own machine, in your checkout, run `./bin/run parse-members.rb --no-load` before opening the PR. It checks the CSV files without loading them. **Do not run it on the server for this**: it still writes the member XML files.
3. Merge it, bump the submodule pointer here, and deploy. See [Deploy and rollback](deploy-and-rollback.md).
4. Load the member data: `make production-parse-members`. See [Members and links](members-and-links.md). UNVERIFIED: whether a missing member row stops the day parse or only degrades what the site shows. The day parse reads the CSV files from the deployed checkout, so step 3 alone is enough for the parser.
5. Re-run the day (see "After the fix").

A names or dates fix does **not** need the cache deleted, because the cached XML is still correct.

## Data file errors at startup

These come from `lib/people_csv_reader.rb` and are raised before any date is parsed, so **they break every date**, not one day.
`parse-speeches.rb` reads only `people.csv`, `representatives.csv` and `senators.csv`. It never reads `ministers.csv` or `shadow-ministers.csv`.

| Error | Fix |
|---|---|
| `Unrecognised party: '<x>', check mapping in people_csv_reader.rb` | Add the abbreviation to `parse_party`. This is a code change, so it needs a PR, a pointer bump and a deploy |
| `Couldn't find person <name>` | A stint row names someone not in `people.csv` |
| `More than one match for name <name> found` | Fill in the `person count` column on the stint |
| `State <x> is not a valid ...` | Use NSW, Tasmania, WA, Queensland, Victoria, SA, NT or ACT |
| `Division is undefined for <name>` | A House row has no division |
| `Birthday <x> not valid for <name>` | Birthdays must be `yyyy-mm-dd`, while stint dates are `d.m.yyyy` |
| A date error or `NoMethodError` in a stint row | Use `d.m.yyyy` with a four-digit year. A two-digit year such as `14.2.18` is accepted silently as the year 18, and then breaks matching |

`parse-members.rb` has extra checks that `parse-speeches.rb` lacks (`From and To date the wrong way round` and the overlap errors). A file can pass the day parse and still fail the member parse.
The first two rows of each CSV file (a header and a blank row) are skipped, and lines starting with `#` are dropped. Keep both.

## APH changed its XML

These abort, and are raised with an exact message:

- `lib/hansard_day.rb`: `Unexpected tag <name>`, `Unexpected value for contents '<x>' of <chamber> tag`, `Front title is to short!`.
- `lib/hansard_speech.rb`: `Unexpected tag <name>`, `Unexpected attributes`, `Unexpected font-style value`, `... font-weight ...`, `... font-variant ...`, `... type value ...`, and `Children of <list> are using the 'label' attribute inconsistently`.
- `lib/hansard_rewriter.rb`: `Assertion failed! speech_node was null while trying to append a speaker`, `Assertion failed! Unknown type <t>`, `Expecting string in process_textnode`.

There are two fixes:

- **A one-off defect in one day's XML**: write a [patch](#patches).
- **A new APH format that will recur** (a new tag or style): change the parser in `lib/`, with a spec, then ship it by PR, pointer bump and deploy. If the new format began on one day, expect every later day to hit it until the code is fixed.

The rewriter only logs (WARN, so log file only) for things it ignores, for example `Unknown attribute class` and `Ignoring para node`. Parsing then carries on, so a change can lose content without any error.
Compare a suspicious day on the site with the APH page.

## Patches

A **patch** is a unified diff against APH's XML text for one day and house. It corrects a mistake in the official record's data so the parser can read it.
It is applied after APH's XML is fetched and cleaned of carriage returns, and before the parser rewrites it.

**The catch: a patch is applied only when the day is fetched fresh from APH.** The patched text is then saved to `origxml`, and after that the parser reads `origxml` and never applies a patch again. Adding, regenerating or deleting a patch has **no effect** on a day that already has an `origxml` file. Delete that file (see below).
For the same reason, `Patch failed` can only appear on a fresh fetch: a new day, a deleted cache, or `--proof`.

### When a patch is the right fix

Use one when APH's own data is wrong or malformed for that day, for example:

- `Not an even number of people in the pairs voting (<n> names)`. The message lists the division, time, APH link and every name in the `pairs` element. Compare `num.votes` in the `pairs` element with the names, and check whether someone listed in the pairs also voted in that division. A pair that includes the placeholder name `Vacancy` is dropped, but only **after** this check, so it does not help with an odd list.
- `Could not determine division result`. It is raised only for a **tied House** division, when the result text matches none of "casting vote with the ayes", "agreed to", "casting vote with the noes", "negatived" or "was not carried".
- `Speaker not found`. A tied House division whose heading does not follow the form "Speaker", a dash, then the name in brackets (or "President" in place of "Speaker"). The tie-breaking Speaker is added to the vote list by name, so a Speaker missing from the data also produces a `Couldn't figure out who ...` for a name that is not in the XML.
- `Patch failed`, or an `Unexpected ...` error caused by a single bad passage.

There are 46 patches in `data/patches/` in the parser, such as `senate.2026-09-10.xml.patch`. Read one first to see the form. The one for 2026-09-10 deletes a single spurious `<name>` line from `<pairs>`.

### Before you patch: is it an inference?

A patch changes what the site shows. Some can be checked against another source, and some cannot.
In #996 the Hansard XML was wrong, the Journals of the Senate (the authoritative record of Senate votes) do not record pairs, and the right fix (remove one name, or add another) could only be inferred.

The rule for any patch that is not backed by a primary source:

1. The pull request **and** the commit message must say it is an inference. They must give the evidence, and the alternative that was considered.
2. A second team member approves it before it is deployed.
3. If the patch changes how a **named person is recorded as voting** (ayes or noes, not only pairs), the CEO signs off as well.

Wording stays neutral and factual. Do not describe a vote, or a member, in any way that suggests a view.

### Create a patch (READ-ONLY until you commit)

1. In your checkout of the `openaustralia-parser` repository, run `./bin/run create_patch.rb <reps|senate> <yyyy-mm-dd>`. It fetches the day, **applying any existing patch**, and writes `original.xml` and `patched.xml` in the repository root. Do not commit those two files.
2. Edit `patched.xml`.
3. Run `diff -u original.xml patched.xml >> data/patches/<house>.<date>.xml.patch`, the command the script prints. The name uses `representatives` or `senate`.
4. Test it in a scratch directory (next section), then open a PR in the parser repository with the rationale above.

If a patch for that day already exists, `create_patch.rb` starts from the already-patched text, and the `>>` appends a second diff. To replace a patch, first move the old file out of `data/patches/`, or `create_patch.rb` will fail on it.

### Test a patch without touching production data

`--no-load` alone is **not** side-effect free: it still writes `origxml`, `rewritexml`, `scrapedxml` and the log under `RAWDATA`.
Use a scratch output directory as well:

```
./bin/run parse-speeches.rb --no-load --output-dir=/tmp/parse-test <yyyy-mm-dd>
```

This fetches from APH (using the allowlisted scraper) and writes only under `/tmp/parse-test`. The first run in a directory has no cache, so it fetches fresh and the patch is applied. **Use a new directory for every test**, or delete `origxml/<house>_debates/<date>.xml` in it first: a second run reads the cached `origxml` and does not apply a revised patch, so it can repeat an old failure or pass without testing the latest patch. It is better run on your own machine in a checkout with the patch in place. UNVERIFIED: this scratch-directory test has not been run on the server.

### Deploy a patch and re-run the day (CHANGES PRODUCTION)

1. Merge the parser PR, bump the pointer here, and deploy. See [Deploy and rollback](deploy-and-rollback.md).
2. On the server, delete the cached XML for that day and house, for example `origxml/senate_debates/<date>.xml` under `/srv/www/<stage>/shared/pwdata/`. **Without this, the patch is never applied and the next run hits the same error.** Undo: not possible, but the next run fetches the day again.
3. Re-run the day. See "After the fix".

### `Patch failed`

The fresh APH XML no longer matches the patch's context, usually because APH republished or corrected that day.

- If APH fixed the underlying error, delete the patch.
- If APH changed other things, regenerate it as above.

`Patch.patch` runs GNU `patch`, which tolerates shifted line numbers and fuzz. It fails only when the surrounding lines differ.

## Cache and fetch problems

Fetched XML is kept per house and day in `RAWDATA/origxml/<house>_debates/<date>.xml`. **An empty file means "parliament did not sit", for ever.**

- `<date> <house>: Link to XML download is missing` is **WARN**, so it is in the parser log only, never the cron email. The parser returns nothing, saves an empty `origxml`, and exits 0.
- A page that starts `Unable to find document` takes the same path with no message at all.
- UNVERIFIED, inferred from the same code: if APH has not published a day by the time `morningupdate` runs (09:05), that day is cached as empty and never retried.
- About half of all `origxml` files are empty on purpose. Confirm the house sat that day before deleting one.

Fix (CHANGES PRODUCTION): delete the one empty file and re-run the day.

Fetch errors: `AphMechanizeAgent.with_backoff` retries 403, 429, 502, 503 and 504, five attempts with delays of 5, 10, 20 and 40 seconds (about 75 seconds in total), then raises. Other codes (404, 500) and network errors are not retried and abort straight away. No file is written on this path. A persistent 403 usually means the allowlisted user agent has stopped working. Tell the on-call engineer.

**Proof-stage days.** APH publishes some days in draft. The parser logs `In proof stage` (WARN, log only) and loads the draft text. The cron run does **not** use `--proof`, so a day cached in proof stage stays at the draft text until someone runs `--proof` or deletes its cache.
Reloading may change identifiers, so it needs `--force` on the database load, and it can send alerts for changed content. See [Alerts and email](alerts-and-email.md).

## parse-speeches.rb options

| Option | What it does |
|---|---|
| Dates | One or two. `today`, `yesterday`, `previous-working-day` or any date Ruby parses. Use `yyyy-mm-dd`. `previous-working-day` uses the server clock and the weekday only |
| `--no-load` | Skips the database load, and prints the command it would have run. Still writes `origxml`, `rewritexml`, `scrapedxml` and the log |
| `--output-dir=PATH` | Writes `origxml`, `rewritexml`, `scrapedxml` and `parser.log` under `PATH` instead of `RAWDATA`. It has its own cache: the first run in a directory fetches fresh, and later runs reuse that `origxml`. A database load still reads `RAWDATA`, so use it only with `--no-load` |
| `--force` | Passes `--force` to `xml2db.pl`, which deletes database rows for the date range that are not in the XML |
| `--proof` | Refetches only days whose XML is marked as proof |
| `--interactive` | On an error, asks `Retry / Patch / Continue / Quit?` (first letter only). **Retry** re-parses from the cache, so it fetches nothing. **Patch** runs `create_patch.rb` and then retries at once, before you have written the patch, so it does not help. Make the patch in another terminal, delete the `origxml`, then choose Retry. **Continue** skips that house and day, but the load still runs for the rest. **Quit** aborts |

## After the fix

1. Re-run the failed day (CHANGES PRODUCTION): `./bin/run parse-speeches.rb <yyyy-mm-dd> [<yyyy-mm-dd>]` from `/srv/www/<stage>/current/openaustralia-parser`. If the run changes the shape of a day that is already loaded, add `--force`.
2. **Check the load, because it can fail silently.** `parse-speeches.rb` ignores the exit status of `xml2db.pl`. Look for these messages, which stop a load but still exit 0:
   - `gid <g> in database not in XML, run again with --force to delete`. The day's shape changed. Re-run with `--force`.
   - `Refusing to even force delete, when there are references in other tables` (after `VITAL ERROR! gid ... needs deleting`). Comments, votes or edit-queue entries refer to a row that is going. Do not force it. Tell the on-call engineer.
   - `Got gid <g> twice in XML file`, and `speech without (sub)heading <id>`.
   Then check the day appears on the site. See [Daily Hansard parse](daily-hansard-parse.md).
3. Index the day. See [Search index](search-index.md).
4. If you reloaded old days, stop duplicate alert emails first. See [Alerts and email](alerts-and-email.md).

## Known gaps

- `data/README`, `CONTEXT.md` and the parser README describe patches only loosely, and the README's failure example still shows `uncaught throw` (the code now uses `raise`).
- The messages `Couldn't calculate speech duration` and `invalid data for <member>` appear in old issues (#640, #638) but nowhere in the current parser. `calculate_speech_durations` never raises or logs.
- UNVERIFIED, read in code and not reproduced: a malformed time string (for example `1530`) could raise `ArgumentError` during duration calculation, and an empty speech by an unknown speaker could raise `NoMethodError`.

**Escalate**: tell the on-call engineer. A missing sitting day, or a patch that changes how a named person is recorded as voting, is public-facing data. The CEO signs off any correction notice, and any patch of that kind (see "Before you patch").
