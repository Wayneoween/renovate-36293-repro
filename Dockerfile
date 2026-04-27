# Minimal reproducer for renovatebot/renovate#36293.
#
# Note: there is intentionally NO `ARG DEPENDENCY_PROXY=...` declaration here.
# In a real-world setup the ARG provides an empty default and
# the Dockerfile parser substitutes the variable away before Renovate sees it,
# which hides the bug. Here we keep the variable un-substituted so the only
# resolution path is `registryAliases`, which is the path #36293 fixes.
FROM ${DEPENDENCY_PROXY}python:3.13

CMD ["python", "--version"]
