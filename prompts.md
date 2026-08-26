# Asset generation prompts — Dark Satanic

This file lists every asset worth replacing, the prompt to generate it with an external service, and the technical
constraints it must meet to drop straight into the existing scenes (paths, sizes, orientation, formats).

Status (2026-08-24): everything ships as real assets — models (1–2, vesper regenerated at 1.5k tris), arena (3,
edge ring strip included), VFX sprites (4), UI art (5, plus the app icon), audio (6) and the extras (7:
`skull_arrive` weeper spawn cue and the `whispers` cue played by `WhisperScheduler` under `Game`). Only
`base_enemy.tscn` keeps its procedural sphere on purpose — it is the never-visible template the archetypes
override, and tests instantiate it directly.

Drop-in workflow for a replaced `.glb`: copy it over the file in `assets/models/` (keep the name), run
`tools/bake_textures.py <name>` for its greyscale albedo (names: weeper, mourner, lament, vesper, glutton,
cantor, sexton, thurible, tenebrae, gem, dagger, hand, floor), then `tools/run_tests.sh` — the import regenerates `assets/models/meshes/<name>.res`. If the
mesh name *inside* the new export differs from the old one, update the key under `_subresources/meshes` in the
`.glb.import` — note the key is the **imported resource name** (`<file>_<sanitised glTF name>`, e.g.
`cantor_tmprzjq4x4j_ply`), not the raw glTF name, and Godot assigns its own uid to the saved `.res`, so read it
back with `ResourceLoader.get_resource_uid()` rather than inventing one (or re-tick "Save to File" in the editor's Advanced Import dialog) or the `.res` silently stops being
regenerated. Finally re-fit the `Mesh` node transform in the scene named below and commit the regenerated `.res`.

## Global style sheet (prepend to every visual prompt)

> Style: "Sad Satan" creepypasta aesthetic — monochrome, near-black and bone-white, crushed blacks, heavy film grain,
> low-fidelity VHS capture, 1990s CD-ROM / PS1 low-poly horror, medieval woodcut and blackletter influences, liturgical
> and funereal imagery, silent and oppressive. No colour, no gore splatter, no text, no watermark, no modern UI.

Negative prompt (images and 3D): `color, saturated, neon, cartoon, anime, cute, glossy, photorealistic skin, text,
watermark, logo, blurry, extra limbs, busy background, high detail noise`

Why monochrome matters: the post-process shader (`src/vfx/shaders/sad_satan_post.gdshader`) converts everything to
luminance, crushes blacks, dithers to 5 levels at 0.4× resolution and adds grain. Only **silhouette and value
contrast** survive. Design assets as bold light-on-dark or dark-on-light shapes; fine surface detail is wasted.

### Technical conventions (3D)
- Units: 1 unit = 1 metre. Godot is Y-up, **forward is −Z**. Export glTF binary (`.glb`), triangulated, one
  material, no lights/cameras, origin as stated per asset, scale applied (1.0).
- Budget: 300–3000 triangles per enemy, ≤ 500 for props. Single 512² or 1024² greyscale albedo (PNG) is plenty;
  an emissive mask (white = glows) is the one map that reads well through the dither.
- Drop `.glb` files into `assets/models/` and textures into `assets/textures/` (both are LFS-tracked by
  extension). Then open the scene named in each entry and swap the `mesh` of the `Visual` MeshInstance3D (the
  current scenes point it at the `assets/models/meshes/*.res` Godot saves from the `.glb` on import). Keep the
  collision shapes as they are — the listed sizes are the shapes the gameplay is tuned to; the model should fill
  them. Generated models tend to come as a ±1 cube facing +Z (the Tripo weeper faced +X), so expect to set a
  scale and a yaw on the `Mesh` node; the `Transform3D(...)` literal in a `.tscn` lists the basis **rows**.
- Materials: keep `StandardMaterial3D` with `albedo_color` near white/grey and `emission` as in the scene, or
  `MaterialFactory.toon(...)` (`src/vfx/procedural/material_factory.gd`).

### Technical conventions (audio)
- Format: OGG Vorbis, 44.1 kHz, mono for one-shots, stereo for loops, peak ≤ −3 dBFS. Drop into
  `assets/audio/sfx/` using the **same file names** (the `AudioCue` resources in `assets/audio/cues/*.tres` and
  the `.import` files point at them; loops keep `loop=true` in the `.import`).
- Generate at neutral pitch; the cues randomise pitch at runtime (ranges listed below).
- Everything is played through a VHS bus (low-pass 3.8 kHz + lo-fi distortion + limiter), so bright highs are
  lost — put the character in the low-mids.

---

## 1. Enemies (3D models)

### 1.1 Weeper — swarm skull
- Scene: `src/enemies/archetypes/weeper.tscn` (`Visual/Mesh`), stats `src/enemies/resources/stats/weeper.tres`.
- Fits: sphere r 0.45 m (0.9 m across). Origin at the centre, face toward −Z. Flies at 1.5 m above the floor
  (head height — it never lands), bobbing ±0.25 m.
- Count on screen: up to ~60 at once — keep it ≤ 600 tris.
- Prompt: *"Low-poly human skull, weeping, hollow black eye sockets streaming dark tear stains, jaw slightly open,
  bone-white cracked surface, PS1-era game model, single greyscale texture, facing forward, centred, neutral
  pose, isolated on black."*

### 1.2 Mourner — large tank skull
- Scene: `mourner.tscn`. Fits: sphere r 1.2 m (2.4 m across), origin centre, −Z forward, rests at 1.2 m.
- Prompt: *"Massive low-poly skull wrapped in a torn funeral veil, cracked and fused with a second smaller skull
  at the crown, deep hollow eye sockets with faint inner glow, ash-grey bone, medieval reliquary feel, PS1 game
  model, greyscale texture with a separate emissive mask for the eyes, facing forward, isolated on black."*

### 1.3 Lament — nest / spawner
- Scene: `lament.tscn`. Fits: armoured body cylinder r 1.3 m, height 2.3 m centred at y −0.5 (spans −1.65..0.65),
  decorative stack up to y 1.1, and a **weak-point eye sphere r 0.6 at y 2.0** (spans 1.4..2.6) that must read as
  the obvious target. Total height ≈ 4.2 m. Origin at the body centre (y 0). Hovers at 3.5 m, rises from the
  floor on spawn. Keep the eye a separate mesh or clearly separated so it can glow (emission 2.0). Shipped: the
  eye is a faceted SphereMesh wearing `assets/textures/lament_eye.png` (equirect iris/sclera, albedo + emission),
  pupil staring straight down at the player.
- Prompt: *"Floating low-poly idol: three stacked stone rings of carved bone and iron bands, a cone crown, topped
  by a single large lidless eye on a short stalk, the eye pale and luminous, the body dark and armoured, wailing
  faces etched faintly into the rings, medieval torture-device meets reliquary, PS1 horror game model,
  greyscale texture plus emissive mask for the eye, upright, isolated on black."*

### 1.4 Vesper — stalker
- Scene: `vesper.tscn`. Fits: capsule r 0.3 m, length 1.6 m **along Z** (tip toward −Z at z −0.85), origin at the
  centre. Near-black body with a bright white tip (emission 2.5) — the tip is what the player sees dive at them.
- Prompt: *"Elongated low-poly spectre like a black dart or a shrouded diving bird, body of layered black rags
  streaming backwards, a single pale bone-white beak or candle-flame point at the front, no visible face, built
  for speed, PS1 game model, greyscale texture with emissive mask for the tip, facing −Z, isolated on black."*

### 1.5 Glutton — gem eater
- Scene: `glutton.tscn`. Fits: cylinder r 1.0 m, height 1.3 m (squat), origin centre, rests at 0.8 m; a mouth
  ring (torus inner 0.35 outer 0.6) facing −Z. Grows 3 % per gem eaten (uniform scale).
- Prompt: *"Squat bloated low-poly creature, a flattened sack of grey flesh with a round puckered maw ringed by
  pale teeth at the front, no eyes, stitched seams, breathing slowly, medieval bestiary grotesque, PS1 game model,
  greyscale texture, facing forward, isolated on black."*

### 1.6 Cantor — ranged singer
- Scene: `src/enemies/archetypes/cantor.tscn`, stats `src/enemies/resources/stats/cantor.tres`.
- Fits: capsule r 0.55 m, height 2.6 m, origin at the centre, hovers at 3.6 m. The `Visual/Mouth`
  sphere is the wind-up tell — `WindupVisual` swells its emission 0.7 → 3.0 over the 0.9 s before
  each shot, so keep the mouth a separate mesh.
- The first enemy that attacks from range: it holds off at 6–45 m and sings homing `PsalmShard`s
  (`src/enemies/projectiles/psalm_shard.tscn`) that lead the player by 0.35 s and can be shot down.
- Prompt: *"a tall gaunt low-poly cantor — a hooded choir singer with no legs, its lower body
  trailing away into ragged funeral cloth, thin arms folded around an open songbook held at its
  chest, the head a featureless bone mask split by one wide singing mouth, faint pale light inside
  the mouth, stiff ash-grey robes in flat low-poly folds, small iron bells sewn along the hem.
  Single subject, upright, symmetrical, facing forward, neutral pose, arms and hem fully in frame
  with margin on all sides, PS1-era game model, isolated on a pure black background."*
- Generated with forge-image (Flux, 768×1024) → hunyuan3d `image_to_3d` at `max_facenum=1800`.

### 1.8 Thurible — the zoner
- Scene: `src/enemies/archetypes/thurible.tscn`, stats `src/enemies/resources/stats/thurible.tres`,
  hazard `src/enemies/hazards/cinder.tscn`.
- Fits: sphere r 0.9 m, origin at the centre, hovers at 2.4 m. Mesh scaled 1.15.
- The first enemy that attacks the arena instead of the player: a `CenserComponent` drops
  burning ground (`CinderHazard`) around the *player* every 4 s. Each cinder arms for 2.5 s
  behind a growing sigil, burns for 0.6 s, then fades — long enough to walk out of, which
  is the whole design. Slowest thing in the game (2.2 m/s) and the tankiest non-boss, so
  ignoring it is expensive.
- Prompt: *"a low-poly floating censer — a pierced spherical brazier of dark pitted iron,
  its lid a small cone crown of carved bone, hung from three heavy broken chains that trail
  upward and end in nothing, thin faint light leaking from the pierced holes and seams of
  the sphere, small wailing faces embossed around its belly, a heavy sluggish curl of smoke
  pooling underneath it. Single subject, hanging upright and centred, chains and smoke fully
  in frame with margin on all sides, PS1-era horror game model, isolated on a pure black
  background."*
- Generated with forge-image (Flux, 768×1024) → hunyuan3d `image_to_3d` at `max_facenum=1600`.

### 1.7 Tenebrae — the boss

- Scene: `src/enemies/bosses/tenebrae.tscn`, stats `src/enemies/resources/stats/tenebrae.tres`,
  phases `src/enemies/bosses/boss_phase_controller.gd`.
- Named for the liturgical office of darkness, in which the candles are put out one by one until
  the church is black. That is the fight: the body is armoured (`damage_multiplier = 0`) and the
  only damageable parts are seven `WeakPointComponent` candles in a ring on its crown, each
  snuffed at its seventh of the health bar. It reads perfectly through the 5-level dither —
  seven bright points on a black mass — and the arena goes one notch darker as you win.
- Fits: cylinder r 2.9 m, height 7.9 m, origin at the centre; mesh scaled 4.6 (≈ 6.5 × 8.6 × 5.8 m).
  The candle ring sits at radius 2.3 m, y 3.23; the flames are separate meshes at y 3.74 so the
  controller can hide them one at a time. Hovers at 13 m, drops to 6 m in phase II, charges in III.
- Arrives on `BossDirector`'s own clock (every 180 s), not from the wave table — an ordinary
  SpawnEvent is dropped at max_alive, which is exactly when a boss is most due.
- Prompt: *"a colossal low-poly Tenebrae hearse — a towering triangular church candle-stand of
  blackened pitted iron and fused bone, its upper frame crowned by a ring of seven tall candles
  each tipped with a small pale flame, the whole structure grown into a hooded faceless mourner
  whose stiff funeral drapes hang in heavy flat low-poly folds and end in nothing, no legs,
  hovering, a small barred reliquary door set into its chest. Single subject, upright, symmetrical,
  seen straight on, neutral pose, all seven candles and the full hem inside the frame with margin
  on all sides, PS1-era horror game boss model, isolated on a pure black background."*
- Generated with forge-image (Flux, 768×1024) → hunyuan3d `image_to_3d` at `max_facenum=2600`.

## 2. Weapon and pickups

### 2.1 Dagger projectile
- Scene: `src/weapons/projectiles/dagger_projectile.tscn` (`Mesh`). Fits: 0.04 × 0.04 × 0.55 m, length along Z,
  tip at −Z, origin at the centre. Emissive light grey. Hundreds on screen — ≤ 60 tris.
- Prompt: *"Slender bone dagger, carved from a single rib, needle point, faint runic scratches, pale ivory, very
  low poly, pointing along its length, isolated on black."*

### 2.2 Gem
- Scene: `src/pickups/gem_pickup.tscn` (`Mesh`; the script builds an octahedron when the mesh is empty). Fits:
  0.6 m wide × 0.9 m tall octahedron, origin centre; spins; white emission 2.0 (brightest object in the game).
- Prompt: *"Small faceted crystal shard like a tear or a communion wafer of glass, glowing bone-white from within,
  low poly octahedral cut, isolated on black."*

### 2.3 Player hands (first-person view model)
- Scene: `src/player/player.tscn` → `CameraRig/Camera3D/HandViewModel` (two `BoxMesh` fingers 0.05 × 0.05 × 0.3 m).
  Replace with one `.glb` of a right hand/forearm, ≈ 1 m long including the full forearm, fingers pointing −Z,
  palm facing slightly inward; keep the `Muzzle` Marker3D at local (0, 0, −0.2). Visible at the bottom-right of a
  100° FOV camera at 0.4× resolution — keep it chunky, and fit the transform so the elbow cut stays outside the
  frustum at every sway/kick extreme (fingers near the muzzle, forearm exiting the bottom-right frame corner).
- Prompt: *"First-person view model of a gaunt pale human hand and forearm, fingers splayed forward as if casting,
  knuckles bound in grey cloth strips, faint scars, bone-white skin, low poly PS1 game asset, greyscale texture,
  pointing forward, isolated on black."*

## 3. Arena

### 3.1 Floor texture (tileable)
- Used by `src/arena/arena.tscn` floor material (`void_floor.gdshader`, `noise_tex`; 1 tile ≈ 6.7 m at
  `texel_scale 0.15`). Seamless, 1024², greyscale PNG, mid-grey average (the shader multiplies by brightness 0.85
  and fades to black at the edge). Drop in `assets/textures/floor_bone.png` and set it as `noise_tex`.
- Prompt: *"Seamless tileable top-down texture of a vast cathedral floor of cracked flagstones and packed bone
  fragments, shallow engraved circles and scratched prayers, dust, greyscale, high contrast, no lighting
  direction, 1024×1024."*

### 3.2 Edge ring
- `arena.tscn` `EdgeRing` is a thin white torus at r 30 m. Optional replacement: a 1024×64 tileable greyscale strip
  (thorn chain / rosary beads) mapped on the torus.
- Prompt: *"Seamless horizontal strip of a rosary chain of bone beads and iron thorns, greyscale, glowing white
  on black, 1024×64."*

## 4. VFX sprites (2D, PNG with alpha)
- `src/vfx/particles/hit_spark.tscn` (quad 0.08 m): 64² spark — *"single sharp four-point bone-white spark on
  transparent background, pixel art, greyscale"*.
- `death_burst.tscn` (box chunks 0.12 m, 40 of them): optional 64² bone-chip sprite — *"tiny jagged bone fragment,
  pixel art, greyscale, transparent background"*.
- `gem_sparkle.tscn` (quad 0.06 m): 32² soft glint — *"small soft cross-shaped glint, white, transparent
  background"*.
- `spawn_rift.tscn` (billboard quad 3.4 m, plus 24 rising motes): 512² summoning circle,
  `assets/textures/spawn_sigil.png`, generated with forge-image (Flux) — *"Top-down view of a ritual summoning
  circle carved into stone, seen from directly above, perfectly centred and circular: a bone-white ring of
  medieval blackletter script with radial spokes and small occult sigils around its rim, an empty dark centre.
  Medieval woodcut engraving, stark high contrast bone-white line art glowing on a pure black background."*
  Generated on black (**not** `transparent=True`, which hard-keys glows into a dark halo); alpha is rebuilt in
  post as `alpha := luminance, RGB := white` with a black floor lift and a radial fade past 0.94 r so the square
  corners vanish. That makes it an additive-blend sprite, which is what the particle `color_ramp` needs.
- To use: set the quad's material `albedo_texture`, `transparency = alpha`, `billboard = enabled`. Sprites driven
  by a particle `color_ramp` or `scale_curve` also need `vertex_color_use_as_albedo = true`, or the curve is
  computed and then thrown away.

## 5. UI (2D)
- **Title logo** (optional; the menu renders "DARK SATANIC" in UnifrakturMaguntia): 1600×400 PNG alpha —
  *"Blackletter title lettering reading DARK SATANIC, hand-inked, ink bleed and worn edges, white on
  transparent, medieval woodcut, no other elements."* → `src/ui/main_menu/main_menu.tscn` title label.
- **Panel frame** (9-slice, 96×96, alpha): *"ornate thin frame of carved bone and iron nails, corners with tiny
  skulls, white line art on transparent"* → replace `StyleBoxFlat` in `src/ui/theme/sad_satan_theme.tres` with
  a `StyleBoxTexture`.
- **Crosshair** (32×32 alpha): *"tiny inverted cross crosshair, pixel art, white on transparent"* →
  `src/ui/hud/crosshair.gd` draws procedurally; swap for a `TextureRect` if preferred.
- **HUD icons** (24×24 alpha, greyscale): gem (crystal tear), kills (skull), tier (roman numeral tablet).
- **Menu backdrop** (1280×720 PNG, very dark): *"empty black void with a faint distant procession of hooded
  figures, heavy film grain, VHS tracking lines, almost nothing visible, greyscale"* → `MainMenu` Backdrop.
- **Death screen ornament** (800×120 alpha): *"funeral banner scrollwork with skulls and lilies, white line art
  on transparent"* under the "REQUIESCAT" title.

## 6. Audio

Services: a text-to-SFX model for one-shots; a music model (Suno/Udio/Stable Audio) for the two loops. All
prompts should end with: *"lo-fi, recorded to worn VHS tape, slightly slowed, no music, no voice"* (for SFX) and
be rendered dry so the in-game reverb can sit on top.

The player-action and combat-feedback set below is generated **locally** with the `moss-sfx` MCP server
(48 kHz mono WAV) instead of sox, and each cue holds several interchangeable takes so a repeated action never sounds identical twice. Two
things about that model matter when regenerating: it centres the event inside the window it is given (so ask for
a window comfortably longer than the sound and trim the head yourself), and takes vary wildly in level, so render
`variations=3` and throw away the quiet ones. The trim/normalise pass is: cut from ~6 ms before the first frame
within 26 dB of the peak to the last frame within 40 dB of it, 2 ms fade in, 50 ms fade out, `sox gain -n -3`.
`tools/gen_audio.sh` deliberately does **not** synthesise these — running it must not overwrite them.

| File (`assets/audio/sfx/`) | Length | Used by (cue) | Runtime pitch | Prompt |
|---|---|---|---|---|
| `dagger_shot_01..03.wav` | 0.07–0.18 s | every stream shot (`dagger_tick`, −15 dB, 3 takes) | 0.92–1.12 | "one knife thrown hard: a crisp dry percussive snap immediately followed by a short whip of the blade slicing through air. Recorded very close, anechoic, no reverb, the whole sound over instantly" (plus a "single bone dagger launch" take) |
| `shotgun_blast_01..03.wav` | 0.95 s | shotgun burst (`shotgun_thump`, −7 dB, 3 takes) | 0.94–1.06 | "a heavy occult shotgun blast firing a burst of bone shards: a deep punchy low thump with a gritty crackling spray of splintering bone, close-up, dry with a short dark cavernous tail" |
| `jump_01..02.wav` | 0.45 s | player jump (`jump`, −13 dB, 2 takes) | 0.94–1.10 | "a single athletic jump takeoff: boots scuff and push off hard from stone, a short sharp grunt of exertion and a quick rustle of cloth. Close mic, dry, indoors" |
| `land_01..02.wav` | 0.37–0.55 s | player lands hard (`land`, −12 dB, 2 takes) | 0.90–1.08 | "boots landing hard on cold stone after a fall: one dull heavy thud with a faint gritty scrape of dust. Close-up, dry, short, no music" |
| `spawn_rift_01..02.wav` | 1.6 s | directed spawn telegraph (`spawn_rift`, −10 dB, 2 takes) | 0.90–1.12 | "a demonic summoning portal opening: a low ominous rising swell out of silence, hissing rush of air, dark occult rumble and a faint chorus of whispers, ending in a soft dry crack as something arrives" |
| `hit_01..02.wav` | 0.03–0.10 s | dagger hits an enemy (`hit`, −16 dB, 2 takes) | 0.88–1.20 | "a thrown blade striking bone: one tiny dry crack, like a knife punching into chalk. Extremely short, close-up, no reverb, no music" |
| `death_screech_01..03.wav` | 0.46–0.75 s | enemy death (`skull_screech`, −9 dB, 3 takes) | 0.80–1.25 | "one sharp burst of a skull shattering: an instant wet crack of bone splintering with a tiny strangled shriek inside it, over immediately. Close-up, dry, harsh, no reverb, no music" |
| `gem_chime_01..03.wav` | 0.75 s | gem collected (`gem_chime`, −14 dB, 3 takes) | 0.95–1.10 | "a single small cold glass bell struck once and immediately damped, slightly detuned, with a faint icy shimmer. Very short, close-up, dry, no music" |
| `spawner_groan.ogg` | 2.7 s | nest rises / emits (`spawner_groan`) | 0.9–1.1 | "long low groan of stone grinding and a slowed-down church organ pedal note, rising then sinking" |
| `tier_up.ogg` | 1.1 s | dagger tier up (`tier_up`, UI bus) | 1.0 | "short rising three-note bell chord with a reversed tail, solemn, church-like" |
| `death_stinger.ogg` | 3.0 s | player death (`death_stinger`) | 1.0 | "slow descending funeral chord on a detuned organ, slowed to half speed, reversed tail, tape hiss, ends in silence" |
| `ui_click.ogg` | 0.03 s | menu buttons (`ui_click`, UI bus) | 1.0 | "tiny dry tick of a rosary bead, one click" |
| `amb_drone.ogg` | 30 s loop, stereo | gameplay music (`amb_drone`, Music bus) | 1.0 | "seamless 30-second loop: a cathedral drone of sub-bass organ and reversed choir, slowed to half speed, distant, hollow, no melody, no rhythm, tape-warped" |
| `menu_hum.ogg` | 30 s loop, stereo | main menu (`menu_hum`, Music bus) | 1.0 | "seamless 30-second loop: faint electrical hum of an old CRT television in an empty room, a very low breathing tone beneath it, almost silence" |

Loops must be cut so the end matches the start (crossfade the last 0.5 s into the first 0.5 s) and stay under
−10 dBFS RMS; the menu hum should be about 6 dB quieter than the drone.

## 7. Optional extras (not wired yet, nice to have)
- **Whisper lines** (voice): 8–12 half-heard latin/english whispers (2–4 s each, dry, male, breathy) for random
  playback during runs — "requiescat", "ave", counting down numbers. Would become new `AudioCue`s played by
  `Game` on a random interval.
- **Skull spawn cue**: a softer "skull_arrive.ogg" (0.3 s, "dry breath intake with a hint of a far bell") — the
  Weeper currently has no spawn cue on purpose (its death screech was too loud for a 16-skull ring).
- **Splash/icon**: 512² app icon — *"bone-white inverted cross inside a rough circle on black, woodcut, greyscale"*
  → `icon.svg` / export presets.
