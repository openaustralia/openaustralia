# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, GitHub Copilot, and others) when working with code in
this repository. `CLAUDE.md` and `.github/copilot-instructions.md` point here so the guidance lives in one place.

## What this repository is

The umbrella repository for OpenAustralia.org.au: issue tracking for the whole project, plus the Capistrano
deployment that stitches the site together. Almost no code lives here. The site is six git submodules
(`.gitmodules`): `twfy` (the PHP web app), `openaustralia-parser` (the Ruby Hansard parser), and the libraries
`phplib`, `perllib`, `rblib` and `shlib`. If a change is to application behaviour, it belongs in a submodule's own
repository; what belongs here is deployment, submodule pointer bumps, and cross-cutting issues.

## Setup

- `make init-submodules` then `make init-bundle`. Nothing useful happens without initialised submodules; even the
  deploy has a custom `git:create_release` in `Capfile` because `git archive` drops submodule content.
- Ruby 3.4.9 (`.ruby-version`), but this repo's `Gemfile` is deployment tooling only (Capistrano and friends). The
  deployed runtime is defined by the parser submodule: `config/deploy.rb` reads
  `openaustralia-parser/.ruby-version` and uses `openaustralia-parser/Gemfile`; PHP dependencies come from
  `twfy/composer.json` via capistrano-composer.
- This repository is not a development environment. The README points to `twfy`'s own Docker Compose setup
  (`twfy/README.md`: `make dependencies` → `make docker` → `make docker-db-migrate` → `make docker-db-seed` →
  `make docker-run`) for working on the web app, and to the parser submodule's own README for the parser.

## Commands

```
make init-submodules       # git submodule update --init
make init-bundle           # bundle install (deploy tooling)
make check-submodules      # report which submodules lag their branch
make update-<name>         # fetch/pull a submodule then commit the pointer bump (twfy,
                           # openaustralia-parser, rblib, phplib, perllib - no update-shlib exists)
make staging-deploy        # bundle exec cap staging deploy
make production-deploy     # bundle exec cap production deploy
make staging-parse-members / production-parse-members
```

- The `update-*` targets are interactive (`git add --patch`) and **commit for you**.
- `check-submodules` may suggest `make update-shlib`, which doesn't exist; bump that pointer by hand.
- Dependabot bumps submodule pointers daily (`.github/dependabot.yml`); there is no CI in this repo.

## Deployment

Capistrano 3, defined in `Capfile` and `config/deploy.rb`, stages `production` and `staging`
(`config/deploy/*.rb`) - both on the same host (`openaustralia.org.au`), differing only by `deploy_to` path. The
deploy keeps a `cached-copy` with submodules initialised, symlinks shared config into the release
(`twfy/conf/general` and `openaustralia-parser/configuration.yml` live in `shared/`, not in git), compiles
`twfy/scripts/run-with-lockfile`, runs Phinx migrations inside `twfy`, and restarts Apache with sudo.
`scripts/tag-prod.sh` / `tag-staging.sh` **force-push** the `PRODUCTION`/`STAGING` tags.

Treat every `*-deploy`, `parse:*` and tag command as a live production action: never run one without an explicit,
specific go-ahead for that exact action, right now, however routine the request sounds.

## Gotchas

- Config files (`twfy/conf/general`, `openaustralia-parser/configuration.yml`) don't exist in a fresh checkout;
  they're symlinked from `shared/` at deploy time. Locally, copy each submodule's example file.
- After merging a change in a submodule repo, the pointer here must be bumped (by `make update-<name>` or
  Dependabot) before a deploy picks it up.
- `make staging-deploy`/`make production-deploy` never deploys your local checkout. Capistrano's `git:create_release`
  task clones straight from GitHub on the deploy target, at the branch named by `STAGING_BRANCH`/`PRODUCTION_BRANCH`
  (default `main`). Testing an unmerged branch means `STAGING_BRANCH=that-branch make staging-deploy`, not just
  running the target while that branch is checked out.
- The stack is old in places; check what a file actually targets before assuming modern Ruby/PHP idioms apply.

## Agent skills

Configuration the engineering skills read. These files describe how this repo works; edit them directly rather than
re-running the setup skill.

### Issue tracker

Issues live as GitHub issues in `openaustralia/openaustralia`, driven by the `gh` CLI. See
`docs/agents/issue-tracker.md`.

### Triage labels

The default five-label vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`.
See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and one `docs/adr/` at the root, both created lazily. The submodules are separate
repositories and keep their own. See `docs/agents/domain.md`.

## Contributing

This repository has no `CONTRIBUTING.md` or templates of its own; the org-wide ones in
[`openaustralia/.github`](https://github.com/openaustralia/.github) apply. Fetch the current versions rather than
relying on a copy:

`curl -fsSL https://raw.githubusercontent.com/openaustralia/.github/main/.github/CONTRIBUTING.md`

`curl -fsSL https://raw.githubusercontent.com/openaustralia/.github/main/AGENTS.md`

Any equivalent fetch of those URLs works (web fetch, or `gh api` if the GitHub CLI
is installed); don't assume a particular tool is present.
