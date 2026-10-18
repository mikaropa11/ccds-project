# Report

The project report, written in LaTeX on the UPC report class.

## Who writes what

| File in `sections/` | Owner |
|---|---|
| `stack-basic.tex`, `stack-stats.tex` | Mikael |
| `stack-app.tex` | Bernat |
| `stack-atenea.tex` | Víctor |
| everything else | Víctor, with input from each stack owner |

Edit only your own files, so nobody's changes collide. Red
`[TODO: ...]` marks show what each section still needs, and the
delivered PDF must contain none. Cite sources by adding them to
`references.bib`.

## Building

```bash
make
```

It runs pdflatex and biber and writes `report.pdf`, which git ignores.

The report needs the UPC LaTeX package `snippetsltx`, which this
repository does not include: the package states no licence, so it is not
ours to publish. Ask Víctor for the tarball, unpack it and run `make`
inside it. It installs into `~/texmf` without touching the system's
packages. On Debian or Ubuntu you also need `texlive`,
`texlive-latex-extra`, `texlive-science`, `texlive-fonts-recommended`,
`texlive-bibtex-extra` and `biber`.

If you cannot build it, push your section anyway: Víctor builds the PDF.
