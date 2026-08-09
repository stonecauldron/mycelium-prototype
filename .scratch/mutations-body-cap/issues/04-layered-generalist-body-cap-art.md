# 04 — Layered Generalist body + cap art

**What to build:** Player units render as layered Generalist body + cap sprites (child pair while Child, imago pair while Adult). Filled Mutation slots tint their layer; empty slots use the fixed default colors; Tier multiplies both layers. The body layer owns weapon mount and idle animation; the cap follows. Body mutations such as Mini/Lanky adjust scale and hurtbox only — not the physics body collider. Specialty full-body strain sprites are not used for player composition under this design.

**Blocked by:** 02 — Mutations in Shop → Plot → hatch → combat

**Status:** ready-for-human

- [x] Hub portraits and combat use layered `gen_*_body` + `gen_*_cap` for the unit’s life stage
- [x] Filled slots tint with the Mutation’s color; empty slots use child cap `#51422D`, child/imago body `#E4C8A2`, imago cap `#472D1C`
- [x] Tier color multiplies both layers
- [x] Body owns weapon mount and animation; cap follows body motion
- [x] Body mutations can adjust scale and hurtbox without changing the physics body collider
- [x] Player units do not swap in specialty full-body strain appearances for composition

## Comments

- Implemented layered `gen_*_body`/`gen_*_cap` appearances; player portrait/combat paths use `UnitAppearance.instantiate_player_layers`; empty-slot defaults + mutation tints + tier root modulate; CapFollow; body `silhouette_scale` after BodyShape remount.
