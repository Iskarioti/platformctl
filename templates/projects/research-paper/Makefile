.PHONY: paper clean

paper:
	latexmk -pdf -interaction=nonstopmode -halt-on-error -cd paper/main.tex

clean:
	latexmk -C -cd paper/main.tex
