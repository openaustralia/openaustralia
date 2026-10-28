# Runbooks

How to diagnose and fix problems with OpenAustralia.org.au.
Find your symptom in the table, then follow the linked runbook.
Terms such as `origxml`, `RAWDATA` and `alerts-lastsent` are defined in [`CONTEXT.md`](../../CONTEXT.md).

## Find your symptom

| What you see | Runbook |
|---|---|
| A deploy failed, or a deploy left the site half updated | [Deploy and rollback](deploy-and-rollback.md) |
| A day of debates is missing from the site | [Daily Hansard parse](daily-hansard-parse.md) |
| The morning cron email or Sentry check-in shows a parser error | [Daily Hansard parse](daily-hansard-parse.md), then [Parse failures and patches](parse-failures-and-patches.md) for the fix |
| The parser stops on one day with an error that needs a person: an unknown name, `Not an even number of people in the pairs voting`, `Patch failed`, `Unexpected tag` | [Parse failures and patches](parse-failures-and-patches.md) |
| The parser fails on every date, before it parses anything | [Parse failures and patches](parse-failures-and-patches.md#data-file-errors-at-startup) |
| You have fixed the data or written a patch and the day still fails the same way | [Parse failures and patches](parse-failures-and-patches.md#patches) (the cached XML bypasses a patch) |
| A member is missing, has the wrong dates, or a division fails with "Couldn't figure out who" | [Members and links](members-and-links.md) and [Daily Hansard parse](daily-hansard-parse.md) |
| A member photo is missing | [Members and links](members-and-links.md) |
| New debates are on the site but search does not find them | [Search index](search-index.md) |
| Search returns nothing at all | [Search index](search-index.md) |
| Alert emails did not go out, went out twice, or went out for old debates | [Alerts and email](alerts-and-email.md) |
| One person says they stopped getting alerts | [Alerts and email](alerts-and-email.md) |
| A migration failed, or the schema in CI differs from `db/schema.sql` | [Database and migrations](database-and-migrations.md) |
| You need to restore files or the database | [Backups and restore](backups-and-restore.md) |
| A Sentry cron monitor failed, or you need to find a log | [Cron and monitoring](cron-and-monitoring.md) |
| A Dependabot bump or a library change broke something | [Deploy and rollback](deploy-and-rollback.md#pointer-bumps-dependabot) and [library errors](deploy-and-rollback.md#library-errors) |
| A comment, account, alert, API key or privacy request needs handling | [Site administration](site-administration.md) |
| A federal election, a redistribution or the new year is coming | [After an election, and yearly tasks](after-an-election-and-yearly-tasks.md) |
| You found a script and are not sure it is safe | [Scripts not to run](scripts-not-to-run.md) |

## How the system fits together

```
APH (parlinfo.aph.gov.au)
   |  openaustralia-parser: parse-speeches.rb   (weekdays, via morningupdate)
   v
RAWDATA/scrapedxml/*.xml  ----------------------> served as the data site
   |  twfy/scripts/xml2db.pl
   v
MySQL (RDS) --> twfy PHP site (Apache)
   |  twfy/search/index.pl
   v
Xapian index (searchdb) --> search, and alert emails (alertmailer.php)
```

Members, links and postcodes follow the same route from CSV files and web pages, through `parse-members.rb`, `parse-member-links.rb` and `postcodes.rb`.
The servers, cron jobs, backups and monitoring are defined in the [`openaustralia/infrastructure`](https://gitlab.com/openaustralia/infrastructure) repository on GitLab. Its old GitHub copy is archived and read-only.
This repository holds the deploy tooling and pins the code (`twfy`, `openaustralia-parser` and four small libraries) as git submodules.

## Conventions

- **READ-ONLY** steps only look at things. Run them freely.
- **CHANGES PRODUCTION** steps alter live data or services. Each one says what it affects, how to check it worked and how to undo it.
  Do not run one without an explicit go-ahead for that exact action, right now. The same rule covers every `make *-deploy`, `cap`, `parse:*` and tag command.
- **UNVERIFIED** marks a fact that could not be confirmed from the code or the infrastructure repository. Check it before relying on it, then fix the runbook.
- Commands that name a stage use `<stage>`, which is `production` or `staging`. Staging shares one server with production, and its cron jobs are switched off.
- Paths are on the server under `/srv/www/<stage>/`. `current` is the live release, `shared` holds data that survives deploys and `log` holds logs.
- Code references give a file and a function or error text to search for, not line numbers, because the submodule pointers change daily.

## Who to tell

Each runbook ends with an Escalate line. It names roles, not people.

- **On-call engineer**: owns the fix. Start here for every problem on this page.
- **CEO**: signs off any public statement, status notice or correction text before it goes out. This covers wrong or missing parliamentary data, an outage people notice, and any alert email sent in error.
  The engineer drafts the wording and the CEO approves it. Corrections state what was wrong and what was fixed. They do not comment on any party, member or position.

## Keeping these runbooks accurate

Runbooks drift. When you fix something that the runbook got wrong, change the runbook in the same pull request.
Known gaps are listed under UNVERIFIED in each file, and the follow-up issues are tracked in `openaustralia/openaustralia`.
