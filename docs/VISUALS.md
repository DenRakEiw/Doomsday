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

This is why *Plague Inc.*, *Pandemic*, *Rebel Inc.* and *Bio Inc.* are all flat, and why the games
that do use globes — *Civilization VI*, *Hearts of Iron* — are not about global comparison at a
glance. They are about a front line, which is local.

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
inverse sphere projection in a 2D fragment shader. That gives a rotating globe with correct
perspective, a controllable palette, and zero additions to the project's technical surface. Build it
that way first; reach for a real `MeshInstance3D` only if the shader version is not beautiful enough.

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

- **Penetration:** a single-hue sequential ramp, dark to bright. Value carries the magnitude, so it
  survives any form of colour blindness and greyscale screenshots alike.
- **Societal collapse:** desaturation plus a hatching pattern, *not* a second hue. Two variables,
  two different visual channels — the standard solution to a bivariate choropleth.
- **The four containment factions:** a qualitative, colourblind-safe palette of four distinct hues,
  each paired with its own icon so colour is never the only signal.
- **Red is reserved.** It means "a thing is happening right now." If everything is red, nothing is.

### Shaders are the production value

A small shader set does more for how this game feels than any amount of hand-made art, and it is
work that scales to every screen at once:

map overlay and highlight · animated link flow · anomaly pulse · scanlines and CRT curvature ·
ordered dithering · chromatic aberration on alerts · glow · noise and grain · dissolve transitions ·
the menu globe.

This is the highest-leverage art budget in the project. Spend it here first.

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

1. Natural Earth Admin-0 (public domain) as the source, committed as input data.
2. Merge microstates, simplify geometry, reproject to an equal-area projection.
3. Rasterise the **ID map**: each region a unique flat colour encoding its index, with
   anti-aliasing **off** — a single blended pixel on a border is a mis-click.
4. Rasterise the **base map** separately, at higher resolution, with anti-aliasing **on**.
5. Extract for free, from the same geometry: **region centroids** (label and marker anchors) and the
   **land-border adjacency list**.

That last step matters. The adjacency graph — which regions border which — is the backbone of the
spread simulation, and deriving it from the geometry rather than hand-authoring sixty regions of
borders removes an entire category of tedious, error-prone work.

The conversion script lives in `tools/` and is committed. The outputs are committed too, but any one
of them can be regenerated from scratch.

### 3.3 Icons: vector sets plus custom silhouettes

Roughly 120 technology nodes, plus interface icons. This is the largest bespoke art cost in the
project.

- **Baseline:** a permissive open icon set as SVG, recoloured at runtime. Several good ones are
  MIT-licensed; at least one large set is game-themed specifically. Licences must be verified per set
  before adoption, and attribution-required sets need that attribution shipped in-game.
- **Custom:** the ~25 headline nodes — the ones a player will remember and screenshot — get bespoke
  silhouettes drawn to a shared grid.
- **Consistency beats quality.** One hundred and twenty icons that share a stroke weight and grid
  look professional. Twenty beautiful icons among a hundred mismatched ones look broken.

### 3.4 Illustration and key art: generated locally

This project has a strong local generation pipeline available — an RTX 5090 with current image
models including an instruction-driven editing model, which is the one that matters here. That is
well suited to:

- ending illustrations and scenario key art,
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

Two families: a technical monospace and a clean sans. Requirements are non-negotiable and easy to
check: an open licence that permits embedding in a commercial product, and **full coverage of German
diacritics** including ß. A font that fails on `Straße` is discovered late and hurts.

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

1. Which projection? Equal-area is honest about population-carrying landmass, which this game is
   literally about; the familiar-looking alternatives distort exactly the regions that matter most.
2. Does the menu globe survive as a shader, or does it want real geometry? Prototype in M2.
3. How far does the phase palette shift go before it stops being atmosphere and starts being
   unreadable? Cap it and test at the reduced-motion setting.
4. Do region vignettes justify their cost, or is the map plus the ticker enough? Decide at M4.
