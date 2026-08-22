# Asset generation prompts — Dark Satanic

Everything in the game is currently a procedural placeholder (primitive meshes, noise textures, sox audio). This
file lists every asset worth replacing, the prompt to generate it with an external service, and the technical
constraints it must meet to drop straight into the existing scenes (paths, sizes, orientation, formats).

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
  extension). Then open the scene named in each entry and swap the `mesh` of the `Visual` MeshInstance3D (or
  replace the MeshInstance3D with the imported scene). Keep the collision shapes as they are — the listed sizes
  are the shapes the gameplay is tuned to; the model should fill them.
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
- Fits: sphere r 0.45 m (0.9 m across). Origin at the centre, face toward −Z. Floats 0.45 m above the floor.
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
  floor on spawn. Keep the eye a separate mesh or clearly separated so it can glow (emission 2.0).
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
  Replace with one `.glb` of a right hand/forearm, ≈ 0.5 m long, origin at the wrist, fingers pointing −Z, palm
  facing slightly inward; keep the `Muzzle` Marker3D at local (0, 0, −0.2). Visible at the bottom-right of a
  100° FOV camera at 0.4× resolution — keep it chunky.
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
- To use: set the quad's material `albedo_texture`, `transparency = alpha`, `billboard = enabled`.

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

Services: a text-to-SFX model (ElevenLabs SFX, Stable Audio) for one-shots; a music model (Suno/Udio/Stable
Audio) for the two loops. All prompts should end with: *"lo-fi, recorded to worn VHS tape, slightly slowed,
no music, no voice"* (for SFX) and be rendered dry so the in-game reverb can sit on top.

| File (`assets/audio/sfx/`) | Length | Used by (cue) | Runtime pitch | Prompt |
|---|---|---|---|---|
| `dagger_tick.ogg` | 0.08 s | every stream shot (`dagger_tick`, −8 dB) | 0.9–1.15 | "very short dry bone click with a faint air hiss, like a tooth snapping, one hit" |
| `shotgun_thump.ogg` | 0.4 s | shotgun burst (`shotgun_thump`) | 0.9–1.1 | "deep muffled thump of a coffin lid dropping with a brittle crackle of splintering bone, one hit" |
| `hit.ogg` | 0.07 s | dagger hits an enemy (`hit`) | 0.9–1.2 | "tiny wet crack, knife into chalk, one hit, very short" |
| `skull_screech.ogg` | 0.5 s | enemy death (`skull_screech`, −6 dB) | 0.7–1.3 | "short strangled shriek of a choir of tiny voices cut off abruptly, distorted, tape-warped" |
| `spawner_groan.ogg` | 2.7 s | nest rises / emits (`spawner_groan`) | 0.9–1.1 | "long low groan of stone grinding and a slowed-down church organ pedal note, rising then sinking" |
| `gem_chime.ogg` | 0.55 s | gem collected (`gem_chime`) | 0.95–1.05 | "single small glass bell struck once, slightly detuned, reversed swell into the strike, cold" |
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
