# Engineering Agent Instructions

Operate only inside this repository unless explicitly authorized otherwise.

Required workflow:
1. Read README and relevant docs/ADRs before making architectural changes.
2. Make the smallest change that satisfies the requirement.
3. Never read, print, copy, commit, or modify secrets/private keys/production credentials.
4. Use project commands instead of inventing alternate workflows.
5. Run `task lint`, `task type`, and `task test` while iterating.
6. Run `task verify` before declaring work complete.
7. Review `git diff` and identify risks/regressions.
8. Do not deploy to production from this environment.
9. Infrastructure changes must be proposed through code/PR.
10. Destructive operations require explicit human approval.
