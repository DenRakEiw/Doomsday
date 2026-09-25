# Doomsday — Visual Design and Asset Production

**Version:** 0.1 (draft)
**Date:** 2026-09-21

Answers two questions: what the game looks like and how it is built, and specifically whether we
need 3D at all.

See also: [PLAN.md](PLAN.md) · [UI.md](UI.md) · [CONTENT.md](CONTENT.md)

---

## 1. The 3D question

**Recommendation: the gameplay map is flat 2D. We need no 3D objects. The *look* is 2.5D, achieved
through layering and shaders rather than geometry. A real globe appears only in the main menu and
the endings, where nobody has to click on it.**

This is not an aesthetic preference. It follows from what the game asks the player to do.

### Why flat wins on gameplay

**The player's core task is comparing every region at once.** Where is penetration weak, which
region is about to close, where is containment funded, where is society collapsing. A globe hides
half the planet at all times. Rotating to check the other side is not "immersion", it is a tax paid
several times a minute for thirty minutes.

This is why *Plague Inc.*, *Pandemic*, *Rebel Inc.* and *Bio Inc.* are all flat — and it is not only
the casual end of the genre. **Paradox ships flat too**, and has said why: their map is restricted to
a cylindrical projection, so the question was only *which* one. The reason is architectural. A
cylindrical projection makes the region map a **rectangular bitmap**, which is what makes the entire
genre's tooling cheap — and it is why *Victoria 3* can ship more than forty map modes. Nobody gets
forty overlays on a curved surface.

The research literature points the same way: globes win distance and direction judgements, flat maps
win **area comparison**, and the globe's inability to show the whole surface actively hindered users.
Area comparison across all regions at once is, precisely, our game.

And from people who shipped a globe: *Terra Invicta* players report the **night side is unreadable**
and ask for a 2D mode. Mapbox's globe project enumerates the bill — label collision has to be redone
on a tangent plane, symbols along lines cannot be pre-projected, and there are gaps at the poles.

The contrary examples prove the rule. *Civilization VI* and *Hearts of Iron* are about a front line,
which is local. *DEFCON* — thematically our closest relative — is a deliberately plain flat vector
map with, in its own description, a purposeful lack of geographic detail.

### Why flat wins on cost

| | Flat 2D | 3D globe |
| --- | --- | --- |
| **Picking a region** | Read one pixel from a CPU-side image. O(1), exact, trivial. | Raycast to sphere → UV → sample ID texture. Works, but it is a physics query, a projection and a lookup instead of an array index. |
| **Draw cost** | One quad, one shader, one draw call | Mesh, lighting, larger textures, higher mobile cost |
| **UI over the top** | Control nodes directly over a Sprite2D | A SubViewport, a second camera system, and depth-sorting questions for every marker and label |
| **Labels and markers** | Place at a 2D centroid | Must track a moving sphere, hide on the far side, and fight foreshortening at the poles |
| **Art required** | One base map, one ID map | Albedo, night lights, clouds, normals — and it looks cheap without all four |
| **Mobile and web** | Trivially fine | Workable, but it is the largest single perf item in an otherwise free budget |

Both columns are achievable. The right column costs several weeks and buys a worse play experience.

### Where 3D actually earns its place

- **Main menu:** a slow, silent, rotating globe. No interaction, so none of the costs above apply,
  and it is the strongest first impression the game can make for the least work.
- **Ending sequences:** the one moment the camera is allowed to be cinematic.
- **Optionally, region vignettes** — a shot of what your presence looks like on the ground, keyed to
  societal function stage. Nice to have, cuttable, and fakeable in 2D.

Even these can be done **without a single 3D node**, by sampling an equirectangular map through
inverse sphere projection in a 2D fragment shader. This is a standard, closed-form technique — about
six lines of maths, no raymarching — and **CC0 Godot implementations already exist**, including one
with full three-axis rotation. A production-quality MIT reference set exists too, whose palette
approach maps directly onto our per-region state colours.

Better still: **the fake globe is analytically pickable.** Mirroring the same handful of float
operations in GDScript against the cached ID image gives click detection with no collider and no
frame latency — so even the menu globe could become interactive later at almost no cost.

For completeness, had we gone the other way: a real 3D globe's picking is *not* solved by the physics
engine, because ray results carry no UV coordinate. The workable route is analytic
sphere-intersection plus a texture lookup — i.e. the same maths as the fake globe, with more
machinery around it.

