# Dismiss–scroll dual-mount coexistence

Under Interaction Mode `scroll`, Scroll Arbitration owns the nested scrollable's axis (mid-list on-axis drags scroll; edge overscroll dismisses), and a gesture shell may coexist when off-axis dismissal is required — always for Free Motion; for Constrained Motion when any allowed Dismiss Directions side leaves the scroll axis. On-axis mid-list scrolling stays with the list; the shell must not steal it.

The shells differ because the motions do: Constrained dual-mount uses an axis-partitioned directional recognizer so Flutter's arena routes only the cross axis to dismiss; Free dual-mount uses a full-plane recognizer that self-yields when the initial dominant delta is on-axis and the list can scroll, then tracks the full plane after it wins.

## Considered Options

- **Exclusive arbitration-or-shell gate** — rejected. Treating `scroll` as exclusive of any gesture shell made cross-axis Constrained sides and Free off-axis dismiss dead under nested lists (the coexistence regressions this ADR records).
- **Restore stock ImmediateMultiDrag + overscroll NotificationListener** — rejected. That tangle worked for multi-axis demos but fought the engine/adapter split; dual-mount keeps arbitration on the scroll axis and a thin shell for the rest without bringing the old listener stack back.
