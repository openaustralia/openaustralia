# Alerts and email

People subscribe to email alerts about what their representatives say. `twfy/scripts/alertmailer.php` sends them on weekday mornings (10:00, Australia/Sydney, production only), after `morningupdate` has loaded and indexed the day.
Outgoing mail goes through the host mail agent to the OAF Postal server. Postal tells the site about permanent failures through a signed webhook, and the site then **suppresses** that address.
Terms (suppression, lift, index batch): [`CONTEXT.md`](../../CONTEXT.md) and `twfy/CONTEXT.md`.

How it decides what to send:

- `alerts-lastsent` holds two lines: a Unix time, then the last index batch sent. The alertmailer builds a query for every batch after that one, and for each alert it sends only what is newer.
- It writes the file back at the end of a run.
- It skips suppressed addresses and counts them (`Suppressed addresses skipped: N` in its stats mail).
- It skips items older than a maximum age (`AlertMaxAge`).
- It reads and writes `alerts-lastsent` **in the current directory**, so run it from `twfy/scripts`.
- It takes no lock. Two runs at once can send twice.

`alerts-lastsent` on the server is `/srv/www/<stage>/shared/alerts-lastsent` (linked into `current/twfy/scripts`).
Flags:

| Flag | Effect |
|---|---|
| `--nomail` | Plans and prints, sends nothing, and leaves `alerts-lastsent` alone |
| `--only=<email>` | Handles one address. It also leaves `alerts-lastsent` alone and sends no stats mail |
| `--from=<email>` | Skips every address that sorts **at or before** it (lower-cased). Alerts are handled in address order |
| `--to=<email>` | Skips every address that sorts at or after it |

`--from` and `--to` do **not** protect `alerts-lastsent`: a run with only those flags sends, **rewrites `alerts-lastsent` to the latest batch and the current time**, and sends the stats mail. Only `--nomail` or `--only` leave the file alone.
`--only` with `--from` or `--to` prints `Can't have both from/to and only!` and exits with status 0.
If `alerts-lastsent` is missing, the mailer warns and starts from today at 00:00 and batch 0, which builds a query over every batch.
Items older than 8 weeks (`AlertMaxAge`), items before 2008-01-14, and items in `gidredirect` are skipped, and at most 3 items are shown per section and per alert.

## Symptom: alert emails did not go out

**Diagnose (READ-ONLY)**

1. Did the 10:00 job run? Check the Sentry cron monitor and `/srv/www/<stage>/log/alertmailer.log`. See [Cron and monitoring](cron-and-monitoring.md).
2. Did the morning parse and index finish first? Alerts only cover indexed batches. See [Daily Hansard parse](daily-hansard-parse.md) and [Search index](search-index.md).
3. Read `alerts-lastsent`. A second line that is ahead of the real last batch (`select max(indexbatch_id) from indexbatch`) means someone bumped it to skip alerts, and the next batches are fine.
4. Look at the stats mail from the last run. A large `Suppressed addresses skipped` figure points to a delivery problem. See below.

**Fix (CHANGES PRODUCTION)** If the job failed **before it sent anything**, re-run it. If it failed **part-way**, do not simply re-run it: there is no record of who was already emailed, so a plain re-run emails the earlier addresses again.
Read `alertmailer.log` and the stdout email for the last `SEND n : Sending email to <address>` line, and resume after that address with `--from=<that address>` (lower case). Use `--nomail --from=<address>` first, to see what it would do.

```
cd /srv/www/<stage>/current/twfy/scripts
php -q alertmailer.php --nomail     # first, to see what it would do
php -q alertmailer.php
```

Check after any run that `alerts-lastsent` has the batch you expect.


Check: the stats mail, and one test subscription. Undo: sent email cannot be unsent.
Do not run it while another copy is running. Check with `pgrep -fa alertmailer`.

## Symptom: alerts went out twice, or for old debates

Cause: a second run, or reloaded old days. Every reload gives the day's items a new index batch, and the next alert run treats them as new.