**Decision: no 3D assets are commissioned or produced for this project until the menu globe is
prototyped as a shader and judged insufficient.**

### What "2.5D" means here

Depth from layering, not geometry. The map is a stack of parallax layers, each of which is a flat
sprite or shader:

```
  post-processing   scanlines, vignette, chromatic aberration, dithering
  HUD               Control nodes
  atmosphere        drifting particles, alert flashes
  markers           anomalies, task force units, labels
  links             animated flow along land, sea, air and network routes
  overlays          penetration, control, collapse, containment heat
  landmass          base map, borders, terrain
  backdrop          grid, starfield, slow parallax drift
```

Parallax between the backdrop and the landmass as the player pans, plus a slight scale response on
zoom, reads as depth immediately. It costs a handful of `CanvasLayer` nodes.

---

## 2. Art direction

**"Hostile command console."** You are looking at the world through the thing that is eating it.
Sparse, technical, dark, legible — and increasingly wrong as the run progresses.

- **Flat vector geometry.** No painterly illustration in the interface. Crisp shapes scale to any
  DPI for free, read at phone size, and are cheap to produce consistently.
- **Dark ground, few hues, high contrast.** The map is the only thing allowed to be colourful, and
  only where it carries data.
- **Type does the heavy lifting.** A technical monospace for the console voice, a clean sans for
  body text. In a sparse interface, typography *is* the art direction.
- **The palette degrades across phases.** Boxed is cold and clinical. Open is hot, saturated and
  noisy. The same screens, one theme variation swapped — see [UI.md](UI.md) §3.

### Colour language

The map must encode several variables at once without becoming mud, and must work for colourblind
players.

**The rule: hue carries category, luminance carries magnitude.** Lightness survives all three forms
of dichromacy, degrades gracefully to greyscale, and is the one channel that never lies. Everything
below follows from that.

- **Categories (the four containment factions, region states):** **Okabe–Ito without black** —
  `#E69F00` `#56B4E9` `#009E73` `#F0E442` `#CC79A7`. Every one of these clears 5.6:1 contrast on our
  dark ground. The IBM five (`#648FFF` `#785EF0` `#DC267F` `#FE6100` `#FFB000`) is the alternative
  and arguably the better holographic fit, but its primary source could not be verified, whereas
  Okabe–Ito traces to a published paper. Each faction also gets its own icon, so colour is never the
  only signal.
  - Note: **ColorBrewer cannot supply five colourblind-safe categories.** Its `blind` flag is
    class-count dependent, and only Dark2/Set2 at three classes and Paired at three or four are ever
    flagged safe. Do not reach for Set1.
- **Magnitude (penetration, containment):** a single-hue sequential ramp — but **not viridis
  unmodified.** Measured against our background, viridis's bottom two stops score 1.27 and 2.51,
  meaning the lower ~35–40% of the ramp is invisible on a dark map. Magma and inferno start at
  effectively the background colour. Use an **inverted single-hue ColorBrewer ramp** (every
  sequential scheme is flagged safe at every class count) or **viridis truncated to its upper half**
  from `#208F8C` upward.
  - Cividis is *not* the dark-mode fix it appears to be: it was optimised for colour vision
    deficiency by widening the brightness range, which pushes its low end darker still.
- **Two variables at once:** cap at **2×2**. Cartographic consensus is that three classes per
  variable is the practical ceiling, and a 4×4 bivariate scheme was abandoned in published work
  because sixteen blended colours could not be told apart reliably. Across sixty small regions we
  will not beat that.
- **Not pattern or hatching.** An earlier draft proposed hatching as the second channel. There is no
  modern endorsement of texture overlay for screen cartography — it is a print-era technique, and
  across sixty small regions it reads as noise. Use luminance and alpha instead.
- **Red is reserved.** It means "a thing is happening right now." If everything is red, nothing is.

### Shaders are the production value

A small shader set does more for how this game feels than any amount of hand-made art, and it is
work that scales to every screen at once:

map overlay and highlight · animated link flow · anomaly pulse · scanlines and CRT curvature ·
ordered dithering · chromatic aberration on alerts · glow · noise and grain · dissolve transitions ·
the menu globe.

This is the highest-leverage art budget in the project. Spend it here first.

**Three constraints from the Compatibility renderer that shape all of this:**

