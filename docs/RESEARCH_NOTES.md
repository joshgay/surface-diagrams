# Mathematical references and open inputs

Planning notes, September 12, 2026. Relevance judgments below are architectural
recommendations, not claims that this library implements the cited algorithms.
Use primary papers and authors' documentation before choosing an algorithm.

## Curves and coordinates

- **Dylan P. Thurston, _Geometric intersection of curves on surfaces_**, draft:
  [author-page PDF](https://dpthurst.pages.iu.edu/DehnCoordinates.pdf).
  The indexed first page calls it a pre-preprint and describes geometric
  intersection, smoothing, Dehn-Thurston coordinate changes, and twisting.
  This is a strong candidate for the unpublished webpage note Richard mentioned,
  but the exact title has not yet been confirmed by him. The direct PDF returned
  404 during this session; do not claim the complete draft was read or freeze an
  algorithm from the indexed abstract. Obtain a working author copy before the
  R0 coordinate comparison. Do not confuse Dylan's work with William's.
- **William P. Thurston, _On the geometry and dynamics of diffeomorphisms of
  surfaces_**, Bulletin AMS 19 (1988), 417-431:
  [publisher DOI](https://doi.org/10.1090/S0273-0979-1988-15685-6).
  Foundational context for surface dynamics and measured-foliation/lamination
  viewpoints. This is a relevant candidate, not a claim that Richard named this
  particular paper. Full publisher text was not successfully retrieved here;
  defer theorem-level algorithm decisions pending an accessible primary copy.
- **Flipper, authors' documentation**:
  [package overview](https://flipper.readthedocs.io/en/latest/api/flipper.html).
  The package computes mapping-class actions on laminations on punctured surfaces
  using ideal-triangulation coordinates. Evaluate overlap and assumptions rather
  than rebuilding those algorithms automatically. Its documented domain is not
  proof of support for this project's notched-boundary conventions.

## Reference systems and the Alexander method

- **Farb and Margalit, _A Primer on Mapping Class Groups_, Proposition 2.8**:
  [book text](https://euclid.nmu.edu/~joshthom/Teaching/MA589/farbmarg.pdf).
  The Alexander method controls a filling system and its induced graph action.
  It supports investigating Richard's image-of-cut-system representation, while
  warning against an unconditional uniqueness claim for arbitrary curve systems.
  Our orbit/stabilizer and torsor formulation is the elementary group-action
  interpretation of that proposal. It is not a claim of a new duality theorem.

## Coverings and boundary conventions

- **Rebecca R. Winarski, _Symmetry, Isotopy, and Irregular Covers_**:
  [arXiv:1309.3650](https://arxiv.org/abs/1309.3650).
  Gives necessary and sufficient-condition results concerning the Birman-Hilden
  property, with irregular-cover examples. The paper's topic is not a blanket
  assertion that every mapping class lifts or that every cover has the property.
- **Dan Margalit and Rebecca R. Winarski, _The Birman-Hilden theory_**:
  [authors' survey](https://celebratio.org/Birman_JS/article/471/).
  Sections 2-3 distinguish liftable classes, symmetric classes, deck groups and
  theorem hypotheses. Particularly relevant: boundary and upstairs marking
  conventions matter. Any application to a notched enlargement requires checking
  those conventions afresh. ARCHITECTURE.md records the proposed separation of
  these questions.

## Later diagram families

- **Castro, Gay, Pinzon-Caicedo, _Diagrams for Relative Trisections_**:
  [arXiv:1610.06373](https://arxiv.org/abs/1610.06373).
  A bordered surface with three curve tuples and pairwise standardness conditions
  motivates dedicated relative diagram records. Consult the corrected version
  when implementing boundary open-book/monodromy algorithms.
- **Meier and Zupan, _Bridge trisections of knotted surfaces in 4-manifolds_**:
  [arXiv:1710.01745](https://arxiv.org/abs/1710.01745).
  Its shadow-diagram viewpoint is relevant to the proposed surface-and-arc core.
  Keep generalized bridge trisections separate from classical link bridge diagrams.

Kirby, Heegaard, and braid algorithm references should be selected for the exact
first operation requested. This note is not a comprehensive literature survey
or a commitment to implement every theory appearing in the references.

## Richard's additional work

Richard reports additional work of his own. At the time of the planning revision,
`main` and `origin/main` were synchronized at `065a69f` and the worktree was clean.
No new branch/file/commit or mathematical notes have yet been identified. The
follow-up identified the Dylan Thurston webpage note, but did not locate the
additional user work. Incorporate that work before freezing R0 contracts. Do not
claim to have reviewed it, overwrite it, or infer its contents from this plan.

Richard clarified that fractional boundary actions are intended to admit lifts
excluded by pointwise boundary fixing. The plan preserves full twist information
and leaves the precise isotopy/category convention to be formalized on his
examples. No relation making every fractional turn finite order has been imposed.

## Homology, fundamental groups and Lefschetz signatures (later priorities)

- **Allen Hatcher, Algebraic Topology**, Chapters 1 and 2:
  [author's book page](https://pi.math.cornell.edu/~hatcher/AT/ATpage.html).
  Cellular presentations and homology provide the standard starting point for
  explicit surface generators, relations and basis calculations.
- **Burak Ozbagci, Signatures of Lefschetz fibrations**:
  [arXiv:math/9809178](https://arxiv.org/abs/math/9809178).
  Gives a signature technique using global monodromy for fibrations over disk or sphere.
- **Adalet Cengel and Cagri Karakurt, Partial fiber sum decompositions and
  signatures of Lefschetz fibrations**:
  [arXiv:1907.11507](https://arxiv.org/abs/1907.11507).
  The abstract describes an implementation-oriented reformulation and coverage of
  bordered Lefschetz fibrations over a disk. Full algorithm/hypothesis review is
  still required before implementation; this session read the abstracts.

Richard explicitly prioritizes the diagram tutorial and all visualizations over
these calculations. Do not turn the existence of an algorithm into a reason to
resume calculation-first staging.
