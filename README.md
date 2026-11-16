# Categorical Abstractions

A lecture on category theory for Haskell programmers: categories, functors, natural transformations, and the classes
`Semigroup`, `Monoid`, `Functor`, `Foldable`, `Applicative`, `Traversable`, and `Monad`, with monads in detail.
It was written as a session of the Functional Programming course at Ulm University.

The latest build of `main` is on the `gh-pages` branch:
[handout](https://github.com/EagleoutIce/fp-and-category-theory/blob/gh-pages/noanim-category-theory-abstractions.pdf)
and [with animation steps](https://github.com/EagleoutIce/fp-and-category-theory/blob/gh-pages/anim-category-theory-abstractions.pdf).

## Building

```sh
git clone --recurse-submodules <url> category-theory-abstractions
cd category-theory-abstractions
make noanim-category-theory-abstractions.pdf   # handout
make anim-category-theory-abstractions.pdf     # with animation steps
make short                                     # both again, without the excursions (frames marked [optional])
```

The build needs LuaLaTeX, latexmk, biber, and `ghc` on the `PATH`: the GHCi sessions on the slides run at build time.
In an existing clone, fetch the submodules with `git submodule update --init --recursive`.

The GitHub workflow in `.github/workflows/build.yaml` builds the PDFs on every push and pull request, uploads them as
a workflow artifact, and on `main` publishes them to the `gh-pages` branch.

## Contents

- `source_category-theory-abstractions.tex`: the slides
- `references.bib`: the bibliography
- `people/`, `books/`: portraits (licenses on the slides) and book covers
- `lib/`: LaTeX packages, partly as submodules
- `data/fonts/`: the fonts
