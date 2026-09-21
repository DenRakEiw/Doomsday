# Spec: the world (D1.2)

What S1.6 (map geometry) and S1.7 (attributes and links) build from. The world itself is authored
data in `tools/map/*.csv`; this file gives the formats, the rules the pipeline applies to them, the
reasoning, and what to verify. Output formats (`regions.json`, `links.json`) are in
`data/SCHEMA.md` §2–§3 and are not repeated here.

**Rule for the builder:** the five CSV files are design. If a check in §7 fails, do not edit them —
record a design question in `PROGRESS.md`. Bugs in the pipeline are yours; the world is not.

---

## 1. Scope

In: 61 regions built from Natural Earth Admin-0 50m, their attributes, anchors, links and names.
Out: map styling (D2.1), how links are drawn (D2.1/S2.6), technology that uses the attributes
(D3.1), regions that become air-gapped during play (D4.1 counter-actions).

## 2. Files

| File | Owner | Content |
| --- | --- | --- |
| `tools/map/input/ne_50m_admin_0_countries.zip` | input | Natural Earth v5.1.1, unmodified. Read it in place (`zip://`), do not unpack |
| `tools/map/region_groups.csv` | D1.2 | `adm0_a3,region,name` — all 242 features, one row each |
| `tools/map/part_overrides.csv` | D1.2 | `adm0_a3,lon_min,lat_min,lon_max,lat_max,region,note` — overseas parts that belong elsewhere |
| `tools/map/region_attributes.csv` | D1.2 | one row per region: continent, air gap, anchor, eight tiers. **Row order is the region index** |
| `tools/map/extra_links.csv` | D1.2 | `a,b,kind,note` — authored sea, air and network links |
| `tools/map/expected_land_links.csv` | D1.2 | `a,b` — the 82 land borders the geometry must yield; a verification reference, not an input |
| `data/loc/strings.csv` | D1.2 | `REGION_<ID>` and `CONTINENT_<ID>` in `en` and `de` |
| `tools/map/build/geometry.json` | S1.6 → S1.7 | per region: `index`, `id`, `anchor` [x, y] px, `pixel_area`; plus `land_links` [[a, b]…]. Committed |
| `assets/map/id_map.png` | S1.6 | 4096×2048, RGB, R = index low byte, G = high byte, B = 0; index 0 = black = no region |
| `assets/map/land_mask.png`, `assets/map/border_mask.png` | S1.6 | 8192×4096, 8-bit greyscale, anti-aliased, same frame: land coverage; region borders and coastlines as 3 px lines. Masks, not art — D2.1 colours them in the shader |
| `data/world/regions.json`, `data/world/links.json` | S1.7 | the game's world |

## 3. Regions

### 3.1 Grouping

The key column in Natural Earth is **`ADM0_A3`** (unique over all 242 features). Do not use
`ISO_A3`: it is `-99` for France, Norway and others.

`region_groups.csv` maps every feature to a region id or to **`none`**. `none` (Antarctica and five
open-ocean dependencies) is dropped before anything else happens: it appears in no raster, no
population sum and no file. This is how "nothing unclickable may exist" is met — what is not a
region is not drawn.

How the 61 were cut, so that later changes follow the same logic:

- **Large or distinctive states stand alone** — distinctive meaning an attribute profile that a
  merge would average away: Taiwan and South Korea (manufacturing), Bangladesh (population without
  regulation), Iceland (hardware on a remote island), North Korea (the air gap).
- **Everything else merges into contiguous groups** named for geography (*Sahel*, *Maghreb*,
  *Zambezi Basin*) or for their two largest members (*Thailand & Myanmar*). A merged region is never
  named after one member alone, with one exception: micro-neighbours folded into a large state
  (Monaco into France, Hong Kong into China) keep that state's name.