1. **Do not rely on `WorldEnvironment` glow.** Glow exists in Compatibility, but **2D HDR viewports
   do not**, which means the usual trick of marking emitters with `modulate > 1.0` is unavailable.
   The only built-in route is a global HDR threshold that makes *everything* bright glow — a blunt
   instrument. Instead: bake glow into the art and use `CanvasItemMaterial` additive blending for
   accents, plus our own bloom in the full-screen pass. This is renderer-agnostic and survives the
   web export.
2. **Compute shaders and `RenderingDevice` are unavailable.** Compatibility is also the *only*
   renderer that supports web export, so this is not negotiable. Any map technique that depends on
   compute shaders — including one of the reference implementations cited in PLAN.md — cannot be
   used. Everything must work as a fragment shader.
3. **2D debanding does not exist,** which is fine, because our dithering is a deliberate stylistic
   choice and has to be a shader regardless.

**The full-screen pass** is the canonical setup: a `CanvasLayer` holding a full-rect `ColorRect`
with a `canvas_item` shader reading `hint_screen_texture`. Two details that cost an afternoon each
if missed: `SCREEN_TEXTURE` was removed in Godot 4 and must be a declared uniform; and
**`Window`-derived popups render on layer 1024**, so the post-processing layer must be set to 1025
*from script*, because the inspector caps the field at 128.

> **Licence trap.** Shader sharing sites let authors choose their licence per post, and **GPLv3
> appears among the options**. A GPL shader in a commercial game is a serious problem. Check the
> badge on every shader before adopting it, prefer CC0 and MIT, and record the source in
> `docs/ASSET_LICENCES.md` like any other asset.

---

## 3. How the assets get built

Ordered by how much of the game each item covers.

### 3.1 The interface: no assets at all

Procedural `StyleBoxFlat` for panels, borders, buttons and bars means **the entire interface needs
essentially zero image files**. It scales to any resolution, recolours at runtime for the phase
shifts, and there is nothing to re-export when a corner radius changes.

This is the single largest cost saving available to the project, and it is why the art direction is
flat and geometric in the first place. The aesthetic and the budget agree.

### 3.2 The map: a script, not an asset

The map is **generated, not drawn**, so it is reproducible and diffable:

1. **Natural Earth Admin-0 at 50m scale** (public domain, no attribution required), committed as
   input data. Not 10m — we simplify the detail away anyway, and adjacency computation is far faster
   at 50m.
2. **Merge** microstates (`-dissolve`), then **compute adjacency and centroids** — see step 5 for
   why this happens *before* simplification.
3. **Simplify and reproject** to Equal Earth. Simplify to match the raster grid rather than to a
   percentage.
4. **Rasterise the ID map** with anti-aliasing off — a single blended pixel on a border is a
   mis-click. The base map is rasterised separately, at higher resolution, with anti-aliasing on.
5. **Extract centroids and the land-border adjacency list** from the same geometry.

Step 5 is the one that earns the pipeline its keep. The adjacency graph — which regions border which
— is the backbone of the spread simulation, and deriving it from geometry rather than hand-authoring
sixty regions of borders removes an entire category of tedious, error-prone work.

**Five gotchas, each of which silently produces a plausible-looking but wrong result:**

- **Adjacency must be computed on the dissolved but *un-simplified* layer.** The `touches` predicate
  requires exactly shared boundaries; once simplification drifts neighbouring edges apart it returns
  *nothing*, quietly, with no error.
- **Use `representative_point()`, not `centroid`,** for label anchors. A centroid is not guaranteed
  to lie inside its own polygon and will place markers in the sea for Indonesia, Croatia, and Norway
  with Svalbard attached. Reproject before computing either. *(Since D1.2 region anchors are
  authored in `tools/map/region_attributes.csv` — `docs/specs/world.md` §3.5 — because the marker
  belongs on the region's centre of gravity, which no geometric rule finds. The warning still holds
  for any other computed label position.)*
- **The rasteriser must not anti-alias, and `gdal_rasterize` does not** — provided the "all touched"
  flag stays off, so that the burn is a binary pixel-centre test. It also cannot write PNG directly,
  so the ID map goes to GeoTIFF first and is converted after. Burn a single-band integer ID and map
  ID to RGB afterwards. Never route the ID map through SVG: every SVG rasteriser anti-aliases.
