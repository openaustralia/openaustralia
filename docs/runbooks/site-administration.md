# Site administration

How to handle comments, people's accounts, email alerts, API keys and privacy requests on OpenAustralia.org.au.
Most of this is done in the admin pages at `/admin/`, and the rest needs SQL by hand on the server. Terms: [`CONTEXT.md`](../../CONTEXT.md).
Never copy a person's email address, name or comment text into a ticket, chat or this repository. Refer to the row (user id, alert id, comment id) instead.

## Who can do what

People have one of these statuses: Viewer, User, Moderator, Administrator, Superuser.

- A **Moderator** can delete comments.
- Only an **Administrator** or **Superuser** can open the admin section (`viewadminsection`).
- Editing another person's account (`edituser`) needs a higher status than a Moderator.
- Nothing in the code creates the first administrator, so the first one needs SQL (`UPDATE users SET status = ... WHERE user_id = ...`). A Superuser can set any person to Superuser from the edit page, so keep the number of Superusers small.

## The admin pages

| Page | Use |
|---|---|
| `/admin/` | Find and list people |
| `/admin/comments.php` | The latest 50 comments |
| `/admin/reports.php` and `report.php` | Reports on comments, and the page to act on one |
| `/admin/badusers.php` | People flagged as problems |
| `/admin/alerts.php`, `alert_stats.php` | Alert subscriptions and their statistics |
| `/admin/glossary_pending.php` | Glossary terms people have proposed |
| `/admin/glossary.php` | Existing glossary terms |
| `/admin/statistics.php`, `searchlogs.php`, `popularsearches.php`, `failedsearches.php` | Site and search statistics |

## Comments

A comment is **never deleted** from the database. Deleting one in the admin pages sets `comments.visible` to 0, and it can be set back.
People can report a comment, and a report emails the `REPORTLIST` address and acknowledges the reporter. Anyone can report, including people who are not logged in, who give a name and email. The only limit on reports is 20 seconds between reports from the same logged-in person.

**A stuck report lock.** When a moderator opens a report it is locked, and the code that unlocks it (`COMMENTREPORT::unlock()`) is never called. Every other moderator then sees "Someone else was examining this report at <time> so you can only look at it...", and the lock never expires.
Fix (CHANGES PRODUCTION): in `commentreports`, set `locked` and `lockedby` to NULL on that report's row. Undo: set them back. Tell the moderator who locked it.

**Switching comments off.** `ALLOWCOMMENTS` in `twfy/www/includes/easyparliament/init.php` is a constant in code, not a setting. Turning comments off means a code change by pull request, pointer bump and deploy (see [Deploy and rollback](deploy-and-rollback.md)). People then see "Sorry, the posting of comments has been temporarily disabled."

## People's accounts

- Edit an account at `/user/?pg=editother&u=<user id>`. It can change the email, the status, `deleted` and `confirmed`. Setting the status to Viewer removes the ability to comment or add glossary terms.
- **"Deleting" an account is a soft delete** (`users.deleted = 1`). There is no hard delete anywhere in the site. A person whose account is deleted, or whose password changes, is logged out, because the login cookie includes a hash of the password.
- **Changing an email** updates `users.email` and also `alerts.email` for that address. The new address is **not** asked to confirm, and `email_suppressions` is not touched, so an old suppressed address stays suppressed. See [Alerts and email](alerts-and-email.md).
- A person can reset their own password at `/user/password/`. There is no administrator reset.

## Email alerts

- To stop alerts for an address, run `scripts/delete-alerts` from `twfy/scripts` with addresses on standard input, one per line (CHANGES PRODUCTION): it runs `update alerts set deleted=1 where email=?` and prints the number of rows changed for each address. There is **no dry run**.
  Check one address first: `select alert_id, deleted from alerts where email = '<address>'`. Undo: set `deleted` back to 0.
- An alert is only flagged as deleted. Signing up again, or following an undelete link, switches it back on. Unconfirmed alerts are never purged.
- The links in alert emails are `/A/<id>-<token>` (confirm), `/D/<id>-<token>` (delete) and `/U/<id>-<token>` (user confirm). The Apache rewrite rules for them are in the infrastructure repository. The one-click unsubscribe link in alert emails posts to `/alert/unsubscribe/?t=<id>-<token>` and deletes **all** the alerts at that address, and a plain visit asks first.
- A person who stopped getting alerts may be **suppressed** after a bounce. See [Alerts and email](alerts-and-email.md).

## API keys

- A logged-in person makes their own key at `/api/key`. There is no administrator page for keys.
- **There is no rate limit and no revoke.** The code only checks that a row exists in `api_key`. The `disabled` column exists, but nothing reads it, so setting it does nothing. To revoke a key, delete its row (CHANGES PRODUCTION): `delete from api_key where id = <id>`. Undo: not possible, so note the key's owner and `created` first.
- Each call is logged in `api_stats` (the key is removed from the stored query, but the IP address is kept). Nothing deletes old rows.
- API errors come back with HTTP 200 and a text message: `No API key provided`, `Invalid API key.`, `No parameter provided to function "<method>"`.

## The glossary

Terms people propose go to a queue (`editqueue`). Approve or decline them at `/admin/glossary_pending.php`.
**Deleting a term at `/admin/glossary.php` is permanent** (`DELETE FROM glossary`).

## Bots and abuse

Bot and abuse handling is done in front of the site (Cloudflare or the web server), through the infrastructure repository, not in the application. `robots.txt` disallows `/pwdata`, `/user` and `/search`.

## Privacy requests (access, correction, deletion)

> **Proposal, not yet agreed.** The rest of this section describes what exists and a suggested process. Who decides a deletion, and how long data is kept, are policy decisions for the CEO that have not been made. Treat the steps below as a draft until they are confirmed.

Personal data is in these places:

| Table | Personal data |
|---|---|
| `users` | Name, email, registration IP address, password hash |
| `alerts` | Email address |
| `comments`, `commentreports` | Comment text, and a name and email on anonymous reports |
| `api_key`, `api_stats` | The key's owner, and the IP address of each call |
| `search_query_log` | The IP address of searches |
| `email_suppressions` | Email address and a reply excerpt from the receiving mail server |
| `glossary`, `editqueue`, `uservotes` | The person's user id |

There is **no export tool, no hard delete and no retention job** for any of these. The tools that exist are soft deletes (`users.deleted`, `alerts.deleted`, `comments.visible`) and SQL by hand.
Do not use `export-comments.rb` or `import-comments.rb` in the parser for this: they cannot run (see [Scripts not to run](scripts-not-to-run.md)).

Suggested handling of a request (**proposal**):

1. The on-call engineer finds the rows by user id and email, in a read-only session, and keeps the list of tables and row counts, **not the data**, in the ticket.
2. For correction or soft deletion, use the admin pages and `delete-alerts`.
3. A request that needs rows **removed** goes to the CEO first, because it cannot be undone. UNVERIFIED: no written policy exists for how long data is kept, or when a hard delete is required.
4. The reply to the person is drafted by the engineer and sent only after the CEO signs it off.

**Escalate**: tell the on-call engineer. The CEO decides any hard deletion and signs off any reply about a person's data.
