# Hand-off: continue building game1 overnight

## What this is
A Roblox RPG: medieval setting, dragons, action combat (soulslike-ish: dodge-roll
with i-frames, directional block, telegraphed enemy attacks). Built with Rojo,
synced to a local Roblox Studio session (not available to you — you have no way
to see the live Studio session or render anything; everything you do is through
files in this repo plus reasoning about how Roblox will interpret them).

Read `README.md` for the Rojo basics. Read this whole file before starting.

## Tonight's goal
Keep building the game world and its inhabitants:
1. **Terrain** — replace/extend the flat `Baseplate` with actual medieval-game
   terrain (hills, a village clearing, maybe a forest edge).
2. **Buildings and trees** — populate the world.
3. **NPCs** — townsfolk, not necessarily hostile (distinct from the existing
   combat enemies in `EnemyService`/`EnemyAIService`/`EnemyMovementService`).
4. **Use "design" to create GLB models** for buildings/trees/NPCs, imported into
   Roblox as meshes, rather than only blocky Part-built geometry.

On point 4: I don't know what 3D-model-generation tooling is available in your
environment. Check for it first (e.g. `which blender`; Blender can be driven
headlessly via `blender --background --python script.py` using its `bpy` API to
build simple low-poly geometry — boxes, cylinders, cones composed into a
house/tree/character silhouette — and export `.glb`). If nothing like that is
available, don't block on it: fall back to procedural Part-based geometry in
Luau (see "Fallback" below) so the world still gets built. Whatever you produce,
note clearly in your summary which path you took and why.

If you do generate `.glb` files: Roblox Studio's built-in 3D Importer accepts
glTF/.glb (Avatar > Import 3D, or drag-and-drop into a MeshPart's MeshId via the
importer). You can't do that import yourself — you have no Studio access. Put
generated files under a clearly-named folder (e.g. `assets/glb/`) and leave
explicit instructions in your final summary for what the human needs to do in
Studio to bring each one in (exact file, suggested name/location in Workspace).
This mirrors how `arming_sword` and the R6 rig template were handled this
session: placed in Studio by a human, then found and cloned *by name* from
Workspace at runtime by a server script — not by file sync.

## Architecture conventions (follow these — don't reinvent)

- **No third-party framework** (no Knit, no Wally). Hand-rolled Services
  (server) / Controllers (client) pattern:
  - `src/server/init.server.luau` and `src/client/init.client.luau` generically
    load every ModuleScript in `Services/`/`Controllers/`, calling `.Init()` on
    all of them, then `.Start()` on all of them. **New services/controllers
    need zero wiring in the loader** — just drop the file in the folder with
    `Init`/`Start` functions on the returned table.
  - `src/shared/Net.luau` — `Net.GetEvent(name)`/`Net.GetFunction(name)` wrap
    RemoteEvent/RemoteFunction lookup-or-create under `ReplicatedStorage.Remotes`.
  - `src/shared/Signal.luau` — minimal BindableEvent-backed signal class.
  - `src/shared/Constants.luau` — all tunable numbers and remote names live
    here, grouped by system (`Constants.Combat`, `Constants.Enemy`,
    `Constants.Remotes`). Add new tunables here, not as magic numbers in logic.
- **Server-authoritative**: every combat action is validated server-side
  (cooldowns, stamina, range/cone checks). Clients only ever *request* actions
  and play cosmetic feedback optimistically; the server decides what actually
  happens.
- **`--!strict`** on every Luau file. Match the existing style: tabs, no
  end-of-line comments explaining *what* code does, only short comments for
  non-obvious *why* (see existing files for the level of terseness expected).
  A `stylua`-like formatter hook runs on save via the harness — don't fight it.
- Enemies/players use **real `Humanoid.Health`**, not a parallel HP counter —
  gives free death/ragdoll/respawn semantics. See the gotcha below though.
