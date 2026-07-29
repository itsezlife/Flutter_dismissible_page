# Page Shape Strategy replaces scalar min/max radius

Dismiss chrome clips by a progress-resolved **Page Shape** (`ShapeBorder`) from a sealed **Shape Strategy**, not by lerping `minRadius`→`maxRadius`. Library default is **Shape Snap** (rest shape until Drag Progress exceeds a small threshold, then the full dragged shape); callers who need fine-grained control use a progress builder. Chrome is clip-only. Device corners and third-party borders are authored outside the package and passed in. Scalar radius knobs and callback `radius` are removed in a hard break so the public model cannot contradict non-circular / per-corner shapes.

## Considered Options

- **Keep scalar min/max radius** — rejected. Cannot express superellipse, smooth rect, or per-corner device radii; forces a false “one number” model.
- **Full-progress shape lerp as library default** — rejected for the common product case; authors wanted the dragged outline almost immediately. Fine control remains via the builder strategy.
- **Compressed lerp on `0…ε`** — rejected in favor of a step Snap; simpler contract, builder covers continuous cases.
- **Package device-corner helpers / `screen_corner_radius` dependency** — rejected. Keeps the package Flutter-only and avoids coupling to APIs missing on current supported Flutter versions.
- **Chrome paints `ShapeBorder.side`** — rejected. Stroke/decoration stay with content; chrome only clips.
- **Deprecated scalar shim beside Shape Strategy** — rejected. Two models invite conflict during an already-breaking API era.
