# Coordinated Battle AI

First tactical implementation, September 20, 2026. This replaces the independent
nearest-target planner in native Godot battles. The browser implementation and
campaign decision loop are unchanged.

## Try It

Open Battle Exercises and select **Coordinated Defense**. This uses Saint Martin,
a cautious enemy commander, an infantry line, a fresh reserve, supporting guns,
and screening cavalry. It is a separate exercise and cannot overwrite the campaign.
The same tactical planner also runs in ordinary battles and the other exercises.

In battle, Settings > **AI diagnostics** enables enemy intention labels, movement
paths, and the army's current plan. Click a visible enemy to read its decision
reason and commander doctrine. Diagnostics do not reveal hidden unit positions
or affect the simulation. Disable them for normal play.

## Decision Layers

- The army reassesses its plan every 12 simulation seconds: defend, advance,
  pressure a flank, or withdraw. Severe cohesion loss can interrupt this interval.
- Observations refresh every two simulation seconds using the shared terrain,
  range, woodland and building LOS checks. Lost contacts retain their last observed
  position and strength for up to 16 seconds; they do not follow hidden movement.
- Regiments receive their orders on successive physics ticks, rather than running
  every route search in one frame. Each normally commits for four seconds under
  an aggressive commander, six under an opportunist, or eight under a cautious one.
- Recovery, withdrawal, close battery threats, and forming square can interrupt
  routine commitments. Charges are cancelled when their target disappears or
  is observed forming a square.

Battle plans and unit assignments are serialized with the campaign, including
reserve commitment, contact memory and decision deadlines. Older saves without
these fields initialize the planner on their next planning cycle. Transient
scheduling queues are discarded on load and when an engagement ends.

## Unit Behavior

### Infantry And Reserves

Infantry share frontage assignments centered on the objective or the planned
advance. Widths derive from the existing formations, with spacing between
regiments. Candidate positions prefer open formation space, but reachable town
streets remain available when no completely open position exists.

Defenders may reserve a useful, appropriately facing wall or hedge near their
sector. They use the same approach, manning time, capacity and directional
protection rules as the player. Infantry stop for clear volleys near their sector
and initiate timed squares in response to nearby charging cavalry.

Reserves remain behind the line until observed pressure threatens a sector, an
arrived line regiment leaves a gap, or an advancing army can exploit a wavering
enemy supported by nearby infantry. Their assignments persist after commitment.
There is no fixed forty-second reserve release.

### Cavalry And Artillery

Cavalry screen or seek a flank rather than charging every nearby target. Charge
evaluation considers condition, morale, run-up distance, squares (including those
forming), woodland, occupied cover, friendly obstruction, supporting infantry,
and nearby enemy guards. Actual charges still use the shared stamina, momentum,
impact, cooldown and collision systems.

Batteries score a bounded set of positions for weapon range, enemy separation,
terrain, clear LOS, current friendly obstruction and planned infantry lanes.
They prefer retaining an already useful position, limber for longer moves, and
deploy when stationary. Close enemy threats trigger displacement away from the
observed threat. Artillery never charges.

### Disengagement

Exhausted or ammunition-starved regiments seek rear positions and the existing
supply wagon. Recovery uses different entry/exit thresholds to avoid repeatedly
switching between resting and fighting. Shaken or heavily depleted units receive
real withdrawal orders; leaving the correct map edge marks them withdrawn.
Severe army-wide losses or a badly shaken, outmatched force trigger a committed
army withdrawal. No extra morale, ammunition or movement bonuses are granted.

## Current Limits

- This is a bounded tactical planner, not a complete campaign commander. Strategic
  objectives, army reinforcement coordination, scouting/courier reports, and supply
  raids remain follow-up work. Existing campaign personalities feed battle doctrine.
- Battlefield observations are shared within the enemy army. Physical messengers
  and command-distance communication delays are not simulated.
- Existing street navigation and local friendly avoidance remain responsible for
  movement. Congestion, narrow-crossing compression, multi-front melee and full
  formation rotation clearance are not solved by the planner.
- Infantry fire positions and cavalry maneuvers use a small candidate set, not an
  exhaustive terrain or encirclement solver. Difficult terrain can still require
  the AI to hold when it cannot find a route or safe battery position.
- Tactical withdrawal retains surviving men in the battle report, but a victory
  still uses the existing campaign defeated-army rule. Persistent strategic enemy
  retreats and their effect on campaign victory objectives are not implemented.
- There are no new difficulty presets, trained models, online services or hidden
  combat-stat bonuses. Doctrine and order commitment are the current variation.

## Verification

From this directory, replacing `godot` with the installed executable:

```text
godot --headless --path . --script res://tests/battle_ai.gd
godot --path . -- --verify-ai
```

`godot --path . -- --ai-demo` opens the defensive exercise directly while retaining
the loaded campaign for the Return to campaign command.

Headless checks cover doctrine, frontage, reserves, expiring intelligence, charge
restrictions, firing lanes, emergency reactions, retreat completion, fortification
reservations, save validation and staggered scheduling. They also exercise all
three existing scenarios from both starting edges.

The native check opens the exercise through the UI, operates the diagnostic toggle,
captures desktop/narrow views and inspectors, creates an observed breach, triggers
army withdrawal, and verifies campaign isolation. Captures and logs are in
`test-results/ai-*` and `test-results/battle-ai.log`. The full native verification
runner includes this exercise; the normal Verify launcher includes the headless AI
suite. Full renderer performance remains a separate measurement from AI step cost.