**Stop it before it happens (CHANGES PRODUCTION).** The bump skips *every* batch up to the number you set, including real ones, so the timing matters.

1. Do the reload and the re-index **after the 10:00 `alertmailer` run has finished, and before the next 09:05 `morningupdate`**. By then every genuine batch has already been emailed.
2. Check the highest batch with `select max(indexbatch_id) from indexbatch`.
3. Set the first line of `alerts-lastsent` to the current time (`date +%s`) and the second line to **exactly that highest batch number**. Do not add one: the next genuine batch is `max + 1`, and the mailer would skip it.
4. Run `php -q alertmailer.php --nomail` and confirm it plans no old items.

If you must reload between 09:05 and 10:00, today's genuine batch may already be indexed, and bumping would skip its alerts too.
In that case use the manual date check in the script instead. The parser README explains it, under "Skipping email alerts after fixing a scraper failure".

**Escalate**: an alert sent in error is public-facing. Tell the on-call engineer at once. The CEO signs off any apology or correction notice to subscribers.

## Symptom: one person has stopped getting alerts

Check for a **suppression**. Postal marks an address as suppressed after a hard bounce, and the site stops sending until someone lifts it.
Their alerts are never deleted. Following a confirmation link does **not** lift a suppression.

**Diagnose (READ-ONLY)** `select * from email_suppressions where email = '<address>'` (use a fictional address in your notes, never paste a real one into a ticket).
Confirm with the person that their mailbox now works.

**Fix (CHANGES PRODUCTION)**

```
cd /srv/www/<stage>/current/twfy/scripts
php lift-suppression.php person@example.org
```

It keeps the suppression row with the time it was lifted. Alerts resume at the next run.
Undo: a further hard bounce suppresses the address again.
Do not use `import-suppressions.php`. It is a one-off bulk import that handles personal data.

## Symptom: the Postal webhook returns errors

The endpoint is `/postal/event` (`twfy/www/docs/postal/event.php`).
It verifies a signature using keys that it fetches from Postal and caches in the system temporary directory.

| Response | Meaning |
|---|---|
| 403 | The request was unsigned or the signature failed |
| 503 | The site could not fetch Postal's signing keys. Postal will retry |
| 405 | Not a POST |
| 200 | Handled, or deliberately ignored (it logs which) |

What creates a suppression: only the events `MessageBounced` and `MessageDeliveryFailed`, for mail that carries an `X-Postal-Tag` of `alert`, `confirmation`, `password` or `notice` (anything else is "ignored, not mail we tagged").
A `MessageDeliveryFailed` whose reply starts with a 5.7.x code is ignored, because it blames our server and not the address. That rule does not apply to `MessageBounced`.
A failure older than the last lift is ignored. A bounce of a confirmation or password email also suppresses **alerts** for that address.
A suppression only stops mail of the `alert` kind. Confirmation, password and notice emails are still sent to a suppressed address.
Postal's signing keys are cached in the system temporary directory for 15 minutes (a failed fetch for 60 seconds).
The log lines contain no address.

**Diagnose (READ-ONLY)** Check that the web server can reach Postal's key address, and that `POSTAL_JWKS_URL` in `conf/general` is unset or correct. It is unset on production, so the default Postal address in `event.php` applies.
The Apache production and staging virtual hosts both rewrite `/postal/event` to `event.php`, which keeps a POST from being redirected.
Webhook deliveries and retries are in Postal's own admin pages (the [infrastructure repository](https://gitlab.com/openaustralia/infrastructure) has the Postal documentation in `docs/POSTAL.md`).

## Known gaps

- The mail charset is hard-coded as `iso-8859-1`, while the database is `utf8mb4`.
- On production, mail goes out through `msmtp` (`/etc/msmtprc`), and there is no mail catcher (`~deploy/log/mail` does not exist). Checked on the server. UNVERIFIED for staging, which can be set to catch mail instead of sending it. If staging shows no mail, look in `~deploy/log/mail/`.
- `scripts/fawkesuser/handlemail` is dead code (it begins with `exit;`). Bounces are handled only by the webhook.