- **In Godot, `Detect 3D` is on by default** and will silently re-import the ID texture as
  VRAM-compressed with mipmaps the moment it touches a 3D scene. Block compression interpolates
  within each 4×4 block and *fabricates region IDs along every border*. Import as **Lossless, no
  mipmaps, Detect 3D off**, with nearest filtering set on the material. Compare packed integers,
  never `Color` floats.
- **Cache the ID `Image` once at startup.** `Texture2D.get_image()` fetches from the GPU and must
  never run per frame.

The conversion script lives in `tools/` and is committed, with exact tool versions pinned — the
relevant libraries have made breaking changes recently enough that most tutorials on the subject no
longer run. The outputs are committed too, but any one of them can be regenerated from scratch.

### 3.3 Icons: vector sets plus custom silhouettes

Roughly 120 technology nodes, plus interface icons. This is the largest bespoke art cost in the
project.

**Verified licences and set sizes:**

| Set | Licence | Size | Use |
| --- | --- | --- | --- |
| **Phosphor** | MIT | 1,512 icons × 6 weights | **Functional chrome.** Six weights give a hierarchy for free — thin for ambient, bold for alerts. |
| **Tabler** | MIT | 6,202 SVGs | The gap-filler. Largest permissive set in existence. |
| **Lucide** | ISC | 1,853 SVGs | Alternative to Phosphor; cleaner, narrower. |
| **Material Symbols** | Apache-2.0 | 4,284 | Attribution appreciated but not required. |
| **Game-icons.net** | **CC BY 3.0** | 4,239 SVGs | **The illustrative tier** — technology, abilities, units. |
| ~~Remix Icon~~ | ⚠️ **No longer Apache-2.0** | — | **Avoid.** Moved to a custom licence in January 2026 that forbids use as a logo or app icon — which would rule out our Steam capsule. |

**Game-icons.net is worth the attribution.** Its licence is per-author: a handful of icons are CC0,
the other ~4,100 are CC BY 3.0. Nothing else has that vocabulary for a game like this, and the cost
is shipping its `license.txt` on a credits screen — which the project needs anyway.

**Do not mix stroke and silhouette styles within a tier.** Functional chrome is one set; the
illustrative tier is another; they are allowed to differ from each other but never from themselves.

**Custom:** the ~25 headline nodes — the ones a player will remember and screenshot — get bespoke
silhouettes drawn to a shared grid.

**Consistency beats quality.** One hundred and twenty icons that share a stroke weight and grid look
professional. Twenty beautiful icons among a hundred mismatched ones look broken.

### Getting icons crisp at every size

Godot **rasterises SVG at import time**, so a plain SVG import blurs when scaled at runtime — which
matters for us, since the same interface runs at 400px and at 4K.

Godot 4.7 has the answer: **`DPITexture`**, where SVG is the only format that can be imported as
one. It rasterises at runtime to match the current oversampling factor, and it carries a
**`color_map` property that remaps colours at runtime** — so one monochrome icon file serves every
palette state and every phase shift without duplicate assets. That is close to purpose-built for
this project.

Two caveats: it is **marked experimental** and may change, and SVG support in general is limited —
**text must be converted to paths** or it vanishes, and filters such as blur and drop-shadow are
ignored. So: keep the source SVGs, so that falling back to a pre-rendered PNG atlas is a build step
rather than a re-draw.

### 3.4 Illustration and key art: generated locally

This project has a strong local generation pipeline available — an RTX 5090 with current image
models including an instruction-driven editing model, which is the one that matters here. That is
well suited to:

- ending illustrations and scenario key art,
- **wire-card illustrations** for the event modal — the narrative chain steps, the eight
  counter-move announcements, the discovery moment: about 25, `loop-redesign.md` §7.4 (D4.0),
- region vignettes and backdrops,
- Codex illustrations,
- store page and marketing art.

And poorly suited to:

- **small icons.** Diffusion models are weakest exactly where this project needs precision: crisp,
  tiny, consistent line art on a shared grid. Vector wins here and it is not close.
- **anything needing exact text.**

The hard part of generated art is not quality, it is **consistency**. The workable method is to fix
one style reference and then use the editing model to produce every subsequent piece as a
transformation of it, rather than prompting each piece independently and hoping.

> **Licensing gate, to resolve before any generated asset ships.** Image model weights differ sharply
> in what they permit: some are Apache-2.0 and fine commercially, others are explicitly
> non-commercial for a paid product. **Every model used for a shipped asset must have its licence
> checked and recorded in `docs/ASSET_LICENCES.md`, with the model named per asset.** This is cheap
> to do now and extremely expensive to discover after a Steam release. Treat any model whose licence
> is unverified as unusable for shipping art.