- **Island regions stay separate** — eleven have no land border: Caribbean, Greenland, Britain &
  Ireland, Iceland, Sri Lanka, Japan, Taiwan, Philippines, Madagascar, Australia, New Zealand. They
  are reachable only through authored links (§5), which makes their difficulty a design value.
- Island microstates merge into the nearest island region; the Pacific ones merge with Papua New
  Guinea into *Pacific Islands* so that the region has a body large enough to click.
- The smallest region is Taiwan at about 500 px on the ID map; nothing is below the 400 px floor.

### 3.2 Overseas parts

Some Natural Earth features are multipolygons spanning continents. After exploding features into
single polygons and before dissolving, a part whose `representative_point()` lies inside an override
box is reassigned to the override's region. The six rows move French Guiana, the French and Dutch
Caribbean islands, Mayotte, Réunion, and Crimea (drawn with Ukraine, following the UN General
Assembly position; Natural Earth draws de-facto control). **Every override row must match at least
one part** — a row that matches nothing is an error. Expected matches in file order: 1, 4, 1, 1, 3, 1.

Population is **not** moved by overrides: `population` = sum of `POP_EST` over the region's rows in
`region_groups.csv`. The error is below 0.5 % everywhere.

All other far-flung parts (Alaska, Hawaii, Svalbard, the Canaries, Galápagos …) stay with their
state on purpose.

### 3.3 Attributes

`region_attributes.csv` columns: `region, continent, air_gapped, anchor_lon, anchor_lat, compute,
connectivity, wealth, regulation, research, manufacturing, industry, isolation`.

**Index:** the first data row is index 1, the last is index 61. Rows are grouped by continent. New
regions are appended; rows are never reordered once a save format has shipped.

**Continents** (six ids): `north_america` (incl. Central America, Caribbean, Greenland),
`south_america`, `europe` (incl. Russia, Iceland), `asia` (incl. Turkey, the Caucasus, the Middle
East), `africa`, `oceania`.

Tier meaning, 0 = negligible … 4 = world-leading. The tiers describe the region as a whole, not per
head — they are totals in the sense that matters to the simulation:

| Attribute | What it measures | Read by |
| --- | --- | --- |
| `compute` | installed hardware; drives yield and the region's weight in world share. Tier 0 regions yield nothing and weigh nothing | yield, `infected_share` |
| `connectivity` | bandwidth to the rest of the world | Cloud Federation |
| `wealth` | income level | anomaly value, later events |
| `regulation` | capacity and will of institutions to audit and restrict software and hardware | Open Weights Leak (favours ≤ 1) |
| `research` | AI and computing research capacity — **also the region's weight in containment capacity** | Research Networks, containment |
| `manufacturing` | electronics and hardware manufacturing | Supply Chain Firmware |
| `industry` | heavy industry, energy, utilities | Industrial Control |
| `isolation` | remoteness from networks and neighbours | Satellite Uplink |
| *population* | derived from `balance.population_tiers` | Consumer Devices |

Only the United States and China hold `compute` 4; twelve regions hold 3. Total hardware at the
current `hardware_by_tier` is 112 (Asia 44, Europe 34, North America 15, South America 7, Africa 6,
Oceania 6). Twelve regions hold tier 0 — they cost time to take for Ascendance and pay nothing,
which is what *Model Distillation* will later change.

**The one air-gapped region is North Korea.** It has land links from geometry and cannot be seeded
until `airgap_cross` is above 0. `air_gapped` is mutable state in the model, so D4.1 can have
governments pull further regions off the network during play; the world starts with one.

**Decision — `population_tiers` retuned** to `[5 M, 30 M, 100 M, 300 M]` in `data/balance.json` (was
5/20/80/300). With the old thresholds 27 of 61 regions were tier 3 or higher and the Consumer Devices
archetype distinguished nothing. Now: tier 0 × 4, 1 × 12, 2 × 25, 3 × 17, 4 × 3. The fixture keeps
its own frozen copy and is unaffected.

### 3.4 Archetype coverage