- New enemy or NPC types should go through `EnemyService`'s clone-and-tag
  pattern (`cloneEnemy`, `CollectionService` tags) rather than one-off spawn
  code, if they need health/death/respawn. Pure decorative NPCs (villagers with
  no combat role) can be simpler — you don't need Humanoid/health machinery for
  something that's just supposed to stand around or walk a patrol path.

## Known gotchas from this session (read before you hit them again)

1. **Two-way Rojo sync can silently revert your edits.** If the Studio plugin's
   two-way sync is on and a script is open in Studio's own editor, edits you
   make to the file on disk can get overwritten back to the old content within
   moments. If a tool result says a file "was modified since you last read it,"
   don't assume that's you — re-read before continuing. If you find yourself
   re-applying the same edit twice, that's the symptom. You likely don't have
   this problem overnight (no human actively editing in Studio), but if things
   look stale, check `git diff` against what you expect.

2. **Never set `$ignoreUnknownInstances: false` in `default.project.json`**
   without a very good reason and extreme caution. It's not an "import new
   stuff" switch — it tells live two-way sync to reconcile away (i.e. delete)
   any Studio-side instance not declared in the project tree. With `rojo serve`
   connected to a live session this is destructive. (This is how we pulled in
   `HelloClaude` safely instead: added an explicit named stub
   `"HelloClaude": { "$className": "Part" }` under `Workspace` in
   `default.project.json`, *then* ran `rojo syncback -i <place file> --dry-run`
   first to preview, then for real. Syncback only ever fills in properties for
   instances already named in the tree — it doesn't auto-discover new ones.)

3. **Roblox `Humanoid` latches into a permanent Dead state once `Health` hits
   0.** Setting `.Health` back up afterward does *not* revive it — it stays
   functionally dead. `EnemyService`'s respawn logic destroys the old
   `Humanoid` and parents in a fresh one instead. Follow this pattern for any
   new respawnable NPC.

4. **Don't directly set `.CFrame` on a moving, unanchored, Humanoid-controlled
   part every frame/tick to "smooth out" rotation.** It fights the physics
   engine and visibly kills walk speed (this ate two debugging rounds this
   session). For NPC movement/facing, just call `Humanoid:MoveTo(position)`
   repeatedly at a reasonably fast interval (`EnemyMovementService` uses
   `Constants.Enemy.RepathInterval = 0.1`) with `AutoRotate` left at its
   default `true`, and let the engine handle both walking and turning. This is
   the current, working pattern — copy it for new mobile NPCs.

5. **You have no visual feedback on anything** — no Studio, no screenshots, no
   way to render a mesh or a CFrame and see if it looks right. Grip/attach
   offsets (`CFrame` position + rotation for welding things to a hand, etc.)
   were repeatedly wrong-guessed this session before landing close to right,
   purely from reasoning about coordinate axes. For terrain/building
   placement, prefer approaches that are self-evidently correct from first
   principles (e.g. placing a building's base at a known Y, sized from known
   dimensions) over anything requiring iterative "does this look right" tuning.
   Where tuning is unavoidable, leave the exact numbers as named constants in
   `Constants.luau` with a comment saying they're first-guesses that likely
   need a human pass in Studio, the way `WeaponService`'s `GRIP_C0` is flagged.

6. **Validate every change** with `rojo sourcemap default.project.json -o
   /tmp/check.json && rm /tmp/check.json` (or similar) — this is the only
   compile-ish check available; there's no Luau type-checker installed
   (`luau-analyze` isn't present). It catches structural/project.json errors
   but not logic bugs or type errors, so read code back carefully after writing
   it, especially anything involving `Instance` type casts (`:: SomeType`).

## Fallback for terrain/buildings/trees without a mesh pipeline

If GLB generation isn't feasible in your environment, build the world the same
way the existing blocky fallback dummy/sword were built: plain `Part`s (and
`Terrain:FillBlock`/`FillRegion` for actual ground terrain, or just large
`Part`s with `Material.Grass`/`Rock` for something simpler and easier to reason
about) composed in a server script or a one-time world-building script. This is
lower-fidelity but fully testable by you (no human eyes needed) via
`rojo sourcemap` and by reading the generated instance tree back.

## Wrap-up expectations

- Commit your own work incrementally with clear messages (this repo's existing
  single commit, `e95f881`, covers everything up to the combat system + sword
  swap — don't squash into it, build on top).
- End with a summary of: what you built, what's untested (anything needing a
  human in Studio — mesh imports, visual tuning), and a short prioritized list
  of what a human should check first when they sit down at Studio in the
  morning.

## Session 2 update: terrain, village, townsfolk (commit `2a9c419`)

Built out points 1-3 of "Tonight's goal" above. Point 4 (GLB pipeline) was
checked and skipped — see below.

**GLB/mesh pipeline**: checked for `blender`/`bpy` (not installed, no package
manager access to add them within this session's time budget) — none
available. Went straight to the Part-based fallback this doc already
describes; every new visual (terrain, houses, trees, NPC rig) is procedural
Parts/Terrain voxels. If a later session gets Blender/bpy access, the
highest-value thing to convert first is probably the tree canopy (currently
overlapping spheres, cheap to mesh into something less blobby) — houses and
the NPC rig are more structural and lower priority to reshape.

**New files**:
- `src/shared/WorldHeightMap.luau` — pure function `GetGroundY(x, z)`, the
  single source of truth for ground height (flat village clearing, easing
  into hills toward the forest ring). Both `TerrainService` (paints voxels)
  and `VillageService` (places buildings/trees/NPCs) call this so nothing
  floats or clips relative to the actual terrain.
- `src/server/Services/TerrainService.luau` (`Init` only) — paints
  `Workspace.Terrain` via `FillRegion` on an 8-stud grid.
- `src/server/Services/VillageService.luau` (`Init` only) — 9 houses in a
  ring around center (doors facing in), a well at dead center, ~140 trees
  scattered in an annulus outside the clearing (density-biased toward the
  outer edge), and one townsfolk NPC spawned per house doorway, tagged
  `"Townsfolk"`.
- `src/server/Services/NPCWanderService.luau` (`Start` only) — polls for
  `"Townsfolk"`-tagged models (same discovery pattern as
  `EnemyMovementService`) and gives each one a wander coroutine: idle or
  `Humanoid:MoveTo` a random point near its spawn, no aggro/combat logic at
  all. Deliberately a separate tag and service from `Enemy`/`EnemyMover` —
  do not fold townsfolk into `EnemyService`'s clone-and-tag path; they were
  kept simpler on purpose (see the architecture note in this doc about
  decorative NPCs not needing Humanoid health machinery — though they *do*
  use a Humanoid here, for free `MoveTo` walking/turning, just no
  health/respawn logic).
- `src/server/WorldGen/` — geometry builders, called only from
  `VillageService`, not auto-loaded by the Services loader:
  - `PartUtil.luau` — shared `NewPart`/`NewWedge` helpers (anchoring/material
    defaults).
  - `HouseBuilder.luau` — four walls + door gap + pitched wedge roof +
    chimney.
  - `TreeBuilder.luau` — tapered trunk + a small cluster of foliage spheres.
  - `TownsfolkFactory.luau` — a hand-built R6-shape rig (Parts + Motor6D
    joints, real body-part names so `Humanoid`/`RigType.R6` behave
    normally), plus a name-tag `BillboardGui`.

**`Constants.luau`**: added `Constants.World` (village/forest radii, ground
level, max hill height) and `Constants.NPC` (walk speed, wander radius/
interval, idle chance) groups, following the existing grouped-by-system
convention. Did not touch `Constants.Enemy`/`Constants.Combat`/
`Constants.Remotes`.

**`default.project.json`**: removed the old flat gray `Baseplate` part (the
new terrain is the ground now) and added `VoidFloor` — a large (2048x2048),
invisible, anchored safety-net `Part` far below everything (Y=-100). The
generated terrain only covers a ~220-stud radius circle, smaller than the
old 512x512 square `Baseplate`, so without a floor under the corners/outside
the forest ring a wandering player could fall into the void; `VoidFloor`
catches that. `HelloClaude` was left untouched.

**Load-order note**: `TerrainService`, `VillageService`, and
`EnemyService`/`WeaponService` all only implement `Init()` (no `Start()`
dependency), so the loader's two-phase "all `Init()` before any `Start()`"
guarantee means terrain exists before anything's `Start()` runs (e.g. before
`EnemyService.Start()` spawns an unanchored, physics-simulated mover that
needs solid ground under it). `VillageService` doesn't actually *need*
`TerrainService` to have run first, either — it computes ground height
itself from the same pure `WorldHeightMap` function rather than depending on
`TerrainService`'s side effects, so there's no real ordering dependency
between the two despite both running in the `Init` phase. `NPCWanderService`
only has `Start()`, and (like `EnemyMovementService`) discovers its targets
by polling a `CollectionService` tag every second rather than assuming
`VillageService` ran first — so there's no hard ordering requirement there
either.

### What's unverified (needs a human in Studio)

No Studio access this session either — everything below is reasoned from
first principles / matched to known-working patterns in this codebase, not
visually confirmed:

1. **`HouseBuilder`'s pitched roof** (`RoofLeft`/`RoofRight` wedges) — the
   `CFrame.Angles` chain to orient the two wedges into a symmetric peaked
   roof is the single riskiest piece of math in this session's work (wedge
   orientation from a cold start, no way to preview it). If houses look
   wrong in Studio, start here; worst case, swap the roof for two plain
   tilted `Part`s (easier to reason about than `WedgePart` local axes) or a
   single low-poly pitched-roof shape if a mesh pipeline becomes available.
2. **`TownsfolkFactory`'s idle/walk animation ids** (`180435571`/
   `180426354`) — well-known public default R6 animation ids, referenced by
   asset id only (no download needed), but never actually seen playing.
   If townsfolk stand T-posed instead of idling/walking, check these first;
   the rig/joint math underneath should still make them walk via
   `Humanoid:MoveTo` even with no animation (just without limb motion).
