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
| Sundays, inside `weeklyupdate` | Compact the index with `xapian-compact` (`compactsearchdb`) | `./compactsearchdb` |

`sincefile` indexes rows whose `hansard.modified` is at or after the time stored in `searchdb-lastupdated`, then writes the new time.
**If that file does not exist, `sincefile` indexes everything.** That is slow and uses a lot of memory, so do not delete the file casually.

`index.pl` actions: `all`, `lastweek`, `lastmonth`, `daterange <from> <to>`, `sincefile <file>`, `check`.
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

`compactsearchdb` also shares the lock `morningupdate-lockfile`, so it cannot run at the same time as `morningupdate`.
If it ran while the lock was held, it prints `morningupdate or compactsearchdb is already running`.

## Known gaps

- UNVERIFIED: `config/deploy.rb` links `current/searchdb` to `shared/shared/search/searchdb`, a doubled `shared`. The server config puts the index at `shared/search/searchdb`. Nothing here depends on `current/searchdb`, but the mismatch needs confirming.
- `compactsearchdb` reads the exit code of the lock check after `exit` handling, so a lock failure may report the wrong code. Read the output, not the exit status.
- The `check` action reports documents missing from the index but does not repair them.

**Escalate**: tell the on-call engineer. If search has been down for people for more than a day, the CEO decides whether to post a notice and signs off the wording.
