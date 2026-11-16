SHELL := /usr/bin/env bash

# This is the meta makefile included in all slides, it is a modified variant of a standard makefile which i've used for several years.
# therefore it may contain some dead code and cleanups
SLIDES_TEX             := $(shell find . -maxdepth 1 -type f \( -name "source_*.tex" -and -not -name "*anim-*" \) -printf '%P\n')
OUTER_DEPENDENCIES     := $(shell find data/ -type f) $(shell find lib/ -type f)
# the sources of this deck, without build/ (rewritten by every run) and the generated wrappers (anim-*.tex, ...): those
# would mark every other pdf as outdated as soon as one pdf is built
LOCAL_SOURCES          := $(shell find . \( -path ./build -o -path ./.git -o -path ./lib -o -path ./data \) -prune -o -type f \
                             \( -name '*.hs' -o -name '*.bib' -o -name '*.tex' -o -name '*.cls' -o -name '*.sty' -o -name '*.code' \) \
                             -not -path './anim-*' -not -path './noanim-*' -print)
DEPENDENCIES           := ${OUTER_DEPENDENCIES} ${SLIDES_TEX} ${LOCAL_SOURCES}
# for each 'source_*' we create n pdf versions which will be prepared here
SLIDES_BASE            := $(basename ${SLIDES_TEX:source_%=%})
SLIDES_VARIANTS_NOANIM := $(addprefix noanim-, ${SLIDES_BASE})
SLIDES_VARIANTS_ANIM   := $(addprefix anim-, ${SLIDES_BASE})
# the short variants leave out the excursions: the frames marked [optional] (\LectureShort, see the source)
SLIDES_VARIANTS_SHORT  := $(addprefix noanim-short-, ${SLIDES_BASE}) $(addprefix anim-short-, ${SLIDES_BASE})
SLIDES_VARIANTS_ALL    := ${SLIDES_VARIANTS_NOANIM} ${SLIDES_VARIANTS_ANIM} ${SLIDES_VARIANTS_SHORT}
SLIDES_PDF_NOANIM      := $(addsuffix .pdf,${SLIDES_VARIANTS_NOANIM})
SLIDES_PDF             := $(addsuffix .pdf,${SLIDES_VARIANTS_ALL})
BUILD_DIR              := ./build
# exercise sheets, if any: a bare latexmk would also pick up the helper files (shared.tex, ...) and stop at an error prompt
SHEETS_TEX             := $(wildcard sheet*.tex)
# every pdf runs its own lualatex, and one run takes up to about 8 GB: build as many pdfs in parallel as the free memory
# allows, at least one and at most one per core. JOBS=n overrides it (make all JOBS=2)
JOBS                   ?= $(shell n=$$(( $$(awk '/MemAvailable/ {print $$2}' /proc/meminfo 2>/dev/null || echo 0) / 8000000 )); \
                             c=$$(nproc 2>/dev/null || echo 1); [ $$n -lt 1 ] && n=1; [ $$n -gt $$c ] && n=$$c; echo $$n)
MAKEFLAGS              += --jobs=${JOBS} --output-sync=target

# used internally for rule reuse
__FILENAME    := ""
__JOBNAME     := ""
__FILECONTENT := ""

.PHONY = default all sheets compile compile-noanim short clean produce
# notes/ is a directory, so the target notes must be phony for real
.PHONY: notes

default: compile-noanim
	@echo -e "\033[35mRun default rule. If you want anim variants to be prouced as well, use 'make all' (all pdfs: long, short and note versions)\033[m"

# the note versions first: the animated short one with notes is the one to present
all: notes compile sheets

sheets:
ifneq (${SHEETS_TEX},)
	latexmk -interaction=nonstopmode ${SHEETS_TEX}
else
	@echo No exercise sheets to build.
endif

compile-noanim: ${SLIDES_PDF_NOANIM}
	@echo Built the pdfs: ${SLIDES_PDF}

short: $(addsuffix .pdf,${SLIDES_VARIANTS_SHORT})
	@echo Built the short pdfs: $^

compile: ${SLIDES_PDF}
	@echo Built the pdfs: ${SLIDES_PDF}

