# Search index

Search uses a Xapian index. `twfy/search/index.pl` (Perl, `Search::Xapian`) writes it and the PHP site reads it through the Xapian PHP bindings.
The index lives at `XAPIANDB`, which is set in `twfy/conf/general` to `/srv/www/<stage>/shared/search/searchdb`.
The same directory also holds `searchdb-lastupdated`, a small file with a Unix time.

Each indexing run that adds anything records a numbered **index batch** and tags the documents `batch:N`. The alert emailer reads those batches. See [Alerts and email](alerts-and-email.md).
Terms: [`CONTEXT.md`](../../CONTEXT.md).

## How the index is kept up to date

| When | What | Command |
|---|---|---|
| Weekday mornings, inside `morningupdate` | Index what changed since the last run | `index.pl "$XAPIANDB" sincefile "$XAPIANDB/../searchdb-lastupdated"` |
| Sundays, inside `weeklyupdate` | Compact the index with `xapian-compact` (`compactsearchdb`). **Not currently running:** `weeklyupdate` fails before it gets there. See "Known fault" below | `./compactsearchdb` |

`sincefile` indexes rows whose `hansard.modified` is at or after the time stored in `searchdb-lastupdated`, then writes the new time.
**If that file does not exist, `sincefile` indexes everything.** That is slow and uses a lot of memory, so do not delete the file casually.

`index.pl` actions: `all`, `lastweek`, `lastmonth`, `daterange <from> <to>`, `sincefile <file>`, `check`. An optional last argument, a number, restricts a run to one section, for example `daterange <from> <to> 101` for the Senate. `cronquiet` as the last argument silences output.

**Take care with `index.pl`:**

- **A mistyped database path silently creates a new, empty index there.** The script opens the index with create-or-open and only checks that the argument is not empty. Combined with `all`, or with `sincefile` and a missing timestamp file, it then indexes everything into the wrong place. Copy the path from `XAPIANDB`, and run `ls` on it first.
- **`check` deletes.** It opens the index for writing and deletes every document whose term is not in MySQL. The "needs adding to Xapian indexing" lines are only printed, and nothing is added. It takes the write lock, so it cannot run with an indexer. `search/indexall.sh` ends with `check`, so running it deletes too.
- Only one writer at a time. A second indexer, or `check`, fails with `DatabaseLockError`.
- An empty run (nothing changed) creates no new index batch.
`all` can leak memory and fail. Index by `daterange` in chunks instead. `search/indexall.sh` is a leftover from the UK site (it loops 1999 to 2007). Do not use it.

## Symptom: new debates are on the site but search cannot find them

**Diagnose (READ-ONLY)**

1. Did `morningupdate` get as far as indexing? Read `/srv/www/<stage>/log/morningupdate.log`. A parse failure stops the job before the index step. See [Daily Hansard parse](daily-hansard-parse.md).
2. Was the index step skipped? The log says `SKIPPED Xapian indexing: XAPIANDB is blank` if `XAPIANDB` is empty.
3. Compare the date in `searchdb-lastupdated` (`date -d @$(cat .../searchdb-lastupdated)`) with the date you expect.

**Fix (CHANGES PRODUCTION)** Index the missing days explicitly. The action and the two dates are separate arguments:

```
cd /srv/www/<stage>/current/twfy
./search/index.pl "$XAPIANDB" daterange 2018-06-25 2018-08-17
```

Check: search for a phrase from one of those days. Undo: not needed, indexing a day again only refreshes it.
Each run takes a new batch number. If these days are old, skip the alert emails. See [Alerts and email](alerts-and-email.md).

## Symptom: search returns nothing at all

**Diagnose (READ-ONLY)**

- **`XAPIANDB` blank in `conf/general`.** The search class then returns early and every query comes back empty. README text mentions a MySQL fallback, but none was found in the code. UNVERIFIED.
- **The path is wrong.** Check that `ls -l /srv/www/<stage>/shared/search/searchdb` shows a directory with `*.glass` files.
- **Bindings missing.** The PHP page loads the bindings only if the file exists in one of a few standard directories (`xapian.php`). Check the Apache and PHP error log for a missing Xapian class or function. The infrastructure repository compiles the bindings from source, so a PHP upgrade can break them.
- **Compaction swapped the directory.** `compactsearchdb` runs `xapian-compact`, then moves the old index to `searchdb-previous` and the new one into place. If it stops half way there is no live index at the expected path.

