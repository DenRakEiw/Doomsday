"""Checks the built map against `docs/specs/world.md` §7.

    uv run --project tools/map python tools/map/verify_map.py

Every check here exists because the step it guards produces a plausible-looking
wrong result when it goes wrong: a blended border pixel is a mis-click, a lost
land link is a region nobody can reach, a smeared polygon is a map that looks
almost right. Exits 1 and names what failed.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd
import pyproj
from PIL import Image

import build_map as build

# Expected matches per row of `part_overrides.csv`, in file order.
EXPECTED_OVERRIDE_MATCHES = [1, 4, 1, 1, 3, 1]
# Nothing below this may be drawn: it could not be clicked.
MIN_PIXEL_AREA = 400
# An anchor has to sit at least one pixel inside its own region.
ANCHOR_MARGIN = 1
# Where Russia's two halves must have fused after the +360° shift.
SEAM_LON = 180.0
SEAM_LAT_RANGE = (62.0, 69.0)

Image.MAX_IMAGE_PIXELS = None


class Report:
    """Collects failures instead of stopping at the first one."""

    def __init__(self) -> None:
        self.failures: list[str] = []

    def check(self, name: str, ok: bool, detail: str = "") -> None:
        if ok:
            print(f"  ok    {name}")
            return
        self.failures.append(f"{name}: {detail}" if detail else name)
        print(f"  FAIL  {name}{': ' + detail if detail else ''}")


def check_tables(report: Report) -> None:
    groups = build.read_groups()
    attributes = build.read_attributes()

    report.check(
        "every Natural Earth code is grouped exactly once",
        len(groups) == build.FEATURE_COUNT and groups["adm0_a3"].is_unique,
        f"{len(groups)} rows, unique={groups['adm0_a3'].is_unique}",
    )

    grouped = {r for r in groups["region"] if r != build.NO_REGION}
    authored = set(attributes["region"])
    report.check(
        "grouped regions and authored regions are the same set",
        grouped == authored,
        f"only grouped: {sorted(grouped - authored)}; only authored: {sorted(authored - grouped)}",
    )
    report.check(
        "region ids are unique",
        attributes["region"].is_unique,
        "",
    )


def check_overrides(report: Report, parts: gpd.GeoDataFrame) -> None:
    """Re-counts the override matches; `build_map` already fails on a zero."""
    overrides = build.read_overrides()
    features = build.load_features(build.read_groups())
    exploded = features.explode(index_parts=False, ignore_index=True)
    points = exploded.geometry.representative_point()
    counts = [
        int(((exploded[build.KEY] == override.adm0_a3)
            & points.within(build.shapely.box(*override.bounds))).sum())
        for override in overrides
    ]
    report.check(
        "override matches per row",
        counts == EXPECTED_OVERRIDE_MATCHES,
        f"{counts}, expected {EXPECTED_OVERRIDE_MATCHES}",
    )


def check_links(report: Report, links: list[tuple[str, str]]) -> None:
    expected_frame = pd.read_csv(build.ROOT / "expected_land_links.csv")
    expected = {(str(row.a), str(row.b)) for row in expected_frame.itertuples()}
    found = set(links)
    report.check(
        "land links match expected_land_links.csv exactly",
        found == expected,
        f"missing {sorted(expected - found)}; unexpected {sorted(found - expected)}",
    )
    report.check(
        "every land link is sorted and no pair appears twice",
        all(a < b for a, b in links) and len(links) == len(found),
        "",
    )


def check_id_map(report: Report, count: int) -> np.ndarray:
    pixels = np.asarray(Image.open(build.ASSETS / "id_map.png"))
    report.check(
        "the ID map has the frame world.md §4 gives",
        pixels.shape == (build.HEIGHT, build.WIDTH, 3),
        str(pixels.shape),
    )
    report.check("blue is 0 everywhere", not pixels[:, :, 2].any(), "")

    ids = pixels[:, :, 0].astype(np.uint16) | (pixels[:, :, 1].astype(np.uint16) << 8)
    present = np.unique(ids)
    # A blended pixel decodes to an index that belongs to nobody, which is how
    # anti-aliasing would show up here.
    report.check(
        "every pixel decodes to a known region or to 0",
        int(present.max()) <= count,
        f"highest index {int(present.max())}, {count} regions",
    )
    report.check(
        "every region is actually drawn",
        len(present) == count + 1,
        f"{len(present) - 1} of {count} regions have pixels",
    )
    return ids


def check_areas(report: Report, geometry: dict, ids: np.ndarray) -> None:
    counts = np.bincount(ids.ravel(), minlength=len(geometry["regions"]) + 1)
    too_small = [
        (r["id"], r["pixel_area"])
        for r in geometry["regions"]
        if r["pixel_area"] < MIN_PIXEL_AREA
    ]
    report.check(
        f"every region covers at least {MIN_PIXEL_AREA} pixels",
        not too_small,
        str(too_small),
    )
    mismatched = [
        r["id"] for r in geometry["regions"] if counts[r["index"]] != r["pixel_area"]
    ]
    report.check(
        "the recorded pixel areas are the ones in the image",
        not mismatched,
        str(mismatched),
    )
    smallest = sorted(geometry["regions"], key=lambda r: r["pixel_area"])[:3]
    print("        smallest: " + ", ".join(f"{r['id']} {r['pixel_area']}" for r in smallest))


def check_anchors(report: Report, geometry: dict, ids: np.ndarray) -> None:
    wrong: list[str] = []
    for region in geometry["regions"]:
        x, y = region["anchor"]
        window = ids[
            y - ANCHOR_MARGIN : y + ANCHOR_MARGIN + 1,
            x - ANCHOR_MARGIN : x + ANCHOR_MARGIN + 1,
        ]
        if not np.all(window == region["index"]):
            wrong.append(f"{region['id']} at ({x}, {y})")
    report.check(
        "every anchor and the eight pixels round it belong to their region",
        not wrong,
        str(wrong),
    )


def check_seam(report: Report, ids: np.ndarray) -> None:
    """Russia's two halves must have fused where Natural Earth split them at 180°.

    A seam is a column of ocean, or of border line, running the whole height of
    Chukotka — the one failure mode of the +360° shift that still looks like a
    map.
    """
    transformer = pyproj.Transformer.from_crs("EPSG:4326", build.CRS_TARGET, always_xy=True)
    x, _ = transformer.transform(SEAM_LON, SEAM_LAT_RANGE[0])
    column = build.to_pixel(x, 0.0, build.SCALE)[0]
    rows = [
        build.to_pixel(x, transformer.transform(SEAM_LON, lat)[1], build.SCALE)[1]
        for lat in SEAM_LAT_RANGE
    ]
    band = ids[min(rows) : max(rows) + 1, column - 4 : column + 5]
    gaps = (band == 0).sum(axis=0)
    middle = int(gaps[4])
    neighbours = int(np.median(np.delete(gaps, 4)))
    report.check(
        "no gap along the antimeridian through Chukotka",
        middle <= neighbours + 1,
        f"{middle} empty pixels in the seam column against {neighbours} beside it",
    )

    borders = np.asarray(Image.open(build.ASSETS / "border_mask.png"))
    mask_column = column * build.MASK_FACTOR
    mask_rows = (min(rows) * build.MASK_FACTOR, max(rows) * build.MASK_FACTOR)
    strip = borders[mask_rows[0] : mask_rows[1], mask_column - 8 : mask_column + 9]
    lit = (strip > 0).mean(axis=0)
    report.check(
        "no border line runs down the antimeridian",
        float(lit[8]) < 0.9,
        f"{float(lit[8]):.2f} of the seam column is a border line",
    )


def check_masks(report: Report) -> None:
    for name in ["land_mask.png", "border_mask.png"]:
        image = Image.open(build.ASSETS / name)
        report.check(
            f"{name} is {build.MASK_WIDTH}x{build.MASK_HEIGHT} greyscale",
            image.size == (build.MASK_WIDTH, build.MASK_HEIGHT) and image.mode == "L",
            f"{image.size} {image.mode}",
        )
        values = np.unique(np.asarray(image))
        report.check(
            f"{name} is anti-aliased, not a hard stencil",
            len(values) > 2,
            f"{len(values)} distinct values",
        )


def outputs() -> list[Path]:
    return [
        build.ASSETS / "id_map.png",
        build.ASSETS / "land_mask.png",
        build.ASSETS / "border_mask.png",
        build.BUILD / "geometry.json",
    ]


def digest() -> dict[str, str]:
    return {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in outputs()}


def check_reproducible(report: Report) -> None:
    before = digest()
    print("  ...   rebuilding to compare")
    build.main()
    after = digest()
    changed = [name for name in before if before[name] != after[name]]
    report.check("a second build is byte-identical", not changed, str(changed))


def main() -> int:
    missing = [p.name for p in outputs() if not p.exists()]
    if missing:
        print(f"nothing to verify — run build_map.py first (missing {missing})")
        return 1

    report = Report()
    print("tables")
    check_tables(report)

    print("geometry")
    attributes = build.read_attributes()
    features = build.load_features(build.read_groups())
    parts = build.apply_overrides(features, build.read_overrides())
    check_overrides(report, parts)
    regions = build.dissolve(parts, attributes)
    check_links(report, build.land_links(regions))

    print("raster")
    geometry = json.loads((build.BUILD / "geometry.json").read_text(encoding="utf-8"))
    ids = check_id_map(report, len(attributes))
    check_areas(report, geometry, ids)
    check_anchors(report, geometry, ids)
    check_seam(report, ids)
    check_masks(report)

    print("reproducibility")
    check_reproducible(report)

    print()
    if report.failures:
        print(f"{len(report.failures)} check(s) failed:")
        for failure in report.failures:
            print(f"  - {failure}")
        return 1
    print("every check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
