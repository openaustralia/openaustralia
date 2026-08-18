# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings
used in this repo's issue tracker. This repo keeps the default vocabulary, so both columns match.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (for example "apply the AFK-ready triage label"), use the corresponding label string
from this table.

Edit the right-hand column to match whatever vocabulary you actually use.

## Other labels in this repo

These sit outside the five canonical roles and the skills don't read them. Leave them alone unless you are
deliberately triaging with them:

- `needs-dev-env` for issues that can only be verified with a working development environment. Given the state of
  the local Vagrantfile and `docker.sh` (see `AGENTS.md`), a fair number of issues sit here.
- `stale` for probable close candidates from a triage sweep, pending human confirmation.
- Type and area labels such as `bug`, `task`, `New feature`, `improvement`, `parser`, `web app`, `votes`, `API`.
