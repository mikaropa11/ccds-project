# Build the reports.
#
#   make            build every .tex in this directory
#   make report     build just report.pdf
#   make clean      remove build by-products, keep the PDFs
#   make distclean  remove build by-products and the PDFs
#
# Runs pdflatex three times (title -> toc -> refs) with biber in between,
# which is enough to settle the table of contents, cross-references and
# the bibliography.

DOCS  := report
PDFS  := $(addsuffix .pdf, $(DOCS))
DEPS  := mlcsreport.sty references.bib $(wildcard sections/*.tex)

LATEX := pdflatex -interaction=nonstopmode -halt-on-error -file-line-error
BIBER := biber --quiet

.PHONY: all clean distclean $(DOCS)

all: $(PDFS)

# Allow "make report" as a shorthand for "make report.pdf".
$(DOCS): %: %.pdf

%.pdf: %.tex $(DEPS)
	$(LATEX) $*
	-$(BIBER) $*
	$(LATEX) $*
	@n=0; while grep -q 'Rerun to get' $*.log && [ $$n -lt 3 ]; do \
	   echo "    (pasada extra: referencias aun sin cuadrar)"; \
	   $(LATEX) $* >/dev/null; \
	   n=$$((n+1)); \
	 done
	@grep -q 'Rerun to get' $*.log \
	   && echo "    !! referencias sin converger tras 5 pasadas" || true
	@echo "==> $@ built"

clean:
	$(RM) *.aux *.log *.out *.toc *.bbl *.bcf *.blg *.run.xml \
	      *.lof *.lot *.fls *.fdb_latexmk *.synctex.gz *.xmpi

distclean: clean
	$(RM) $(PDFS)
