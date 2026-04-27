# Reproducer for renovatebot/renovate#36293

Minimal repository demonstrating the bug fixed by
[renovatebot/renovate#36293](https://github.com/renovatebot/renovate/pull/36293):
when a `registryAliases` key contains a shell variable whose value is
substituted in CI but empty locally (e.g. GitLab's
`CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX` indirected through a project-level
`DEPENDENCY_PROXY` variable), Renovate on `main` skips the dependency with
`skipReason: contains-variable` and never opens a PR.

## Files

- [`Dockerfile`](Dockerfile): `FROM ${DEPENDENCY_PROXY}python:3.13`. The
  `ARG DEPENDENCY_PROXY=...` declaration is intentionally **omitted** so
  the Dockerfile parser does not substitute the variable away (which
  would mask the bug). The only resolution path here is `registryAliases`.
- [`.gitlab-ci.yml`](.gitlab-ci.yml): same pattern via a top-level
  `variables: DEPENDENCY_PROXY: "${CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX}/"`
  indirection, which is a common real-world layout.
- [`renovate.json`](renovate.json):
  `"registryAliases": { "${DEPENDENCY_PROXY}": "docker.io" }`.

## Measured behaviour (LOG_LEVEL=debug, --platform=local --dry-run=lookup)

### On `renovatebot/renovate` `main` (without the fix)

```
"deps": [
  {
    "skipReason": "contains-variable",
    "replaceString": "${DEPENDENCY_PROXY}python:3.13",
    ...
    "updates": []
  }
]
```

Both the Dockerfile and the gitlab-ci dep are skipped → Renovate opens
**zero PRs** for this repository.

### On the PR branch (with the fix)

```
"deps": [
  {
    "depName": "${DEPENDENCY_PROXY}python",
    "packageName": "docker.io/python",
    "currentValue": "3.13",
    "registryUrl": "https://index.docker.io",
    "lookupName": "library/python",
    "currentVersion": "3.13",
    "updates": [
      { ..., "branchName": "renovate/python-3.x" }
    ]
  }
]
```

Both deps resolve to `docker.io/library/python:3.13` (Docker normalises
`docker.io/python` to `docker.io/library/python`). The branch name is
clean, with no `${...}` placeholder leaking into it.

## How to verify locally

```sh
# 1. Get this reproducer.
git clone https://github.com/Wayneoween/renovate-36293-repro.git /tmp/repro

# 2. Get the PR branch and build it.
git clone https://github.com/Wayneoween/renovate.git /tmp/renovate-fork
cd /tmp/renovate-fork
git checkout main           # the PR HEAD lives on main of the fork
pnpm install --frozen-lockfile
pnpm build

# 3. Run against the reproducer.
cd /tmp/repro
LOG_LEVEL=debug RENOVATE_PLATFORM=local RENOVATE_DRY_RUN=lookup \
  node /tmp/renovate-fork/dist/renovate.js 2>&1 \
  | grep -B1 -A8 'skipReason\|branchName\|depName.*python'

# 4. (Optional) repeat from a clean checkout of upstream/main to see the
#    "skipped, no PR" baseline.
cd /tmp/renovate-fork
git fetch https://github.com/renovatebot/renovate.git main
git checkout FETCH_HEAD
pnpm install --frozen-lockfile
pnpm build
cd /tmp/repro
LOG_LEVEL=debug RENOVATE_PLATFORM=local RENOVATE_DRY_RUN=lookup \
  node /tmp/renovate-fork/dist/renovate.js 2>&1 \
  | grep -B1 -A6 'skipReason\|branchName\|depName.*python'
```