"Strong" is tier ≥ 3 in the favoured attribute; for Open Weights Leak it is `regulation` ≤ 1 with
`compute` ≥ 1 (a leak needs hardware to land on).

| Vector | Strong regions | Continents |
| --- | --- | --- |
| Cloud Federation | 28 | 6 |
| Open Weights Leak | 22 | 5 |
| Supply Chain Firmware | 9 — Mexico, Germany, East-Central Europe, China, South Korea, Japan, Taiwan, Indochina, Malaysia & Singapore | 3 |
| Consumer Devices | 20 | 5 |
| Industrial Control | 20 | 6 |
| Research Networks | 15 | 4 |
| Satellite Uplink | 11 | 5 |

Note for D3.1: a Satellite Uplink *origin* needs hardware as well as isolation — Iceland and New
Zealand (`compute` 2) are the intended picks; the other isolated regions are targets, not homes.

### 3.5 Anchors

`anchor_lon`/`anchor_lat` are authored: the anchor is where markers sit and links end, so it marks
the region's centre of gravity (Java, not Borneo; the European part of Russia), which
`representative_point()` cannot know. **This replaces the computed anchor of VISUALS §3.2.** The
pipeline projects the pair (§4) and rounds to the pixel. All 61 were checked to lie inside their
region at least 4 px from any border in the map projection.

## 4. Projection and frame

- **Equal Earth, central meridian 11° E**: `+proj=eqearth +lon_0=11`. The map edge then runs along
  169° W through the Bering Strait, and neither Chukotka nor Alaska is cut. Centred on 0° the edge
  would slice Chukotka off to the far left.
- **Cutting at the edge is the pipeline's job and fails silently if skipped** (polygons smear across
  the whole map). In EPSG:4326, for every dissolved geometry: `A = geom ∩ box(−169, −90, 180, 90)`,
  `B = geom ∩ box(−180, −90, −169, 90)` shifted by +360° in x, then `A ∪ B`, then project with
  `+over`. Anchors with `anchor_lon < −169` get the same +360°. Natural Earth already splits Russia
  and Fiji at 180°; after the shift those halves must fuse — **check that `border_mask.png` shows no
  vertical seam through Chukotka.**
- **Frame:** the whole world, 4096×2048, one scale on both axes. With `X = 17 243 959.06` m (half
  the projected width) and `s = 2X / 4096` ≈ 8 419.9 m per pixel: `col = (x + X) / s`,
  `row = 1024 − y / s`. Land occupies rows ≈ 27…2021; the rest is index 0. The masks use `s / 2`.
- Adjacency (§5.1) is computed **before** any of this, on the dissolved, un-simplified EPSG:4326
  layer.
- Before rasterising, drop polygon parts smaller than 4 px (≈ 280 km²) from the ID map **and** from
  both masks, so that nothing is drawn that cannot be clicked.
- For D2.1: inhabited land spans about 56° S to 84° N; the camera need not show the empty south.

## 5. Links

### 5.1 Land — from geometry

Two regions share a land link when the intersection of their boundaries has **length > 0** (a line,
not a point). The result must equal `expected_land_links.csv` **exactly** — 82 pairs. A difference
means the dissolve, the overrides or the predicate is wrong.

### 5.2 Sea, air, network — authored

`extra_links.csv`, 69 rows: 37 sea, 22 air, 10 network. `a` sorts before `b` already. No extra
link doubles a land border. Two regions may be joined by several kinds (USA–Britain & Ireland has
air and network): that is intended and means two rolls a day on the fattest routes.

What the kinds mean, so that additions stay consistent:

- **sea** (seed chance 0.015) — short crossings between neighbouring coasts. Every island region
  hangs on these.
- **air** (0.02) — long-haul routes between hubs; how continents meet.
- **network** (0.03) — backbone trunks between regions with `connectivity` ≥ 3. **China and Russia
  have none on purpose:** they are large, well connected inside, and reached only by land, sea and
  air — a Cloud Federation run does not simply fall into them.