**Fix (CHANGES PRODUCTION) after a failed compaction**

1. Check `ls -ld /srv/www/<stage>/shared/search/*`.
2. If `searchdb` is missing and `searchdb-previous` exists, move it back: `mv searchdb-previous searchdb`. Undo: move it again.
3. If both exist, leave them and tell the on-call engineer.
4. Rebuild only as a last resort (below).

## Rebuild from scratch (CHANGES PRODUCTION, slow)

Indexing everything can need a swap file, because a full run uses a lot of memory. The server has one for this reason (see the [infrastructure repository](https://gitlab.com/openaustralia/infrastructure)).
Do not run `index.pl ... all`. Index each month with `daterange`, and run it during a quiet period.
Take a copy of the existing index first (`cp -a searchdb searchdb-before-rebuild`) if you have the disk space.

## Compaction leaves copies behind

`compactsearchdb` leaves `searchdb-previous` after each run, and may leave `searchdb-compacted` if it was interrupted.
They are safe to delete once search works. **Do not delete `searchdb`.**
Check the disk first with `df -h /data`. On 2026-10-21 `/data` was 73% full (5.2 GB free), `searchdb` was 3.0 GB and `searchdb-previous` 2.3 GB.
A compaction writes a full new copy beside the live index, so it needs free space about the size of the index.

## Known fault: weekly compaction has not run since July

Observed 2026-10-21. `weeklyupdate` has exited with status 1 on each of the last 13 Sundays (since 26 July), so `compactsearchdb`, its last step, has not run in that time.
It fails silently, with no error message. Its first step reads the latest English Wikipedia dump date from `dumps.wikimedia.org`, matching `"enwiki/<date>/` with a trailing slash. The page now links `enwiki/<date>` without one, so the match is empty, and `set -e` stops the script inside the command substitution before it can print its own message.
The same failure also stops the weekly refresh of the Wikipedia titles table.
Checked read-only from the server: the page loads (HTTP 200), the script's pattern matches nothing, and a looser pattern matches `enwiki/20261001`.
Until the script is fixed, compact by hand (CHANGES PRODUCTION) only if disk space is a problem, with `./compactsearchdb` from `current/twfy/scripts`, after checking free space as above. The lasting fix is to change the match in `weeklyupdate`, which is a change in the `twfy` repository.

`compactsearchdb` also shares the lock `morningupdate-lockfile`, so it cannot run at the same time as `morningupdate`.
If it ran while the lock was held, it prints `morningupdate or compactsearchdb is already running`.

## Known gaps

- The Capfile links `current/searchdb` to `shared/shared/search/searchdb`, a doubled `shared` that does not exist on either stage. The link dangles and nothing uses it. The real index is at `shared/search/searchdb`, which is a link to `/data/<stage>/search/searchdb`. Checked on the server.
- `compactsearchdb` runs under `set -e`. If another run holds the lock, it exits 100 at once and prints nothing. If the compaction itself fails, the exit status is hidden (see [Cron and monitoring](cron-and-monitoring.md#which-exit-statuses-to-trust)), so check the directories afterwards. It also runs `rm -fr` on `searchdb-compacted` and `searchdb-previous` with `$XAPIANDB` unquoted, so never run it with `XAPIANDB` blank or from the wrong directory.
- The search page (`searchengine.php`) catches no Xapian exception. A missing or unreadable `XAPIANDB` path is an uncaught fatal on every search.
- `search/indexall.sh` (UK years 1999 to 2007, ending in `check`), `breaktest.sh` and `search.pl` are leftovers. Do not run them.

**Escalate**: tell the on-call engineer. If search has been down for people for more than a day, the CEO decides whether to post a notice and signs off the wording.
