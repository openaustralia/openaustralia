# OpenAustralia.org.au umbrella repository

The deployment and operations repository for OpenAustralia.org.au. It pins the code for the site, the Hansard parser and four small libraries, and deploys them together.
This file defines the words the [runbooks](docs/runbooks/README.md) use. It holds terms only. For procedures, read the runbooks.
The web application has its own glossary in `twfy/CONTEXT.md` (suppression, lift, paused).

## Language

### Parliamentary data

**Hansard day**:
The record of one house sitting on one date, in the official transcript published by the Australian Parliament House (APH). Each day has a House of Representatives record and a Senate record.

**House**:
The House of Representatives or the Senate. In the parser and the database the Senate is stored under the older UK name "lords" in places.

**Proof**:
A Hansard day that APH has published in draft, which may still change. The parser records it so the text can be fetched again when it is final.

**Members**:
The people who have sat in either house, with their periods of service, parties and ministerial roles. They come from CSV files in the parser, not from APH.

### Data stages

**RAWDATA**:
The directory that holds the parser's output: `origxml`, `rewritexml` and `scrapedxml`. On the server it is `shared/pwdata`, and it is also what the data site publishes.

**origxml**:
The XML exactly as fetched from APH, kept as a cache. An empty file means "no data for that day".

**rewritexml**:
The origxml after the parser has rewritten APH's format into the shape the rest of the system reads. Regenerated on every run.

**scrapedxml**:
The final per-day XML that the database load reads, and that the data site publishes.

**PWMEMBERS**:
The directory that holds the members XML files (`people.xml`, `representatives.xml`, `senators.xml`, `ministers.xml`, `divisions.xml`).

### Search and alerts

**Index batch**:
A numbered record made each time the search index run adds anything. Documents are tagged with their batch, and the alert emailer sends only items from batches after the last one it sent.

**`alerts-lastsent`**:
A two-line state file for the alert emailer: a Unix time, then the last index batch sent. Editing it is how people stop alerts going out for reloaded old days.

**searchdb**:
The Xapian search index directory (`XAPIANDB`). `searchdb-lastupdated` beside it records when indexing last ran.

### Deployment

**Stage**:
`production` or `staging`. Both run on one server, in separate directories under `/srv/www/`, with separate databases.

**Release**:
One deployed copy of the code, in `releases/<timestamp>`. The `current` symlink points at the live one, and five are kept.

**Shared directory**:
`/srv/www/<stage>/shared`. It holds config, data, feeds and images that survive from one release to the next, and is linked into each release.

**Pointer bump**:
Moving a submodule's pinned commit forward in this repository. Dependabot opens one for each lagging submodule, daily. A merged bump to `main` deploys to staging.

**Parse**:
Turning Hansard or member data into XML, and loading it into the database. The scheduled morning parse covers one working day.