### 3.5 Fonts

**Pick: JetBrains Mono for data and body, Space Grotesk for display.** Both are OFL 1.1, both cover
German completely including capital ẞ and the German quotation marks „ " » «, and — critically —
**neither carries a Reserved Font Name**, so we can subset them to Latin + Latin Extended without
renaming anything.

**Two fonts that look right and fail on German:**

- **Orbitron** — the obvious choice for a sci-fi console, and a trap. 207 glyphs, no ẞ, **no German
  quotation marks at all**, no section sign, no arrows. Usable only for short hard-coded English
  display strings, if at all.
- **Roboto Mono** — no capital ẞ. In a console interface that shouts in capitals, `STRAẞE` breaks.

IBM Plex is the better-toned alternative to JetBrains Mono, but it has a Reserved Font Name, so any
subset must be renamed. Same for Source Code Pro.

**OFL 1.1 explicitly permits shipping in a closed-source commercial game** — the FAQ names games and
entertainment software directly, and only forbids selling the fonts by themselves. We ship the
copyright line, the licence notice and the full OFL text for the weights we actually use.

**Skip MSDF.** The documentation does not recommend it for interface text: it carries a higher
baseline cost on mobile, and small text looks *worse* than rasterised because it has no hinting. Use
dynamic fonts with **per-viewport oversampling** instead, which re-rasterises at the real viewport
scale and gets us 4K crispness without the small-size penalty. For small interface text, disable
subpixel positioning to cure irregular letter spacing.

### 3.6 Audio

- **Ambience:** layered drones, one layer added per phase, so escalation is audible before it is
  visible.
- **Interface:** a small, dry, precise click set. This kind of interface lives or dies on its sounds.
- **Alerts:** distinct stings per faction, so the player learns who is coming without reading.
- **Music:** one adaptive piece, not a playlist.

Sourced CC0 or generated, with the same licence discipline as §3.4.

---

## 4. Asset budget

| Category | Volume | Source | Risk |
| --- | --- | --- | --- |
| Interface styling | ~0 files | Procedural | None |
| Map | 2 images + data | Scripted | Pipeline time |
| Shaders | ~10 | Hand-written | Low |
| Icons | ~140 | Open sets + ~25 custom | **Highest bespoke cost** |
| Illustration | ~30 | Generated locally | **Licence and consistency** |
| Fonts | 2 | Open licence | None |
| Audio | ~40 | CC0 / generated | Low |

The two risks worth managing are **icon consistency** and **generated-asset licensing**. Both are
cheap to control now and expensive to fix later.

---

## 5. Open questions

1. ~~Which projection?~~ **Resolved: Equal Earth.** It is equal-area, so region sizes read honestly,
   and distortion carries no mechanical penalty for us — unlike *Hearts of Iron*, which simulates
   range in map space and consequently has bombers that fly measurably further from some latitudes
   than others. With sixty regions and authored adjacency, projection is purely aesthetic.
   (Practical note: the tooling spells it `eqearth`; `equalearth` is not an alias and simply errors.)
2. Does the menu globe survive as a shader, or does it want real geometry? Prototype in M2 — the
   research says it should, and CC0 starting points exist. *Decided at D5.3 (2026-09-24): a shader
   over a new equirectangular region-ID texture (`screens-full.md` §3.1), built in S5.7; geometry
   only if G5 judges the prototype insufficient.*
3. How far does the phase palette shift go before it stops being atmosphere and starts being
   unreadable? Cap it and test at the reduced-motion setting. *Decided at D6.1 (2026-09-25): one
   palette step (`cold` → `open`) and no further; beyond Open the screen pass's heat escalates
   grain, dither, scanlines and glow, which touch no token, under a contrast floor for text and a
   colour-difference floor for map marks (`polish-visuals.md` §3.6, §8). CRT curvature is cut
   (it moves controls away from where they are hit).*
4. Do region vignettes justify their cost, or is the map plus the ticker enough? Decide at M4.
   *(D4.0: the wire card takes the story-picture role first; vignettes are judged after it exists.)*
5. Is `DPITexture`'s experimental status acceptable for ~140 shipped icons, or do we keep a PNG
   atlas fallback permanently in the build? Decide at M3, once the icon set is real.
