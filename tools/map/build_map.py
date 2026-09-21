"""Builds the game's map from Natural Earth.

    uv run --project tools/map python tools/map/build_map.py

Reads the authored tables next to this file and writes, from scratch every time:

    assets/map/id_map.png       4096x2048 RGB, R = index low byte, G = high byte
    assets/map/land_mask.png    8192x4096 greyscale, anti-aliased
    assets/map/border_mask.png  8192x4096 greyscale, anti-aliased
    tools/map/build/geometry.json   per region: anchor in pixels, pixel area;
                                    plus the land links taken from the geometry

The order of the steps is the whole point of the script, and four of them fail
silently rather than loudly if they are moved or skipped:

  * adjacency is computed on the dissolved but **un-simplified** layer, because
    once simplification drifts neighbouring edges apart the shared boundary is
    gone and the predicate quietly returns nothing;
  * the geometry is **cut at the map edge** before projecting, or polygons smear
    across the whole map;
  * the ID map is burnt with `all_touched=False` and no anti-aliasing at all,
    because one blended pixel on a border is a mis-click;
  * anchors are **authored**, not computed — see `docs/specs/world.md` §3.5.

Everything it produces is reproducible: run it twice and the bytes are the same.
`verify_map.py` checks that, and everything else in world.md §7.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd
import rasterio.features
import rasterio.transform
import shapely
from PIL import Image, ImageDraw
from shapely.geometry import MultiPolygon, Polygon

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parent.parent
INPUT = ROOT / "input" / "ne_50m_admin_0_countries.zip"
BUILD = ROOT / "build"
ASSETS = PROJECT / "assets" / "map"

# The key column of Natural Earth. Never ISO_A3: that is -99 for France, Norway
# and others.
KEY = "ADM0_A3"
FEATURE_COUNT = 242
NO_REGION = "none"
# The link kind the geometry produces; the others are authored.
LAND_KIND = "land"

# Equal Earth with the central meridian at 11° E, so that the map edge runs
# through the Bering Strait and neither Chukotka nor Alaska is cut. `+over`
# keeps the shifted eastern half from wrapping back round.
CRS_TARGET = "+proj=eqearth +lon_0=11 +over +datum=WGS84 +units=m +no_defs"
EDGE_LON = -169.0

# Half the projected width, in metres, and the frame built on it.
HALF_WIDTH = 17243959.06
WIDTH = 4096
HEIGHT = 2048
SCALE = 2.0 * HALF_WIDTH / WIDTH
TOP = (HEIGHT / 2.0) * SCALE

# The masks are twice the ID map's resolution, and are drawn at twice that again
# and boxed down — which is where their anti-aliasing comes from, since neither
# the rasteriser nor the line drawing does any.
MASK_FACTOR = 2
SUPERSAMPLE = 2
MASK_WIDTH = WIDTH * MASK_FACTOR
MASK_HEIGHT = HEIGHT * MASK_FACTOR
BORDER_PIXELS = 3

# Simplification is to the raster grid, not to a percentage: a quarter of a
# pixel is invisible in the output and takes most of the vertices away.
SIMPLIFY_TOLERANCE = SCALE / 4.0
# Nothing is drawn that cannot be clicked.
MIN_PART_PIXELS = 4
MIN_PART_AREA = MIN_PART_PIXELS * SCALE * SCALE


@dataclass(frozen=True)
class Override:
    """One row of `part_overrides.csv`: a box that reassigns the parts inside it."""

    adm0_a3: str
    bounds: tuple[float, float, float, float]
    region: str
    note: str


def read_groups() -> pd.DataFrame:
    return pd.read_csv(ROOT / "region_groups.csv", dtype=str)


def read_overrides() -> list[Override]:
    frame = pd.read_csv(ROOT / "part_overrides.csv")
    return [
        Override(
            str(row.adm0_a3),
            (float(row.lon_min), float(row.lat_min), float(row.lon_max), float(row.lat_max)),
            str(row.region),
            str(row.note),
        )
        for row in frame.itertuples()
    ]


def read_attributes() -> pd.DataFrame:
    """The authored regions. **Row order is the region index**, starting at 1."""
    frame = pd.read_csv(ROOT / "region_attributes.csv")
    frame.insert(0, "index", range(1, len(frame) + 1))
    return frame


def load_features(groups: pd.DataFrame) -> gpd.GeoDataFrame:
    """Natural Earth, read in place out of its zip and cut down to what we use."""
    features = gpd.read_file(f"zip://{INPUT.as_posix()}")
    if len(features) != FEATURE_COUNT:
        raise SystemExit(f"expected {FEATURE_COUNT} features, found {len(features)}")

    mapping = dict(zip(groups["adm0_a3"], groups["region"], strict=True))
    missing = sorted(set(features[KEY]) - set(mapping))
    if missing:
        raise SystemExit(f"{KEY} codes with no row in region_groups.csv: {missing}")

    features = features[[KEY, "POP_EST", "geometry"]].copy()
    features["region"] = features[KEY].map(mapping)
    # `none` is Antarctica and five open-ocean dependencies. They are dropped
    # here and appear in no raster, no population sum and no file: what is not a
    # region is not drawn, which is how "nothing unclickable may exist" is met.
    return features[features["region"] != NO_REGION].reset_index(drop=True)


def apply_overrides(features: gpd.GeoDataFrame, overrides: list[Override]) -> gpd.GeoDataFrame:
    """Moves overseas parts to the region they belong to, before dissolving.

    Population is deliberately *not* moved with them: it follows
    `region_groups.csv`, and the error that leaves is below 0.5 % everywhere.
    """
    parts = features.explode(index_parts=False, ignore_index=True)
    points = parts.geometry.representative_point()
    for row, override in enumerate(overrides):
        box = shapely.box(*override.bounds)
        selected = (parts[KEY] == override.adm0_a3) & points.within(box)
        matched = int(selected.sum())
        if matched == 0:
            raise SystemExit(
                f"part_overrides.csv row {row + 1} ({override.note}) matched no part"
            )
        print(f"  override {override.note}: {matched} part(s) -> {override.region}")
        parts.loc[selected, "region"] = override.region
    return parts


def dissolve(parts: gpd.GeoDataFrame, attributes: pd.DataFrame) -> gpd.GeoDataFrame:
    """One geometry per region, in the authored index order."""
    merged = parts.dissolve(by="region")[["geometry"]]
    authored = list(attributes["region"])
    missing = sorted(set(authored) - set(merged.index))
    if missing:
        raise SystemExit(f"regions with no geometry: {missing}")
    extra = sorted(set(merged.index) - set(authored))
    if extra:
        raise SystemExit(f"geometry for regions that are not authored: {extra}")
    ordered = merged.loc[authored].reset_index()
    # The row order *is* the index, so it is carried with the geometry from here
    # on rather than looked up again.
    ordered.insert(0, "index", range(1, len(ordered) + 1))
    return ordered


def land_links(regions: gpd.GeoDataFrame) -> list[tuple[str, str]]:
    """Land borders straight out of the geometry.

    Computed here, on the dissolved but **un-simplified** EPSG:4326 layer, and
    nowhere else: simplification moves neighbouring edges apart, after which a
    shared boundary has length 0 and every land link silently disappears.

    Two regions share a border when their boundaries meet in a line, not a point.
    """
    boundaries = regions.geometry.boundary
    tree = shapely.STRtree(regions.geometry.values)
    found: set[tuple[str, str]] = set()
    for i, geom in enumerate(regions.geometry.values):
        for j in tree.query(geom):
            if j <= i:
                continue
            shared = boundaries.iloc[i].intersection(boundaries.iloc[j])
            if shared.is_empty or shared.length <= 0.0:
                continue
            a, b = sorted((regions.at[i, "region"], regions.at[j, "region"]))
            found.add((a, b))
    return sorted(found)


def cut_at_the_edge(geom: Polygon | MultiPolygon) -> Polygon | MultiPolygon:
    """Splits the world at 169° W and moves the far side round to the east.

    Without this the projection smears every polygon that crosses the edge right
    across the map, and it does so without an error of any kind. Natural Earth
    already splits Russia and Fiji at 180°; after the shift those halves have to
    fuse again, which is what the seam check in `verify_map.py` is for.
    """
    east = geom.intersection(shapely.box(EDGE_LON, -90.0, 180.0, 90.0))
    west = geom.intersection(shapely.box(-180.0, -90.0, EDGE_LON, 90.0))
    if west.is_empty:
        return east
    shifted = shapely.transform(west, lambda points: points + np.array([360.0, 0.0]))
    return shapely.union(east, shifted)


def project(regions: gpd.GeoDataFrame) -> gpd.GeoDataFrame:
    projected = regions.copy()
    projected["geometry"] = projected.geometry.apply(cut_at_the_edge)
    projected = projected.set_crs(regions.crs, allow_override=True).to_crs(CRS_TARGET)
    projected["geometry"] = projected.geometry.simplify(
        SIMPLIFY_TOLERANCE, preserve_topology=True
    )
    projected["geometry"] = projected.geometry.apply(drop_small_parts)
    return projected


def drop_small_parts(geom: Polygon | MultiPolygon) -> Polygon | MultiPolygon:
    """Removes anything below the four-pixel floor from the map entirely."""
    if isinstance(geom, Polygon):
        return geom
    kept = [part for part in geom.geoms if part.area >= MIN_PART_AREA]
    if not kept:
        # A region that is nothing but small parts keeps its largest one: losing
        # it completely would leave a hole in the index space.
        kept = [max(geom.geoms, key=lambda part: part.area)]
    return MultiPolygon(kept) if len(kept) > 1 else kept[0]


def project_anchors(attributes: pd.DataFrame) -> list[tuple[int, int]]:
    """The authored anchors, in map pixels.

    Anchors west of the map edge take the same +360° shift as the geometry, or
    they would land on the wrong side of the world.
    """
    longitudes = [
        lon + 360.0 if lon < EDGE_LON else lon for lon in attributes["anchor_lon"].astype(float)
    ]
    points = gpd.GeoSeries(
        gpd.points_from_xy(longitudes, attributes["anchor_lat"].astype(float)),
        crs="EPSG:4326",
    ).to_crs(CRS_TARGET)
    return [(*to_pixel(point.x, point.y, SCALE),) for point in points]


def to_pixel(x: float, y: float, scale: float) -> tuple[int, int]:
    return int((x + HALF_WIDTH) / scale), int((TOP - y) / scale)


def rasterise_ids(regions: gpd.GeoDataFrame) -> np.ndarray:
    """The ID map: one integer per pixel, burnt by pixel centre, never blended.

    `all_touched=False` keeps the burn a binary pixel-centre test. Anti-aliasing
    here would fabricate region ids along every border.
    """
    transform = rasterio.transform.from_origin(-HALF_WIDTH, TOP, SCALE, SCALE)
    shapes = [
        (geom, index)
        for geom, index in zip(regions.geometry, regions["index"], strict=True)
    ]
    return rasterio.features.rasterize(
        shapes,
        out_shape=(HEIGHT, WIDTH),
        transform=transform,
        fill=0,
        all_touched=False,
        dtype="uint16",
    )


def write_id_map(ids: np.ndarray, path: Path) -> None:
    """Index to colour: R is the low byte, G the high byte, B always 0."""
    rgb = np.zeros((HEIGHT, WIDTH, 3), dtype=np.uint8)
    rgb[:, :, 0] = (ids & 0xFF).astype(np.uint8)
    rgb[:, :, 1] = (ids >> 8).astype(np.uint8)
    Image.fromarray(rgb).save(path, optimize=True)


def write_land_mask(regions: gpd.GeoDataFrame, path: Path) -> None:
    scale = SCALE / MASK_FACTOR / SUPERSAMPLE
    transform = rasterio.transform.from_origin(-HALF_WIDTH, TOP, scale, scale)
    burnt = rasterio.features.rasterize(
        [(geom, 255) for geom in regions.geometry],
        out_shape=(MASK_HEIGHT * SUPERSAMPLE, MASK_WIDTH * SUPERSAMPLE),
        transform=transform,
        fill=0,
        all_touched=False,
        dtype="uint8",
    )
    _downsample(burnt).save(path, optimize=True)


def write_border_mask(regions: gpd.GeoDataFrame, path: Path) -> None:
    """Region borders and coastlines as lines, drawn oversized and boxed down.

    PIL draws no anti-aliased lines, so the anti-aliasing the spec asks for comes
    from drawing at twice the size and halving it afterwards.
    """
    scale = SCALE / MASK_FACTOR / SUPERSAMPLE
    image = Image.new("L", (MASK_WIDTH * SUPERSAMPLE, MASK_HEIGHT * SUPERSAMPLE), 0)
    draw = ImageDraw.Draw(image)
    width = BORDER_PIXELS * SUPERSAMPLE
    for geom in regions.geometry:
        parts = geom.geoms if isinstance(geom, MultiPolygon) else [geom]
        for part in parts:
            for ring in [part.exterior, *part.interiors]:
                points = [to_pixel(x, y, scale) for x, y in ring.coords]
                if len(points) > 1:
                    draw.line(points, fill=255, width=width, joint="curve")
    _downsample(image).save(path, optimize=True)


def _downsample(source: Image.Image | np.ndarray) -> Image.Image:
    image = source if isinstance(source, Image.Image) else Image.fromarray(source)
    return image.resize((MASK_WIDTH, MASK_HEIGHT), Image.BOX)


def write_geometry(
    attributes: pd.DataFrame,
    anchors: list[tuple[int, int]],
    ids: np.ndarray,
    links: list[tuple[str, str]],
    path: Path,
) -> None:
    counts = np.bincount(ids.ravel(), minlength=len(attributes) + 1)
    regions = [
        {
            "index": int(row.index),
            "id": str(row.region),
            "anchor": [anchors[i][0], anchors[i][1]],
            "pixel_area": int(counts[int(row.index)]),
        }
        for i, row in enumerate(attributes.itertuples())
    ]
    payload = {"regions": regions, "land_links": [[a, b] for a, b in links]}
    # newline="\n" explicitly: the default is the platform's, and a file that
    # comes out CRLF here would differ between this machine and Linux CI for no
    # reason at all — which is exactly what the reproducibility check is for.
    path.write_text(json.dumps(payload, indent="\t") + "\n", encoding="utf-8", newline="\n")


def main() -> int:
    BUILD.mkdir(parents=True, exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)

    groups = read_groups()
    attributes = read_attributes()
    print(f"regions: {len(attributes)}")

    features = load_features(groups)
    parts = apply_overrides(features, read_overrides())
    regions = dissolve(parts, attributes)

    links = land_links(regions)
    print(f"land links: {len(links)}")

    projected = project(regions)
    anchors = project_anchors(attributes)

    ids = rasterise_ids(projected)
    print(f"land pixels: {int((ids > 0).sum())} of {WIDTH * HEIGHT}")

    write_id_map(ids, ASSETS / "id_map.png")
    write_land_mask(projected, ASSETS / "land_mask.png")
    write_border_mask(projected, ASSETS / "border_mask.png")
    write_geometry(attributes, anchors, ids, links, BUILD / "geometry.json")
    print("written: id_map.png, land_mask.png, border_mask.png, build/geometry.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