# for each pdf we set the filename similarly
%.pdf: __FILENAME = $(addsuffix .tex, $(basename $@))
%.pdf: __JOBNAME  =  $(basename $@)

# this are mere wrapper rules to be used with the common producer below
# with $* we get the stem (whatever the '%' did expand to)
# \\def\\btdmmode{lightmode-fill}
noanim-%.pdf: __FILECONTENT = \\PassOptionsToClass{handout}{beamer}\\input{session-global.tex}\\input{source_$*.tex}
noanim-%.pdf: ${DEPENDENCIES}
	$(produce)

# the short variants: make picks these over the rules below, their stem is shorter
noanim-short-%.pdf: __FILECONTENT = \\PassOptionsToClass{handout}{beamer}\\def\\LectureShort{}\\input{session-global.tex}\\input{source_$*.tex}
noanim-short-%.pdf: ${DEPENDENCIES}
	$(produce)

anim-short-%.pdf: __FILECONTENT = \\def\\LectureShort{}\\input{session-global.tex}\\input{source_$*.tex}
anim-short-%.pdf: ${DEPENDENCIES}
	$(produce)

# the note versions of the short form, with the speaker notes of notes/notes.tex beside every slide: the handout, and
# every overlay for presenting with pdfpc --notes=right (see present.sh). Their stem is the shortest, so make picks them
# over the short variants above. The public copy has no notes/notes.tex and builds neither of them.
ifeq ($(wildcard notes/notes.tex),)
notes:
	@echo No speaker notes here: notes/notes.tex is missing.
else
SLIDES_PDF_NOTES := $(addsuffix .pdf,$(addprefix anim-short-notes-, ${SLIDES_BASE}) $(addprefix noanim-short-notes-, ${SLIDES_BASE}))
notes: ${SLIDES_PDF_NOTES}
	@echo Built the note pdfs: $^

noanim-short-notes-%.pdf: __FILECONTENT = \\PassOptionsToClass{handout}{beamer}\\def\\LectureShort{}\\def\\LectureNotes{}\\input{session-global.tex}\\input{source_$*.tex}
noanim-short-notes-%.pdf: ${DEPENDENCIES}
	$(produce)
	$(copy-pdfpc)

anim-short-notes-%.pdf: __FILECONTENT = \\def\\LectureShort{}\\def\\LectureNotes{}\\input{session-global.tex}\\input{source_$*.tex}
anim-short-notes-%.pdf: ${DEPENDENCIES}
	$(produce)
	$(copy-pdfpc)
endif

# specified below so it does not trigger the others
anim-%.pdf: __FILECONTENT = \\input{session-global.tex}\\input{source_$*.tex}
anim-%.pdf: ${DEPENDENCIES}
	$(produce)

# by using define we can use target-specific variables :D
# we only make use of temporary files to do not clutter
define produce
	echo "${__FILECONTENT}" > "${__FILENAME}"
	mkdir -p "${BUILD_DIR}"
	latexmk -jobname="${__JOBNAME}" -pdf -lualatex -shell-escape -interaction=nonstopmode "${__FILENAME}" </dev/null
	# copy, then rename: a viewer (pdfpc) that has the old pdf open keeps it, the new one appears only once complete
	cp "${BUILD_DIR}/${__JOBNAME}.pdf" "./$(basename ${__FILENAME}).pdf.tmp"
	mv -f "./$(basename ${__FILENAME}).pdf.tmp" "./$(basename ${__FILENAME}).pdf"
	rm "${__FILENAME}"
endef

# the pdfpc file of a note version (the font size of the notes), next to its pdf
define copy-pdfpc
	cp "${BUILD_DIR}/${__JOBNAME}.pdfpc" "./${__JOBNAME}.pdfpc.tmp"
	mv -f "./${__JOBNAME}.pdfpc.tmp" "./${__JOBNAME}.pdfpc"
endef

clean:
	rm -r "${BUILD_DIR}"
	latexmk -c

# TODO: compct version

ifeq (${VERBOSE},0)
MAKEFLAGS += --silent
# Better than defining '.SILENT'
endif