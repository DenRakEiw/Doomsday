# Asset Licences

Every third-party or generated asset that ships in a build is recorded here, with its source and
licence. This is not bureaucracy: licence problems are cheap to prevent now and very expensive to
discover after a commercial release.

**Rules:**

1. Nothing ships without an entry here.
2. **Anything whose licence cannot be verified is unusable.** "Probably fine" is not a licence.
3. Attribution-required assets must have their attribution present in the in-game credits *before*
   the asset is used, not afterwards.
4. Generated art records the **model** used and that model's licence — weights differ sharply on
   commercial use, and some current models are explicitly non-commercial.
5. Shader sources count. Shader-sharing sites allow per-post licence choice and **GPLv3 is among the
   options**, which would be a serious problem in a commercial game.

---

## Tooling (not shipped in builds)

| Asset | Source | Licence | Notes |
| --- | --- | --- | --- |
| godot-mcp v3.1.0 | github.com/tugcantopaloglu/godot-mcp | MIT | AI-assisted development tooling. Lives outside the repository; nothing ships. Builds on `Coding-Solo/godot-mcp` (MIT). |

## Engine

| Asset | Source | Licence | Notes |
| --- | --- | --- | --- |
| Godot Engine 4.7.2 | godotengine.org | MIT | Attribution in credits |

## Planned — approved, not yet integrated

Verified during research; recorded here so the decision is not re-litigated later.

| Asset | Licence | Attribution | Notes |
| --- | --- | --- | --- |
| Natural Earth Admin-0 50m | **Public domain** | Not required | Map source geometry. v5.1.1, committed as `tools/map/input/ne_50m_admin_0_countries.zip` (from naciscdn.org, 2026-09-21). Pipeline input only; S1.7 marks it integrated |
| Phosphor Icons | MIT | Not required | Functional interface icons; six weights |
| Tabler Icons | MIT | Not required | Gap-filler |
| Lucide | ISC | Not required | Alternative to Phosphor |
| Material Symbols | Apache-2.0 | Appreciated, not required | No NOTICE file exists |
| Game-icons.net | **CC BY 3.0** (per-author; a few are CC0) | **Required** | Illustrative tier. Ship the set's `license.txt` in credits. |
| JetBrains Mono | OFL 1.1 | Notice required | **No Reserved Font Name** — subsetting is permitted without renaming |
| Space Grotesk | OFL 1.1 | Notice required | **No Reserved Font Name** |

## Rejected

| Asset | Reason |
| --- | --- |
| **Remix Icon** | Left Apache-2.0 in January 2026 for a custom licence that forbids use as a logo or app icon — which would rule out the Steam capsule. |
| **Orbitron** | Incomplete German coverage: no capital ẞ, no German quotation marks. Reserved Font Name. |
| **Roboto Mono** | No capital ẞ; breaks uppercased German text. |
| **IBM Plex, Source Code Pro** | Not rejected on merit — both are good — but they carry Reserved Font Names, so any subset must be renamed. Only revisit if the chosen pair fails. |

## Generated assets

*(none yet)*

| Asset | Model | Model licence | Commercial use | Date |
| --- | --- | --- | --- | --- |

> Before generating any shipped asset, confirm the model's licence and add its row here. Several
> widely-installed image models are non-commercial for a paid product.

## Audio

*(none yet)*

| Asset | Source | Licence |
| --- | --- | --- |

## Shaders

*(none yet — anything adapted from a public source goes here with its licence badge)*

| Shader | Source | Licence |
| --- | --- | --- |
