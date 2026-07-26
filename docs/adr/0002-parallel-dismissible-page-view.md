# Parallel Constrained Dismissible Page View

Pager support is a parallel page entrypoint (`DismissiblePageView`), not a third Interaction Mode and not an extension of `DismissiblePage`'s list-`ScrollController` builder. MVP is Constrained Motion + horizontal pager only: fork package `PageController` / page `ScrollPosition` for Scroll Arbitration with Pager Commitment (default locked-until-release; opt-in handoff-at-origin); use stock `PageView` in `builder(context, pageController)`; off-pager-axis dismiss via dual-mount gesture shell. List pages keep handoff-at-origin. Free Motion pager, vertical pager Commitment, TabBarView, and per-page vertical scrolling are out of this decision's MVP.

## Considered Options

- **Pager as Interaction Mode / bag on `DismissiblePage.builder`** — rejected. Forces a zombie list `ScrollController` onto pager-only content and contradicts the glossary rule against modeling PageView as an Interaction Mode.
- **Content-only wrapper inside ordinary `DismissiblePage`** — rejected for the same builder pollution; replaced by a parallel page family that reuses engine/chrome/shell.
- **Full vendored `PageView` / `TabBarView` in MVP** — deferred. Hard casts on `_PagePosition` require forking controller/position; stock `PageView` plus package controller is enough until TabBarView (internal `PageController`) forces a widget vendor.

## Consequences

- Example stories should migrate onto `DismissiblePageView` and stop using gesture-mode `DismissiblePage` + orphan `PageController` for pager demos.
- `CubicPageView` remains demo chrome that consumes the package page controller from the page-view builder (not a package API).
