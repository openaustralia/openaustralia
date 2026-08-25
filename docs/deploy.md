# Deployment

OpenAustralia.org.au is deployed from this repository. The application and its supporting libraries live in six
Git submodules, so their pointers in this repository must be updated before a deployment can include new submodule
commits.

## Update submodules with GitHub Actions

The [Update submodules](https://github.com/openaustralia/openaustralia/actions/workflows/update.yaml) workflow
updates the repository's submodule pointers. It is manually triggered and does not deploy the site.

To run it:

1. Open **Actions** in the `openaustralia/openaustralia` GitHub repository.
2. Select **Update submodules**.
3. Select **Run workflow**, leave the branch set to `main`, and confirm **Run workflow**.

The workflow checks out this repository's `main` branch with all submodules, fetches each submodule's `main` branch,
and compares its latest commit with the commit recorded here. For every submodule that is behind, it updates the
pointer to `origin/main`. If at least one pointer changes, the workflow creates one commit named
`Update submodules to latest main commits` and pushes it directly to this repository's `main` branch.

The commit is attributed to the GitHub user who started the workflow. The workflow uses that user's GitHub username
and account ID to construct their GitHub noreply commit identity. Push access is provided separately by the
workflow's `GITHUB_TOKEN` and its `contents: write` permission.

Only one update workflow runs at a time. If a recorded submodule commit has diverged from, rather than being an
ancestor of, that submodule's `origin/main`, the workflow stops without replacing it. Resolve the divergence
manually before running the workflow again. If all pointers are current, the workflow exits successfully without
creating a commit.

## Update submodules locally

To inspect or update pointers locally, use the Makefile targets:

```bash
make init-submodules
make check-submodules
make update-twfy                 # replace with the submodule reported by check-submodules
```

Each `make update-<name>` target fetches the selected submodule's `main` branch and creates a commit for that pointer.
Review the result with `git status` before pushing it or opening a pull request.

## Deploy

After the required submodule pointers are present on this repository's `main` branch, deploy with the existing
Capistrano targets:

```bash
make staging-deploy
make production-deploy
```

These are live deployment actions. Run them only when intentionally deploying the corresponding environment. See
the repository [README](../README.md#deployment) for environment configuration, member parsing, dependencies, and
other operational details.
