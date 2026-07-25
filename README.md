<div align="center">
  <h1 align="center" style="font-size: 70px;">Flutter Dismissible Page From <a href="https://www.linkedin.com/in/thornike/" target="_blank">Tornike</a> </h1>

<!--  Donations -->
 <a href="https://ko-fi.com/flutterman">
  <img width="300" src="https://user-images.githubusercontent.com/26390946/161375567-9e14cd0e-1675-4896-a576-a449b0bcd293.png">
 </a>
 <div align="center">
   <a href="https://www.buymeacoffee.com/fman">
    <img width="150" alt="buymeacoffee" src="https://user-images.githubusercontent.com/26390946/161375563-69c634fd-89d2-45ac-addd-931b03996b34.png">
  </a>
   <a href="https://ko-fi.com/flutterman">
    <img width="150" alt="Ko-fi" src="https://user-images.githubusercontent.com/26390946/161375565-e7d64410-bbcf-4a28-896b-7514e106478e.png">
  </a>
 </div>
<!--  Donations -->

[![Pub package](https://img.shields.io/pub/v/dismissible_page.svg)](https://pub.dev/packages/dismissible_page)
[![Github starts](https://img.shields.io/github/stars/tkko/flutter_dismissible_page.svg?style=flat&logo=github&colorB=deeppink&label=stars)](https://github.com/tkko/flutter_dismissible_page)
[![style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://github.com/tenhobi/effective_dart)
[![pub package](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

</div>

Flutter widget that allows you to dismiss page to any direction, forget the boring back button and plain transitions.

## Concepts

| Term | Meaning |
|--|--|
| **Constrained Motion** | Axis-locked drag: each gesture locks onto one axis, then moves only toward sides allowed by **Dismiss Directions**. |
| **Free Motion** | Full-plane (2D) drag. Independent of Dismiss Directions — use `FreeDismissiblePage`, not a direction flag. |
| **Dismiss Directions** | Combinable bitmask of atomic sides (`up`, `down`, `startToEnd`, `endToStart`) plus composites (`vertical`, `horizontal`, `all`). Empty set turns drag-dismiss off. |
| **Interaction Mode** | Orthogonal to motion. `scroll` (default) arbitrates with a nested scrollable; `gesture` is for content that never scrolls. |

`PageView` / `TabBarView` are **not** an Interaction Mode in this package and are
not supported as a dismiss coordination path in this release.

## Why This Fork Exists

This fork focuses on fixing long-standing scroll + dismiss gesture conflicts,
especially for pages that contain scrollable content.

### What It Fixes

- Introduces a custom `ScrollController` + `ScrollPosition` arbitration path
  for `interactionMode: DismissiblePageInteractionMode.scroll`.
- Ensures drag delta is routed correctly between page dismissal and inner
  scrollable content.
- Fixes the issue where reversing direction could leave the page in a dismiss
  state or leak part of the delta into dismiss drag unexpectedly.

### Behavior Comparison

Old behavior (problematic):

https://user-images.githubusercontent.com/26390946/194924545-1712b63b-2a25-4182-b731-db49ecc50c23.mov

New behavior (expected):

https://github.com/user-attachments/assets/9ef89285-7d6a-45f9-87aa-d589d8d89c5e

## Features

- Dismiss to any direction
- Works with nested list view
- Animating border
- Animating background
- Animating scale

## Support

#### PRs Welcome
#### Discord [Channel](https://rebrand.ly/qwc3s0d)
#### Don't forget to give it a star ⭐

## Demo
| [Live Demo](https://rebrand.ly/gw8nktq) | Free Motion | Constrained (vertical) |
|--|--|--|
| <a href="https://rebrand.ly/gw8nktq"><img width="300" src="https://user-images.githubusercontent.com/26390946/156333539-29aefaf2-5f42-4414-8d8c-1ecbae40c377.png"/></a> | <img src="https://user-images.githubusercontent.com/26390946/161377483-78e5dbaf-678f-4381-a393-52af8180bbcb.gif" /> | <img src="https://user-images.githubusercontent.com/26390946/156391449-a9235d05-bc87-4f51-8a5d-50c44fd0c582.gif"/> |

## Getting Started

### Constrained Motion + scroll Interaction Mode

```dart
const imageUrl =
    'https://user-images.githubusercontent.com/26390946/155666045-aa93bf48-f8e7-407c-bb19-bc247d9e12bd.png';

class FirstPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(228, 217, 236, 1),
      body: GestureDetector(
        onTap: () {
          // Use extension method to use [TransparentRoute]
          // This will push page without route background
          context.pushTransparentRoute(SecondPage());
        },
        child: Center(
          child: SizedBox(
            width: 200,
            // Hero widget is needed to animate page transition
            child: Hero(
              tag: 'Unique tag',
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SecondPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Scroll is the default Interaction Mode — attach the builder's
    // ScrollController to the primary scrollable.
    return DismissiblePage.constrained(
      onDismissed: () {
        Navigator.of(context).pop();
      },
      // Atomic sides and composites: vertical, horizontal, all, or
      // DismissDirections.up.add(DismissDirections.startToEnd), etc.
      // Cross-axis combinations stay Constrained (Axis Lock) — they are
      // not Free Motion. Use DismissDirections.empty to disable drag-dismiss.
      directions: DismissDirections.vertical,
      isFullScreen: false,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Hero(
          tag: 'Unique tag',
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
```

### Free Motion + gesture Interaction Mode

Use Free Motion when the page should drag in the full plane. Prefer gesture
Interaction Mode when the child never scrolls:

```dart
DismissiblePage.free(
  onDismissed: () => Navigator.of(context).pop(),
  interactionMode: DismissiblePageInteractionMode.gesture,
  builder: (_, __) => YourStaticContent(),
);
```

## API overview

```dart
// Constrained — Dismiss Directions + per-side thresholds
DismissiblePage.constrained(
  builder: ...,
  onDismissed: ...,
  directions: DismissDirections.vertical, // or .all, atoms, .add / .remove
  thresholds: const DismissThresholds(up: 0.1, down: 0.2),
  interactionMode: DismissiblePageInteractionMode.scroll, // default
);

// Free — single threshold, no directions
DismissiblePage.free(
  builder: ...,
  onDismissed: ...,
  threshold: 0.15,
  interactionMode: DismissiblePageInteractionMode.gesture,
);
```

Shared chrome (both variants): `onDismissed`, `interactionMode`, `disabled`,
drag callbacks, `isFullScreen`, `backgroundColor`, scale / radius / opacity,
`dragSensitivity`, `reverseDuration`, `hitTestBehavior`, and related fields.

Dismiss Engine internals (Axis Lock, Scroll Arbitration, presentation mapping)
live behind `package:dismissible_page/dismissible_page_engine.dart` and are not
re-exported from the thin root API.
