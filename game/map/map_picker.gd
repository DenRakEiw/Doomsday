class_name MapPicker
extends RefCounted
## Screen point → region index (spec ui-foundation.md §7.4).
##
## Pure and static: no node, no viewport, no frame. The camera contributes one
## `Transform2D` and the ID map one `Image`, so every rule here can be checked
## without a running game — which is the point, because a picking error is a
## mis-click the player cannot see and cannot explain.
##
## The ID map is read as decoded integers, exactly as the shader reads it
## (`map.gdshader`): the pixel is the region's number, never its colour.

## Index 0 is "no region": the ocean, and everything outside the map.
const NO_REGION: int = 0


## The region under `screen`, or `NO_REGION`. `id_image` is the ID map cached
## once at startup — `Texture2D.get_image()` copies from the GPU and must never
## happen per click.
static func region_at(screen: Vector2, camera: MapCamera, id_image: Image) -> int:
	if camera == null:
		return NO_REGION
	return region_at_transform(screen, camera.canvas_transform(), id_image)


## The same with the transform stated outright, which is what the camera's is:
## world → screen. Everything testable about picking is testable here.
static func region_at_transform(screen: Vector2, canvas: Transform2D,
		id_image: Image) -> int:
	return index_at(map_pixel(screen, canvas), id_image)


## Screen → map pixel. `MapView` draws the ID map at 1 : 1 from the world
## origin, so a world unit is a map pixel and no second scale exists.
static func map_pixel(screen: Vector2, canvas: Transform2D) -> Vector2:
	return canvas.affine_inverse() * screen


## The index stored at a map pixel, or `NO_REGION` outside the image. The
## fractional part is dropped rather than rounded: pixel 3 covers 3.0 … 3.999.
static func index_at(pixel: Vector2, id_image: Image) -> int:
	if id_image == null:
		return NO_REGION
	var x: int = floori(pixel.x)
	var y: int = floori(pixel.y)
	if x < 0 or y < 0 or x >= id_image.get_width() or y >= id_image.get_height():
		return NO_REGION
	var encoded: Color = id_image.get_pixel(x, y)
	return roundi(encoded.r * 255.0) + 256 * roundi(encoded.g * 255.0)
