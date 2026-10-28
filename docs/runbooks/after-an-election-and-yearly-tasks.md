# After an election, and yearly tasks

Some jobs happen only around a federal election or once a year, so nobody remembers them. This page lists them in order.
Terms: [`CONTEXT.md`](../../CONTEXT.md). The day-to-day failures are in [Members, links, postcodes and photos](members-and-links.md) and [Parse failures and patches](parse-failures-and-patches.md).

The data here is public. Wording of any notice about it is signed off by the CEO, and a change to what the site says about a named person follows the same rule as a patch (see [Parse failures and patches](parse-failures-and-patches.md#before-you-patch-is-it-an-inference)).

## Every year: the recess calendar (before 1 January)

The recess dates that drive the "The Houses of Parliament are in recess" banner and the calendar marking are **hard-coded**, as an array of date ranges in `twfy/www/includes/easyparliament/recess.php`.
**The last range ends 2026-12-31.** From 1 January 2027 the site shows no recess banner and no recess marking until someone adds the 2027 ranges.

Fix (a code change, so it is not instant): add the ranges to `recess.php` in the `twfy` repository from the Parliament's published sitting calendar, with a pull request, a pointer bump here, and a deploy. See [Deploy and rollback](deploy-and-rollback.md). Cite the calendar in the pull request.
`RECESSFILE` in `conf/general` is not read by anything, so pointing it at a file does nothing. `docs/data-updates.md` in the parser mentions the same file.

## Every year or so: the news items

News on the site comes from the `$all_news` array in `twfy/www/docs/news/editme.php`. Adding or removing an item is a code change by pull request, pointer bump and deploy. The CEO signs off the wording.
The sitemap's news step also runs this file, so a PHP notice in it breaks `sitemap.rb` (see [Daily Hansard parse](daily-hansard-parse.md#sitemap)).

## After a federal election or a redistribution

Do these in order. Sequencing matters because of the nightly job at 01:37.

1. **Members' CSV files**, in the order `docs/data-updates.md` gives: `people.csv` first (each new person needs an **upper-case** `aph id`), then `representatives.csv` and `senators.csv` (close the old stints and add the new ones, with four-digit years, and the `SPK`, `CWM`, `PRES` and `DPRES` pseudo-party stints for the presiding officers), then `ministers.csv` and `shadow-ministers.csv`.
   Make the person row and the stint row in the same pull request.
2. **Check them** on your own machine with `./bin/run parse-members.rb --no-load --output-dir=<scratch directory>`. Fix `Can't find <name> for date <date>` (a ministers name with no person on that date) and any overlap or date error. Reasons that are not on the accepted list become `unknown` without an error, so check them against `docs/data-updates.md`.
3. **Get the new people into `people.csv` before the next 01:37 `dailyupdate`.** Otherwise `parse-member-links.rb` fails every night with `NoMethodError: undefined method 'id' for nil`, because morph.io lists a member the file does not know. The register-of-interests and Senate failures show only as a Sentry exception, not on the cron monitor. See [Members, links, postcodes and photos](members-and-links.md#symptom-dailyupdate-fails-or-member-links-are-missing).
4. **Pull request, merge, pointer bump, deploy**, then **load the members**: `make production-parse-members`. See [Members, links, postcodes and photos](members-and-links.md).
5. **The first sitting day.** The Speaker and President stints must exist, or the day parse fails with `Could not find house speaker for date <date>` (or the senate and deputy forms). See [Parse failures and patches](parse-failures-and-patches.md#speakers).
6. **Divisions.** No code change is needed for a new division. Optionally add abolished divisions to `old_divisions` in `parse-members.rb`, only to silence `WARNING: No current member for <division>`.
7. **Photos.** Once the new members are in the CSV, run `member-images.rb`. One new member without a published photo can stop the run for everyone after them. See [Members, links, postcodes and photos](members-and-links.md#symptom-a-member-photo-is-missing).
8. **Postcodes.** `data/postcodes.csv` was last updated on 2022-07-07 (after the 2022 election). It has no rows for `Bullwinkel` (a new 2025 division that is in `representatives.csv`), and it still has rows for the abolished divisions `Higgins` and `North Sydney`.
   The process is to refresh the morph.io scraper, run `parse-postcodes.rb` locally, commit the CSV, bump the pointer, deploy, then load it. **The loader, `postcodes.rb`, cannot currently run**, so a fix to it comes first. Check what the live table holds with `SELECT name, COUNT(*) FROM postcode_lookup GROUP BY name`.
9. **ABC election links.** A new election needs a new block in `parse-member-links.rb` (copy the 2025 one, with the key `abc_election_results_<year>`) **and** a new `abc_election_results_<year>` entry in `twfy/www/includes/easyparliament/page.php`, which lists only 2007 to 2022. So the 2025 links are scraped and stored, but never shown. Both are code changes by pull request.
10. **Rankings.** During a dissolution no House member has a future end date, so `mpinfoin.pl rankings` prints `Failed to find any MPs for rankings ...` and the rankings stop refreshing until the new House sits.

## Things that look like tasks but are not

- `ministers.csv` is not read by the day parse. It matters only to `parse-members.rb`.
- The register of interests: nothing needs running. The member page links to a scan URL stored by `parse-member-links.rb`, and `register-split.rb` is obsolete. Leave `shared/regmem_scan` alone.
- Comments can be switched off with `ALLOWCOMMENTS` in `twfy/www/includes/easyparliament/init.php`. That is a code change by pull request and deploy, not a setting. See [Site administration](site-administration.md).

**Escalate**: tell the on-call engineer. The CEO signs off any public notice about a change to members, divisions or dates.