3. **Visual density/scale generally** — house ring radius, tree count/
   density falloff, wander radius, are first-guess constants (now in
   `Constants.World`/`Constants.NPC`), not tuned against anything. Cheap to
   retune once someone can actually look at it.
4. **Terrain material thresholds** (`Rock` above ~55% of `MaxHillHeight`,
   `Grass` below) — reasonable-sounding but arbitrary; adjust in
   `TerrainService.luau` if hills look wrong (too much rock too low, etc).

### Morning checklist (priority order)

1. Open Studio, let the Rojo plugin sync, and just look at the village —
   confirm terrain/houses/trees/NPCs exist at all and nothing is
   catastrophically wrong (a NaN CFrame, a part the size of the map, etc).
2. Check the roof geometry on a couple of houses (item 1 above) — likely the
   thing most in need of a fix.
3. Watch a townsfolk NPC for ~30s — does it walk smoothly to a wander point
   and either idle or turn to walk again, or does it T-pose / stutter /
   clip into its own house?
4. Walk from the village out toward the forest edge and past it — confirm
   the terrain height easing feels right and `VoidFloor` actually catches a
   deliberate fall off the far edge.
5. If it's all reasonable: tune `Constants.World`/`Constants.NPC` to taste
   (house ring radius, tree density, wander radius) rather than touching the
   generation code itself.
6. Longer-term: nothing in this session touched combat/enemies/weapons;
   `EnemyService`'s R6-rig-template search (`findRigTemplate`) only looks at
   direct `Workspace` children, so it will not pick up anything under the
   new `Village`/`Forest`/`Townsfolk` folders — no interaction expected
   there, but worth confirming once a human can see both systems running
   together.
