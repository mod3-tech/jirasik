---
description: Pre-PR self-review of the current branch (auto-detects base; handles submodules).
agent: branch-review
---

Review the current branch. Optional `$1`: a submodule path, a git range (e.g. `main...HEAD`), or a base branch name. With no arg, auto-detects: if a submodule has branch work it gets reviewed; otherwise the cwd repo is reviewed against its `origin/HEAD`.
