.PHONY: paper clean diff

paper:
	latexmk -pdf -interaction=nonstopmode -halt-on-error -cd paper/main.tex

clean:
	latexmk -C -cd paper/main.tex
	rm -f paper/main-diff.tex paper/main-diff.pdf paper/.main-old.tex

# Reviewer-facing changed-PDF, e.g. for a submission's revision response:
#   make diff REF=v1-submitted   (a tag, branch, or commit)
#   make diff REF=HEAD~5
diff:
	@if [ -z "$(REF)" ]; then \
	  echo "Usage: make diff REF=<git ref to diff against, e.g. a tag or HEAD~5>"; \
	  exit 2; \
	fi
	git show $(REF):paper/main.tex > paper/.main-old.tex
	latexdiff paper/.main-old.tex paper/main.tex > paper/main-diff.tex
	latexmk -pdf -interaction=nonstopmode -halt-on-error -cd paper/main-diff.tex
	rm -f paper/.main-old.tex
	@echo "Reviewer-facing diff PDF: paper/main-diff.pdf"
