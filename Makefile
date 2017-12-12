PAPER := thesis
all: thesis.pdf

thesis.pdf:
	pdflatex $(PAPER).tex
	bibtex $(PAPER)
	pdflatex $(PAPER).tex
	pdflatex $(PAPER).tex

clean:
	rm -f $(PAPER).pdf $(PAPER).dvi $(PAPER).aux $(PAPER).bbl $(PAPER).blg $(PAPER).log $(PAPER).ent q.log