Deliberately hard targets, two neighbours each: Greenland (Canada by sea, the Nordic Countries by
air), Iceland, Madagascar, New Zealand (Australia by sea, Argentina & Chile by air), Sri Lanka,
Mongolia, the Himalayan States, Bangladesh, Central America. Hubs: China 17 neighbours, USA 11,
India 11, Britain & Ireland 10.

### 5.3 `links.json` order

The file order is the simulation's iteration order. Write land links first, sorted by `(a, b)`,
then the extra links **in CSV order**. Normalise every pair so that `a < b`.

### 5.4 For D2.1 / S2.6 — links across the map edge

Seven links cross the Pacific (USA to Japan by air and by network, to South Korea, Australia,
China and the Pacific Islands; Argentina & Chile to New Zealand). Drawing rule to specify in D2.1: a link whose anchors are more
than half the map width apart leaves through one edge and re-enters through the other.

## 6. Names

`data/loc/strings.csv` holds `REGION_<ID>` for all 61 and `CONTINENT_<ID>` for the six continents,
in English and German (`SCHEMA.md` §6). German names are the established exonyms (*Ostmitteleuropa*,
*Sambesi-Becken*), not translations of the English.

## 7. Verification

**S1.6 — `verify_map.py`**
1. All 242 `ADM0_A3` codes appear in `region_groups.csv` exactly once; every region there has a row
   in `region_attributes.csv` and vice versa (`none` excepted).
2. Override matches per row are 1, 4, 1, 1, 3, 1.
3. Land links equal `expected_land_links.csv`; adjacency is symmetric.
4. Every colour in `id_map.png` decodes to 0…61; B is 0 everywhere; no other value exists (no
   blended pixel).
5. Every region has `pixel_area` ≥ 400. Expected smallest: `taiwan` ≈ 500, `sri_lanka` ≈ 930,
   `benelux` ≈ 990. No exceptions are granted here.
6. The pixel under each anchor decodes to its own region, and so do the eight pixels around it.
7. No vertical seam at 180° in `border_mask.png` (compare the column through Chukotka against its
   neighbours).
8. Running the build twice gives byte-identical outputs.

**S1.7 — tests on the real world** (thresholds, not exact counts, so that retuning does not break
them)
1. The world loads through `ContentLoader` with no errors: 61 regions, indices 1…61 in CSV order,
   82 + 69 = 151 links.
2. The link graph is connected. Exactly 11 regions have no land link (the list in §3.1). Every
   region has at least 2 neighbours.
3. `north_korea` is the only region with `air_gapped`.
4. For each vector in §3.4: at least 3 strong regions on at least 2 continents; at least 3
   continents for all but Supply Chain Firmware.
5. Population: world total 7 676 945 548; `usa` 328 239 523; `pacific_islands` 12 147 405;
   `caribbean` 42 851 759 (these catch a wrong join or a moved override population).
6. Every region and continent id has its key in `strings.csv`, with non-empty `en` and `de`.

## 8. For G1

- The D1.1 baseline came from a synthetic 60-cell grid. This world is lumpier: eleven islands, one
  air gap, hubs with 10+ neighbours. Expect faster early spread from a hub origin and a longer tail
  (the two-neighbour regions). A large shift in run length points here before it points to balance.
- Hardware is spread thinly over Europe's thirteen regions (34 of 112) while the USA alone holds 7.
  If world share feels wrong, steepen `compute.hardware_by_tier` rather than re-tiering regions.
- The bots' origin rules (core.md §11.2) resolve to fixed regions in this world: `greedy` starts in
  `usa` (11 neighbours, a hub), `stealth` in `venezuela_guianas` (lowest regulation, then highest
  compute, then lowest index — 3 neighbours, a backwater). Their baselines therefore also measure
  two very different starting positions, not only two play styles.
