# Daily workflow

## Start
1. Open Windows Terminal.
2. `wsl`
3. `platformctl doctor`
4. Start no containers until a project requires them.

## Project work
1. `cd ~/src/company/<repo>`
2. `code .`
3. Reopen in Dev Container.
4. `task bootstrap`
5. `task dev`
6. Make the smallest useful change.
7. `task verify`
8. Commit and push.
9. CI runs equivalent checks.
10. Deploy through pipeline.

## Incident
1. Diagnose from WSL, not an application container.
2. `platformctl incident collect --host <target> --port <port>`
3. Preserve evidence.
4. Form/test hypothesis.
5. Remediate through controlled mechanism.
6. Verify.
7. Add prevention/automation.

## Learning
1. Create a lab repo under `~/src/labs`.
2. Put the environment in `.devcontainer`.
3. Put dependencies in Compose profiles.
4. Document conclusions.
5. Convert useful outcomes into standard/module/runbook/tooling.
6. Destroy lab containers when finished.
