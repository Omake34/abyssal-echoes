# Gameplay recording review

Reviewed November 1, 2026. Source: [Retromation's Time Walker: Dark World gameplay](https://www.youtube.com/watch?v=Azn2pf6Td3c). Method: selected paused frames and sections of the auto-generated transcript, not uninterrupted viewing. The recording's exact build is unverified; installed-build facts remain separate.

## Timestamped visual evidence

| Approximate time | Observation |
|---|---|
| [1:10](https://youtu.be/Azn2pf6Td3c?t=70) | Four Rookies appear in preparation, with a placement grid and Fight control. |
| [1:30–1:50](https://youtu.be/Azn2pf6Td3c?t=90) | Loot appears over the arena beside inventory and crafting controls. |
| [2:15](https://youtu.be/Azn2pf6Td3c?t=135) | The tutorial distinguishes identical-copy upgrades from recasting three same-level abilities into a random same-level ability. |
| [3:25](https://youtu.be/Azn2pf6Td3c?t=205) | Combatants occupy a shared arena; four compact hero strips remain below. |
| [20:08](https://youtu.be/Azn2pf6Td3c?t=1208) | Shop, inventory, crafting, and equipped abilities share the preparation view. |

Transcript references to range, class conversion, and boss positioning are leads, not independently established mechanics.

## Implementation decisions for our project

These are engineering recommendations based on the Godot code audit, rather than recovered source code:

- Keep the shared arena milestone first. Tie actor placement and targeting to the same authoritative state before polishing another formation grid.
- Build equipment, inventory, and crafting around one preparation context. Preserve the existing reward checkpoint and save behaviour while adapting presentation.
- Replace the unused `MergeSystem` generic same-type tier upgrade with explicit operations: a deterministic recipe lookup, a separately specified random recast, and EX recipes. Define valid inputs and output pools in our resources before implementation.
- Make previews stable. The current `preview_merge()` can draw a random result independently of `perform_merge()`, so a displayed preview is not a reliable promise. A random operation should describe its pool or retain the rolled result through the transaction.
- Validate ownership and ingredient multiplicity, reserve inputs, validate the result, and commit the exchange atomically. The existing sequence of separate removals/addition needs a shared transaction boundary before it becomes a player-facing workbench.
- Keep the current six selectable heroes for the first arena prototype. Class-conversion progression needs a separate design decision; do not silently rewrite existing saves based on an incompletely checked recording.

## Still unverified

Exact attack/movement timings, target tie-breakers, equipment restrictions, class-token replacement rules, loot weights, and differences between the recording and installed version. No gameplay scripts changed in this review.
