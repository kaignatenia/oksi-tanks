## Tank pictures (top-down, from the CraftPix "2D Battle Tank Game Assets" freebie; baked by tools/bake_tanks.py).
## The only place that knows the files: the battle, the menu, the garage and the shop all draw tanks through here.
extends RefCounted

## Player skin id -> picture. Enemies are "e1".."e5" (enemy type), the wingman is "ally".
## New painted tanks (tools/bake_tanks2.py) are "n_<name>"; a skin without a new picture keeps the old one.
const SKIN := {"classic": "n_veteran", "khaki": "n_khaki", "arctic": "n_arctic", "inferno": "n_inferno",
	"neon": "n_neon", "titan": "n_titan", "bear": "n_bear", "katyusha": "n_katyusha", "amphibia": "n_amphibia",
	"twin": "n_twin", "tiger": "n_tiger", "panther": "n_panther", "thunder": "n_thunder", "ricochet": "n_ricochet",
	"guardian": "n_guardian", "samurai": "n_samurai", "ninja": "n_ninja", "mirage": "n_mirage", "dragon": "n_dragon",
	"pulse": "n_pulse"}
const ALIAS := {"e0": "n_e_light", "e1": "n_e_fast", "e2": "n_e_heavy", "e3": "n_e_sniper", "e4": "n_e_raider",
	"e5": "n_e_boss", "ally": "n_ally"}
const FILL_NEW := 0.5
## Part of the picture the tank body covers (the rest is transparent margin), so pictures match the old cell size.
const FILL := 0.62

static var _cache := {}


static func sprite_for_skin(skin_id: String) -> String:
	return SKIN.get(skin_id, "p_classic")


static func tex(name: String, frame: int = 0) -> Texture2D:
	name = ALIAS.get(name, name)
	var key := "%s_%s" % [name, "A" if frame % 2 == 0 else "B"]
	if not _cache.has(key):
		_cache[key] = load("res://art/tanks/%s.png" % key)
	return _cache[key]


## Draws tank `name` centred at `c`; `size` = the tank body's length on screen, `angle` 0 = facing up.
static func draw(ci: CanvasItem, name: String, c: Vector2, size: float, angle: float = 0.0, frame: int = 0,
		mod: Color = Color.WHITE) -> void:
	var t := tex(name, frame)
	if t == null:
		return
	var s := size / (FILL_NEW if str(ALIAS.get(name, name)).begins_with("n_") else FILL)
	ci.draw_set_transform(c, angle, Vector2.ONE)
	ci.draw_texture_rect(t, Rect2(-s * 0.5, -s * 0.5, s, s), false, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Battle items (CraftPix "Objects and Items for 2D Tank Game" freebie): bonus kinds, "mine", explosion frames.
static func item(name: String) -> Texture2D:
	var key := "item_" + name
	if not _cache.has(key):
		_cache[key] = load("res://art/tank_items/%s.png" % name) if ResourceLoader.exists("res://art/tank_items/%s.png" % name) else null
	return _cache[key]


static func draw_item(ci: CanvasItem, name: String, c: Vector2, size: float, mod: Color = Color.WHITE) -> bool:
	var t := item(name)
	if t == null:
		return false
	ci.draw_texture_rect(t, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), false, mod)
	return true


## Explosion at progress k (0..1): 5 frames; big = tank destroyed, small = shell hit.
static func draw_boom(ci: CanvasItem, c: Vector2, size: float, k: float, big: bool) -> void:
	var f := clampi(int(k * 5.0), 0, 4) + 1
	draw_item(ci, "boom_%s%d" % ["A" if big else "B", f], c, size, Color(1, 1, 1, clampf(1.6 - k * 1.4, 0.0, 1.0)))
