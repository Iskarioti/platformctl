# __PROJECT_NAME__

Governed LaTeX/Quarto research-paper project created by platformctl.

## Layout

- `paper/main.tex` - the paper itself, `paper/refs.bib` - bibliography (biblatex/biber)
- `paper/figs/`, `paper/tables/` - **generated**, not hand-edited (see `code/`)
- `code/` - scripts that generate figures/tables
- `data/` - inputs (or a DVC/git-lfs pointer for anything large)

## Building

```bash
make paper   # latexmk -pdf, output at paper/main.pdf
make clean   # remove LaTeX build artifacts
```

Quarto (`.qmd`) is also available in this Dev Container if you'd rather
combine code+prose in one document instead of raw LaTeX - render with
`quarto render`.

## Reviewer-facing revision diffs

A submission's revision response usually needs a changed-text PDF, not just
a changelog. `make diff` builds one via `latexdiff` (already in this
template's Dev Container):

```bash
make diff REF=v1-submitted   # any git ref: a tag, branch, or commit
make diff REF=HEAD~5
```

Produces `paper/main-diff.pdf` with insertions/deletions marked inline -
compare the ref's `paper/main.tex` against the current one, without needing
a second checkout. `make clean` also removes it.

## Reference management

[Zotero](https://www.zotero.org) is GUI-only (no official CLI) - export your
library to `paper/refs.bib` (BibTeX/Better BibTeX), or automate it with
[`pyzotero`](https://pyzotero.readthedocs.io) /
[`pyzotero-cli`](https://pypi.org/project/pyzotero-cli/) (`pip install
pyzotero-cli`) if you want scripted export instead of manual.
