class_name ScreenFxParams
extends RefCounted
## What the full-screen pass draws with, derived by `ScreenFxRules.params` from
## the setting, the heat and reduced motion (spec polish-visuals.md §3.7).
##
## Plain values, so a test reads them without a shader or a tree.

## False at *Screen effects* `Off`: the decoration is gone and the pass is
## hidden unless a wash or a dissolve is running.
var enabled: bool = false
var scan_depth: float = 0.0
var grain_amp: float = 0.0
var vignette: float = 0.0
var bloom_strength: float = 0.0
## 0, 8 or 16.
var bloom_taps: int = 0
var dither_levels: float = 0.0
## Multiplies `UiTokens.FX_CA_PX`; 0 means no aberration at all.
var ca_scale: float = 0.0
