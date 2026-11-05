# Field Command: Visual Depth Demo and Northern Italy Feature Plan

**Status:** Roadmap prepared; the user has authorized proceeding with the demo after this document. Later campaign systems remain planned, not implemented.\
**Prepared:** September 7, 2026.\
**Scope:** First prove a polished, playable visual-depth demo on both the battlefield and campaign map; then expand the existing game into the requested single-army Northern Italy campaign. Full 3D is optional, not a requirement.

**Next-session TODO:** [September 8 playtest feedback](#22-next-session-todo-september-8-playtest-feedback). These items are recorded for tomorrow's work, not implemented or approved as complete.

## 1. Recommended Direction

Build one representative battlefield and a companion playable campaign-map view before committing the entire game to a new rendering approach. That demo should answer the hardest question early: can we achieve the visual quality, readable formations, responsive commands, and sense of depth you want without sacrificing performance or the simplicity of the interface?

The demo must be a playable battle and a campaign map with moving armies, not a camera flythrough or an attractive scene with placeholder gameplay. It should demonstrate the smaller interface, contextual orders, visible ranges, embedded corps commanders, morale, fatigue, and gradual formation changes. These are part of the desired experience, not decorations to add after the graphics work.

After reviewing the demo, integrate the approved approach into the existing game and expand in stages: leadership, regiment levels, equipment and timed replenishment, Northern Italy geography, objectives and intelligence, campaign AI, forts, and a complete campaign progression loop.

**Latest visual clarification:** the main problem is flat maps and flat-looking units, not the absence of a fully 3D engine. Prioritize a painterly, dimensional, Ultimate General-inspired presentation: terrain relief, directional light, grounded shadows, layered vegetation and settlements, and recognizable miniature formations. A hybrid 2.5D approach using textured relief terrain and dimensional sprites is an acceptable first choice. Apply the same depth treatment to the campaign map, not just battles. We should not accept worse-looking or harder-to-read combat simply because it is technically 3D.

### Product Boundaries

- The player commands one persistent field army, not an entire nation.
- Campaign movement and battles remain real time. Keep pause and 0.5x, 1x, 2x, and 4x speeds.
- Encounters transition into tactical battles, with eligible nearby armies able to reinforce.
- Keep two player corps with up to four regiments each as the initial army limit.
- Maintain the battle-funded economy, weapon trading, recruiting, training, and persistent casualties. Do not introduce a large national production or taxation simulator.
- Keep the Army, Armory, and Officers headquarters as the main administrative screens.
- Preserve timed formation changes, supply wagons, ammunition, routing, and other working systems.
- Use original or properly licensed assets. Match the reference game's readability and quality, not its proprietary artwork, branding, or exact interface.

The official description of Ultimate General: Civil War emphasizes terrain, detailed maps, army development, and varied equipment. Those are useful reference qualities; copying a screenshot's colors alone would not reproduce the experience. [Reference: official game overview](https://www.ultimategeneral.com/ug-civil-war.html).

### Working Historical Assumption

Use the **1796-1797 Northern Italy campaign** unless a different campaign is chosen before historical content production. Mantua provides a natural anchor for fortifications, supply, and relief operations. Its siege is documented in the Fondation Napoleon's overview of the Italian campaigns. [Historical starting point](https://www.napoleon.org/en/magazine/publications/napoleon-in-italy-the-sieges-of-mantua-1796-1799/).

Exact starting positions, dates, weapons, uniforms, commanders, and political boundaries require a separate content-research pass. The first demo can be an explicitly fictional Italian river-crossing engagement, avoiding an unsupported claim of historical reconstruction.

## 2. Baseline Before Demo Work

This plan is based on the current repository, not a proposed rebuild from nothing.

| Area                | Existing foundation                                                                      | Required extension                                                                                |
| ------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Runtime             | React interface, Phaser Canvas maps, campaign model, tactical helpers, PathFinding.js    | Introduce a Three.js rendering option and a renderer-independent simulation clock                 |
| Formations          | Timed line, column, and square transitions                                               | Preserve timing and show believable movement in 3D                                                |
| Command             | Main general, two corps, commissioned officers and command effects                       | Recruitable army command and corps leadership embedded in a regiment                              |
| Progression         | Regiment experience, skills, one selectable perk, officer ranks, wounds, and assignments | Add explicit regiment levels and tiered abilities; connect the main general to the officer system |
| Replenishment       | Instant regular/veteran replacements; regular recruits dilute experience and skills      | Timed replenishment, manpower budgets, level-scaled veteran costs, and perk loss after demotion   |
| Weapons             | Seven equipment definitions, inventory, buying, selling, and equipping                   | Research-backed expanded catalog and actual weapon-type capture accounting                        |
| Campaign            | Small fictional Danube map, moving armies, basic enemy patrol/chase behavior             | Northern Italy geography, objectives, meaningful routes, intelligence, and AI                     |
| Scouting            | Temporary paid increase in reveal radius                                                 | Physical detachments with travel, observations, recall, and losses                                |
| Terrain             | Forest and hill effects, line-of-sight helpers, bridge pathfinding                       | Consistent movement costs, slopes, cover, crossing rules, and campaign geography                  |
| Battle presentation | Soldiers, flags, effects, labels, selection, a basic selected-unit range circle          | Improved art, firing arcs, contextual cursors, and readable condition indicators                  |
| Headquarters        | Full-screen Army, Armory, and Officers views                                             | Extend the existing visual language and information hierarchy                                     |
| Persistence         | Save schema version 3, migrations for earlier saves                                      | Versioned scenarios, new entities, migration tests, and isolated demo storage                     |
| Testing             | Simulation tests and Playwright campaign/battle/interface coverage                       | Renderer parity, WebGL checks, intelligence invariants, and performance measurements              |

### Architectural Constraints To Address Deliberately

1. `src/game/scene.js` currently drives simulation updates as well as rendering. Adding a second renderer without separating ownership could advance the game twice or change gameplay with frame rate.
2. `src/App.jsx` includes minimap and camera integration tied to Phaser. A Three.js scene cannot simply replace the canvas without adapting these interfaces.
3. Campaign and battlefield coordinates currently share fixed world dimensions. A larger Italy map requires scenario-specific dimensions and explicit distance conversions, not a stretched background.
4. Enemy campaign armies currently have aggregate strength rather than persistent, itemized equipment rosters. Accurate captured weapons depend on fixing that first.
5. The browser tests inspect Phaser internals and use a 2D canvas pixel read. WebGL verification needs different capture and projection helpers.
6. The existing headquarters already provides a coherent foundation. Replace redundant battlefield panels, not the entire headquarters design.

## 3. Coverage of Every Requested Feature

Phase names below are defined in Sections 5-14. "Demo" means a representative implementation, not necessarily the complete campaign version.

| ID  | Request                                                                                                                         | Demo coverage                                                                                       | Full delivery                                                                                         |
| --- | ------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| W01 | Recruitable army commanders who gain experience                                                                                 | One configured army officer using the intended command model                                        | Phase 3: recruitment, assignment, XP, wounds, succession, and career history                          |
| W02 | More weapons and captured weapons after battles                                                                                 | A few visually distinct, period-appropriate weapon roles                                            | Phase 3: expanded catalog, persistent enemy equipment, recovery ledger, and loot report               |
| W03 | Larger Northern Italy campaign                                                                                                  | One Italian-style battlefield                                                                       | Phase 4: regional map; Phase 9: complete campaign content                                             |
| W04 | Smarter AI with aggressive, passive, and random personalities                                                                   | Tactical regression coverage; no full campaign AI rewrite                                           | Phase 7: aggressive, cautious, and bounded erratic behavior using actual intelligence                 |
| W05 | Campaign and battle terrain penalties                                                                                           | Forest, slope, road, river, and bridge behavior on one battlefield                                  | Phase 4: shared terrain rules and campaign routing; Phase 8: fort geometry                            |
| W06 | More polished, less flat maps and units; full 3D optional                                                                       | Primary deliverable: playable, art-directed battlefield and campaign map with convincing depth      | Phases 2, 4, 8, and 10: all maps, forts, campaign presentation, and final optimization                |
| W07 | Strategic capture, supply, and army-destruction objectives                                                                      | Capture a crossing or depot and defeat a defending force                                            | Phase 5: objective system; Phase 9: connected campaign missions                                       |
| W08 | Physical, toggleable, recallable scouts that can be lost                                                                        | Not simulated in the battlefield demo                                                               | Phase 6: scout detachments, patrols, recall, encounters, and casualty accounting                      |
| W09 | Town loyalty and messengers reporting army positions                                                                            | Town art only                                                                                       | Phase 6: loyalty, observation, physical couriers, and delivered reports                               |
| W10 | Smaller bottom interface and smaller unit cards                                                                                 | Compact corps strip and contextual inspector                                                        | Phase 2: apply throughout campaign and battle; Phase 10: responsive audit                             |
| W11 | Forts                                                                                                                           | No siege system in the demo                                                                         | Phase 8: garrisons, supply, blockade, relief, and tactical assaults                                   |
| W12 | Clearly visible weapon ranges                                                                                                   | Effective/max range, facing arc, and blocked-fire feedback                                          | Phase 3: per-weapon tuning; Phase 10: readability and accuracy audit                                  |
| W13 | Corps commanders embedded in units                                                                                              | Corps officer attached to a host regiment, no separate corps entity                                 | Phase 3: reassignment, casualties, acting command, and persistence                                    |
| W14 | Left-click inspection, right-click move/attack, contextual cursor                                                               | Complete desktop command interaction                                                                | Phase 2: campaign integration, touch equivalents, and accessibility                                   |
| W15 | Main general remains a separate unit                                                                                            | Independent main general with command radius                                                        | Phase 3: link entity to a recruitable, persistent army officer                                        |
| W16 | Friendly morale and white wavering indication for enemies                                                                       | Compact morale bars and slow white pulse on visible enemy labels/flags                              | Phase 10: reduced-motion, color-independent cues, and all zoom levels                                 |
| W17 | Fatigue visible on the map                                                                                                      | Separate, readable fatigue/condition indicator                                                      | Phase 4: campaign marching and recovery; Phase 10: final presentation audit                           |
| W18 | Regiment levels and abilities; timed replenishment with expensive veterans, recruit dilution, and perk loss after losing levels | Show representative level and ability states in the inspector, without a full replenishment economy | Phase 3: levels, tiered perks, manpower, timed replacement orders, veteran cost scaling, and demotion |

## 4. Overall Sequence and Gates

These are dependency-based stages, not delivery-date promises. The relief rendering, art, and animation work must be measured before reliable calendar estimates can be made.

| Phase | Deliverable                                                          | Depends on    | Exit gate                                                                                   |
| ----- | -------------------------------------------------------------------- | ------------- | ------------------------------------------------------------------------------------------- |
| 0     | Isolated demo harness and simulation boundary                        | Current game  | Existing behavior preserved; one simulation clock; no save contamination                    |
| 1     | Representative dimensional battle and campaign-map demo              | Phase 0       | Both maps pass visual, interaction, gameplay, and performance review                        |
| 2     | Approved renderer and compact controls integrated                    | Demo approval | Existing campaign-to-battle-to-headquarters loop works end to end                           |
| 3     | Commanders, regiment progression, equipment, and timed replenishment | Phase 2       | Persistent progression, perk demotion, replacement queues, and resource accounting verified |
| 4     | Northern Italy geography and terrain                                 | Phase 2       | Playable regional campaign with fair movement and encounters                                |
| 5     | Strategic objective framework                                        | Phase 4       | Capture, supply, and named-army objectives persist and resolve correctly                    |
| 6     | Scouts, loyalty, messengers, and intelligence                        | Phases 3-5    | Observable information travels through physical, testable systems                           |
| 7     | Personality-driven campaign AI                                       | Phases 4-6    | AI pursues objectives using its own information without omniscient tracking                 |
| 8     | Forts, blockade, relief, and assaults                                | Phases 4-7    | One complete fort operation works strategically and tactically                              |
| 9     | Complete Northern Italy campaign                                     | Phases 3-8    | Campaign can be finished, lost, and replayed without broken progression                     |
| 10    | Release-quality polish and hardening                                 | All phases    | All requested features and quality checks pass together                                     |

Some post-demo work can be scheduled independently, such as equipment research and map art. Integration should still follow these gates. Polish and testing happen in every phase, not only Phase 10.

## 5. Phase 0: Prepare the Demo Without Breaking the Game

### Deliverables

- Add an explicit demo entry point or development mode, separate from the normal campaign.
- Use in-memory demo state by default. Any demo save uses a separate key and scenario identifier.
- Keep the current renderer available for comparison and rollback during development.
- Create a reproducible battle fixture with fixed rosters, terrain, positions, objectives, and random seed.
- Record baseline screenshots and a short command sequence in the current renderer.

### Simulation and Rendering Boundary

Introduce a small, application-owned runtime that advances the authoritative model. Both renderers consume state and issue the same commands; neither owns combat rules.

The boundary needs only the capabilities actually required:

- Advance simulation with a fixed time step and explicit pause/speed controls.
- Submit orders such as select, move, attack, face, reform, withdraw, and recall.
- Project world positions to screen positions for labels and inspectors.
- Resolve screen positions into legal terrain points or visible entities.
- Control camera position, bounds, zoom, and minimap footprint.
- Notify the interface of selection, battle results, and other meaningful changes.

The existing update loop uses a clamped variable delta, so deterministic replay is not an existing guarantee. Add fixed-step and seeded-randomness tests before using replay as a parity test. Keep cosmetic animation randomness separate from combat randomness. Cap catch-up work after stalls and pause on backgrounding rather than unexpectedly simulating minutes of combat when the tab returns.

Do not introduce a new ECS, networking architecture, physics engine, or wholesale state-management rewrite. The current model and tactical helpers should remain authoritative wherever they already work.

### Clock Policy

For this roadmap, **campaign time pauses during tactical battles**, matching the current single-army model. Campaign scouts, couriers, loyalty, and sieges therefore also pause while the player fights.

At encounter creation, snapshot eligible reinforcements and calculate their battle arrival schedule from campaign distance, route, and condition. Save that schedule. Do not run campaign movement and tactical arrivals independently and accidentally count the same army twice.

### Acceptance

- Exactly one runtime advances the model, regardless of the active renderer.
- Pause and 0.5x remain correct; rendering at different frame rates does not change order execution.
- Existing simulation tests still pass after the boundary changes.
- Entering, resetting, and leaving the demo does not alter the player's campaign save.
- Repeatedly opening and closing the demo disposes of listeners, audio, textures, and renderer resources.

## 6. Phase 1: Build the Visual Depth Demo

### 6.1 The Playable Slice

Create a roughly 10-15 minute engagement on a fictional Northern Italian river crossing. Include:

- Five to eight player regiments across two corps, with infantry, cavalry, and artillery represented.
- An independent main general and two corps officers embedded in host regiments.
- A mixed enemy force and one scheduled reinforcement group.
- A river, bridge, road, wooded area, low ridge, small settlement, and supply position.
- Deployment, maneuver, firing, melee, gradual formation changes, exhaustion, wavering, and routing.
- A capture/hold objective, an enemy counterattack, and clear victory and withdrawal outcomes.
- Existing finite ammunition, resupply, casualty, and command effects.
- A temporary result summary and restart/exit controls. Full persistent loot and headquarters progression wait for Phase 3.

Include a companion campaign view in the same isolated demo, with marching army markers, readable settlements, roads, river crossings, and visibly raised terrain. It may reuse the current campaign mechanics and a clearly identified illustrative geography layout; it is not yet the researched, expanded Northern Italy campaign. Provide direct access to the representative battle as well as the normal contact transition so both visual treatments can be reviewed easily.

Exclude the full Italy map, town loyalty, recruitable officer economy, physical campaign scouts, campaign personality AI, and siege warfare from this demo. Those systems would not answer the initial graphics and battlefield-control question.

### 6.2 Visual Direction

Use an elevated, painterly battlefield with convincing depth and a stable tactical camera. The map should occupy the primary viewport without a decorative frame. Prefer a hybrid relief-and-sprite implementation if it produces the desired style with less cost than fully modeled soldiers and buildings.

- Test an orthographic camera first, with a bounded tilt and zoom range. Free-flight and ground-level camera modes are out of scope.
- Favor clear silhouettes, recognizable formations, visible terrain contours, and consistent lighting over cinematic effects.
- Give infantry, cavalry, artillery, officers, and wagons distinct silhouettes at normal play distance.
- Use original or licensed bitmap textures for ground, roofs, foliage, uniforms, and interface art.
- Preserve faction recognition through flags, trim, silhouettes, and labels rather than covering everything in one color tint.
- Keep smoke localized and readable. It should support firing feedback without continually hiding the battlefield.
- Avoid a generic low-poly appearance as the final visual target. Blockout assets are acceptable during development, not at the approval gate.

**Minimum representative art set:** infantry for both sides, cavalry with riders, artillery and crews, a mounted general, wagon, flags, several trees, a small building family, bridge, ground materials, and firing/impact effects. Include recognizable marching, firing, reforming, melee, and routing animation states.

Use the existing asset documentation as the starting point for provenance. Record each asset's source, license, modifications, scale, texture budget, and supported animation states in `docs/ASSETS.md` when implementation begins.

### 6.3 Hybrid Rendering Approach

For the initial depth experiment, Three.js can provide textured terrain relief, lighting, camera projection, and grounded sprites while React retains interface screens. This is a 2.5D presentation choice, not a commitment to fully modeled units or freely rotating cameras. Reuse appropriate existing bitmap art, then improve representative unit art where the current shapes remain too flat. Pin the evaluated dependency version when implementation starts; do not upgrade unrelated dependencies as part of the experiment.

- Use shared geometry, material atlases, and instancing for repeated soldiers and scenery where appropriate. Three.js provides `InstancedMesh` specifically for repeated geometry with different transforms. [InstancedMesh documentation](https://threejs.org/docs/pages/InstancedMesh.html).
- Prototype animation cost before building the complete troop catalog. Static instancing alone does not solve animated character rendering. Compare shared-part animation and baked animation techniques against a small number of conventional animated models.
- Choose an approach that can show coherent marching and formation changes without giving every visible soldier an expensive independent animation system. Directional sprite animation is an acceptable alternative to skeletal models.
- Use distance/zoom-dependent detail for troops, foliage, and shadows. Three.js provides an LOD mechanism, but orthographic zoom also needs screen-size-aware thresholds. [LOD documentation](https://threejs.org/docs/pages/LOD.html).
- Resolve pointer hits through explicit terrain and unit selection proxies. Three.js raycasting can support this, but game visibility and command eligibility must filter the results. [Raycaster documentation](https://threejs.org/docs/pages/Raycaster.html).
- Treat soldier models as visual representatives of regiment strength, not one authoritative combat entity per model. Casualties, targeting, and morale remain regiment-level simulation rules.
- Profile transparent foliage and smoke, shadow passes, draw calls, and per-frame allocations early.

Battlefield relief and simulation must use the same elevation and obstruction data. A visible ridge cannot be decorative if the player expects it to block fire. Conversely, hidden collision geometry cannot obstruct a route through apparently open ground. The campaign demo should distinguish presentation-only regional relief from existing functional terrain until Phase 4 completes terrain-aware campaign routing.

### 6.4 Camera and Map Edges

The previous blank/green edge issue needs a geometric solution, not a larger fixed background painted for one screen size.

- Separate playable bounds from visual terrain bounds.
- Clamp camera movement and zoom using the full visible ground footprint, including aspect ratio and tilt.
- Render sufficient surrounding terrain or deliberate distant scenery beyond the playable boundary.
- Recalculate limits after window resizing, orientation changes, and interface layout changes.
- Keep units and objectives within valid navigation bounds even when scenery extends farther.
- On the future campaign map, stream or tile geography rather than allocating one enormous texture.

**Acceptance:** extreme zoom and pan at narrow mobile, standard desktop, and ultrawide sizes reveal no unpainted strips, voids, clipped battlefield corners, or inaccessible objectives.

### 6.5 Controls and Smaller Battlefield Interface

| Input or state                          | Intended behavior                                                                                          |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Left-click friendly unit                | Select it and open a compact contextual inspector                                                          |
| Left-click visible enemy                | Inspect only information the player is entitled to know; do not issue an order                             |
| Drag on empty ground                    | Select a group without accidentally issuing movement                                                       |
| Modifier-click                          | Add or remove friendly units from selection                                                                |
| Right-click legal ground                | Move the selected units                                                                                    |
| Right-click visible hostile unit        | Attack when legal; otherwise show the reason the order cannot be issued                                    |
| Right-click and drag on ground          | Anchor the destination at the initial press; preview the formation there facing toward the cursor; release sets facing, not destination |
| Hover ground or target with a selection | Show move, attack, inspect, or blocked-action cursor and matching target feedback                          |
| Pause                                   | Permit planning and order queuing without advancing simulation                                             |
| Touch                                   | Provide explicit selection and order modes plus contextual move/attack actions; do not require right-click |

Cursor feedback must come from the same order validation used by the simulation. A sword cursor must not promise an attack the game will silently discard. Use familiar icon assets, with tooltips for unfamiliar commands, and suppress the browser context menu only over the game surface.

Replace the large bottom roster with:

- A shallow, collapsible corps strip showing selection, unit identity, strength, and urgent state.
- A compact selected-unit inspector that appears only when relevant.
- A small command toolbar with formation, posture, supply, and withdrawal controls.
- The existing headquarters button for roster administration.

Avoid duplicating the entire Army screen on the battlefield. On a typical desktop viewport, target at least 80% of the vertical space remaining map-visible in the default, unselected state. Treat this as an initial layout goal to validate, not a reason to shrink text below comfortable sizes. On phones, use a dismissible inspector and collapsed corps navigation rather than overlapping the map with several permanent panels.

### 6.6 Range, Morale, Fatigue, and Command Readability

**Weapon range**

- Show effective range and maximum range separately for the inspected or actively ordered unit.
- Use an arc where facing matters, not an unrestricted circle that suggests firing in every direction.
- Mark obstructed portions and invalid targets; account for terrain and friendly blocking using authoritative tactical queries.
- Do not draw eight overlapping full-strength range overlays during group selection. Emphasize the hovered/primary unit and offer a deliberate range-display toggle.
- Tie artillery overlays to the ammunition and fire mode that actually exist in the simulation. Do not display unsupported ballistic behavior.

**Morale and fatigue**

- Give friendly units separate compact morale and fatigue indicators, plus clear routed/exhausted symbols.
- The current `condition` value behaves as readiness, where a higher number is better. Either label it "Condition" consistently or display fatigue as its inverse; do not show a high value labeled "Fatigue" as a positive state.
- Show exact values in the inspector and stronger map warnings only when a threshold matters.
- Pulse the label or flag of a visible wavering enemy slowly toward white. Do not flash the entire regiment or expose hidden units.
- Include a non-color symbol and a reduced-motion mode that replaces pulsing with a steady state indicator.

**Command and formations**

- Attach each corps officer to a designated host regiment. The host carries a small command badge, and its position determines the corps command radius.
- Keep the main general independently selectable and movable.
- Show a command-radius overlay only when inspecting command or when explicitly toggled.
- Animate soldiers between formation positions over the existing transition duration. Maintain the corresponding movement/combat penalties until the transition actually completes.
- Keep selection footprints and hit targets stable during animation so units do not become difficult to click while reforming.

### 6.7 Demo Quality Gate

The demo passes only when all four areas below are acceptable.

| Gate                      | Evidence required                                                                                                                                                       |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Visual quality            | Side-by-side current/new screenshots of the same engagement at close, normal, and distant zoom; coherent assets and readable terrain, not placeholder blocks            |
| Interaction               | A player can identify units, inspect range and condition, issue move/attack/facing orders, and change formations without opening headquarters or fighting the interface |
| Gameplay                  | A complete battle with resupply, reinforcement, routing, victory, and withdrawal works; renderer changes do not change authoritative rules                              |
| Performance and stability | Representative combat is measured on agreed hardware; repeated loading has no persistent resource growth; resize and zoom tests pass                                    |

**Provisional performance targets:** 60 FPS on the agreed desktop reference machine, with median frame time at or below 16.7 ms and 95th percentile at or below 22 ms after warm-up. For an agreed lower-power tier, target 30 FPS with median at or below 33.3 ms and 95th percentile at or below 40 ms using reduced visual settings. These are proposed budgets, not measurements of the current application or promises for every device.

Start stress testing with up to 24 visible regiments including reinforcements and roughly 2,000 representative soldier models, then revise the visual population budget using measured results. This does not raise the player's eight-regiment army limit. Record hardware, browser, resolution, visual settings, draw calls, and frame-time distributions over several minutes of active combat. Headless CI alone is not a GPU benchmark.

Use Playwright at 1440x900, 1920x1080, 2560x1080, 768x1024, 390x844, and 360x800. Verify nonblank rendering, visible assets, camera framing, moving/animated content, selection, and absence of overlapping text. For WebGL, inspect screenshot pixels or a dedicated render-target capture; do not attempt `getContext('2d')` on the WebGL canvas.

### Decision After the Demo

1. **Pass:** approve the look and controls, then integrate them in Phase 2.
2. **Needs iteration:** improve the specific weak area before expanding content.
3. **The rendering approach does not justify its cost:** improve or simplify it while retaining the approved depth and painterly direction. Full 3D is not the acceptance criterion; convincing, readable depth on both maps is.

The review package should include a playable URL, comparison screenshots of both maps, representative gameplay captures, performance measurements, and known limitations. Full campaign expansion starts after this direction is accepted. An initial reviewable implementation may expose remaining demo-gate work explicitly; do not call the entire gate passed before its evidence exists.

## 7. Phase 2: Integrate the Approved Demo Into the Game

### Work

- Route normal battles through the approved renderer while preserving the campaign and headquarters loop.
- Adapt minimap data, camera controls, labels, selection, audio events, and browser test hooks to the new boundary.
- Apply compact HUD and input rules to both campaign and battle screens. Contextual actions differ, but left inspection and right orders remain consistent.
- Bring the existing village, bridge, and ridge scenarios to the approved visual standard, or explicitly retain a supported legacy renderer while conversions are completed.
- Provide loading, missing-asset, unsupported-graphics, and context-loss states. A graphics failure must not destroy the save.
- Add quality settings for visual population, shadows, foliage, particles, and render resolution. These settings must never change combat outcomes or enemy visibility.
- Preserve the existing Army/Armory/Officers typography, column structure, portraits, and inspector pattern. Make command administration another part of this hierarchy, not a separate visual design.

### Acceptance

- Complete a campaign encounter, battle, result report, headquarters visit, equipment change, save, and reload.
- Opening headquarters, resizing, pausing, or changing speed does not duplicate updates or lose orders.
- The smaller HUD remains readable on every target viewport and does not hide selected units behind an unavoidable panel.
- Existing formation, supply, officer, and reinforcement behavior survives the renderer integration.
- Decide the supported fallback policy explicitly before removing any legacy renderer.

## 8. Phase 3: Progression, Weapons, and Replenishment

### 8.1 Recruitable Army Commanders

Unify the standalone general's identity with the existing officer records. An officer can occupy an army, corps, or regiment role, but cannot hold incompatible simultaneous assignments.

- Add qualified army commander candidates to Officers with recruitment cost, rank, experience, traits, status, and a clear comparison inspector.
- Allow appointing and replacing the main general from headquarters, with role eligibility and assignment confirmation.
- Award experience for command participation, completed objectives, and battle outcomes. Avoid idle-time XP farming or disproportionate rewards for sacrificing troops.
- Show promotions, wounds, and deaths in the battle report and officer history.
- Make bonuses bounded and legible: command reach, rally effectiveness, and command efficiency are preferable to numerous invisible multipliers.
- Define what happens when an army commander is wounded, captured, or killed: acting command immediately, permanent appointment in headquarters, no softlock.

Recommended default: a flexible campaign in which the army commander is replaceable. A later historically constrained mode can keep Napoleon's role fixed, but that should be an explicit mode rather than quietly contradicting recruitable army command.

### 8.2 Embedded Corps Leadership

- Store `commanderId` and `commandHostUnitId` on each corps. Remove separate tactical corps-commander entities after migration.
- Let the player choose the host regiment in headquarters or pre-battle deployment.
- Calculate command presence from the host's position and state. Routing, capture, or severe disruption reduces or interrupts command.
- Do not allow an officer to teleport between distant regiments during a battle. Initial implementation permits reassignment outside combat only.
- If the host is destroyed or the officer is incapacitated, apply a clearly reported acting-command penalty until the battle ends. Resolve officer survival separately from assuming every host casualty kills the officer.
- Explain command status in the host's inspector and corps strip without adding another large card.
- Retain the main general as a separate entity linked to the appointed army officer.

### 8.3 Weapon Catalog

Move equipment definitions into a data-driven catalog when the current inline list becomes cumbersome. Each item needs faction/date availability, class, compatible unit type, purchase and sale value, accuracy, reload/fire behavior, effective/max range, ammunition requirements, and relevant handling tradeoffs.

Research the 1796-1797 roster before selecting named models. Do not automatically reuse every weapon from the current 1805-themed prototype. Start with a deliberately limited but meaningful catalog across line infantry weapons, specialized infantry weapons, cavalry equipment, and artillery weights; expand only where a choice changes tactics or logistics.

Avoid a simple expensive-equals-better ladder. Supply availability, range, reload, accuracy, mobility, training, and ammunition compatibility should produce useful tradeoffs. Preserve the straightforward buy/sell/equip workflow and show a concise comparison before purchase or reassignment.

### 8.4 Captured Weapons After Battles

Persistent enemy equipment is a prerequisite. Generate and retain actual regiment equipment and artillery gun counts on campaign armies before resolving captures.

The battle-result pipeline should:

1. Snapshot deployed personnel, carried weapons, artillery pieces, and supply at battle entry.
2. Track surviving formations, prisoners, abandoned equipment, and losses without turning every visual soldier into an inventory object.
3. Determine who controls the field and which retreats recovered equipment.
4. Separate friendly recovered weapons from enemy captured weapons.
5. Apply recovery limits and damaged/unserviceable losses.
6. Credit usable items once, by actual weapon type, and preserve the ledger in the report.

Run recovery after every battle, including defeat and withdrawal, but do not guarantee enemy loot every time. A retreat can retain carried equipment while forfeiting abandoned guns and enemy battlefield salvage. Artillery pieces must be counted separately from crew members.

The report should show casualties, returning men, captured personnel where modeled, recovered equipment, enemy captures, damaged equipment, officer changes, and money. Permit keeping or selling usable captured weapons through the existing armory flow.

### 8.5 Regiment Levels and Unlockable Abilities

Give regiments an explicit level derived from their current average experience, with selectable abilities or perks unlocked at defined level thresholds. Build on the existing experience and skill values rather than adding an unrelated second progression currency.

- Earn experience through meaningful battle participation, completed objectives, and bounded training. Officers and regiments retain separate progression records.
- Add a small, readable set of level tiers and ability choices appropriate to infantry, cavalry, and artillery. Final thresholds and bonuses need balance testing.
- Favor useful specializations such as steadier volleys, better endurance, stronger cohesion, or improved artillery handling over mandatory upgrades that simply multiply all damage.
- Show level, progress to the next level, selected abilities, and relevant prerequisites in the Army inspector. Keep only a compact level indicator on the map.
- Treat level as reversible: a regiment can fall below a threshold when inexperienced replacements dilute its average experience.
- When a level is lost, remove the selected perk slots and effects that depended on that level. Retain lower-tier perks for which the unit still qualifies.
- Record lost selections in history for explanation, but do not keep their bonuses secretly active. Regaining a level unlocks the corresponding choice again; the player can select a perk at that time.
- Do not remove permanent levels or perks merely because of temporary fatigue, low morale, or an officer's absence.

Casualties alone should not automatically reduce the survivors' average experience in the first implementation. The main dilution occurs when lower-experience replacements actually join. This keeps the rule understandable and avoids inventing individual veteran casualty tracking before it is needed.

### 8.6 Veteran and Regular Replacement Costs

Replenishment should be a decision between preserving a regiment's hard-earned quality and restoring its numbers cheaply.

| Replacement type    | Money and manpower                                                                                                           | Experience and ability consequence                                                                                       |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Regular recruits    | Standard manpower and required equipment, with no level-based veteran premium; any base recruiting fee is separately visible | Arrive with low experience and baseline skills, diluting the regiment and potentially removing levels and selected perks |
| Matched veterans    | Higher money and manpower cost per replacement, increasing with the quality/level being preserved                            | Arrive at the purchased experience and skill standard, preserving the quoted regiment quality when that standard matches |
| Mixed replenishment | An explicit combination of veteran and regular allocations, with a combined quote                                            | Predictable intermediate cost and dilution; no hidden automatic substitution                                             |

Add a bounded campaign manpower budget supplied by recruitment allocations, scenario events, and objectives, without introducing national population management. Because veterans cost more manpower per arriving soldier, label that budget as **recruitment manpower/capacity**, and explain the extra veteran preparation requirement in the cost breakdown. It is a resource abstraction, not a claim that two physical soldiers become one replacement. Maintain a separate literal headcount for army casualties, scouts, and arriving men.

Veteran pricing must increase with the experience and skill standard being purchased. Replenishing an elite regiment should cost materially more than replenishing a newly raised one. Do not apply that premium to regular recruits simply because they are joining a high-level regiment; their tradeoff is dilution instead.

Reserve the purchased replacement standard in the order. If the regiment gains experience while the order is underway, the old order does not silently upgrade into more expensive veterans for free. Show the updated projected result and offer an explicit adjustment to the undelivered portion.

### 8.7 Replenishment Over Time

Replace instant replenishment with an order initiated in headquarters and fulfilled in batches over campaign time.

- The player chooses the number of replacements and their quality or mix.
- Before confirmation, show cash, manpower, required weapons, arrival estimate, final strength, projected experience/level, and any perks that would be lost.
- Reserve the required resources when the order is accepted so several regiments cannot spend the same manpower or weapons.
- Initially require the army to be stationary at an eligible friendly, supplied location. Marching, losing access to supply, or entering battle suspends delivery with a visible reason.
- Let replacement batches join at a defined rate based on location capacity and purchased quality. Higher-grade replacement preparation can take longer as well as cost more.
- Share finite location capacity fairly across simultaneous orders; splitting one order into many must not accelerate recruitment or avoid veteran pricing.
- Update actual men, skills, experience, level, and perk eligibility as each batch arrives, not when the order is merely placed.
- Apply the existing pause/speed settings and the campaign-clock policy. No replacements arrive during a paused tactical battle or through unannounced offline progression.
- Allow cancellation of the undelivered portion, returning unspent reserved resources. Already delivered men remain, and explicitly spent preparation costs are not refunded.
- Persist reservations, quality quotes, progress, delivered batches, and cancellation state through save/reload.

Use a weighted experience calculation for arrivals:

```text
new average XP =
  (surviving men * survivor average XP + arriving men * replacement average XP)
  / (surviving men + arriving men)
```

Apply the same principle to the existing trainable skills, then derive the new level and valid perks. For illustration only, 400 survivors at 3.0 average XP joined by 200 recruits at 0 XP become a 600-man regiment at 2.0 average XP. Any perk requiring a threshold above that new value is removed. These numbers illustrate dilution, not finalized level thresholds.

Headquarters should offer a concise progress row with arriving/remaining men and time remaining, plus an inspector for the detailed quote. Do not introduce another permanent battlefield roster panel. Warn before the player commits to a replenishment plan that would remove a selected perk, and report the actual demotion when the relevant batch arrives.

### Acceptance

- Recruit an eligible army commander, appoint them, fight, gain XP, reload, and retain their history and command effects.
- No officer is duplicated across assignments; wounded/dead officers cannot provide active command.
- Corps command follows its host and fails predictably when that host routes or is lost.
- Captured equipment matches the enemy's deployed catalog and never exceeds recoverable quantities.
- Reloading a result screen cannot grant rewards twice; equipping, selling, casualties, and recovery conserve inventory.
- The player can recover from commander loss without being forced to restart a viable campaign.
- A regiment earns enough experience to level up, selects an ability, and retains the correct effects after reloading.
- Veteran replenishment costs more money and manpower at higher purchased quality and preserves the quoted experience standard.
- Regular recruits arrive over time, dilute experience and skills by the actual delivered count, and remove ineligible selected perks when a level is lost.
- A demoted regiment can earn its way back to the level and select an ability again, without stacking the old and new bonuses.
- Queued orders, partial arrivals, cancellation, supply interruption, battle transitions, and reload cannot duplicate men or refund already consumed resources.
- Splitting orders, changing unit level while waiting, or switching replacement quality cannot bypass costs or create free veteran experience.

## 9. Phase 4: Northern Italy Map and Terrain

### 9.1 Geography Before Map Size

Build a regional campaign with meaningful routes, crossings, supply positions, and defensible approaches. Increasing travel distance alone would make the game slower, not deeper.

- Begin with one connected region containing approximately 6-10 useful strategic locations, then expand toward a researched theater with roughly 20-30 meaningful locations if that density supports the campaign.
- Use a research-backed geography plan covering the necessary approaches, river corridors, settlements, and fortified positions. Mantua is a proposed strategic anchor, not the only objective.
- Give campaign coordinates their own scale and units. Separate campaign distance, tactical distance, elevation, and travel time.
- Define scenario metadata for bounds, terrain, faction presence, battle templates, and legal retreats.
- Stream or tile map artwork and terrain with distance-dependent detail. Do not upscale the current fixed-size Danube texture.
- Preserve a readable strategic view with army banners, roads, towns, forts, and optional intelligence layers. Individual tactical soldiers are unnecessary at campaign scale.

Use the approved 3D terrain approach for campaign relief where it improves readability, with simplified assets and an elevated strategic camera. Do not let mountains or town models obscure army banners or routes. Reuse the demo's palette and materials so campaign and battle feel like the same game.

### 9.2 Terrain Rules

| Terrain                 | Campaign behavior                                             | Tactical behavior                                        |
| ----------------------- | ------------------------------------------------------------- | -------------------------------------------------------- |
| Road                    | Faster, lower-fatigue travel when the route is usable         | Efficient movement, but no automatic cover bonus         |
| Open ground             | Baseline movement and observation                             | Clear formation space and exposure                       |
| Forest                  | Slower movement and reduced observation                       | Cover, disrupted movement, and restricted line of sight  |
| Slope or ridge          | Greater travel effort; routes prefer viable grades            | Movement cost and elevation-dependent visibility         |
| River                   | Impassable except at an allowed crossing                      | No walking through water where a crossing is required    |
| Bridge or ford          | Route bottleneck, with width and availability                 | Constrained movement and defensible approaches           |
| Wet or difficult ground | Optional authored movement penalty, not a full weather system | Slower cavalry/artillery and additional fatigue          |
| Town or fort            | Destination, supply, ownership, and access rules              | Buildings, walls, gates, cover, and valid approach lanes |

Use one source of terrain truth for movement, route previews, estimated arrival, fatigue, and visible feedback. Apply the same rules to player and enemy forces, adjusted only by explicit unit capabilities and condition.

Retain proven pathfinding code where it fits. Validate whether the installed PathFinding.js APIs support each required cost model; do not assume the current bridge A* setup supports arbitrary weighted terrain. If necessary, use a maintained weighted-graph pathfinding library for campaign road networks while retaining tested grid navigation for tactical obstacles.

Add regiment footprint and crossing behavior incrementally. A bridge needs a usable queue/column approach and stuck-unit recovery; it does not require a new individual-soldier physics simulation.

### 9.3 Campaign Experience

- Show the proposed route, estimated arrival, expected fatigue, and blocking reason before confirming movement.
- Allow orders while paused and keep 0.5x available at all times.
- Add automatic pause options for contact, scout loss, objective change, and important intelligence.
- Choose battle templates from encounter terrain and approach direction, not only hard-coded enemy IDs.
- Resolve withdrawal to a valid friendly or otherwise legal fallback location. Do not send Italy armies to a legacy Danube town.
- Preserve nearby-army reinforcement logic using route distance and travel conditions rather than a simple unqualified radius.

### Acceptance

- Both factions take legal crossings and pay equivalent terrain and fatigue costs.
- A faster road detour can beat a shorter difficult route when expected.
- Campaign and battle maps agree on the strategic crossing or fort being contested.
- No units leave navigable bounds, become permanently stuck at bridges, or spawn across an impassable barrier.
- The map remains usable at minimum zoom and on ultrawide screens without blank margins or unreadable labels.
- Legacy Danube coordinates are never interpreted as Northern Italy positions during loading.

## 10. Phase 5: Strategic Objectives

Create a data-driven objective system before authoring a long campaign. Objectives should refer to stable town, depot, fort, or army IDs rather than text labels or proximity hacks.

### Initial Objective Types

- Capture and hold a location for a defined campaign duration.
- Secure or deny a supply depot.
- Defeat, force the surrender of, or reduce a specifically identified army below an explicit threshold.
- Defend a crossing or keep a route open.
- Reach a destination or intercept a force before a deadline.
- Later, relieve a fort, maintain a blockade, or escort a dispatch.

Define the difference between winning one engagement and destroying an army. A defeated army that retreats and reforms should not satisfy a destruction objective unless the objective explicitly allows that outcome.

Each objective needs prerequisites, success/failure conditions, known location or search area, rewards, persistence, and a clear completion message. Hidden objectives must not reveal hidden enemy positions through markers or progress updates.

Supply locations should provide bounded stock, resupply access, or objective rewards rather than an unlimited income engine. Prevent repeatedly capturing the same location from generating infinite rewards.

### Acceptance

- Complete one location objective and one named-army objective through normal play.
- Objective progress survives saving, tactical transitions, and a target army's retreat.
- Failures and deadlines are clear, fair, and measured in the intended campaign clock.
- Rewards apply once, and objectives cannot refer to deleted or regenerated entities accidentally.

## 11. Phase 6: Scouts, Town Loyalty, and Physical Intelligence

These features form one system: observers discover something, reports travel, and commanders act on the information that actually arrives.

### 11.1 Real Scout Detachments

- Replace the temporary reveal-radius purchase with a deploy/recall control for physical scouting parties.
- Initially allow a small, bounded number of parties, such as one or two, drawn from eligible troops in the player's army.
- Allocate men, equipment, and condition from a parent regiment. Scouts are detachments, not free extra units and not a second player field army.
- Offer patrol routes or waypoints, automatic avoidance of superior forces, and a visible return route.
- Track states such as preparing, outbound, observing, evading, returning, captured, and destroyed.
- Treat toggling scouting off as a recall order. Scouts must physically return; the toggle must not teleport them or erase pursuit.
- Allow enemy scouts to operate under the same rules.

For the first implementation, avoid a separate tactical battle for every tiny patrol encounter. Use a documented, seeded resolution based on detection, nearby force strength, terrain, and escape opportunity, with visible outcomes. Larger contacts can trigger normal army battles where appropriate.

Nearby scouts may rejoin before a battle if they can reach the army in time. Otherwise they remain detached under the campaign-clock policy. A scout party cannot simultaneously contribute full strength to its parent regiment and exist elsewhere on the map.

### 11.2 Observation and Reports

Separate live observation from delivered intelligence:

- A scout or army observes an entity within its actual sight and terrain limits.
- Store a report containing observer, target identity or classification, estimated strength, observed position, observation time, and confidence.
- Reports are snapshots, not live references to an enemy's current coordinates.
- Directly observed enemies can be shown live; lost contacts become visibly stale last-known markers.
- Remote scout reports reach the army through a return trip or an explicit dispatch process. No radio-like instant updates from an isolated patrol.
- Expire or degrade old information and show its age in an inspector.

### 11.3 Town Loyalty

Track occupation/ownership separately from local loyalty. Capturing a town changes control immediately when conditions are met; it does not instantly change local sympathies.

- Loyalty affects the likelihood, delay, and reliability of reports to a faction.
- Use restrained inputs such as sustained friendly presence, successful defense, delivered supplies, and relevant objectives.
- Make changes gradual and explain their causes in the town inspector.
- Avoid a large population-management subsystem or repeated modal choices at every town.
- A town must actually observe a nearby force or receive a report before it can relay its whereabouts.

### 11.4 Messengers

- Spawn a physical courier when a town or scouting party sends a dispatch.
- Give it a destination, route, payload, faction, dispatch time, and delivery state.
- The payload retains the original observation time and location; it does not follow the target invisibly.
- Couriers can be detected, intercepted, captured, delayed, or lost through the same bounded encounter rules as other small detachments.
- Delivery updates the recipient's intelligence. Capture may disclose the dispatch to the captor; destruction without recovery discloses nothing.
- Avoid leaking unseen couriers through notifications, minimap icons, selection, or hover targets.
- Support friendly information networks as well as hostile ones, so this is a strategic tool rather than only a punishment for the player.

### Acceptance

- A scout leaves the army, observes an enemy, reports, is recalled, and returns its surviving personnel and equipment.
- Captured or destroyed scouts cause losses exactly once and cannot be recalled back into existence.
- An enemy-friendly town spots the player, launches a courier, and the enemy reacts only after delivery unless it has another legitimate source.
- Intercepting that courier prevents its report from reaching the recipient.
- A delivered stale report sends an enemy toward the old position, not the player's hidden current position.
- Scouts, couriers, reports, and loyalty survive save/reload without duplicate deliveries or time jumps.

## 12. Phase 7: Smarter Campaign AI and General Personalities

Build the AI on objectives, routes, logistics, and intelligence. Personality should alter sound decisions, not replace decision-making with fixed pursuit radii or arbitrary movement.

### Personality Model

| User description | Proposed label | Behavior                                                                                 |
| ---------------- | -------------- | ---------------------------------------------------------------------------------------- |
| Aggressive       | Aggressive     | Accepts narrower advantages, pursues more readily, and pressures objectives              |
| Passive          | Cautious       | Prefers stronger odds, defensible positions, reinforcement, and supply security          |
| Random           | Erratic        | Makes bounded, seeded variations among plausible plans and sometimes takes unusual risks |

"Cautious" should not mean standing still forever. "Erratic" should not mean changing destination every frame or deliberately throwing away the army.

### Decision Structure

- Give armies states such as patrol, defend, investigate, attack, raid supply, regroup, retreat, reinforce, and relieve a fort.
- Score candidate plans using known enemy strength, own losses, condition, supplies, objective value, terrain, and reinforcement prospects.
- Let personality adjust risk tolerance, pursuit duration, reserve preference, and willingness to abandon a plan.
- Reconsider at scheduled intervals and on important events, with a minimum commitment period to prevent oscillation.
- Store seeded random choices and enough decision state to make save/reload behavior stable.
- Use remembered observations and uncertainty. The AI must not access hidden current player coordinates through a convenience helper.
- Permit coordination through explicit faction orders and shared/delivered reports, not an unexplained all-knowing faction map.

For tactical AI, retain working behaviors and incrementally add better target selection, reserve use, terrain occupation, artillery positioning, exhaustion management, and coordinated counterattacks. Campaign personality can influence tactical risk, but it should not make basic battle competence disappear.

### Acceptance

- In repeatable scenarios, aggressive and cautious commanders make measurably different decisions across multiple seeds.
- Every personality can defend an objective, withdraw from a hopeless fight, and seek resupply.
- The AI can be misled by stale reports and can recover through new scouting.
- Armies do not repeatedly reverse direction, pursue forever, or get trapped cycling between supply and attack states.
- A development-only decision inspector explains the selected plan and the information supporting it.
- Difficulty primarily adjusts competence and disclosed advantages, not secret visibility cheats.

## 13. Phase 8: Forts, Blockades, and Relief Battles

Forts should matter first as military positions, not as a requirement for fully destructible wall physics.

### First Complete Fort

- Persistent location with owner, garrison, stored supplies, defensive strength, and approach geometry.
- Garrison recruitment or reinforcement through a bounded cost and supply workflow, without granting control of another roaming field army.
- Campaign actions to observe, blockade, prepare an assault, reinforce a friendly garrison, or relieve a besieged position.
- A blockade model based on controlled approaches and supply access. Being somewhere inside a large radius is not sufficient by itself.
- Supply consumption, relief deliveries, and surrender conditions that progress in campaign time.
- A tactical map with functional walls or ramparts, gates, artillery positions, cover, and valid infantry approaches.
- A relief battle in which the surrounding geography and garrison support have explicit roles.
- Persistent garrison losses, supply expenditure, and limited damage or repair state after the operation.

For the first release, use authored gates, assault entrances, and predefined breach states where needed. Defer arbitrary wall destruction, underground works, and highly detailed engineering mechanics. These are optional expansions, not prerequisites for delivering useful forts.

### Acceptance

- A fort can be supplied, blockaded, relieved, assaulted, captured, and defended through a complete campaign sequence.
- A relief army opens an actual route or defeats the relevant blocking force; its mere presence does not reset every siege condition.
- Cavalry cannot cross walls, artillery cannot fire through invalid obstructions, and attackers have usable paths.
- Garrison casualties and supplies persist correctly, and a defeated garrison cannot regenerate for free.
- Fort objectives, ownership, and tactical results remain consistent after saving and loading.

## 14. Phase 9: Complete the Northern Italy Campaign

Expand the regional slice into a campaign only after its core systems work together.

### Content and Progression

- Research and author the selected campaign's factions, geography, commanders, uniforms, weapon availability, and mission sequence.
- Preserve the player's two-corps organization as a deliberate gameplay abstraction. Review historical terminology before presenting it as an exact 1796 order of battle.
- Create an authored strategic progression with optional objectives and reactive enemy operations rather than only a counter of armies defeated.
- Mix crossing battles, town defenses, supply interceptions, open-field engagements, fortified positions, and relief operations.
- Carry the player's army identity forward through casualties, regiment levels and abilities, reinforcements, officer careers, equipment, and campaign reports.
- Balance travel, recovery, timed replenishment, recruitment manpower, level-scaled veteran costs, weapon availability, and battle rewards together.
- Define campaign victory, campaign defeat, voluntary withdrawal, and recovery from a costly but survivable loss.
- Prevent softlocks where an unfinished objective is unreachable, a required enemy was deleted, or the army cannot replenish enough to continue despite the campaign supposedly remaining active.

### Representative End-to-End Campaign Story

1. Appoint an army commander, organize two corps, assign command hosts, and equip the army.
2. Receive an objective to secure a supply position and open a route toward a fortified area.
3. Send a scouting party ahead while the army follows a lower-fatigue road route.
4. A hostile-leaning town observes the army and dispatches a courier.
5. Intercept the courier or accept that an enemy commander may receive the report.
6. Encounter a defending army and transition into a terrain-matched battle.
7. Maneuver through a crossing, watch fatigue and morale, and use visible range information to position artillery.
8. Win or withdraw; resolve losses, officer XP, and actual recovered/captured weapons.
9. Refit through headquarters, choose whether to preserve veteran quality or accept recruit dilution, and decide whether to wait for replacements, pursue, secure supplies, or move against the fort.
10. Respond to a personality-driven relief operation, complete the strategic objective, and continue the campaign.

This sequence is the integration test for the requested experience. Each system must produce consequences the player can understand without requiring a large permanent dashboard.

## 15. Phase 10: Visual, Feature, and Release Polish

### Battlefield and Campaign Presentation

- Consistent materials, lighting, unit scale, flag readability, and animation quality across all maps.
- Clear marching, firing, reloading, reforming, charging, wavering, routing, and exhausted states.
- Responsive command acknowledgement, destination markers, formation previews, and invalid-order reasons.
- Controlled smoke, impacts, sound distance, and audio volume; mute settings continue to work.
- Label priority and collision handling so important units remain readable when formations overlap.
- Smooth camera transitions and reliable minimap navigation with no blank map edges.
- Quality settings that preserve gameplay-relevant visibility and information.

### Headquarters and Command Screens

- One visual system across Army, Armory, Officers, command assignment, recruitment, and reports.
- Dense, organized rows and connected corps structure instead of larger decorative cards.
- A persistent contextual inspector for detailed decisions, with no duplicated statistics across several panels.
- Clear comparison of officers and weapons before committing money or changing assignments.
- Clear replenishment quotes, arrival progress, projected level changes, and warnings about losing selected abilities.
- Visible disabled-state explanations, confirmation for destructive actions, empty states, and error recovery.
- Keyboard focus, screen-reader labels for controls, touch alternatives, and reduced-motion behavior.

Keep the aesthetic restrained and original: readable serif display accents, practical body typography, portrait and equipment art, limited metallic accents, and balanced terrain/faction colors. Do not turn every screen into a dark brown panel or a wall of ornate borders.

### Campaign Usability

- A compact objective list and dismissible intelligence log, not a stream of blocking popups.
- Optional auto-pause for genuinely urgent events.
- Clear timestamps and uncertainty for reports.
- Tooltips for unfamiliar icons; no permanent instructional paragraphs occupying the battlefield.
- Useful battle reports and officer histories without requiring the player to inspect every regiment after every engagement.

## 16. Data, Persistence, and Migration Plan

### Proposed Record Extensions

These are responsibilities, not a requirement to introduce a new module for every row.

| Record               | Important additions                                                                                                                                    |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Campaign scenario    | Stable ID, historical setting, bounds, distance scale, terrain references, factions, and objective definitions                                         |
| Army                 | Persistent regiment roster, appointed commander ID, supplies, knowledge, AI plan, personality, and campaign location                                   |
| Corps                | Commander ID, host regiment ID, member IDs, and current command status                                                                                 |
| Regiment progression | Average XP, derived level, skill values, tiered perk selections, prerequisites, and demotion history                                                   |
| Officer              | Eligible roles, assignment, XP, traits, service history, wounds, and capture/death state                                                               |
| Recruitment budget   | Available and reserved manpower/capacity, allocation sources, and accounting history                                                                   |
| Replenishment order  | Regiment ID, requested/delivered men, quality mix, purchased XP/skills, reserved resources, delivery rate, progress, and suspension/cancellation state |
| Equipment            | Catalog ID, compatibility, date/faction availability, tactical stats, price, and ammunition class                                                      |
| Battle result        | Stable battle ID, deployed inventory snapshot, survivor returns, loss/recovery ledger, and reward-applied state                                        |
| Scout party          | Parent unit ID, allocated personnel/equipment, route, orders, condition, state, and reports                                                            |
| Town                 | Owner, loyalty by relevant faction, supplies, observation capability, and report cooldowns                                                             |
| Courier              | Sender, recipient, route, immutable report payload, dispatch time, and delivery/capture state                                                          |
| Intelligence report  | Observer, subject estimate, observed location/time, confidence, delivery time, and expiry                                                              |
| Fort                 | Owner, garrison, stores, approaches, blockade state, defenses, and persistent damage                                                                   |
| Objective            | Stable ID, referenced targets, prerequisites, progress, deadline, result, and reward state                                                             |

### Migration Rules

- Continue supporting current version-3 saves and existing earlier migration paths.
- Assign subsequent schema versions when each implementation lands; do not bundle every future field into one speculative migration.
- Preserve a recoverable copy before transforming a save and validate the result before replacing the active slot.
- Keep the demo's storage isolated from normal saves.
- Identify legacy campaigns explicitly as the Danube scenario. Do not reinterpret their coordinates, enemy identities, weapon availability, or completed objectives as Italy data.
- Offer starting a new Italy campaign separately. Cross-campaign army import, if later desired, needs explicit conversion and confirmation and is not assumed here.
- Migrate separate corps commanders into valid officer/host references, choosing a deterministic eligible host where possible.
- Map existing regiment XP and selected perks into the new level system with documented thresholds and a visible migration summary. Give legacy campaigns a defined opening manpower allocation; do not fabricate pending replacement orders for men already replenished under the old instant system.
- Persist pending orders, formation progress, reinforcement schedules, detached personnel, courier deliveries, and partially resolved results where supported by saving.
- Use stable IDs and idempotent resolution so loading cannot duplicate rewards, scouts, prisoners, or weapons.
- Validate missing references and corrupt data; show a recoverable error instead of silently replacing the player's campaign with a new game.

## 17. Testing and Verification

### Automated Simulation Tests

- Fixed-step pause/speed behavior and seeded replay across different render frame schedules.
- Existing formation timing, queued orders, ammunition, morale, fatigue, and routing behavior.
- Command radius, host routing, officer loss, acting command, assignment limits, and XP.
- Regiment level thresholds, tiered ability choices, weighted recruit dilution, perk removal after demotion, and valid reselection after regaining a level.
- Level-scaled veteran quotes, manpower reservations, timed batches, mixed quality, cancellation, supply suspension, and save/reload during replenishment.
- Weapon compatibility, availability, item accounting, artillery crew/gun separation, and reward idempotency.
- Weighted routes, impassable terrain, crossings, route estimates, and symmetric movement costs.
- Stable objective identity, deadlines, failure, completion, and one-time rewards.
- Scout personnel/equipment conservation, recall travel, capture, and battle participation rules.
- Town observation, delayed reports, courier interception, stale intelligence, and hidden-information isolation.
- AI personality differences, plan commitment, retreats, supply behavior, and non-omniscient decisions.
- Fort access, blockade, relief, surrender, assault, and persistent losses.
- Save migration fixtures, corrupt data handling, and reload during pending transitions.

### Browser and Visual Tests

- Real campaign movement through battle and back to headquarters, including victory and withdrawal.
- Left inspection, right orders, facing drag, group selection, cursors, and blocked actions.
- Touch-equivalent interactions and keyboard focus without reliance on hover alone.
- Terrain-conforming range overlays that match actual firing eligibility.
- Morale/fatigue visibility, reduced-motion wavering indicators, and label overlap at each zoom level.
- Hidden enemies and couriers absent from rendering, picking, minimap, overlays, and inspector data.
- Extreme pan/zoom, resize, orientation changes, ultrawide framing, and no blank margins.
- Nonblank WebGL screenshots, expected asset colors/coverage, and changes between frames while units move.
- Headquarters scrolling, recruitment, assignment, trading, result inspection, and save/reload.
- Replenishment previews, perk-loss warnings, partial arrival progress, cancellation/refund display, and updated regiment abilities.
- Repeated scene transitions, context loss, missing assets, and low-quality rendering mode.

Existing entry points are `npm test`, `npm run test:browser`, and `npm run build`. Extend those workflows where practical. The current Phaser-specific browser helpers need adaptation; a green legacy browser run alone will not establish that the new renderer works.

### Human Review

- Judge normal play distance, not only promotional close-ups.
- Compare before/after captures from equivalent states and camera footprints.
- Confirm that a player can distinguish unit type, facing, morale trouble, exhaustion, firing opportunity, and command support quickly.
- Run several complete campaign sessions with different AI seeds and personalities.
- Assess difficulty and economy over losses as well as victories.
- Record performance on actual reference hardware and supported browsers.

## 18. Main Risks and How To Control Them

| Risk                                                                            | Why it matters                                                                       | Control                                                                                                                  |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| New depth treatment looks less polished than the current game                   | A renderer change does not create art direction or good animation                    | A representative demo of both maps and explicit visual approval before conversion                                        |
| Animated troop rendering is too expensive                                       | Large numbers of individually animated models can exceed browser budgets             | Prototype instanced/shared animation early; profile visual population and LOD                                            |
| Renderer work changes gameplay                                                  | Timing and input are currently coupled to Phaser                                     | Single authoritative clock, command boundary, regression fixtures, and parity tests                                      |
| Bigger map creates tedious travel                                               | Geographic scale alone does not create decisions                                     | Start with a dense regional slice, meaningful routes, pause controls, and objective pacing                               |
| Intelligence becomes frustrating or unfair                                      | Hidden information can feel arbitrary if age and delivery are unclear                | Explicit reports, visible uncertainty, symmetric rules, and interception tests                                           |
| Personalities become simplistic or chaotic                                      | Labels alone do not produce competent opponents                                      | Contextual plan scoring, bounded variation, commitment periods, and multi-seed scenarios                                 |
| Equipment or scout duplication breaks progression                               | Several systems move the same men and items between records                          | Central accounting invariants and idempotent battle/report resolution                                                    |
| Veteran replacement costs make the campaign unwinnable or perks feel disposable | Progression and replenishment can punish losses twice without a viable recovery path | Preview dilution, preserve eligible lower-tier perks, provide bounded manpower access, and balance costly-loss scenarios |
| Historical detail expands without limit                                         | Accurate assets and research are substantial content work                            | Lock the campaign/date, use an approved catalog, and separate abstractions from historical claims                        |
| Forts become a separate game                                                    | Destruction, engineering, and siege micromanagement can consume the roadmap          | Deliver garrison/supply/blockade/relief/assault first; defer arbitrary destruction                                       |
| Saves break during repeated expansion                                           | New geography and entity types cannot safely inherit every old assumption            | Versioned scenarios, backups, migration fixtures, and isolated demo storage                                              |
| Polished UI grows back into a large HUD                                         | Every feature competes for permanent screen space                                    | Contextual inspectors, compact strips, optional layers, and viewport acceptance tests                                    |

## 19. Decisions To Confirm Before the Relevant Phase

These do not block writing the plan. Use the recommended defaults until the relevant work is approved.

| Decision                                       | Recommended default                                                                                                    | Needed before                                    |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| Which Italian campaign?                        | 1796-1797                                                                                                              | Historical asset and campaign content production |
| Is full 3D required?                           | No. Start with painterly relief, dimensional sprites, shadows, and an elevated camera on both campaign and battle maps | Confirmed by the user's visual clarification     |
| Can the overall commander be replaced?         | Yes in the main flexible campaign; historical restrictions would be a separate mode                                    | Phase 3                                          |
| How large is the player army?                  | Two corps, four regiments each; no expansion without a separate balance/UI decision                                    | Demo fixture and campaign balance                |
| How do replacement quality and demotion work?  | Level-scaled veteran money/manpower costs; timed batches; regular-recruit dilution removes perks above the new level   | Phase 3                                          |
| Does campaign time advance during battles?     | No; snapshot and schedule eligible reinforcements at encounter start                                                   | Runtime and intelligence implementation          |
| How are scouts commanded?                      | One or two real detachments with waypoints, avoidance, and physical recall                                             | Phase 6                                          |
| How detailed are forts?                        | Garrisons, supply, blockade, relief, and authored tactical assaults                                                    | Phase 8                                          |
| Which devices define performance?              | Desktop-first tactical quality; lower-quality functional tablet/mobile mode                                            | Demo performance approval                        |
| What happens on unsupported graphics hardware? | Preserve saves and offer an explicitly supported fallback or clear compatibility state                                 | Phase 2 rollout                                  |
| What happens to old campaigns?                 | Retain the Danube scenario; start Italy separately                                                                     | Phase 4 save migration                           |

## 20. Implementation Checklist and Completion Criteria

### First Approval: The Demo

- [ ] Establish isolated demo entry, baseline fixture, and save protection.
- [ ] Separate simulation timing and rendering/input adapters without unrelated rewrites.
- [ ] Build the playable crossing battle and companion campaign view with painterly depth; hybrid 2.5D is acceptable.
- [ ] Replace blockout art with the representative production-quality asset set.
- [ ] Implement compact HUD, left inspection, right orders, facing previews, and contextual cursors.
- [ ] Show effective/max range, obstruction, morale, fatigue, embedded corps command, and the standalone general.
- [ ] Preserve gradual formation changes, supplies, reinforcements, pause, and 0.5x speed.
- [ ] Pass functional, screenshot, pixel, map-edge, and performance checks.
- [ ] Review the playable demo and decide whether to proceed, iterate, or change rendering direction.

### Expansion After Approval

- [ ] Integrate the approved renderer, headquarters flow, minimap, input, and settings.
- [ ] Complete recruitable army command, officer progression, and embedded corps persistence.
- [ ] Add regiment levels and abilities, timed replenishment, manpower reservations, veteran cost scaling, recruit dilution, and perk loss/reselection after level changes.
- [ ] Add the researched weapon catalog and actual post-battle recovery/capture ledger.
- [ ] Build the first Northern Italy region with terrain-aware routing and encounters.
- [ ] Add persistent strategic objectives and bounded supply rewards.
- [ ] Add physical scouts, town loyalty, couriers, and delivered intelligence.
- [ ] Replace simplistic campaign pursuit with competent, personality-driven AI.
- [ ] Complete a fort blockade, relief, and assault sequence.
- [ ] Expand to the complete Northern Italy campaign and balance the progression economy.
- [ ] Finish art, animation, sound, accessibility, performance, migrations, and end-to-end regression coverage.

### Definition of Done

The roadmap is complete when every W01-W18 request has its acceptance evidence, the player can finish a Northern Italy campaign with a persistent army, and the approved visual/interface standard is maintained throughout normal play. No requested feature is considered finished solely because a button, label, or static model exists for it.

The authorized first implementation commitment is **Phases 0 and 1 only**, followed by a review. Both the campaign map and battlefield are part of this demo. That provides a concrete demonstration of the intended experience before spending effort expanding a visual and technical direction that has not yet been proven.

## 21. Initial Demo Implementation and Remaining Review

An initial, isolated implementation is now available at `/?demo=depth`. The original game remains at `/`. The demo uses separate in-memory campaign and battle sessions, never reads or writes the normal campaign save, and starts at 0.5x speed.

### Implemented for Review

- Three.js textured relief terrain on both maps, directional lighting, grounded shadows, layered bitmap vegetation and settlements, and detailed original troop sprites.
- An elevated, bounded camera with zoom, pan, centering, minimap navigation, and a relief/flat comparison toggle.
- A compact corps strip, contextual inspector, left-click inspection, right-click movement/attack, group selection, facing orders, contextual cursors, and a touch order mode.
- The existing timed formations, ammunition, supply, tactical combat, routing, campaign contact transition, and battle results through an independent fixed-step demo clock.
- Corps command attached to host regiments, a separate main general, command-radius feedback, and rally controls.
- Maximum firing arcs with terrain/friendly obstruction feedback, friendly morale bars, explicit fatigue readings, and reduced-motion-aware wavering indicators for visible enemies.
- Existing headquarters screens operating on demo state rather than the player's saved army.
- Focused simulation and browser tests for the new rendering/input path, in addition to the original game tests.
- An animation pass retaining the original painted sprites: displacement-driven infantry steps and horse gaits on both maps, per-soldier reforming movement, firing/reload poses for both armies' infantry and mounted cavalry, cannon recoil, crew activity, melee reactions, and individual volley flashes/smoke. Pause and speed use the simulation clock, not wall time.

### Not Yet an Approved Final Visual Gate

- The Italian sector is illustrative and reuses prototype campaign mechanics. The larger researched geography, terrain-aware campaign AI, physical scouts/couriers, forts, and objective progression still belong to the expansion phases.
- Regiment level tiers, perk demotion, manpower budgets, and timed veteran/regular replenishment are specified in Phase 3, not implemented by this visual demo. Headquarters still uses the existing prototype's replenishment behavior.
- Troops use one detailed painted direction with mirroring, mesh-articulated movement, and supplemental firing/reload poses. This is a 2.5D animation pass, not a complete skeletal or multi-directional sprite set. Independent wheel rotation, full directional marching/firing/melee animation, and final historical uniforms remain art work.
- Maximum range is tied to the current weapon rules. A separately calibrated effective-range band and additional ammunition modes remain future tuning, not invented demo statistics.
- The general remains the configured Napoleon fixture. Army commander recruitment and career integration remain Phase 3.
- Automated headless rendering checks establish functionality, not 60-FPS approval on real target hardware. Reference-device measurement and the user's assessment of both maps are still required.

The broad phase checklists above remain acceptance targets rather than an assertion that every demo or campaign gate is complete. Record the visual review before converting the normal game or starting the full campaign expansion.

## 22. Next-Session TODO: September 8 Playtest Feedback

**Status:** This was recorded as a next-session backlog on September 8. The September 10 native Godot pass now implements persistent bodies, fixed casualty slots, precise press-anchored group facing, and painted infantry/cavalry/gun/wagon movement. Full formation obstruction, melee contact and fortification occupation remain open. See the [native checklist and verification](../godot/POLISH_PASS.md). The original browser implementation remains unchanged.

**September 10 follow-up:** [Formation movement and melee](../godot/COMBAT_MOTION.md) now implements consistent marching left/right, oriented edge contact, mutual melee without shooting, and painted infantry/cavalry melee cycles. The user subsequently requested rear-rank replacements, superseding the original leave-gaps rule below: infantry now step forward within affected files, without moving bodies or recentering all survivors. In melee, ranks refill the current contact frontage. Multi-front contact allocation, gun-crew melee art, full friendly obstruction and fortification occupation remain open.

### Casualties and Bodies

- [x] Native Godot: leave dead soldiers on the battlefield and preserve surviving soldiers' formation positions.

  Remove visual soldiers in front-to-back rank order: the front/top rank first, then the ranks behind it. Interpret front relative to the unit's facing, not the screen orientation. Leave gaps where soldiers died instead of shrinking/recentering the layout or making every survivor move after each casualty. Keep stable soldier/slot identities; normal movement and deliberate formation-change orders may still reposition survivors. Place each body at its actual world position when killed, grounded on the terrain, and leave it there as its regiment moves away. Use pooled/batched rendering and distance-based detail so accumulated bodies do not introduce another smoothness regression.

  **Completion check:** successive losses remove soldiers front-to-back without moving stationary survivors; bodies remain at the casualty locations after movement, rotation, and camera changes.

### Movement and Facing Orders

- [ ] Make ordinary movement direct, precise, and less clunky.

  On unobstructed ground, a right-click should move the regiment straight to the exact clicked point, then leave it facing its direction of travel. Avoid unnecessary bends, oscillating turns, drifting past the destination, and stopping at a nearby pathfinding cell instead of the requested position. Retain legal routes around real obstacles and across bridges rather than allowing straight-line movement through impassable terrain. Preserve natural individual soldier motion without letting cosmetic following change the regiment's ordered destination.

  **Completion check:** a single order on open ground reaches the marked point with stable final facing and no overshoot or last-moment reshuffling; routes that genuinely require a detour still work.

- [x] Native Godot: implement press-anchored right-click-and-hold facing orders with a live formation box, including multiple selected regiments.

  After selecting a unit, pressing and holding the right mouse button on ground fixes the destination at that initial world point. Show a formation footprint/box centered there. Dragging rotates the preview to face from the original press point toward the current mouse position. Releasing confirms that orientation; it must not move the destination to the release point. Thus, pressing at A and releasing at B means move to A and face toward B, not move to B or face back toward A. Convert both points through terrain picking so the behavior remains correct on hills and at different zoom levels. A click without a meaningful drag remains an ordinary move; provide cancellation without issuing an order.

  **Completion check:** the preview stays centered at A throughout the gesture, the destination remains A during execution, and the regiment center reaches A on arrival. Final facing matches the A-to-B direction for every drag direction, including orders issued while paused. Selection and right-click attacks must not regress.

### Friendly Fire Obstruction

- [x] Native Godot: direct shots are blocked by intervening oriented friendly formation footprints, including close and offset formations. Selected target-line feedback uses the same obstruction check. Per-soldier lanes and building/fortification footprints remain future work; see [battle-order implementation](../godot/BATTLE_ORDERS.md).

  Reproduce the reported case and make shot obstruction account for the actual occupied formation frontage/depth, not just a narrow test against regiment centers. Check the full source-to-target firing path, including close friendly ranks and regiments crossing the line of fire. Use the same result for actual shot/damage permission, range feedback, and blocked-fire status. This request is to prevent firing through friendlies, not to introduce friendly-fire casualties.

  **Completion check:** intervening friendly infantry, cavalry, and artillery formations block shots when occupying the firing path, including offset/wide formations; moving clear restores fire. An enemy cannot take damage from a shot blocked by a friendly formation.

### Melee Contact and Animation

- [ ] Keep opposing formations adjacent in melee and improve close-combat animations.

  Establish contact at the opposing formation edges instead of sending both regiment centers to the same point. Keep individual combatants next to their opponents at believable fighting distance, not stacked on top of one another. Add readable attack, recovery, and hit-reaction poses appropriate to the unit type, with staggered timing instead of every soldier making the same motion simultaneously. Separate cosmetic contact placement from authoritative damage so animation cannot create extra attacks.

  **Completion check:** sustained melee stays in contact without overlapping whole formations, jittering, or repeatedly pushing apart and reapproaching; visible attacks correspond to actual combat and freeze on pause.

### Multi-Frame Painted Animation

- [ ] Preserve the existing painted style while replacing single-sprite deformation as the primary movement animation.

  Create small, genuinely distinct sprite-frame cycles for each relevant unit type rather than only bending or augmenting one static image. For infantry marching, show alternating steps with the legs swapping forward/back positions; keep the body, equipment, scale, and foot baseline registered between frames. Give stationary infantry a separate standing/resting base sprite rather than freezing a walking pose. Extend the matching frame approach to firing, reloading, and melee, and to appropriate mounted, gun-crew, and supply movement. Preserve the artwork the user likes and directional consistency. Cycle frames from simulation time and actual movement, respecting pause and 0.5x speed; stagger soldiers' phases and keep atlas/instancing costs bounded.

  **Completion check:** standing and marching infantry are visibly different, a slow close-up clearly shows alternating feet rather than a warped single silhouette, and starting/stopping does not pop or slide. Review a small representative atlas in-game before producing every unit's frames.

### Cover and Enterable Fortifications

- [ ] Add functional cover and fortifications with authored troop placements.

  Cover must affect actual combat, with protection determined by the occupied position and incoming direction where appropriate. Select a regiment and right-click an eligible fortification to order it to approach, enter, and occupy its defensive positions. Different fortification types should define their own troop slots, frontage, facing, firing positions, capacity, and entry/exit points, rather than all using the same rectangle. Include occupied/full/invalid feedback and a way to leave; movement into and out of cover must not teleport troops or place them inside walls. Integrate occupied positions with firing arcs, friendly obstruction, melee contact, and casualty slots. Prototype one complete tactical emplacement before extending this to the broader Phase 8 fort and siege systems.

  **Completion check:** an eligible regiment can enter, fight from, and leave a fortification by normal orders; distinct fortification layouts produce distinct placements, protection works in the simulation, and excess troops cannot silently overfill it.

### Suggested Order for Tomorrow

1. Fix precise movement and press-anchored facing previews together.
2. Stabilize casualty slots and add grounded bodies.
3. Correct friendly obstruction and melee contact using consistent formation footprints.
4. Review the standing/walking sprite prototype, then expand combat animation frames.
5. Build one complete cover/fortification interaction and expand its layouts after review.

Keep these items unchecked until their behavior is implemented and reviewed. Re-run simulation tests, desktop/mobile input and screenshot checks, and sustained-combat performance checks as each change lands; recording this TODO does not itself change the game.

## 23. Godot Migration Baseline

A native Godot project now lives in `godot/` beneath the existing project.
It combines the implemented campaign/army-management systems with the painted
depth-demo rendering and controls. The original browser implementation, artwork,
and browser saves remain available separately.

See [native setup](../godot/README.md) and the
[port inventory and remaining limits](../godot/PORTING.md) before starting the
next feature. This migration is not completion of the larger Italy campaign,
fortifications, full formation obstruction, or the new replenishment systems
above. The later native polish pass adds casualty bodies/slots, an expanded
illustrative Italy sector, and painted movement frames; it does not complete
the entire historical campaign or every planned animation state.

The native version includes an exact legal arrival point and press-anchored
right-drag facing, with automated checks. The broader movement and formation
backlog remains open for in-game review. Future features can now be developed
against the Godot simulation and native graphical test suites while retaining
the browser version as a reference.

## 24. Native Battle Orders And Steady Movement

The follow-up in [BATTLE_ORDERS.md](../godot/BATTLE_ORDERS.md) adds rendered-ground
LOS, shared enemy sightings, individual off-field retreats, one-time charge
impacts with separate mounted/foot fatigue, and side/rear morale penalties.
Rear attacks cause the greatest morale pressure. Moving figures share their
regiment's pace without distance-based catch-up acceleration or expanding
trail-based frontage. Existing painted movement and melee frames are retained.

These changes do not complete enterable fortifications, building occlusion,
per-soldier combat/pathfinding, historical Italy geography, or the long-term
replenishment roadmap. They are covered by focused simulation and native
graphical tests; movement feel still benefits from extended player review.
