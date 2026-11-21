extends Node2D
## Super game "Tank Battle": original top-down tank mini-game.
## Destroy the enemy wave and guard the generator, which powers your super weapon.

signal finished(win: bool)
const Data = preload("res://scripts/tank_data.gd")

const N := 13
const EMPTY := 0
const BRICK := 1
const STEEL := 2
const WATER := 3
const BUSH := 4
const BASE := 5
const ICE := 6
const MUD := 7
const DIRS := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
const PLAYER_SPAWN := Vector2(4.5, 12.5)
const GEN := Vector2(6.5, 12.5)
const HALF := 0.43
const FORT := [Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11), Vector2i(5, 12), Vector2i(7, 12)]
# enemy types: 0 rifleman, 1 scout, 2 heavy, 3 sniper, 4 sapper, 5 super tank (last)
const E_SPEED := [1.35, 2.1, 1.0, 1.15, 1.4, 0.9]  # the super tank is big and heavy: slow, but smart
const E_HP := [1, 1, 3, 1, 2, 10]
const BOSS_SUPER_DMG := 5
const TankArt = preload("res://scripts/tank_art.gd")
const UI_FIRE = preload("res://art/ui/tk_fire.png")  # painted controls and generator (Oksi Core style)
const UI_SUPER = preload("res://art/ui/tk_super.png")
const UI_FLAME = preload("res://art/ui/tk_flame.png")  # Inferno's flamethrower button
const UI_MINE = preload("res://art/ui/tk_mine.png")
const UI_GEN = preload("res://art/ui/tk_generator.png")
const UI_BG = preload("res://art/ui/tanks_bg.jpg")
const T_BRICK = preload("res://art/ui/tile_brick.png")  # grey, tinted with the arena's brick colour
const T_STEEL = preload("res://art/ui/tile_steel.png")
const T_ICE = preload("res://art/ui/tile_ice.png")
const T_WATER = preload("res://art/ui/tile_water.png")  # seamless; each cell shows its own quarter
const T_MUD = preload("res://art/ui/tile_mud.png")
const UI_JOY = preload("res://art/ui/joy_base.png")
const UI_KNOB = preload("res://art/ui/joy_knob.png")
const UI_HEART = preload("res://art/ui/heart.png")
const UI_MINE_BTN = preload("res://art/ui/tk_mine_btn.png")
const UI_PLATE = preload("res://art/ui/tk_plate.png")        # riveted armour button plates
const UI_PLATE_ON = preload("res://art/ui/tk_plate_on.png")
const FX_CRACK1 = preload("res://art/ui/fx_crack1.png")   # a wall hit once
const FX_CRACK2 = preload("res://art/ui/fx_crack2.png")   # about to break
const FX_TRACKS = preload("res://art/ui/fx_tracks.png")   # tread prints, pointing up
const FX_SCORCH = preload("res://art/ui/fx_scorch.png")
const FX_FIRE = preload("res://art/ui/fx_fire.png")
const FX_MUZZLE = preload("res://art/ui/fx_muzzle.png")   # cone pointing up
const FX_SMOKE = preload("res://art/ui/fx_smoke.png")
const FX_SHELL = preload("res://art/ui/fx_shell.png")     # pointing up
const UI_ENEMY = preload("res://art/ui/enemy_icon.png")
const UI_FLASK = preload("res://art/ui/boss_flask.png")
const TRACKS_MAX := 260
var brick_hits: Array = []   # shots a wall has taken (cracks)
var tracks: Array = []       # tread prints {"p", "d", "t"}; fade out over a while
var boss_shown := 1.0        # the flask level, eases toward the real hp
var flask_slosh := 0.0       # how hard the blood is sloshing (a hit shakes it, then it settles)
var fx: Array = []           # short effects {"k": muzzle/smoke, "p", "d", "t", "life"}
const HIT_FLASH := Color(2.4, 2.4, 2.4)
const ALLY_HP := 2          # helper hit points at upgrade level 0 (+1 per level)
const ALLY_SPEED := 2.8     # cells per second (+0.3 per level); the player's tank starts at 2.4
const ALLY_RELOAD := 0.42   # seconds between shots (-0.06 per level)
const ALLY_SIGHT := 9.0     # cells he looks for targets (+1 per level)
const CRATE_L := 1
const CRATE_R := 2
const BRICK_HP := 2         # shots to break a brick wall
const CRATE_HP := 4         # shots to break a container
const DECALS_MAX := 14
const BONUS_HOME_ROW := 6      # first row of the player's half of the field
const BONUS_HOME_SHARE := 0.85  # share of bonuses that appear there
const FROZEN := Color(0.65, 0.88, 1.35)

var tr_fn: Callable
var reward := 0  # coins the game pays for a win (set by game.gd, VIP already applied)
var sfx: Callable
var vibe: Callable
var stage := 1
var diff := "normal"     # Tanks mode difficulty (Data.TANK_DIFF); set before setup()
var game_speed := 1.0    # from the difficulty: harder = the whole battle runs faster
var map_style := ""      # Data.TANK_MAPS id; "" = by stage
var font: Font

var tiles: Array = []
var brick_hp: Array = []
## Wall material per tile: 0 = brick, CRATE_L / CRATE_R = left / right half of a container (two tiles, tougher).
var mat: Array = []
var crate_col: Array = []   # container colour (0..3) per tile
var decals: Array = []      # scorch marks left by destroyed tanks: {"p", "k", "r"}
var tree_kind := 1          # one kind of tree per battle (1..3), chosen with the map
var player := {}
var enemies: Array = []
var bullets: Array = []
var booms: Array = []
var spawns: Array = []
var bonuses: Array = []
var mines: Array = []
var strikes: Array = []
var trails: Array = []
var total_enemies := 10
var next_id := 1
var to_spawn := 10
var max_active := 4
const BOSS_ESCORT := 3   # the boss spawns together with this many last enemies
var boss_out := false
var elvl := 0
var hard := 0.0  # 0 up to level 10, then rises evenly to 1 at level 100: everything grows past the elvl cap
var killed := 0
var flank_phase := 0.0  # escorts' circle around the player turns differently each battle
## Battle report shown on the result screen. Kill sources: p = player's gun, a = wingman, mine, super = super shot.
var st := {}
var best_time := 0.0       # best winning time on this map and difficulty (0 = none yet); set by the game
var new_record := false
var penalty := 0          # coins a loss costs (shown on the result screen); set by the game
var track_best := false   # Tanks mode only: the report compares the time with best_time
var lives := 3
var spawn_timer := 1.0
var state := "play"
var end_t := 0.0
var anim := 0.0
var rng := RandomNumberGenerator.new()

# player tank level
var tier := 1
var gun_lvl := 0
var power_lvl := 0
var want_helper := false
var ally_lvl := 0          # helper upgrade level (shop): tougher, faster, quicker fire
var ally: Dictionary = {}
var ally_used := false
# Temporary pick-ups for the player (seconds left).
var buffs := {"power": 0.0, "rapid": 0.0, "speed": 0.0}
const BUFF_TIME := 12.0
const BONUS_KINDS := ["repair", "shield", "freeze", "fort", "power", "rapid", "speed"]
var p_speed := 2.4
var fire_cd := 0.24
var reload_t := 0.0  # > 0: the player's reload click plays when it runs out
var max_pb := 1
var armor_max := 0
var armor := 0
var super_time := 8.0
var super_time_near := 5.0
var super_charge := 0.0
var p_freeze := 0.0
var mines_left := 0
var mines_used := 0

const GEN_MAX := 5
var gen_hp := GEN_MAX
var gen_own_hits := 0  # generator hits by the player himself (stats/tests)
var gen_hit := 0.0
var freeze_t := 0.0
var fort_t := 0.0
var fort_pending: Array = []  # fort cells still waiting for a tank to drive off
var near_gen := false
var boss_msg_t := 0.0
var strike_t := 0.0
var beam_t := 0.0
var player_color := Color("e8c547")
var player_accent := Color(0, 0, 0, 0)
var player_sprite := "p_classic"  # set by game.gd from the equipped skin (TankArt.SKIN)
## The player's tank ability (Data.SHOP_TANKS): classic, khaki (forest camouflage), arctic (ice and water),
## inferno (flamethrower), titan (electric shells), neon (laser). Set by game.gd before setup().
var perk := "classic"
var test_drive := false     # shop test drive: leaving costs nothing
var paused := false        # pause menu open: the battle stands still
var pause_c := Vector2.ZERO
var deck_y := 0.0   # top of the control panel
var hud_y := 0.0    # centre line of the top bar
var pz_go := Rect2()
var pz_exit := Rect2()
var engine_gain_db := 0.0   # engine sound volume from the sound settings (set by game.gd)
var fuel := 0.0             # Inferno flamethrower fuel, seconds (game.gd keeps it between battles)
var auto_refill: Callable   # game.gd: pays for a refill when the tank runs dry (auto refill on); true = refilled
var flame_on := false
var flame_held := false
var flame_finger := -1
var flame_c := Vector2.ZERO
var flame_r := 0.0
var camo := false           # Khaki in the forest / Ninja after a kill: enemies do not know where he is
# per-tank abilities (perk = the player's tank id, see Data.SHOP_TANKS)
var shot_n := 0             # player's shots this battle (Katyusha volley every 3rd)
var twin_side := 1          # Twin: which barrel fires next (+1 right, -1 left)
var repair_t := 0.0         # Veteran: time to the next armor repair
var shield_t := 0.0         # Guardian: time to the next shield
var shield_on := false
var ninja_t := 0.0          # Ninja: invisible while > 0
var decoy: Dictionary = {}  # Mirage: hologram {"p", "t"}
var decoy_t := 0.0
var fogs: Array = []        # Neon: dark fog {"p", "t"}; enemies inside crawl at half speed
var dash_cd := 0.0          # Samurai: dash cooldown
var dash_tap := -9.0        # Samurai: when the joystick was last let go
var dash_dir := -1
const FLAMER := false       # the old Inferno flamethrower button (its fire went into the shells)
const REPAIR_S := 30.0
const SHIELD_S := 12.0
const DECOY_S := 20.0
const FLAME_LEN := 2.6      # cells of flame in front of the Inferno
const FLAME_DPS := 3.0      # damage per second to every enemy in the flame
const SHELL_BOOST := 1.5    # Titan and Neon: damage and fire rate
var arena := {"bg": Color("0d1014"), "frame": Color("3b4048"), "brick": Color("b5532b"), "mortar": Color("5e2a14"),
	"steel": Color("aeb7c2"), "bush": Color("2f8f3a"), "water": Color("1f5fbf")}

# layout / input
var view := Vector2(720, 1280)
var u := 1.0
var ts := 40.0
var origin := Vector2.ZERO
var pad_c := Vector2.ZERO
var pad_r := 95.0
var fire_c := Vector2.ZERO
var fire_r := 80.0
var super_c := Vector2.ZERO
var super_r := 60.0
var mine_c := Vector2.ZERO
var mine_r := 40.0
var btn_rect := Rect2()
var move_dir := -1
var sfx_on := true
var engine_pl: AudioStreamPlayer = null
var tracks_pl: AudioStreamPlayer = null
var key_dir := -1
var fire_finger := -1
var fire_held := false
var danger := PackedByteArray()
const SPAWN_SAFE_DIST := 3.0
const SPAWN_SHIELD := 1.5
var joy_finger := -1
var joy_base := Vector2.ZERO
var joy_knob := Vector2.ZERO


func setup(stage_: int, font_: Font, skin: Array = [], arena_: Dictionary = {}, tier_: int = 1, mines_: int = 0,
		ups: Dictionary = {}, practice := false, helper := false) -> void:
	flank_phase = randf() * TAU
	stage = maxi(1, stage_)
	hard = clampf((stage - 10) / 90.0, 0.0, 1.0)
	game_speed = float((Data.TANK_DIFF.get(diff, Data.TANK_DIFF["normal"]) as Dictionary).get("speed", 1.0))
	font = font_
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # the ground texture tiles across the field
	rng.seed = stage * 7777 + 5
	if skin.size() == 2:
		player_color = skin[0]
		player_accent = skin[1]
	if not arena_.is_empty():
		arena = arena_
	tier = clampi(tier_, 1, 6)  # skin rank: cosmetic only, the tank itself is improved with upgrades
	var lv_armor := clampi(int(ups.get("armor", 0)), 0, 3)
	var lv_speed := clampi(int(ups.get("speed", 0)), 0, 3)
	var lv_reload := clampi(int(ups.get("power", 0)), 0, 3)
	gun_lvl = clampi(int(ups.get("gun", 0)), 0, 3)
	armor_max = lv_armor
	p_speed = 2.4 * (1.0 + 0.1 * lv_speed)
	fire_cd = 0.26 * (1.0 - 0.15 * lv_reload) / (SHELL_BOOST if perk in ["titan", "neon", "pulse"] else 1.0)
	max_pb = 2 if gun_lvl >= 2 else 1
	match perk:
		"bear":
			armor_max += 2
			p_speed *= 0.85
		"khaki":
			armor_max += 1
		"amphibia":
			p_speed *= 1.1
		"twin":
			fire_cd *= 0.5
			max_pb += 1
		"katyusha":
			max_pb += 1
	shot_n = 0
	repair_t = REPAIR_S
	shield_t = SHIELD_S
	shield_on = false
	ninja_t = 0.0
	decoy = {}
	decoy_t = DECOY_S
	fogs = []
	dash_cd = 0.0
	# Enemies grow with the player (but slower than he does): every 4 upgrade levels add an enemy level,
	# every 6 add two more tanks. Upgrading always pays off, it just never makes the battle trivial.
	power_lvl = power_of(ups, helper)
	ally_lvl = clampi(int(ups.get("ally", 0)), 0, 3)
	var w := wave(stage, power_lvl, diff)
	elvl = int(w["elvl"])
	total_enemies = int(w["enemies"])
	to_spawn = total_enemies
	boss_out = false
	st = {"time": 0.0, "k_p": 0, "k_a": 0, "k_mine": 0, "k_super": 0, "shots": 0, "hits": 0, "deaths": 0, "saves": 0,
		"b_p": 0, "b_a": 0, "walls": 0, "k_flame": 0, "streak": 0, "best_streak": 0, "boss": false, "gen_lost": 0}
	max_active = ((3 if elvl == 0 else 4) if total_enemies < 15 else 5) + int(round(hard * 2.0))
	if practice:
		# Test drive from the shop: a short, easy round with a few targets.
		total_enemies = 4
		to_spawn = 4
		max_active = 2
		elvl = 0
	armor = armor_max
	mines_left = mines_
	want_helper = helper
	_gen_map()
	player = {"p": PLAYER_SPAWN, "d": 0, "cd": 0.0, "inv": 2.0, "tread": 0.0, "dead": false, "rt": 0.0, "slide": 0.0}
	if want_helper:
		_spawn_ally()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_setup_engine()


func _t(k: String) -> String:
	return str(tr_fn.call(k)) if tr_fn.is_valid() else k


func _sfx(n: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if sfx.is_valid():
		sfx.call(n, pitch, vol_db)


## Engine rumble + track clank loops: idle when standing, louder and higher when driving.
func _setup_engine() -> void:
	for pair in [["engine", "t_engine"], ["tracks", "t_tracks"]]:
		var path := "res://audio/tank/%s.wav" % str(pair[0]).trim_prefix("t_")
		if not ResourceLoader.exists(path):
			continue
		var ws = load(path)
		if ws is AudioStreamWAV:
			ws = (ws as AudioStreamWAV).duplicate()
			ws.loop_mode = AudioStreamWAV.LOOP_FORWARD
			ws.loop_begin = 0
			ws.loop_end = int(ws.get_length() * ws.mix_rate)
		var pl := AudioStreamPlayer.new()
		pl.stream = ws
		pl.volume_db = -60.0
		add_child(pl)
		if pair[0] == "engine":
			engine_pl = pl
		else:
			tracks_pl = pl
		if sfx_on:
			pl.play()


func _update_engine(delta: float) -> void:
	if engine_pl == null:
		return
	var moving := state == "play" and not bool(player.get("dead", false)) and p_freeze <= 0.0 \
		and (key_dir >= 0 or move_dir >= 0)
	var alive := state == "play" and not bool(player.get("dead", false))
	var k := minf(1.0, delta * 6.0)
	engine_pl.pitch_scale = lerpf(engine_pl.pitch_scale, 1.3 if moving else 0.85, k)
	engine_pl.volume_db = lerpf(engine_pl.volume_db, maxf(-60.0, (-7.0 if moving else -13.0) + engine_gain_db) if alive else -60.0, k)
	if tracks_pl:
		tracks_pl.pitch_scale = lerpf(tracks_pl.pitch_scale, p_speed / 2.4, k)
		tracks_pl.volume_db = lerpf(tracks_pl.volume_db, maxf(-60.0, -9.0 + engine_gain_db) if moving else -60.0, minf(1.0, delta * 10.0))


func _vibe(ms: int) -> void:
	if vibe.is_valid():
		vibe.call(ms)


# ---------------------------------------------------------------- map

func _set_tile(x: int, y: int, v: int) -> void:
	tiles[y * N + x] = v
	brick_hp[y * N + x] = BRICK_HP if v == BRICK else 0
	if mat.size() == N * N:
		mat[y * N + x] = 0


func _tile_at(p: Vector2) -> int:
	var x := clampi(int(floor(p.x)), 0, N - 1)
	var y := clampi(int(floor(p.y)), 0, N - 1)
	return int(tiles[y * N + x])


## Player strength for enemy scaling: the tank's own upgrades, +2 with a helper (helper upgrades do not count:
## they only matter when he is in the battle). The garage uses the same function.
static func power_of(ups: Dictionary, helper: bool) -> int:
	var n := 0
	for k in ["armor", "speed", "power", "gun"]:
		n += clampi(int(ups.get(k, 0)), 0, 3)
	return n + (2 if helper else 0)


## Enemy count and level of a battle: the only formula (the garage shows the same numbers through it).
## Every 4 upgrade levels add an enemy level, every 6 add two more tanks; difficulty shifts both.
static func wave(stage_: int, power: int, diff_: String) -> Dictionary:
	var d: Dictionary = Data.TANK_DIFF.get(diff_, Data.TANK_DIFF["normal"])
	var n := mini((10 if stage_ % 2 == 1 else 20) + int(power / 6.0) * 2 + int((stage_ - 1) / 6.0) * 2, 44)  # longer waves on high levels
	return {"elvl": clampi(stage_ - 2 + int(power / 4.0) + int(d["elvl"]), 0, 8),
		"enemies": maxi(4, int(round(n * float(d["count"]))))}


## Map of this battle: the chosen style, or styles in turn by stage.
func style() -> String:
	if Data.TANK_MAPS.has(map_style):
		return map_style
	return Data.TANK_MAPS[(stage - 1) % Data.TANK_MAPS.size()]


func _mirror(x: int, y: int, v: int) -> void:
	_set_tile(x, y, v)
	_set_tile(N - 1 - x, y, v)


func _gen_map() -> void:
	tiles.resize(N * N)
	tiles.fill(EMPTY)
	brick_hp.resize(N * N)
	brick_hits.resize(N * N)
	brick_hits.fill(0)
	tracks.clear()
	fx.clear()
	brick_hp.fill(0)
	mat.resize(N * N)
	mat.fill(0)
	crate_col.resize(N * N)
	crate_col.fill(0)
	decals.clear()
	tree_kind = rng.randi_range(1, 3)
	var st := style()
	match st:
		"city":
			for y in range(1, 11):
				for x in range(0, 7):
					if x % 3 != 2 and y % 3 != 0 and rng.randf() < 0.85:
						_mirror(x, y, STEEL if x % 3 == 0 and y % 3 == 1 and rng.randf() < 0.25 else BRICK)
		"fortress":
			for y in range(1, 11):
				for x in range(0, 7):
					var v := EMPTY
					if x == 1 and y >= 2 and y <= 9 and y != 5 and y != 6:
						v = BRICK
					elif (y == 2 or y == 9) and x >= 1 and x <= 4:
						v = BRICK
					elif x == 3 and y >= 4 and y <= 7:
						v = STEEL if y == 4 or y == 7 else BRICK
					elif (y == 4 or y == 7) and x >= 4 and x <= 5:
						v = BRICK
					elif x == 6 and (y == 5 or y == 6):
						v = BUSH
					elif rng.randf() < 0.05:
						v = BUSH
					_mirror(x, y, v)
		"river":
			for y in range(1, 11):
				for x in range(0, 7):
					var v := EMPTY
					if y == 5 or y == 6:
						v = EMPTY if x == 2 or x == 6 else WATER
					elif (y == 4 or y == 7) and (x == 1 or x == 3):
						v = STEEL
					else:
						var r := rng.randf()
						v = BRICK if r < 0.28 else (BUSH if r < 0.36 else EMPTY)
					_mirror(x, y, v)
		"forest":
			for y in range(1, 11):
				for x in range(0, 7):
					var r := rng.randf()
					_mirror(x, y, BUSH if r < 0.14 else (BRICK if r < 0.32 else (STEEL if r < 0.34 else EMPTY)))
		"maze":
			for y in range(1, 11):
				for x in range(0, 7):
					var v := EMPTY
					if x % 2 == 1 and y % 4 != 0 and rng.randf() < 0.8:
						v = BRICK
					elif y % 4 == 0 and x % 2 == 0 and rng.randf() < 0.5:
						v = BRICK
					if v == BRICK and rng.randf() < 0.12:
						v = STEEL
					_mirror(x, y, v)
		_:
			_gen_classic(st)
	if st == "classic" or st == "ice" or st == "steel":
		_patches(6 if st == "ice" else 3, st == "ice")
	for x in [0, 6, 12]:
		_set_tile(x, 0, EMPTY)
		_set_tile(x, 1, EMPTY)
	for y in range(11, 13):
		for x in N:
			_set_tile(x, y, EMPTY)
	for c in FORT:
		_set_tile(c.x, c.y, BRICK)
		brick_hp[c.y * N + c.x] = 8 - mini(elvl, 4)  # reinforced fort; early waves give the player time
	_set_tile(6, 12, BASE)
	_place_crates(0.6 if st == "city" else (0.15 if st == "maze" else 0.3))
	_ensure_paths()


## Some pairs of neighbouring walls become containers: they look different and take CRATE_HP shots.
func _place_crates(share: float) -> void:
	for y in range(1, 11):
		for x in range(0, 5):
			var a := y * N + x
			if int(tiles[a]) != BRICK or int(tiles[a + 1]) != BRICK or int(mat[a]) != 0 or int(mat[a + 1]) != 0:
				continue
			if rng.randf() >= share:
				continue
			var col := rng.randi_range(0, 3)
			for xx in [x, N - 2 - x]:
				var i: int = y * N + xx
				mat[i] = CRATE_L
				mat[i + 1] = CRATE_R
				brick_hp[i] = CRATE_HP
				brick_hp[i + 1] = CRATE_HP
				crate_col[i] = col
				crate_col[i + 1] = col


## Enemies must always be able to reach the base and the player the enemies: steel and water never wall it off
## (bricks can be shot through, so they count as passable).
func _ensure_paths() -> void:
	for attempt in 2:
		if _reachable():
			return
		for i in N * N:
			if attempt == 0 and int(tiles[i]) == STEEL:
				tiles[i] = BRICK
				brick_hp[i] = 2
			elif attempt == 1 and int(tiles[i]) == WATER:
				tiles[i] = EMPTY


func _reachable() -> bool:
	var seen := {}
	var q: Array = [Vector2i(0, 0), Vector2i(6, 0), Vector2i(12, 0)]
	for c in q:
		seen[c] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		if c.y >= 10:
			return true
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if n.x < 0 or n.y < 0 or n.x >= N or n.y >= N or seen.has(n):
				continue
			var v := int(tiles[n.y * N + n.x])
			if v == STEEL or v == WATER:
				continue
			seen[n] = true
			q.append(n)
	return false


func _gen_classic(st: String) -> void:
	var steel_p := 0.3 if st == "steel" else 0.02 * mini(stage, 4)
	var brick_p := 0.35 if st == "ice" else 0.6
	for y in range(1, 11):
		for x in range(0, 7):
			var v := EMPTY
			var r := rng.randf()
			if x % 2 == 1 and y % 5 != 0:
				if r < brick_p - (steel_p if st == "steel" else 0.0):
					v = BRICK
				elif r < brick_p + (0.0 if st == "steel" else steel_p):
					v = STEEL
			elif r < 0.07:
				v = BRICK
			elif r < 0.11:
				v = BUSH
			elif r < 0.13 and y > 2 and y < 9:
				v = WATER
			_set_tile(x, y, v)
			_set_tile(N - 1 - x, y, v)


## Patches of ice and mud on open ground (more ice on the ice map).
func _patches(count: int, icy: bool) -> void:
	for k in count:
		var cx := rng.randi_range(0, 5)
		var cy := rng.randi_range(2, 9)
		var kind := ICE if k % 2 == 0 or (icy and k % 3 != 2) else MUD
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x := cx + dx
				var y := cy + dy
				if x >= 0 and x < 7 and y >= 1 and y <= 10 and int(tiles[y * N + x]) == EMPTY and rng.randf() < 0.8:
					_set_tile(x, y, kind)
					_set_tile(N - 1 - x, y, kind)


# ---------------------------------------------------------------- layout

func _layout() -> void:
	view = get_viewport_rect().size
	u = minf(view.x / 720.0, view.y / 1280.0)
	var asz := minf(view.x * 0.96, view.y * 0.6)
	ts = asz / N
	var top := maxf(0.0, (view.y - 1280.0 * u) * 0.5) + 130.0 * u
	origin = Vector2((view.x - asz) * 0.5, top)
	var area := view.y - origin.y - asz
	deck_y = origin.y + asz + 14 * u
	# control deck, one rhythm: the same edge margin left and right, the same gap between the buttons
	var deck_h := view.y - 14 * u - deck_y
	var m := 40.0 * u
	var gap := 24.0 * u
	fire_r = minf(84.0 * u, deck_h * 0.26)
	pad_r = fire_r * 1.08
	super_r = fire_r * 0.6
	mine_r = super_r
	# right group: Fire, Mine above it, Super to its left; the group is centred in the deck height
	var grp_h := 2.0 * fire_r + gap + 2.0 * mine_r
	var gtop := deck_y + (deck_h - grp_h) * 0.5
	fire_c = Vector2(view.x - 16 * u - m - fire_r, gtop + 2.0 * mine_r + gap + fire_r)
	mine_c = Vector2(fire_c.x, gtop + mine_r)
	super_c = Vector2(fire_c.x - fire_r - gap - super_r, fire_c.y)
	flame_r = super_r
	flame_c = Vector2(super_c.x, mine_c.y)
	pad_c = Vector2(16 * u + m + pad_r, gtop + grp_h * 0.5)  # the joystick sits in the middle of the deck
	hud_y = origin.y - 54 * u
	pause_c = Vector2(origin.x + 40 * u, hud_y)
	flame_r = fire_r * 0.5
	flame_c = fire_c + Vector2(-fire_r * 1.9, 0)
	queue_redraw()


# ---------------------------------------------------------------- tanks

func _all_tanks() -> Array:
	var out: Array = enemies.duplicate()
	if not bool(player["dead"]):
		out.append(player)
	if _ally_alive():
		out.append(ally)
	return out

func _solid(v: int) -> bool:
	return v == BRICK or v == STEEL or v == WATER or v == BASE


func _blocked(p: Vector2, me: Variant) -> bool:
	if p.x - HALF < 0.0 or p.y - HALF < 0.0 or p.x + HALF > N or p.y + HALF > N:
		return true
	for ty in range(int(floor(p.y - HALF)), int(floor(p.y + HALF - 0.001)) + 1):
		for tx in range(int(floor(p.x - HALF)), int(floor(p.x + HALF - 0.001)) + 1):
			var v := int(tiles[ty * N + tx])
			if _solid(v) and not (v == WATER and perk == "amphibia" and is_same(me, player)):
				return true
	for t in _all_tanks():
		if is_same(t, me):
			continue
		var q: Vector2 = t["p"]
		if absf(q.x - p.x) < HALF * 2.0 and absf(q.y - p.y) < HALF * 2.0:
			return true
	return false


func _move_tank(t: Dictionary, dir: int, speed: float, delta: float) -> bool:
	if dir != int(t["d"]):
		if dir % 2 != int(t["d"]) % 2:
			var p: Vector2 = t["p"]
			if dir % 2 == 0:
				p.x = round(p.x * 2.0) / 2.0
			else:
				p.y = round(p.y * 2.0) / 2.0
			if not _blocked(p, t):
				t["p"] = p
		t["d"] = dir
	var ground := _tile_at(t["p"])
	if ground == MUD and not (perk == "amphibia" and is_same(t, player)):
		speed *= 0.4
	if t.has("type"):  # enemy: slowed by Arctic ice shells or Neon fog
		if float(t.get("slow", 0.0)) > 0.0:
			speed *= 0.5
		for f in fogs:
			if (f["p"] as Vector2).distance_to(t["p"]) < 1.6:
				speed *= 0.5
				break
	elif ground == ICE:
		speed *= 1.15
	var np: Vector2 = t["p"] + DIRS[dir] * speed * delta
	if _blocked(np, t):
		return false
	t["p"] = np
	t["tread"] = float(t["tread"]) + speed * delta
	if float(t["tread"]) - float(t.get("print", 0.0)) > 0.3:  # a tread print every 0.3 cells
		t["print"] = t["tread"]
		tracks.append({"p": np, "d": dir, "t": anim})
		if tracks.size() > TRACKS_MAX:
			tracks.pop_front()
	return true


func _bullet_count(t: Dictionary) -> int:
	var n := 0
	for b in bullets:
		if is_same(b["src"], t):
			n += 1
	return n


func _shoot(t: Dictionary, owner: int) -> void:
	var d: int = t["d"]
	var sp := 8.0
	var dmg := 1
	if owner == 0:
		st["shots"] = int(st.get("shots", 0)) + 1
		sp = 10.0 if gun_lvl >= 1 else 8.0
		dmg = (2 if gun_lvl >= 3 else 1) * (2 if float(buffs["power"]) > 0.0 else 1)
	elif owner == 2:
		sp = 8.0
	else:
		var ty := int(t.get("type", 0))
		sp = (7.0 if ty == 3 else (5.2 if ty == 1 else 4.4)) + elvl * 0.3
		if str(t.get("buff", "")) == "power":
			dmg = 2
	var side := Vector2.ZERO  # Twin: the barrel this shot leaves from
	if owner == 0 and perk == "twin":
		twin_side = -twin_side
		side = DIRS[(d + 1) % 4] * 0.17 * twin_side
	var b := {"p": t["p"] + DIRS[d] * 0.45 + side, "d": d, "o": owner, "src": t, "sp": sp, "dead": false, "dmg": float(dmg)}
	if owner == 0:
		shot_n += 1
		match perk:
			"pulse":
				b["laser"] = true  # melts enemy shells, pierces spawn shields
				b["dmg"] = dmg * SHELL_BOOST
				b["sp"] = 14.0
			"titan":
				b["zap"] = true
				b["dmg"] = dmg * SHELL_BOOST
				b["sp"] = 11.0
			"neon":
				b["dark"] = true  # one hit kills any tank; the super tank takes 5x
				b["sp"] = 12.0
			"panther":
				b["sp"] = sp * 1.6
				b["pan"] = true
			"tiger":
				b["pierce"] = 1
			"thunder":
				b["blast"] = true
			"ricochet":
				b["bounce"] = 1
			"dragon":
				b["shard"] = true
			"arctic":
				b["ice"] = true
			"inferno":
				b["fire"] = true
	bullets.append(b)
	if owner == 0 and perk == "katyusha" and shot_n % 3 == 0:  # volley: two more rockets beside the first
		for k in [-1, 1]:
			var vb := b.duplicate()
			vb["p"] = (b["p"] as Vector2) + DIRS[(d + 1) % 4] * 0.34 * k
			vb["volley"] = true
			bullets.append(vb)
	t["kick"] = anim  # recoil: the tank jerks back for a moment
	var mz: Vector2 = t["p"] + DIRS[d] * 0.55 + side
	fx.append({"k": "muzzle", "p": mz, "d": d, "t": anim, "life": 0.09})
	for j in 2:
		fx.append({"k": "smoke", "p": mz + Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12)),
			"d": d, "t": anim + j * 0.05, "life": 0.7, "r": rng.randf() * TAU})
	if owner == 0:
		_sfx("t_shot", rng.randf_range(0.94, 1.06))
		reload_t = 0.16  # the shell is loaded right after the shot
	else:
		_sfx("t_shot", rng.randf_range(1.1, 1.25), -9.0)


## Teams: 1 = enemies, 0 = the player and his helper (owner 2).
func _side(owner: int) -> int:
	return 1 if owner == 1 else 0

func _super_shot(t: Dictionary, owner: int) -> void:
	var d: int = t["d"]
	bullets.append({"p": t["p"] + DIRS[d] * 0.45, "d": d, "o": owner, "src": {}, "sp": 11.0 if owner == 0 else 8.0,
		"dead": false, "super": true, "hits": {}})
	_sfx("t_shot_big", 1.0 if owner == 0 else 0.85)
	_vibe(60)


func _fire_super() -> void:
	if super_charge < 1.0 or bool(player["dead"]) or state != "play" or p_freeze > 0.0:
		return
	super_charge = 0.0
	_super_shot(player, 0)


func _drop_mine() -> void:
	if mines_left <= 0 or bool(player["dead"]) or state != "play":
		return
	var p: Vector2 = player["p"]
	var c := Vector2(floor(p.x) + 0.5, floor(p.y) + 0.5)
	for m in mines:
		if (m["p"] as Vector2).distance_to(c) < 0.5:
			return
	mines.append({"p": c, "arm": 0.8})
	mines_left -= 1
	mines_used += 1
	_sfx("t_mine")


## Enemy classes: light (basic 0, fast 1, sniper 3) die from 1 hit, medium (4) from 2, heavy (2) from 3; 5 is the boss.
## Later waves and a stronger player tank bring more medium and heavy tanks.
func _enemy_type(last: bool) -> int:
	if last:
		return 5
	var t := clampf((stage - 1) * 0.07 + power_lvl * 0.025, 0.0, 0.6 + 0.3 * hard)
	var heavy := 0.06 + 0.4 * t
	var medium := 0.14 + 0.35 * t
	var r := rng.randf()
	if r < heavy:
		return 2
	r -= heavy
	if r < medium:
		return 4
	r -= medium
	if r < 0.12:
		return 3
	if r < 0.32:
		return 1
	return 0

func _boom(p: Vector2, big: bool) -> void:
	booms.append({"p": p, "t": 0.0, "big": big})
	if big:
		decals.append({"p": p, "k": rng.randi_range(1, 3), "r": rng.randf() * TAU, "t": anim})
		if decals.size() > DECALS_MAX:
			decals.pop_front()
		_sfx("t_explode", rng.randf_range(0.9, 1.1))
	else:
		_sfx("t_explode_small", rng.randf_range(0.9, 1.2), -10.0)
		_vibe(40)


# ---------------------------------------------------------------- AI helpers

func _los(a: Vector2, b: Vector2) -> bool:
	if absf(a.x - b.x) < 0.35:
		var x := int(floor(a.x))
		for y in range(int(floor(minf(a.y, b.y))) + 1, int(floor(maxf(a.y, b.y)))):
			var v: int = tiles[y * N + x]
			if v == BRICK or v == STEEL:
				return false
		return true
	if absf(a.y - b.y) < 0.35:
		var y := int(floor(a.y))
		for x in range(int(floor(minf(a.x, b.x))) + 1, int(floor(maxf(a.x, b.x)))):
			var v: int = tiles[y * N + x]
			if v == BRICK or v == STEEL:
				return false
		return true
	return false


## Direction to fire at the generator from `p` if it is lined up within range and no steel is in the way
## (bricks are fine: shooting them open is the point). -1 if not lined up.
func _gen_line(p: Vector2) -> int:
	var aligned_x := absf(p.x - GEN.x) < 0.35
	var aligned_y := absf(p.y - GEN.y) < 0.35
	if not aligned_x and not aligned_y:
		return -1
	if p.distance_to(GEN) > 9.0:
		return -1
	var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
	var g := Vector2i(int(floor(GEN.x)), int(floor(GEN.y)))
	var step := Vector2i(signi(g.x - c.x), signi(g.y - c.y))
	var q := c + step
	while q != g:
		if int(tiles[q.y * N + q.x]) == STEEL:
			return -1
		q += step
	return _dir_to(p, GEN)


func _siegers() -> int:
	var n := 0
	for o in enemies:
		if bool(o.get("siege", false)):
			n += 1
	return n


func _brick_ahead(p: Vector2, d: int, cells: int) -> bool:
	var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
	var v: Vector2 = DIRS[d]
	for k in range(1, cells + 1):
		var q := c + Vector2i(int(v.x) * k, int(v.y) * k)
		if q.x < 0 or q.y < 0 or q.x >= N or q.y >= N:
			return false
		var t: int = tiles[q.y * N + q.x]
		if t == BRICK or t == BASE:
			return true
		if t == STEEL:
			return false
	return false


func _dir_to(a: Vector2, b: Vector2) -> int:
	var d := b - a
	if absf(d.x) > absf(d.y):
		return 1 if d.x > 0 else 3
	return 2 if d.y > 0 else 0


func _cost(v: int, is_goal: bool) -> float:
	if is_goal:
		return 1.0
	match v:
		EMPTY, BUSH, ICE:
			return 1.0
		MUD:
			return 2.5
		BRICK:
			return 4.0
	return 0.0


## Cells in the player's current line of fire. Enemies route around them instead of driving into the gun.
func _update_danger() -> void:
	danger.resize(N * N)
	danger.fill(0)
	if bool(player.get("dead", true)) or camo:
		return  # a hidden Khaki has no known line of fire: nobody drives around it
	var pp: Vector2 = player["p"]
	var c := Vector2i(int(floor(pp.x)), int(floor(pp.y)))
	var d: Vector2 = DIRS[int(player["d"])]
	for k in range(1, 10):
		var q := c + Vector2i(int(d.x) * k, int(d.y) * k)
		if q.x < 0 or q.y < 0 or q.x >= N or q.y >= N:
			break
		var v: int = tiles[q.y * N + q.x]
		if v == BRICK or v == STEEL or v == BASE:
			break
		danger[q.y * N + q.x] = 1


func _path_next(from: Vector2, goal: Vector2, avoid := false) -> Vector2i:
	var s := Vector2i(clampi(int(floor(from.x)), 0, N - 1), clampi(int(floor(from.y)), 0, N - 1))
	var g := Vector2i(clampi(int(floor(goal.x)), 0, N - 1), clampi(int(floor(goal.y)), 0, N - 1))
	if s == g:
		return s
	var cnt := N * N
	var dist := PackedFloat32Array()
	dist.resize(cnt)
	dist.fill(1e9)
	var prev := PackedInt32Array()
	prev.resize(cnt)
	prev.fill(-1)
	var done := PackedByteArray()
	done.resize(cnt)
	var si := s.y * N + s.x
	var gi := g.y * N + g.x
	dist[si] = 0.0
	var dx := [0, 1, 0, -1]
	var dy := [-1, 0, 1, 0]
	for it in cnt:
		var best := -1
		var bd := 1e9
		for i in cnt:
			if done[i] == 0 and dist[i] < bd:
				bd = dist[i]
				best = i
		if best < 0 or best == gi:
			break
		done[best] = 1
		var bx := best % N
		var by := int(best / float(N))
		for k in 4:
			var nx: int = bx + dx[k]
			var ny: int = by + dy[k]
			if nx < 0 or ny < 0 or nx >= N or ny >= N:
				continue
			var ni := ny * N + nx
			var c := _cost(int(tiles[ni]), ni == gi)
			if c <= 0.0:
				continue
			if avoid and danger.size() == cnt and danger[ni] == 1:
				c += 6.0
			if dist[best] + c < dist[ni]:
				dist[ni] = dist[best] + c
				prev[ni] = best
	if prev[gi] < 0:
		return Vector2i(-1, -1)
	var cur := gi
	while prev[cur] != si and prev[cur] >= 0:
		cur = prev[cur]
	return Vector2i(cur % N, int(cur / float(N)))


func _pick_ambush(e: Dictionary) -> Vector2:
	var best := Vector2(e["p"])
	var best_s := -99.0
	var pp: Vector2 = player["p"]
	for k in 28:
		var c := Vector2(rng.randi_range(0, N - 1) + 0.5, rng.randi_range(1, 10) + 0.5)
		var v := _tile_at(c)
		if v != EMPTY and v != BUSH and v != ICE:
			continue
		var sc := rng.randf()
		if v == BUSH:
			sc += 2.0
		if _los(c, pp):
			sc += 3.0
		if absf(c.x - GEN.x) < 0.35 or absf(c.y - pp.y) < 0.35:
			sc += 1.5
		if absf(c.x - GEN.x) < 0.35 and c.y > 5.0:
			sc += 2.0  # sniping lane down to the generator
		var d := c.distance_to(pp)
		if d > 3.0 and d < 9.0:
			sc += 1.0
		for o in enemies:
			if not is_same(o, e) and (o["p"] as Vector2).distance_to(c) < 2.0:
				sc -= 2.0
		if sc > best_s:
			best_s = sc
			best = c
	return best


## The super tank is on the field: it goes only for the generator, the small tanks become its escort and hunt the player.
func _boss_on_field() -> bool:
	for e in enemies:
		if int(e["type"]) == 5 and not bool(e.get("dead", false)):
			return true
	return false


## Escorts spread around the player (each on its own side), sneak up to that point, then close in together.
func _flank_goal(e: Dictionary, pp: Vector2) -> Vector2:
	var esc: Array = []
	for o in enemies:
		if int(o["type"]) != 5 and not bool(o.get("dead", false)):
			esc.append(int(o["id"]))
	esc.sort()
	var n := maxi(1, esc.size())
	var i := maxi(0, esc.find(int(e["id"])))
	var p: Vector2 = e["p"]
	if p.distance_to(pp) < 2.6 or bool(e.get("flank_done", false)):
		e["flank_done"] = p.distance_to(pp) < 6.0  # in position: close in; if the player got away, spread again
		return pp
	var ang := TAU * float(i) / float(n) + flank_phase
	for r: float in [3.0, 2.0, 4.0]:
		var c: Vector2 = pp + Vector2(cos(ang), sin(ang)) * r
		var cell := Vector2i(clampi(int(floor(c.x)), 0, N - 1), clampi(int(floor(c.y)), 0, N - 1))
		if _cost(int(tiles[cell.y * N + cell.x]), false) > 0.0:
			var goal := Vector2(cell) + Vector2(0.5, 0.5)
			if p.distance_to(goal) < 1.0:
				e["flank_done"] = true
			return goal
	return pp


func _update_goal(e: Dictionary) -> void:
	var alive := not bool(player["dead"]) and not camo
	var pp: Vector2 = _tgt()
	var p: Vector2 = e["p"]
	if str(e["role"]) == "breaker":
		e["goal"] = GEN
		return
	if alive and _boss_on_field():
		e["goal"] = _flank_goal(e, pp)  # escort: hunt the player from all sides while the super tank breaks the generator
		return
	if str(e["role"]) != "ambush" and not bool(e.get("siege", false)):
		for b in bonuses:
			if (b["p"] as Vector2).distance_to(p) < 5.0 and float(b["t"]) < 9.0:
				e["goal"] = b["p"]  # grab the pick-up before the player does
				return
	match str(e["role"]):
		"hunter":
			# Hunts the player only when close; otherwise heads for the generator like everyone else.
			e["goal"] = pp if alive and p.distance_to(pp) < 7.0 else GEN
		"flanker":
			if not e.has("wp"):
				var left := pp.x > N * 0.5 if alive else rng.randf() < 0.5
				e["wp"] = Vector2(1.5 if left else N - 1.5, 9.5)
			if not bool(e.get("wp_done", false)) and p.distance_to(e["wp"]) < 1.3:
				e["wp_done"] = true
			e["goal"] = GEN if bool(e.get("wp_done", false)) else e["wp"]
		"ambush":
			if float(e["amb_t"]) > 6.0 or not e.has("amb"):
				e["amb"] = _pick_ambush(e)
				e["amb_t"] = 0.0
			e["goal"] = e["amb"]
		_:
			e["goal"] = GEN

func _kill_enemy(e: Dictionary, src := "") -> void:
	e["dead"] = true
	killed += 1
	if st.has("k_" + src):
		st["k_" + src] = int(st["k_" + src]) + 1
	if src == "p" or src == "super" or src == "mine" or src == "flame":
		st["streak"] = int(st.get("streak", 0)) + 1
		st["best_streak"] = maxi(int(st.get("best_streak", 0)), int(st["streak"]))
	if int(e["type"]) == 5:
		st["boss"] = true
		if src == "p" or src == "super" or src == "mine" or src == "flame":
			st["boss_p"] = int(st.get("boss_p", 0)) + 1  # the player's own super tank kills: the Tanks leaderboard
	_boom(e["p"], true)
	if int(e["type"]) == 5:
		for k in 4:
			_boom(e["p"] + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)), false)
	if int(e["type"]) == 5 or bool(e.get("carrier", false)):
		_spawn_bonus()


func _damage_enemy(e: Dictionary, dmg: float, src := "", quiet := false) -> void:
	if bool(e.get("dead", false)):
		return
	if float(e["inv"]) > 0.0:
		if not quiet:
			_sfx("t_ricochet", rng.randf_range(0.9, 1.15))
		return
	if int(e["type"]) == 5 and float(e.get("heat", 0.0)) > 0.0 and dmg < 2.0:
		dmg *= 2.0
	e["hp"] = float(e["hp"]) - dmg
	e["hit"] = 0.15
	if float(e["hp"]) <= 0.001:
		_kill_enemy(e, src)
	elif not quiet:
		_sfx("t_hit", rng.randf_range(0.9, 1.1))


## Bonuses appear mostly on the player's half (rows BONUS_HOME_ROW and below), where they can really be picked up;
## now and then one appears further up as a risky prize.
func _spawn_bonus() -> void:
	var home := rng.randf() < BONUS_HOME_SHARE
	for attempt in 40:
		var c := Vector2(rng.randi_range(0, N - 1) + 0.5, rng.randi_range(BONUS_HOME_ROW if home else 1, N - 1 if home else 10) + 0.5)
		var v := _tile_at(c)
		if v != EMPTY and v != ICE:
			continue
		var near := false
		for t in _all_tanks():
			if (t["p"] as Vector2).distance_to(c) < 2.0:
				near = true
		if near:
			continue
		bonuses.append({"p": c, "k": BONUS_KINDS[rng.randi_range(0, BONUS_KINDS.size() - 1)], "t": 0.0})
		_sfx("coin", 1.4, -6.0)
		return


func _apply_bonus(k: String, who := "p") -> void:
	st["b_" + who] = int(st.get("b_" + who, 0)) + 1
	_sfx("coin", 1.0)
	match k:
		"repair":
			lives = mini(lives + 1, 6)
			gen_hp = mini(gen_hp + 1, GEN_MAX)
		"shield":
			player["inv"] = 6.0
		"freeze":
			freeze_t = 5.0
		"fort":
			fort_t = 12.0
			gen_hp = GEN_MAX
			fort_pending = FORT.duplicate()
			_fort_fill()
		"power", "rapid", "speed":
			buffs[k] = BUFF_TIME

## Steel around the generator, but never on a cell a tank stands on (it would be walled in); those cells
## are filled as soon as the tank drives off, while the fort lasts.
func _fort_fill() -> void:
	var left: Array = []
	for c in fort_pending:
		if _tank_on_cell(c):
			left.append(c)
		else:
			_set_tile(c.x, c.y, STEEL)
	fort_pending = left


func _tank_on_cell(c: Vector2i) -> bool:
	var cc := Vector2(c) + Vector2(0.5, 0.5)
	var tanks: Array = []
	if not bool(player["dead"]):
		tanks.append(player["p"])
	if _ally_alive():
		tanks.append(ally["p"])
	for e in enemies:
		if not bool(e.get("dead", false)):
			tanks.append(e["p"])
	for tp in tanks:
		var d: Vector2 = (tp as Vector2) - cc
		if absf(d.x) < 0.98 and absf(d.y) < 0.98:
			return true
	return false


func _enemy_bonus(e: Dictionary, k: String) -> void:
	_sfx("click", 0.3)
	match k:
		"repair":
			to_spawn += 1
			total_enemies += 1
		"shield":
			e["inv"] = 6.0
		"freeze":
			p_freeze = 4.0
		"fort":
			for c in FORT:
				if int(tiles[c.y * N + c.x]) == BRICK or int(tiles[c.y * N + c.x]) == STEEL:
					_set_tile(c.x, c.y, EMPTY)
		"power", "rapid", "speed":
			e["buff"] = k
			e["buff_t"] = BUFF_TIME


# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	delta = minf(delta, 0.05) * game_speed
	if paused:
		if engine_pl:
			engine_pl.volume_db = -60.0
		if tracks_pl:
			tracks_pl.volume_db = -60.0
		queue_redraw()
		return
	anim += delta
	for k in buffs.keys():
		buffs[k] = maxf(0.0, float(buffs[k]) - delta)
	if state == "play":
		_update_ally(delta)
	_update_engine(delta)
	for b in booms:
		b["t"] = float(b["t"]) + delta
	booms = booms.filter(func(b): return float(b["t"]) < (0.6 if bool(b["big"]) else 0.3))
	for x in trails:
		x["t"] = float(x["t"]) + delta
	trails = trails.filter(func(x): return float(x["t"]) < 0.35)
	_update_strikes(delta)
	if state != "play":
		var before := int(floor((end_t - REPORT_T0) / REPORT_ROW))
		end_t += delta
		var after := int(floor((end_t - REPORT_T0) / REPORT_ROW))
		if after > before and after >= 0 and after < report_rows().size() and delta < 0.2:
			_sfx("click", 1.0 + 0.05 * after, -8.0)
		queue_redraw()
		return
	st["time"] = float(st.get("time", 0.0)) + delta
	_update_player(delta)
	_update_spawns(delta)
	_update_enemies(delta)
	_update_bullets(delta)
	_update_mines(delta)
	if killed >= total_enemies and to_spawn <= 0 and spawns.is_empty() and enemies.is_empty():
		_finish(true)
	queue_redraw()


func _update_strikes(delta: float) -> void:
	for st in strikes:
		st["life"] = float(st["life"]) - delta
	strikes = strikes.filter(func(x): return float(x["life"]) > 0.0)
	if int(tiles[12 * N + 6]) != BASE:
		return
	var top := GEN + Vector2(0, -0.32)
	strike_t -= delta
	if strike_t <= 0.0:
		strike_t = rng.randf_range(0.12, 0.5)
		var ang := rng.randf_range(PI, TAU) if rng.randf() < 0.7 else rng.randf() * TAU
		var tgt := top + Vector2(cos(ang), sin(ang)) * rng.randf_range(0.7, 1.6)
		strikes.append({"a": top, "b": tgt, "seed": rng.randi(), "life": 0.14, "max": 0.14, "w": 0.8})
	if near_gen and super_charge < 1.0 and state == "play":
		beam_t -= delta
		if beam_t <= 0.0:
			beam_t = 0.07
			strikes.append({"a": top, "b": player["p"], "seed": rng.randi(), "life": 0.1, "max": 0.1, "w": 1.0})


func _update_player(delta: float) -> void:
	near_gen = not bool(player["dead"]) and (player["p"] as Vector2).distance_to(GEN) < 3.5 and int(tiles[12 * N + 6]) == BASE
	super_charge = minf(1.0, super_charge + delta / (super_time_near if near_gen else super_time))
	gen_hit = maxf(0.0, gen_hit - delta)
	p_freeze = maxf(0.0, p_freeze - delta)
	if fort_t > 0.0:
		fort_t -= delta
		_fort_fill()
		if fort_t <= 0.0:
			fort_pending.clear()
			for c in FORT:
				if int(tiles[c.y * N + c.x]) == STEEL:
					_set_tile(c.x, c.y, BRICK)
	for b in bonuses:
		b["t"] = float(b["t"]) + delta
		if not bool(player["dead"]) and (b["p"] as Vector2).distance_to(player["p"]) < 0.75:
			_apply_bonus(str(b["k"]))
			b["t"] = 99.0
	bonuses = bonuses.filter(func(b): return float(b["t"]) < 10.0)
	camo = not bool(player["dead"]) and ((perk == "khaki" and _tile_at(player["p"]) == BUSH) or ninja_t > 0.0)
	_update_perks(delta)
	_update_flame(delta)
	if bool(player["dead"]):
		player["rt"] = float(player["rt"]) - delta
		var sp = _respawn_point() if float(player["rt"]) <= 0.0 else null
		if sp != null:
			player["dead"] = false
			player["p"] = sp
			player["d"] = 0
			player["inv"] = 2.5
			player["slide"] = 0.0
			armor = armor_max
		return
	player["inv"] = float(player["inv"]) - delta
	player["cd"] = float(player["cd"]) - delta
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			_sfx("t_reload", rng.randf_range(0.95, 1.05), -8.0)
	if p_freeze > 0.0:
		return
	var dir := key_dir if key_dir >= 0 else move_dir
	if perk == "samurai":  # double tap the same direction: dash
		if dir < 0 and dash_dir >= 0 and dash_tap < 0.0:
			dash_tap = anim
		elif dir >= 0:
			if dash_tap >= 0.0 and dir == dash_dir and anim - dash_tap < 0.3 and dash_cd <= 0.0:
				_dash(dir)
			if dash_tap >= 0.0 and anim - dash_tap >= 0.0:
				dash_tap = -9.0
			dash_dir = dir
	var on_ice := _tile_at(player["p"]) == ICE and perk != "arctic"  # the Arctic grips the ice
	if on_ice and float(player["slide"]) > 0.0 and (dir < 0 or dir != int(player["d"])):
		if _move_tank(player, int(player["d"]), p_speed * 0.8, delta):
			player["slide"] = float(player["slide"]) - p_speed * delta
		else:
			player["slide"] = 0.0
	elif dir >= 0:
		_move_tank(player, dir, p_speed * (1.4 if float(buffs["speed"]) > 0.0 else 1.0), delta)
		player["slide"] = 0.7 if on_ice else 0.0
	if fire_held and float(player["cd"]) <= 0.0 and _bullet_count(player) < max_pb:
		_shoot(player, 0)
		player["cd"] = fire_cd * (0.5 if float(buffs["rapid"]) > 0.0 else 1.0)


## Inferno: while the flame button is held and there is fuel, burns everything in FLAME_LEN cells ahead:
## enemies take FLAME_DPS, enemy shells burn up, forest burns down. Walls stop the flame.
func flame_cells() -> Array:
	var out: Array = []
	var pp: Vector2 = player["p"]
	var d: Vector2 = DIRS[int(player["d"])]
	var k := 0.6
	while k <= FLAME_LEN:
		var q := pp + d * k
		var v := _tile_at(q)
		if v == BRICK or v == STEEL or v == BASE or q.x < 0.0 or q.y < 0.0 or q.x >= N or q.y >= N:
			break
		out.append(q)
		k += 0.5
	return out


func _update_flame(delta: float) -> void:
	flame_on = FLAMER and flame_held and fuel > 0.0 and not bool(player["dead"]) and p_freeze <= 0.0 and state == "play"
	if not flame_on:
		return
	fuel = maxf(0.0, fuel - delta)
	if fuel <= 0.0 and auto_refill.is_valid() and auto_refill.call():
		fuel = Data.FUEL_MAX
	var pts := flame_cells()
	for e in enemies:
		if bool(e.get("dead", false)):
			continue
		for q in pts:
			if (e["p"] as Vector2).distance_to(q) < 0.75:
				_damage_enemy(e, FLAME_DPS * delta, "flame", true)
				break
	for b in bullets:
		if int(b["o"]) == 1 and not bool(b.get("super", false)):
			for q in pts:
				if (b["p"] as Vector2).distance_to(q) < 0.5:
					b["dead"] = true
	for q in pts:
		var c := Vector2i(int(floor(q.x)), int(floor(q.y)))
		if int(tiles[c.y * N + c.x]) == BUSH and rng.randf() < delta * 1.5:
			_set_tile(c.x, c.y, EMPTY)
	enemies = enemies.filter(func(e): return not bool(e.get("dead", false)))


# ---------------------------------------------------------------- helper (hired in the shop)

## Where the player comes back: his usual spot, or - if an enemy stands on it - the free cell closest to it near the
## generator (enemies parking on the spawn point must never lock the player out of the battle).
func _respawn_point() -> Variant:
	if not _blocked(PLAYER_SPAWN, player):
		return PLAYER_SPAWN
	var best = null
	var best_d := 1e9
	for y in range(N - 1, 6, -1):
		for x in N:
			var c := Vector2(x + 0.5, y + 0.5)
			if _blocked(c, player):
				continue
			var near_enemy := false
			for e in enemies:
				if (e["p"] as Vector2).distance_to(c) < 2.0:
					near_enemy = true
			var d := c.distance_to(PLAYER_SPAWN) + (6.0 if near_enemy else 0.0)
			if d < best_d:
				best_d = d
				best = c
	return best


func _ally_alive() -> bool:
	return not ally.is_empty() and not bool(ally.get("dead", true))


func _spawn_ally() -> void:
	for c in [Vector2(8.5, 12.5), Vector2(8.5, 11.5), Vector2(9.5, 12.5), Vector2(3.5, 12.5), Vector2(4.5, 11.5)]:
		if not _blocked(c, null):
			ally = {"p": c, "d": 0, "cd": 0.5, "hp": ALLY_HP + ally_lvl, "tread": 0.0, "dead": false, "turn": 0.0,
				"next": Vector2i(-1, -1), "inv": 2.0, "hit": 0.0, "dodge": 0.0, "dodge_dir": -1}
			ally_used = true
			return

func _ally_hit() -> void:
	if float(ally["inv"]) > 0.0:
		return
	ally["hp"] = int(ally["hp"]) - 1
	ally["hit"] = 0.15
	ally["inv"] = 0.5
	if int(ally["hp"]) <= 0:
		ally["dead"] = true
		_boom(ally["p"], true)
	else:
		_sfx("t_armor", 1.1, -4.0)


## Helper AI. Priorities: dodge a shell flying at him -> shoot the visible enemy closest to the generator ->
## line up with the most dangerous enemy -> grab a nearby bonus -> stay near the generator.
## Upgrades (ally_lvl 0..3): +1 hp, faster, quicker fire, sees further; 2 shells from level 2.
func _update_ally(delta: float) -> void:
	if not _ally_alive():
		return
	ally["cd"] = float(ally["cd"]) - delta
	ally["inv"] = maxf(0.0, float(ally["inv"]) - delta)
	ally["hit"] = maxf(0.0, float(ally["hit"]) - delta)
	ally["dodge"] = maxf(0.0, float(ally["dodge"]) - delta)
	if freeze_t <= 0.0 and p_freeze > 0.0:
		return
	var speed := ALLY_SPEED + 0.3 * ally_lvl
	var reload := ALLY_RELOAD - 0.06 * ally_lvl
	var shells := 2 if ally_lvl >= 2 else 1
	var sight := ALLY_SIGHT + ally_lvl
	var ap: Vector2 = ally["p"]
	for b in bonuses:
		if (b["p"] as Vector2).distance_to(ap) < 0.7:
			_apply_bonus(str(b["k"]), "a")
			b["t"] = 99.0
	# 1) dodge: an enemy shell coming straight at him -> step aside
	if float(ally["dodge"]) > 0.0 and int(ally["dodge_dir"]) >= 0:
		_move_tank(ally, int(ally["dodge_dir"]), speed, delta)
		return
	for b in bullets:
		if int(b["o"]) != 1 or bool(b["dead"]):
			continue
		var bp: Vector2 = b["p"]
		var bd: int = b["d"]
		var to := ap - bp
		if bp.distance_to(ap) < 3.0 and to.normalized().dot(DIRS[bd]) > 0.9:
			for side in [1, 3] if bd % 2 == 0 else [0, 2]:
				if not _blocked(ap + DIRS[side] * 0.6, ally):
					ally["dodge"] = 0.35
					ally["dodge_dir"] = side
					break
			if float(ally["dodge"]) > 0.0:
				return
	# 2) shoot: of the enemies he can see, the one closest to the generator (the boss first)
	var target = null
	var best := 999.0
	var hunt = null
	var hunt_d := 99.0
	for e in enemies:
		if bool(e.get("dead", false)):
			continue
		var ep: Vector2 = e["p"]
		var dg := ep.distance_to(GEN) - (4.0 if int(e["type"]) == 5 else 0.0)
		if ap.distance_to(ep) < sight and _los(ap, ep) and dg < best:
			best = dg
			target = e
		if dg < hunt_d:
			hunt_d = dg
			hunt = e
	if target != null:
		ally["d"] = _dir_to(ap, target["p"])
		if float(ally["cd"]) <= 0.0 and _bullet_count(ally) < shells:
			_shoot(ally, 2)
			ally["cd"] = reload
		return
	# 3) line up with the most dangerous enemy (same column or row), 4) a bonus on our half, 5) guard
	var goal := GEN + Vector2(0, -2.0)
	if hunt != null and hunt_d < 8.0:
		var hp: Vector2 = hunt["p"]
		var col := Vector2(hp.x, clampf(maxf(hp.y + 2.0, ap.y), 1.5, 10.5))
		var row := Vector2(clampf(ap.x, 0.5, 12.5), hp.y)
		goal = col if ap.distance_to(col) <= ap.distance_to(row) else row
	else:
		var bb := 4.0
		for b in bonuses:
			var bp2: Vector2 = b["p"]
			if bp2.y >= BONUS_HOME_ROW and bp2.distance_to(ap) < bb:
				bb = bp2.distance_to(ap)
				goal = bp2
	ally["turn"] = float(ally["turn"]) - delta
	if float(ally["turn"]) <= 0.0:
		ally["turn"] = 0.25
		ally["next"] = _path_next(ap, goal)
	var nx: Vector2i = ally["next"]
	if nx.x < 0:
		return
	var dv := Vector2(nx) + Vector2(0.5, 0.5) - ap
	var dir := -1
	if absf(dv.x) > 0.06:
		dir = 1 if dv.x > 0 else 3
	elif absf(dv.y) > 0.06:
		dir = 2 if dv.y > 0 else 0
	if dir < 0:
		ally["turn"] = 0.0
		return
	if int(tiles[nx.y * N + nx.x]) == BRICK:
		ally["d"] = dir
		if float(ally["cd"]) <= 0.0 and _bullet_count(ally) < shells:
			_shoot(ally, 2)
			ally["cd"] = reload
		return
	_move_tank(ally, dir, speed, delta)

func _update_spawns(delta: float) -> void:
	spawn_timer -= delta
	# The boss comes in with the last BOSS_ESCORT tanks: they enter right behind him, even over the usual limit.
	var escort := boss_out and to_spawn <= BOSS_ESCORT
	if spawn_timer <= 0.0 and to_spawn > 0 and (enemies.size() + spawns.size() < max_active or escort):
		var pts := [Vector2(0.5, 0.5), Vector2(6.5, 0.5), Vector2(12.5, 0.5)]
		var start := rng.randi_range(0, 2)
		for k in 3:
			var pt: Vector2 = pts[(start + k) % 3]
			var busy := false
			for s in spawns:
				if (s["p"] as Vector2).distance_to(pt) < 0.5:
					busy = true
			if not bool(player.get("dead", false)) and (player["p"] as Vector2).distance_to(pt) < SPAWN_SAFE_DIST:
				busy = true  # no spawning into a camping player's gun
			if not busy and not _blocked(pt, null):
				var is_boss := not boss_out and to_spawn <= mini(BOSS_ESCORT + 1, total_enemies)
				spawns.append({"p": pt, "t": 0.0, "type": _enemy_type(is_boss)})
				to_spawn -= 1
				if is_boss:
					boss_out = true
				spawn_timer = 0.5 if boss_out and to_spawn <= BOSS_ESCORT else maxf(1.2 - 0.5 * hard, 2.6 - elvl * 0.15 - hard)
				break
	for s in spawns:
		s["t"] = float(s["t"]) + delta
	var ready: Array = []
	for s in spawns:
		if float(s["t"]) >= 0.8 and not _blocked(s["p"], null):
			ready.append(s)
	for s in ready:
		spawns.erase(s)
		var ty: int = s["type"]
		var hp: int = E_HP[ty] + (elvl * 3 + int(hard * 15.0) if ty == 5 else 0) + (1 if ty == 2 and hard > 0.5 else 0)
		next_id += 1
		if ty == 5:
			super_charge = 1.0
			boss_msg_t = 3.5
		var role := "hunter"
		# Every enemy's mission is the generator; roles only change the route and who they engage.
		match ty:
			0:
				role = "hunter" if rng.randf() < 0.25 else "raider"
			1:
				role = "flanker"
			2:
				role = "raider"
			3:
				role = "ambush"
			4:
				role = "flanker" if rng.randf() < 0.5 else "raider"
			5:
				role = "breaker"  # the boss has one mission: break the generator, whatever happens around him
		enemies.append({"id": next_id, "p": s["p"], "d": 2, "type": ty, "hp": hp, "maxhp": hp, "role": role, "goal": GEN,
			"next": Vector2i(-1, -1), "turn": 0.0, "shoot": rng.randf_range(0.6, 1.4), "react": 0.0, "aim": 0.0,
			"amb_t": 0.0, "stuck": 0.0, "unstick_t": 0.0, "unstick_dir": 0, "dodge_t": 0.0, "dodge_dir": 0,
			"inv": SPAWN_SHIELD, "sup_t": 4.0, "tread": 0.0, "hit": 0.0, "probe": rng.randf_range(0.8, 2.0),
			"carrier": ty != 5 and rng.randf() < 0.22, "buff": "", "buff_t": 0.0})


func _update_enemies(delta: float) -> void:
	freeze_t = maxf(0.0, freeze_t - delta)
	_update_danger()
	var pp: Vector2 = _tgt()
	var alive := not bool(player["dead"]) and not camo  # enemies cannot see a Khaki hiding in the forest
	for e in enemies:
		var ty: int = e["type"]
		e["hit"] = maxf(0.0, float(e["hit"]) - delta)
		e["inv"] = maxf(0.0, float(e["inv"]) - delta)
		e["slow"] = maxf(0.0, float(e.get("slow", 0.0)) - delta)
		if float(e.get("burn", 0.0)) > 0.0:  # Inferno: burning
			e["burn"] = float(e["burn"]) - delta
			e["burn_dt"] = float(e.get("burn_dt", 0.0)) + delta
			if float(e["burn_dt"]) >= 0.5:
				e["burn_dt"] = 0.0
				_damage_enemy(e, 0.34, "p", true)
				if bool(e.get("dead", false)):
					continue
		if float(e.get("frz", 0.0)) > 0.0:  # Arctic: frozen solid
			e["frz"] = float(e["frz"]) - delta
			continue
		if freeze_t > 0.0 and (ty != 5 or freeze_t > 2.5):
			continue
		var spd: float = E_SPEED[ty] * (1.0 + 0.06 * elvl + 0.15 * hard)
		if float(e.get("buff_t", 0.0)) > 0.0:
			e["buff_t"] = float(e["buff_t"]) - delta
			if str(e["buff"]) == "speed":
				spd *= 1.4
		else:
			e["buff"] = ""
		if ty == 5:
			e["heat"] = maxf(0.0, float(e.get("heat", 0.0)) - delta)
			if float(e.get("charge", 0.0)) > 0.0:
				e["charge"] = float(e["charge"]) - delta
				if float(e["charge"]) <= 0.0:
					_super_shot(e, 1)
					e["sup_t"] = maxf(4.0, 7.0 - elvl * 0.4)
					e["heat"] = 3.0
				continue
			if float(e["heat"]) > 0.0:
				spd *= 0.5
				e["shoot"] = maxf(float(e["shoot"]), 0.3)
		var cd_scale := (1.0 + 0.12 * elvl + 0.35 * hard) * (2.0 if str(e.get("buff", "")) == "rapid" else 1.0)
		e["shoot"] = float(e["shoot"]) - delta
		e["react"] = float(e["react"]) - delta
		e["sup_t"] = float(e["sup_t"]) - delta
		var p: Vector2 = e["p"]
		# pick up bonuses
		for b in bonuses:
			if (b["p"] as Vector2).distance_to(p) < 0.7:
				_enemy_bonus(e, str(b["k"]))
				b["t"] = 99.0
		var max_b := 2 if ty == 5 else 1
		# --- combat: the generator is the mission; the player is a target only when he is a threat or in the way
		var role := str(e["role"])
		var dist_p := p.distance_to(pp)
		var see_p := alive and _los(p, pp)
		var facing_me := alive and int(player["d"]) == _dir_to(pp, p) and dist_p < 9.0
		var threat := see_p and (dist_p < 7.0 or role == "hunter" or facing_me or role == "ambush" or ty == 3)
		var gen_dir := _gen_line(p)
		var tdir := -1
		var at_gen := false
		var ally_near := _ally_alive() and _los(p, ally["p"]) and p.distance_to(ally["p"]) < 5.0
		var escort := role != "breaker" and alive and _boss_on_field()
		if role == "breaker":
			# The super tank ignores everything and shells only the generator.
			threat = false
			ally_near = false
		elif escort:
			# Escorts hunt only the player: no generator shelling, no wingman duels.
			threat = see_p
			ally_near = false
			gen_dir = -1
		if threat:
			tdir = _dir_to(p, pp)
		elif ally_near:
			tdir = _dir_to(p, ally["p"])
			threat = true
		elif gen_dir >= 0:
			tdir = gen_dir
			at_gen = true
		if ty == 4 and threat and see_p and dist_p < 6.0 and float(e.get("ram_cd", 0.0)) <= 0.0:
			e["ram_t"] = 1.2  # Raider: charges straight at the player
			e["ram_cd"] = 5.0
			e["ram_d"] = _dir_to(p, pp)
		e["ram_cd"] = float(e.get("ram_cd", 0.0)) - delta
		if float(e.get("ram_t", 0.0)) > 0.0:
			e["ram_t"] = float(e["ram_t"]) - delta
			e["d"] = int(e["ram_d"])
			if not _move_tank(e, int(e["ram_d"]), spd * 2.3, delta):
				e["ram_t"] = 0.0
			if alive and (e["p"] as Vector2).distance_to(player["p"]) < 1.0 and float(player["inv"]) <= 0.0:
				e["ram_t"] = 0.0
				_player_hit()
			continue
		if tdir >= 0:
			if int(e["d"]) != tdir:
				e["d"] = tdir
				e["react"] = maxf(float(e["react"]), 0.3 - 0.03 * elvl)
			if ty == 3:
				e["aim"] = float(e["aim"]) + delta
				e["amb_t"] = 0.0
				if float(e["aim"]) > 0.5 and _bullet_count(e) < max_b:
					_shoot(e, 1)
					e["aim"] = 0.0
				continue
			if ty == 5 and float(e["sup_t"]) <= 0.0:
				e["charge"] = 1.2
				_sfx("t_charge")
				continue
			elif float(e["react"]) <= 0.0 and float(e["shoot"]) <= 0.0 and _bullet_count(e) < max_b:
				_shoot(e, 1)
				var cd := rng.randf_range(0.55, 0.9) if ty == 5 else rng.randf_range(0.5, 1.0)
				if at_gen:
					cd = rng.randf_range(1.6, 2.4) + maxf(0.0, 1.0 - elvl * 0.25)  # shelling is slower than a duel
				e["shoot"] = cd / cd_scale
			# Heavy tanks stand and duel; up to two tanks lined up on the generator stay to shell it.
			if threat and dist_p < 4.0 and ty == 2:
				continue
			if at_gen and p.distance_to(GEN) < 6.5 and (role == "breaker" or bool(e.get("siege", false)) or _siegers() < (1 if elvl < 2 else 2)):
				e["siege"] = true
				continue
			e["siege"] = false
		else:
			e["siege"] = false
			e["aim"] = 0.0
			# Suppressive / probing fire while advancing: break walls ahead, shake out hidden players.
			e["probe"] = float(e.get("probe", 1.0)) - delta
			if float(e["probe"]) <= 0.0 and _bullet_count(e) < max_b and float(e["shoot"]) <= 0.0:
				e["probe"] = rng.randf_range(1.0, 2.2) / cd_scale
				if _brick_ahead(p, int(e["d"]), 6) or (role != "breaker" and rng.randf() < 0.45):
					_shoot(e, 1)
					e["shoot"] = 0.5 / cd_scale
		# --- dodge incoming player bullets
		if float(e["dodge_t"]) <= 0.0:
			for b in bullets:
				if int(b["o"]) != 0 or bool(b.get("chk", false)):
					continue
				var bd: Vector2 = DIRS[int(b["d"])]
				var rel: Vector2 = p - (b["p"] as Vector2)
				var along := rel.dot(bd)
				var side := absf(rel.dot(Vector2(-bd.y, bd.x)))
				if along > 0.0 and along < 3.5 and side < 0.6:
					b["chk"] = true
					if ty != 5 and rng.randf() < (0.6 if ty == 1 else 0.35 + 0.07 * elvl):
						var pd := (int(b["d"]) + (1 if rng.randf() < 0.5 else 3)) % 4
						if _blocked(p + DIRS[pd] * 0.3, e):
							pd = (pd + 2) % 4
						e["dodge_t"] = 0.35
						e["dodge_dir"] = pd
		if float(e["dodge_t"]) > 0.0:
			e["dodge_t"] = float(e["dodge_t"]) - delta
			_move_tank(e, int(e["dodge_dir"]), spd * 1.25, delta)
			continue
		if float(e["unstick_t"]) > 0.0:
			e["unstick_t"] = float(e["unstick_t"]) - delta
			if not _move_tank(e, int(e["unstick_dir"]), spd, delta):
				e["unstick_dir"] = rng.randi_range(0, 3)
			continue
		# --- navigation
		e["turn"] = float(e["turn"]) - delta
		if float(e["turn"]) <= 0.0:
			e["turn"] = rng.randf_range(0.4, 0.65)
			_update_goal(e)
			# the super tank bulldozes to the generator; escorts and hunters do not shy away from the gun either
			e["next"] = _path_next(p, e["goal"], str(e["role"]) != "hunter" and ty != 2 and ty != 5 and not _boss_on_field())
		var nx: Vector2i = e["next"]
		if nx.x < 0:
			e["unstick_t"] = 0.5
			e["unstick_dir"] = rng.randi_range(0, 3)
			continue
		var c := Vector2(nx) + Vector2(0.5, 0.5)
		var dv := c - p
		var dir := -1
		if absf(dv.x) > 0.06:
			dir = 1 if dv.x > 0 else 3
		elif absf(dv.y) > 0.06:
			dir = 2 if dv.y > 0 else 0
		if dir < 0:
			if str(e["role"]) == "ambush" and c.distance_to(e["goal"]) < 0.1:
				e["amb_t"] = float(e["amb_t"]) + delta
				if alive:
					e["d"] = _dir_to(p, pp)
			else:
				e["turn"] = 0.0
			continue
		var tv := int(tiles[nx.y * N + nx.x])
		var aligned := absf(dv.x) < 0.1 if dir % 2 == 0 else absf(dv.y) < 0.1
		if (tv == BRICK or tv == BASE) and aligned:
			e["d"] = dir
			if float(e["shoot"]) <= 0.0 and _bullet_count(e) < max_b:
				_shoot(e, 1)
				e["shoot"] = 0.55 / cd_scale
			continue
		if _move_tank(e, dir, spd, delta):
			e["stuck"] = 0.0
		else:
			e["stuck"] = float(e["stuck"]) + delta
			if float(e["stuck"]) > 0.5:
				e["stuck"] = 0.0
				e["unstick_t"] = 0.5
				e["unstick_dir"] = (dir + (1 if rng.randf() < 0.5 else 3)) % 4
	bonuses = bonuses.filter(func(b): return float(b["t"]) < 10.0)


func _hit_tile(tx: int, ty: int, owner: int, dmg := 1) -> bool:
	if tx < 0 or ty < 0 or tx >= N or ty >= N:
		return true
	var idx := ty * N + tx
	match int(tiles[idx]):
		BRICK:
			brick_hp[idx] = int(brick_hp[idx]) - dmg
			brick_hits[idx] = int(brick_hits[idx]) + 1
			if int(brick_hp[idx]) <= 0:
				tiles[idx] = EMPTY
				mat[idx] = 0
				if owner == 0:
					st["walls"] = int(st.get("walls", 0)) + 1
			if owner == 0:
				_sfx("t_brick", rng.randf_range(0.9, 1.15))
			return true
		STEEL:
			if owner == 0:
				_sfx("t_ricochet", rng.randf_range(0.85, 1.2))
			return true
		BASE:
			if owner == 2:
				return true  # the helper is careful around the generator
			if owner == 0 and gen_hit <= 0.0:
				gen_own_hits += 1
			_damage_gen()  # friendly fire counts: shooting your own generator hurts it
			return true
	return false


func _damage_gen() -> void:
	if gen_hit > 0.0:
		return
	gen_hp -= 1
	st["gen_lost"] = int(st.get("gen_lost", 0)) + 1
	gen_hit = maxf(2.5, 4.5 - elvl * 0.5)  # pause between generator hits: time to come back and defend
	_boom(GEN + Vector2(0, -0.3), false)
	_vibe(50)
	if gen_hp <= 0:
		tiles[12 * N + 6] = EMPTY
		_boom(GEN, true)
		_finish(false)


func _update_bullets(delta: float) -> void:
	for b in bullets:
		if bool(b["dead"]):
			continue
		if b.has("ttl"):  # Dragon shards fly a short way
			b["ttl"] = float(b["ttl"]) - delta
			if float(b["ttl"]) <= 0.0:
				b["dead"] = true
				continue
		var d: int = b["d"]
		var p: Vector2 = b["p"] + DIRS[d] * float(b["sp"]) * delta
		b["p"] = p
		if p.x < 0.0 or p.y < 0.0 or p.x >= N or p.y >= N:
			b["dead"] = true
			_boom(p.clamp(Vector2.ZERO, Vector2(N, N)), false)
			continue
		if bool(b.get("super", false)):
			_super_step(b, p, d)
			continue
		var perp: Vector2 = DIRS[(d + 1) % 4] * 0.22
		var hit := false
		var seen := {}
		for q in [p + perp, p - perp]:
			var cell := Vector2i(int(floor(q.x)), int(floor(q.y)))
			if seen.has(cell):
				continue
			seen[cell] = true
			if cell.x >= 0 and cell.y >= 0 and cell.x < N and cell.y < N:
				var tv := int(tiles[cell.y * N + cell.x])
				if _solid(tv) and tv != WATER:
					if tv == STEEL and int(b.get("bounce", 0)) > 0:  # Ricochet: back the way it came
						b["bounce"] = 0
						b["d"] = (d + 2) % 4
						b["p"] = p - DIRS[d] * 0.3
						b["o"] = 0
						_sfx("t_ricochet", 1.3)
						hit = false
						break
					_hit_tile(cell.x, cell.y, int(b["o"]), maxi(1, int(round(float(b.get("dmg", 1))))))
					if tv == BRICK and int(b.get("pierce", 0)) > 0 and int(tiles[cell.y * N + cell.x]) == EMPTY:
						b["pierce"] = 0  # Tiger: the wall is gone, the shell flies on
						continue
					if tv == BRICK and int(b.get("pierce", 0)) > 0:
						b["pierce"] = 0
						_set_tile(cell.x, cell.y, EMPTY)
						continue
					hit = true
		if hit:
			b["dead"] = true
			_boom(p, bool(b.get("blast", false)))
			_shell_end(b, p, d)
			continue
		if int(b["o"]) != 1:
			for e in enemies:
				if bool(e.get("dead", false)):
					continue
				var q: Vector2 = e["p"]
				if absf(q.x - p.x) < HALF + 0.08 and absf(q.y - p.y) < HALF + 0.08:
					b["dead"] = true
					if int(b["o"]) == 0:
						st["hits"] = int(st.get("hits", 0)) + 1
						if bool(b.get("laser", false)):
							e["inv"] = 0.0  # the laser burns through a fresh spawn shield
					var dm := float(b.get("dmg", 1))
					if bool(b.get("dark", false)):
						dm = dm * SHELL_BOOST * 5.0 if int(e["type"]) == 5 else 99.0
						e["inv"] = 0.0
					if int(e["type"]) == 2 and int(e["d"]) == (d + 2) % 4 and not bool(b.get("dark", false)):
						dm *= 0.5  # Heavy: thick front armor, hit it from the side
					if bool(b.get("pan", false)) and not bool(e.get("pan_hit", false)):
						e["pan_hit"] = true
						dm *= 2.0
					_damage_enemy(e, dm, "p" if int(b["o"]) == 0 else "a")
					_shell_hit(b, e)
					_shell_end(b, p, d)
					break
		else:
			if not decoy.is_empty() and (decoy["p"] as Vector2).distance_to(p) < HALF + 0.1:
				b["dead"] = true  # Mirage: the hologram swallows the shell
				_boom(p, false)
				continue
			if shield_on and not bool(player["dead"]) and (player["p"] as Vector2).distance_to(p) < HALF + 0.2:
				b["dead"] = true  # Guardian: the shield takes this one
				shield_on = false
				shield_t = SHIELD_S
				_sfx("t_armor", 1.3)
				_boom(p, false)
				continue
			if not bool(player["dead"]):
				var q: Vector2 = player["p"]
				if absf(q.x - p.x) < HALF + 0.05 and absf(q.y - p.y) < HALF + 0.05:
					b["dead"] = true
					if float(player["inv"]) <= 0.0:
						_player_hit()
			if not bool(b["dead"]) and _ally_alive():
				var qa: Vector2 = ally["p"]
				if absf(qa.x - p.x) < HALF + 0.05 and absf(qa.y - p.y) < HALF + 0.05:
					b["dead"] = true
					_ally_hit()
		if not bool(b["dead"]):
			for o in bullets:
				if not is_same(o, b) and not bool(o["dead"]) and _side(int(o["o"])) != _side(int(b["o"])) and not bool(o.get("super", false)) \
						and (o["p"] as Vector2).distance_to(p) < 0.35:
					if bool(b.get("laser", false)):
						o["dead"] = true  # the laser melts the shell and flies on
					elif bool(o.get("laser", false)):
						b["dead"] = true
					else:
						o["dead"] = true
						b["dead"] = true
					_boom(p, false)
	bullets = bullets.filter(func(b): return not bool(b["dead"]))
	enemies = enemies.filter(func(e): return not bool(e.get("dead", false)))


func _super_step(b: Dictionary, p: Vector2, d: int) -> void:
	trails.append({"p": p, "t": 0.0, "o": int(b["o"])})
	var hits: Dictionary = b["hits"]
	var sperp: Vector2 = DIRS[(d + 1) % 4] * 0.42
	for q in [p, p + sperp, p - sperp]:
		var qx := int(floor(q.x))
		var qy := int(floor(q.y))
		if qx >= 0 and qy >= 0 and qx < N and qy < N:
			var tv: int = tiles[qy * N + qx]
			if tv == BRICK or tv == BUSH or (tv == STEEL and int(b["o"]) == 0):
				_set_tile(qx, qy, EMPTY)
			elif tv == BASE and not hits.has("gen"):
				hits["gen"] = true
				_damage_gen()
	if int(b["o"]) == 0:
		for e in enemies:
			var q: Vector2 = e["p"]
			var eid := int(e.get("id", 0))
			if not hits.has(eid) and absf(q.x - p.x) < HALF + 0.4 and absf(q.y - p.y) < HALF + 0.4:
				hits[eid] = true
				if int(e["type"]) == 5:
					e["inv"] = 0.0
					_damage_enemy(e, BOSS_SUPER_DMG, "super")
				else:
					e["inv"] = 0.0
					_damage_enemy(e, 99, "super")
		for o in bullets:
			if int(o["o"]) == 1 and not bool(o.get("super", false)) and (o["p"] as Vector2).distance_to(p) < 0.6:
				o["dead"] = true
	elif not bool(player["dead"]) and not hits.has("p"):
		var q: Vector2 = player["p"]
		if absf(q.x - p.x) < HALF + 0.35 and absf(q.y - p.y) < HALF + 0.35:
			hits["p"] = true
			if float(player["inv"]) <= 0.0:
				_player_hit()


func _update_mines(delta: float) -> void:
	for m in mines:
		m["arm"] = float(m["arm"]) - delta
		if float(m["arm"]) > 0.0:
			continue
		for e in enemies:
			if (e["p"] as Vector2).distance_to(m["p"]) < 0.6:
				m["gone"] = true
				_boom(m["p"], true)
				e["inv"] = 0.0
				_damage_enemy(e, 3, "mine")
				break
	mines = mines.filter(func(m): return not bool(m.get("gone", false)))
	enemies = enemies.filter(func(e): return not bool(e.get("dead", false)))


func _player_hit() -> void:
	if armor > 0:
		armor -= 1
		st["saves"] = int(st.get("saves", 0)) + 1
		player["inv"] = 0.6
		_boom(player["p"], false)
		_sfx("t_armor")
		return
	lives -= 1
	st["deaths"] = int(st.get("deaths", 0)) + 1
	st["streak"] = 0
	_boom(player["p"], true)
	_vibe(80)
	player["dead"] = true
	if lives <= 0:
		_finish(false)
		return
	player["rt"] = 1.0


func _finish(win: bool) -> void:
	if state != "play":
		return
	state = "won" if win else "lost"
	end_t = 0.0
	new_record = win and track_best and (best_time <= 0.0 or float(st.get("time", 0.0)) < best_time)
	_sfx("win" if win else "gameover", 1.0)


# ---------------------------------------------------------------- input

func _joy(pos: Vector2) -> void:
	var v := pos - joy_base
	if v.length() > pad_r:
		joy_base = pos - v.normalized() * pad_r
		v = pos - joy_base
	joy_knob = joy_base + v
	if v.length() < pad_r * 0.22:
		move_dir = -1
	elif absf(v.x) > absf(v.y):
		move_dir = 1 if v.x > 0 else 3
	else:
		move_dir = 2 if v.y > 0 else 0


## Pause (button, Android back, app going to the background). Leaving a battle counts as a loss.
func pause() -> void:
	if state == "play":
		paused = true
		fire_held = false
		flame_held = false
		move_dir = -1
		key_dir = -1


func _input(event: InputEvent) -> void:
	if paused:
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			var pp := (event as InputEventScreenTouch).position
			if pz_go.has_point(pp):
				_sfx("click", 1.0)
				paused = false
			elif pz_exit.has_point(pp):
				_sfx("click", 1.0)
				paused = false
				state = "lost"
				finished.emit(false)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed and state == "play" and e.position.distance_to(pause_c) < 34 * u:
			pause()
			return
		if e.pressed:
			if state != "play":
				if end_t < report_done_t():
					end_t = report_done_t()  # a tap skips the counting
				elif btn_rect.has_point(e.position):
					_sfx("click", 1.0)
					finished.emit(state == "won")
			elif e.position.distance_to(super_c) < super_r * 1.2:
				_fire_super()
			elif FLAMER and e.position.distance_to(flame_c) < flame_r * 1.3:
				flame_finger = e.index
				flame_held = true
			elif e.position.distance_to(mine_c) < mine_r * 1.3:
				_drop_mine()
			elif e.position.distance_to(fire_c) < fire_r * 1.3:
				fire_finger = e.index
				fire_held = true
			elif e.position.x < view.x * 0.5 and joy_finger == -1:
				joy_finger = e.index
				joy_base = e.position
				joy_knob = e.position
				move_dir = -1
		else:
			if e.index == fire_finger:
				fire_finger = -1
				fire_held = false
			if e.index == flame_finger:
				flame_finger = -1
				flame_held = false
			if e.index == joy_finger:
				joy_finger = -1
				move_dir = -1
	elif event is InputEventScreenDrag:
		var dr := event as InputEventScreenDrag
		if dr.index == joy_finger:
			_joy(dr.position)
	elif event is InputEventKey:
		var k := event as InputEventKey
		var map := {KEY_UP: 0, KEY_RIGHT: 1, KEY_DOWN: 2, KEY_LEFT: 3}
		if map.has(k.keycode):
			if k.pressed:
				key_dir = map[k.keycode]
			elif key_dir == map[k.keycode]:
				key_dir = -1
		elif k.keycode == KEY_SPACE:
			fire_held = k.pressed
		elif k.keycode == KEY_X and k.pressed:
			_fire_super()
		elif k.keycode == KEY_M and k.pressed:
			_drop_mine()
		elif k.keycode == KEY_F:
			flame_held = k.pressed
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- drawing

func _cell(x: int, y: int) -> Rect2:
	return Rect2(origin + Vector2(x, y) * ts, Vector2(ts, ts))


func _txt(s: String, cx: float, y: float, size: int, col: Color) -> void:
	var w := view.x * 2.0
	draw_string_outline(font, Vector2(cx - w * 0.5, y), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, int(size * 0.18), Color(0, 0, 0, col.a))
	draw_string(font, Vector2(cx - w * 0.5, y), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


func _draw() -> void:
	# backdrop in two parts: the plain top stretches over the field area, the painted control panel (bottom of
	# the picture) is fitted exactly under the joystick and the buttons
	var cut := 1140.0 / 1536.0 * UI_BG.get_height()
	var deck_top := deck_y
	draw_texture_rect_region(UI_BG, Rect2(0, 0, view.x, deck_top), Rect2(0, 0, UI_BG.get_width(), cut))
	draw_texture_rect_region(UI_BG, Rect2(0, deck_top, view.x, view.y - deck_top), Rect2(0, cut, UI_BG.get_width(), UI_BG.get_height() - cut))
	_draw_hud()
	var ar := Rect2(origin, Vector2(N, N) * ts)
	draw_rect(ar.grow(6 * u), arena["frame"])
	draw_rect(ar, arena["bg"])
	# ground texture tinted for the arena, then scorch marks
	var gt := TankArt.item(str(arena.get("ground", "ground_1")))
	if gt:
		draw_texture_rect(gt, ar, true, arena.get("floor", Color(0.55, 0.5, 0.45)))
		if arena.has("haze"):
			draw_rect(ar, arena["haze"])  # snow cover and the like over the ground
	for dc in decals:
		var dp := origin + (dc["p"] as Vector2) * ts
		draw_set_transform(dp, float(dc["r"]), Vector2.ONE)
		draw_texture_rect(FX_SCORCH, Rect2(-Vector2(ts, ts) * 0.8, Vector2(ts, ts) * 1.6), false, Color(1, 1, 1, 0.85))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for dc in decals:  # a fresh crater keeps burning for a few seconds
		var age := anim - float(dc.get("t", -99.0))
		if age < 0.0 or age > 7.0:
			continue
		var fa := 1.0 - clampf((age - 5.0) / 2.0, 0.0, 1.0)
		for j in 3:
			var off := Vector2([-0.22, 0.2, 0.0][j], [0.1, 0.05, -0.18][j]) * ts
			var fs := ts * 0.42 * (0.8 + 0.2 * sin(anim * 14.0 + j * 2.1))
			var p := origin + (dc["p"] as Vector2) * ts + off
			draw_texture_rect(FX_FIRE, Rect2(p - Vector2(fs * 0.5, fs * 0.9), Vector2(fs, fs)), false, Color(1, 1, 1, fa))
	# tread prints: fresh ones are clear, then they fade out over 25 s
	for tr in tracks:
		var ta := 0.42 * (1.0 - clampf((anim - float(tr["t"])) / 25.0, 0.0, 1.0))
		if ta <= 0.01:
			continue
		draw_set_transform(origin + (tr["p"] as Vector2) * ts, int(tr["d"]) * PI * 0.5, Vector2.ONE)
		draw_texture_rect(FX_TRACKS, Rect2(-ts * 0.62, -ts * 0.17, ts * 1.24, ts * 0.34), false, Color(1, 1, 1, ta))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for y in N:
		for x in N:
			var v: int = tiles[y * N + x]
			if v != EMPTY and v != BUSH:
				_draw_tile(x, y, v)
	for m in mines:
		var c := origin + (m["p"] as Vector2) * ts
		var lit := float(m["arm"]) <= 0.0 and int(anim * 3.0) % 2 == 0
		var mw := ts * 0.66
		var mh := mw * UI_MINE.get_height() / UI_MINE.get_width()
		draw_texture_rect(UI_MINE, Rect2(c - Vector2(mw, mh) * 0.5, Vector2(mw, mh)), false, Color.WHITE if lit else Color(0.65, 0.65, 0.7))
	for s in spawns:
		var k := float(s["t"]) / 0.8
		var c := origin + (s["p"] as Vector2) * ts
		_star(c, ts * (0.2 + 0.25 * absf(sin(k * PI * 3.0))), Color(1, 1, 1, 0.9))
	for e in enemies:
		var ty := int(e["type"])
		var mod := Color.WHITE
		if float(e["hit"]) > 0.0:
			mod = HIT_FLASH
		elif (freeze_t > 0.0 and ty != 5) or float(e.get("frz", 0.0)) > 0.0:
			mod = FROZEN
		elif float(e.get("slow", 0.0)) > 0.0:
			mod = Color(0.75, 0.9, 1.3)
		if bool(e.get("carrier", false)) and float(e["hit"]) <= 0.0:
			mod = mod.lerp(Color(1.6, 0.55, 0.5), 0.25 + 0.45 * absf(sin(anim * 6.0)))  # flashing = drops a bonus
		var esc := 1.28 if ty == 5 else (1.08 if ty == 2 else 1.0)
		# enemy marker: a red glow under every enemy, so they never blend into brick walls
		var ecp := origin + (e["p"] as Vector2) * ts
		draw_circle(ecp, ts * 0.62 * esc, Color(1.0, 0.15, 0.1, 0.22))
		draw_arc(ecp, ts * 0.62 * esc, 0, TAU, 24, Color(1.0, 0.3, 0.2, 0.55), 2.0 * u)
		_draw_tank(_kicked(e), int(e["d"]), "e%d" % ty, float(e["tread"]), mod, esc)
		if float(e.get("burn", 0.0)) > 0.0:
			for j in 2:
				var fs := ts * 0.45 * (0.8 + 0.2 * sin(anim * 15.0 + j * 2.0))
				var fp := ecp + Vector2((j - 0.5) * ts * 0.35, -ts * 0.1)
				draw_texture_rect(FX_FIRE, Rect2(fp - Vector2(fs * 0.5, fs * 0.9), Vector2(fs, fs)), false)
		var ec := origin + (e["p"] as Vector2) * ts
		var mh := int(e["maxhp"])
		if mh >= 2 and ty != 5:
			for k in mh:
				var pr := Rect2(ec + Vector2((k - mh * 0.5) * ts * 0.22, -ts * 0.62), Vector2(ts * 0.18, ts * 0.08))
				draw_rect(pr, Color("ffd35a") if k < int(e["hp"]) else Color(0.25, 0.25, 0.25))
		if str(e.get("buff", "")) != "":
			draw_arc(ec, ts * 0.68, anim * 4.0, anim * 4.0 + PI, 12, Color("ff8a2a"), 2.0 * u)
		if float(e.get("charge", 0.0)) > 0.0:
			var k := 1.0 - float(e["charge"]) / 1.2
			draw_circle(ec, ts * (0.5 + 0.5 * k), Color(0.7, 0.2, 1.0, 0.15 + 0.35 * k))
			draw_line(ec, ec + DIRS[int(e["d"])] * ts * 13.0, Color(0.8, 0.3, 1.0, 0.2 + 0.5 * k), 3.0 * u)
		elif float(e.get("heat", 0.0)) > 0.0:
			var fl := 0.5 + 0.5 * sin(anim * 18.0)
			draw_circle(ec, ts * 0.7, Color(1.0, 0.45, 0.1, 0.2 + 0.2 * fl))
		if float(e["inv"]) > 0.0:
			draw_arc(origin + (e["p"] as Vector2) * ts, ts * 0.62, 0, TAU, 24, Color(1.0, 0.4, 0.4, 0.6), 2.0 * u)
		if ty == 3 and float(e["aim"]) > 0.0:
			var a0 := origin + (e["p"] as Vector2) * ts
			draw_line(a0, a0 + DIRS[int(e["d"])] * ts * 13.0, Color(1, 0.2, 0.2, 0.15 + 0.6 * float(e["aim"])), 2.0 * u)
	if _ally_alive():
		var aa := 0.5 + 0.5 * float(int(anim * 12.0) % 2) if float(ally["inv"]) > 0.0 else 1.0
		var amod := HIT_FLASH if float(ally["hit"]) > 0.0 else Color(0.85, 1.15, 0.85)
		_draw_tank(ally["p"], int(ally["d"]), "ally", float(ally["tread"]), Color(amod, aa), 0.92)
		var ac := origin + (ally["p"] as Vector2) * ts
		for k in int(ally["hp"]):
			draw_rect(Rect2(ac + Vector2((k - int(ally["hp"]) * 0.5) * ts * 0.22, -ts * 0.6), Vector2(ts * 0.18, ts * 0.08)), Color("7cff6b"))
	if not bool(player["dead"]):
		var a := 1.0
		if float(player["inv"]) > 0.0:
			a = 0.45 + 0.55 * float(int(anim * 12.0) % 2)
		var pm := FROZEN if p_freeze > 0.0 else Color.WHITE
		if camo:
			a *= 0.55  # camouflaged
		_draw_tank(_kicked(player), int(player["d"]), player_sprite, float(player["tread"]), Color(pm, a), 1.0)
		var c := origin + (player["p"] as Vector2) * ts
		if float(player["inv"]) > 0.0:
			draw_arc(c, ts * 0.62, 0, TAU, 24, Color(0.6, 0.9, 1.0, 0.6), 2.0 * u)
		if armor > 0:
			draw_arc(c, ts * 0.55, -PI * 0.8, -PI * 0.2, 12, Color("ffd35a"), 3.0 * u)
	for b in bonuses:
		if float(b["t"]) > 7.0 and int(anim * 8.0) % 2 == 0:
			continue
		_draw_bonus(origin + (b["p"] as Vector2) * ts, str(b["k"]))
	for x in trails:
		var k := float(x["t"]) / 0.35
		var tc := Color(1.0, 0.45 + 0.3 * k, 0.1) if int(x["o"]) == 0 else Color(0.7, 0.2, 1.0)
		draw_circle(origin + (x["p"] as Vector2) * ts, ts * 0.42 * (1.0 - k), Color(tc, 0.55 * (1.0 - k)))
	for b in bullets:
		var c := origin + (b["p"] as Vector2) * ts
		if bool(b.get("super", false)):
			var outer := Color(1.0, 0.4, 0.05, 0.6) if int(b["o"]) == 0 else Color(0.6, 0.15, 1.0, 0.6)
			draw_circle(c, ts * 0.42, outer)
			draw_circle(c, ts * 0.3, outer.lightened(0.3))
			draw_circle(c, ts * 0.16, Color("fff1d0"))
			continue
		if bool(b.get("laser", false)):
			var tail: Vector2 = c - DIRS[int(b["d"])] * ts * 0.9
			draw_line(tail, c, Color(1.0, 0.25, 0.9, 0.35), ts * 0.26)
			draw_line(tail, c, Color(0.35, 0.95, 1.0, 0.9), ts * 0.11)
			draw_line(tail, c, Color(1, 1, 1), ts * 0.04)
			continue
		if bool(b.get("zap", false)):
			var dv: Vector2 = DIRS[int(b["d"])]
			var pv := Vector2(-dv.y, dv.x)
			var zz := PackedVector2Array()
			for k in 6:
				zz.append(c - dv * ts * 0.12 * k + pv * ts * (0.09 if (k + int(anim * 30.0)) % 2 == 0 else -0.09))
			draw_circle(c, ts * 0.16, Color(0.4, 0.75, 1.0, 0.35))
			draw_polyline(zz, Color(0.55, 0.85, 1.0), 3.0 * u)
			draw_circle(c, ts * 0.06, Color.WHITE)
			continue
		if bool(b.get("dark", false)):  # Neon: a ball of darkness with a violet core
			draw_circle(c, ts * 0.2, Color(0.25, 0.0, 0.4, 0.55))
			draw_circle(c, ts * 0.13, Color(0.55, 0.15, 0.95))
			draw_circle(c, ts * 0.05, Color(0.85, 0.95, 1.0))
			continue
		draw_set_transform(c, int(b["d"]) * PI * 0.5, Vector2.ONE)
		var sh := ts * (0.3 if bool(b.get("small", false)) else 0.5)
		if bool(b.get("ice", false)):
			draw_circle(Vector2.ZERO, ts * 0.16, Color(0.6, 0.9, 1.0, 0.45))
		elif bool(b.get("fire", false)):
			draw_circle(Vector2.ZERO, ts * 0.16, Color(1.0, 0.45, 0.1, 0.45))
		draw_texture_rect(FX_SHELL, Rect2(-sh * 0.25, -sh * 0.45, sh * 0.5, sh), false,
			Color.WHITE if int(b["o"]) != 1 else Color(1.0, 0.65, 0.6))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flame_on:
		var fp := flame_cells()
		for i in fp.size():
			var fc := origin + (fp[i] as Vector2) * ts
			var fl := 0.75 + 0.25 * sin(anim * 40.0 + i * 1.7)
			draw_circle(fc, ts * (0.28 + 0.07 * i) * fl, Color(1.0, 0.35, 0.05, 0.45))
			draw_circle(fc, ts * (0.17 + 0.04 * i) * fl, Color(1.0, 0.75, 0.2, 0.75))
	for y in N:
		for x in N:
			if int(tiles[y * N + x]) == BUSH:
				_draw_bush(x, y)
	for st in strikes:
		_lightning(origin + (st["a"] as Vector2) * ts, origin + (st["b"] as Vector2) * ts, int(st["seed"]),
			float(st["life"]) / float(st["max"]), float(st["w"]))
	for bm in booms:
		var k := float(bm["t"]) / (0.6 if bool(bm["big"]) else 0.3)
		var c := origin + (bm["p"] as Vector2) * ts
		TankArt.draw_boom(self, c, ts * (2.4 if bool(bm["big"]) else 1.1), k, bool(bm["big"]))
	_draw_fx()
	_draw_controls()
	if state == "play":
		# Pause button (top left)
		draw_circle(pause_c, 22 * u, Color(1, 1, 1, 0.12))
		draw_rect(Rect2(pause_c + Vector2(-9 * u, -10 * u), Vector2(6 * u, 20 * u)), Color(1, 1, 1, 0.9))
		draw_rect(Rect2(pause_c + Vector2(3 * u, -10 * u), Vector2(6 * u, 20 * u)), Color(1, 1, 1, 0.9))
		draw_line(pause_c + Vector2(30 * u, -18 * u), pause_c + Vector2(30 * u, 18 * u), Color(0.35, 0.5, 1.0, 0.5), 2.0 * u)
	if paused:
		_draw_pause()
	if state != "play":
		_draw_result()


func _draw_hud() -> void:
	# top bar, mirrored: [pause | enemies left] ... title / boss flask ... [lives]; two pills of the same size
	var boss_on := false
	for e in enemies:
		if int(e["type"]) == 5:
			boss_on = true
	if not boss_on:  # the boss flask takes the title's place
		_txt(_t("tk_name"), view.x * 0.5, hud_y + 13 * u, int(36 * u), Color("ffd35a"))
	var pw := 176.0 * u
	var ph := 60.0 * u
	var lp := Rect2(origin.x, hud_y - ph * 0.5, pw, ph)
	var rp := Rect2(origin.x + ts * N - pw, hud_y - ph * 0.5, pw, ph)
	for r in [lp, rp]:
		_panel(r, ph * 0.5, Color(0.04, 0.06, 0.2, 0.85), Color(0.35, 0.5, 1.0, 0.7))
	var ei := 40.0 * u
	draw_texture_rect(UI_ENEMY, Rect2(lp.position.x + 76 * u, hud_y - ei * 0.5, ei, ei), false)
	_txt_l("× %d" % (total_enemies - killed), lp.position.x + 76 * u + ei + 6 * u, hud_y + 10 * u, int(27 * u), Color.WHITE)
	for i in lives:  # hearts centred in the right pill
		_heart(Vector2(rp.get_center().x + (i - (lives - 1) * 0.5) * 40 * u, hud_y - 3 * u), 14 * u)
	var act: Array = []  # active bonuses: a small row over the top edge of the field
	for k in ["power", "rapid", "speed"]:
		if float(buffs[k]) > 0.0:
			act.append(k)
	for i in act.size():
		var bx: float = view.x * 0.5 + (i - (act.size() - 1) * 0.5) * 64 * u
		_draw_bonus(Vector2(bx, origin.y + 30 * u), act[i])
		_txt(str(int(ceil(float(buffs[act[i]])))), bx, origin.y + 70 * u, int(20 * u), Color.WHITE)
	var boss: Dictionary = {}
	for e in enemies:
		if int(e["type"]) == 5:
			boss = e
	if not boss.is_empty():
		_boss_flask(float(boss["hp"]) / float(boss["maxhp"]))
	boss_msg_t = maxf(0.0, boss_msg_t - get_process_delta_time())
	if boss_msg_t > 0.0:
		_txt(_t("tk_boss"), view.x * 0.5, origin.y + ts * N * 0.45, int(30 * u), Color(1.0, 0.85, 0.35, clampf(boss_msg_t, 0.0, 1.0)))
	if anim < 5.0:
		_txt(_t("tk_hint"), view.x * 0.5, origin.y + ts * N + 34 * u, int(23 * u), Color(0.7, 0.88, 1.0, clampf(5.0 - anim, 0.0, 1.0)))


func _heart(c: Vector2, r: float) -> void:
	var s := r * 2.4
	draw_texture_rect(UI_HEART, Rect2(c - Vector2(s, s) * 0.5 + Vector2(0, r * 0.3), Vector2(s, s)), false)


## Super tank's health: a glass flask with red liquid that sloshes and drains as the boss is hit.
func _boss_flask(k: float) -> void:
	var fw := minf(ts * N - 2 * 176.0 * u - 24 * u, ts * N * 0.5)
	var fh := fw * UI_FLASK.get_height() / UI_FLASK.get_width()
	var fr := Rect2(view.x * 0.5 - fw * 0.5, hud_y - fh * 0.5, fw, fh)
	var g := Rect2(fr.position + Vector2(fw * 0.2, fh * 0.3), Vector2(fw * 0.68, fh * 0.42))  # glass, measured on the picture
	if absf(boss_shown - k) > 0.004:
		flask_slosh = minf(1.0, flask_slosh + absf(boss_shown - k) * 6.0)  # a hit shakes the blood
	boss_shown = lerpf(boss_shown, clampf(k, 0.0, 1.0), 0.06)
	flask_slosh = maxf(0.0, flask_slosh - 0.012)
	var lw := g.size.x * boss_shown
	if lw > 1.0:
		var amp := g.size.y * (0.07 + 0.16 * flask_slosh)
		var steps := 24
		# back wave (darker), then the front wave: two layers of blood sloshing against each other
		for layer in 2:
			var pts := PackedVector2Array()
			var top := g.position.y + g.size.y * (0.1 if layer == 0 else 0.18)
			for i_ in steps + 1:
				var xx := g.position.x + lw * i_ / float(steps)
				var ph := anim * (4.0 if layer == 0 else 5.5) + i_ * (0.7 if layer == 0 else 0.9) + layer * 2.0
				pts.append(Vector2(xx, top + sin(ph) * amp * (0.8 if layer == 0 else 1.0)))
			pts.append(Vector2(g.position.x + lw, g.end.y))
			pts.append(Vector2(g.position.x, g.end.y))
			draw_colored_polygon(pts, Color("7a0610") if layer == 0 else Color("c0101e"))
		draw_rect(Rect2(g.position.x, g.end.y - g.size.y * 0.3, lw, g.size.y * 0.3), Color(0.35, 0.0, 0.03, 0.55))
		for b_ in 5:  # bubbles rising in the blood
			var bt := fmod(anim * (0.6 + b_ * 0.17) + b_ * 0.37, 1.0)
			var bx := g.position.x + lw * fmod(0.13 + b_ * 0.21 + sin(anim + b_) * 0.03, 1.0)
			var by := g.end.y - g.size.y * 0.75 * bt
			draw_circle(Vector2(bx, by), g.size.y * 0.05 * (1.0 - bt * 0.5), Color(1, 0.55, 0.55, 0.45 * (1.0 - bt)))
		# surface shine and the glare of the glass
		draw_rect(Rect2(g.position.x, g.position.y + g.size.y * 0.3, lw, g.size.y * 0.06), Color(1, 0.5, 0.5, 0.35))
	draw_texture_rect(UI_FLASK, fr, false)


## Rounded glass pill with a thin glowing edge (top bar).
func _panel(r: Rect2, rad: float, fill: Color, edge: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(rad))
	sb.set_border_width_all(maxi(1, int(2.0 * u)))
	sb.border_color = edge
	sb.shadow_color = Color(edge.r, edge.g, edge.b, edge.a * 0.4)
	sb.shadow_size = int(8 * u)
	sb.anti_aliasing = true
	draw_style_box(sb, r)


## Left-aligned HUD text with an outline.
func _txt_l(s_: String, x: float, y: float, size: int, col: Color) -> void:
	draw_string_outline(font, Vector2(x, y), s_, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(6 * u), Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(x, y), s_, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Where enemies aim: the Mirage hologram while it stands, otherwise the player.
func _tgt() -> Vector2:
	return decoy["p"] if not decoy.is_empty() else player["p"]


## Per-tank abilities that tick on their own.
func _update_perks(delta: float) -> void:
	dash_cd = maxf(0.0, dash_cd - delta)
	ninja_t = maxf(0.0, ninja_t - delta)
	for f in fogs:
		f["t"] = float(f["t"]) - delta
	fogs = fogs.filter(func(f): return float(f["t"]) > 0.0)
	if not decoy.is_empty():
		decoy["t"] = float(decoy["t"]) - delta
		if float(decoy["t"]) <= 0.0:
			decoy = {}
	if state != "play" or bool(player["dead"]):
		return
	match perk:
		"classic":
			repair_t -= delta
			if repair_t <= 0.0:
				repair_t = REPAIR_S
				if armor < armor_max + 1:
					armor += 1
					_sfx("t_armor", 1.2)
		"guardian":
			if not shield_on:
				shield_t -= delta
				if shield_t <= 0.0:
					shield_on = true
		"mirage":
			decoy_t -= delta
			if decoy_t <= 0.0:
				decoy_t = DECOY_S
				decoy = {"p": player["p"], "d": int(player["d"]), "t": 6.0}


## Samurai: two cells forward in a blink; rams the first enemy on the way.
func _dash(d: int) -> void:
	dash_cd = 4.0
	_sfx("t_shot_big", 1.4, -6.0)
	for i in 8:
		var before: Vector2 = player["p"]
		if not _move_tank(player, d, 1.0, 0.25):
			break
		fx.append({"k": "smoke", "p": before, "d": (d + 2) % 4, "t": anim, "life": 0.5, "r": rng.randf() * TAU})
		for e in enemies:
			if not bool(e.get("dead", false)) and (e["p"] as Vector2).distance_to(player["p"]) < 1.05:
				e["inv"] = 0.0
				_damage_enemy(e, 2.0, "p")
				_boom(e["p"], false)
				return


## A player shell hit enemy `e`: the tank's own effect.
func _shell_hit(b: Dictionary, e: Dictionary) -> void:
	if bool(e.get("dead", false)):
		if perk == "ninja" and int(b["o"]) == 0:
			ninja_t = 3.0
		return
	if bool(b.get("ice", false)):
		e["slow"] = 2.0
		e["ice_n"] = int(e.get("ice_n", 0)) + 1
		if int(e["ice_n"]) >= 3 and int(e["type"]) != 5:
			e["ice_n"] = 0
			e["frz"] = 1.5
	if bool(b.get("fire", false)):
		e["burn"] = 3.0
	if bool(b.get("zap", false)):  # Titan: the bolt jumps to the nearest other enemy
		var best: Dictionary = {}
		var bd := 3.5
		for o in enemies:
			if not is_same(o, e) and not bool(o.get("dead", false)):
				var dd := (o["p"] as Vector2).distance_to(e["p"])
				if dd < bd:
					bd = dd
					best = o
		if not best.is_empty():
			fx.append({"k": "bolt", "p": e["p"], "q": best["p"], "d": 0, "t": anim, "life": 0.25})
			best["inv"] = 0.0
			_damage_enemy(best, 1.0, "p")


## Where a player shell ends (wall or tank): blast, shards, fog.
func _shell_end(b: Dictionary, p: Vector2, d: int) -> void:
	if int(b["o"]) != 0:
		return
	if bool(b.get("blast", false)):  # Thunder: 3x3 around the hit
		var cx := int(floor(p.x))
		var cy := int(floor(p.y))
		for yy in range(cy - 1, cy + 2):
			for xx in range(cx - 1, cx + 2):
				if xx >= 0 and yy >= 0 and xx < N and yy < N and int(tiles[yy * N + xx]) == BRICK:
					_set_tile(xx, yy, EMPTY)
		for e in enemies:
			if not bool(e.get("dead", false)) and (e["p"] as Vector2).distance_to(p) < 1.6:
				_damage_enemy(e, 1.0, "p", true)
		_boom(p, true)
	if bool(b.get("shard", false)):  # Dragon: three shards fly on
		for nd in [(d + 1) % 4, (d + 3) % 4, (d + 2) % 4]:
			bullets.append({"p": p - DIRS[d] * 0.3, "d": nd, "o": 0, "src": {}, "sp": 9.0, "dead": false, "dmg": 1.0,
				"ttl": 0.35, "small": true})
	if bool(b.get("dark", false)):  # Neon: slowing dark fog
		fogs.append({"p": p, "t": 3.0})


## Short effects over the field: muzzle flash, cannon smoke, flames on fresh scorch marks.
func _draw_fx() -> void:
	var keep: Array = []
	for f in fx:
		var age := anim - float(f["t"])
		var life := float(f["life"])
		if age > life:
			continue
		keep.append(f)
		if age < 0.0:
			continue
		var k := age / life
		var c := origin + (f["p"] as Vector2) * ts
		match str(f["k"]):
			"muzzle":
				draw_set_transform(c, int(f["d"]) * PI * 0.5, Vector2.ONE)
				var mw := ts * 0.55 * (1.0 + k)
				draw_texture_rect(FX_MUZZLE, Rect2(-mw * 0.5, -mw * 1.2, mw, mw * 1.3), false, Color(1, 1, 1, 1.0 - k))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"bolt":
				var q := origin + (f["q"] as Vector2) * ts
				var pts := PackedVector2Array([c])
				for j in range(1, 6):
					pts.append(c.lerp(q, j / 6.0) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * ts * 0.15)
				pts.append(q)
				draw_polyline(pts, Color(0.6, 0.9, 1.0, 1.0 - k), 4.0 * u)
				draw_polyline(pts, Color(1, 1, 1, 1.0 - k), 1.5 * u)
			"smoke":
				var sz := ts * (0.35 + 0.6 * k)
				var drift: Vector2 = DIRS[int(f["d"])] * ts * 0.35 * k
				draw_set_transform(c + drift, float(f["r"]) + k, Vector2.ONE)
				draw_texture_rect(FX_SMOKE, Rect2(-Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(1, 1, 1, 0.55 * (1.0 - k)))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	fx = keep
	for fg in fogs:  # Neon's dark fog
		var fc := origin + (fg["p"] as Vector2) * ts
		var fa := clampf(float(fg["t"]), 0.0, 1.0)
		for j in 3:
			var fs := ts * (2.2 + 0.25 * sin(anim * 2.0 + j))
			draw_set_transform(fc, anim * 0.4 + j * 2.1, Vector2.ONE)
			draw_texture_rect(FX_SMOKE, Rect2(-Vector2(fs, fs) * 0.5, Vector2(fs, fs)), false, Color(0.35, 0.1, 0.6, 0.45 * fa))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not decoy.is_empty():  # Mirage hologram: the player's tank, see-through and flickering
		var da := 0.35 + 0.2 * sin(anim * 20.0)
		_draw_tank(decoy["p"], int(decoy["d"]), player_sprite, 0.0, Color(0.6, 0.85, 1.4, da), 1.0)
	if shield_on and not bool(player["dead"]):  # Guardian shield
		var sc := origin + (_kicked(player)) * ts
		draw_circle(sc, ts * 0.75, Color(0.3, 0.7, 1.0, 0.12))
		draw_arc(sc, ts * 0.75, 0, TAU, 40, Color(0.5, 0.85, 1.0, 0.6 + 0.2 * sin(anim * 4.0)), 2.5 * u)


## The quarter of a seamless 2x2 texture that cell (x, y) shows, so neighbouring cells join up.
func _quarter(t: Texture2D, x: int, y: int) -> Rect2:
	var h := Vector2(t.get_width(), t.get_height()) * 0.5
	return Rect2(Vector2(x % 2, y % 2) * h, h)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var rad := r * (1.0 if k % 2 == 0 else 0.35)
		var ang := anim * 6.0 + k * PI / 4
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, col)


func _draw_tile(x: int, y: int, v: int) -> void:
	var r := _cell(x, y)
	match v:
		BRICK:
			var hp := int(brick_hp[y * N + x])
			var m := int(mat[y * N + x]) if mat.size() == N * N else 0
			if m != 0:
				_draw_crate(r, m, int(crate_col[y * N + x]), hp)
				return
			draw_rect(r, arena["mortar"])
			draw_texture_rect(T_BRICK, r, false, Color(arena["brick"]).lightened(0.35))
			var hits := int(brick_hits[y * N + x]) if brick_hits.size() == N * N else 0
			if hp == 1 or hits >= 3:
				draw_texture_rect(FX_CRACK2, r, false, Color(1, 1, 1, 0.9))
			elif hits >= 1:
				draw_texture_rect(FX_CRACK1, r, false, Color(1, 1, 1, 0.85))
		STEEL:
			# anti-tank hedgehog on a concrete pad: cannot be destroyed
			draw_texture_rect(T_STEEL, r, false)
		WATER:
			var shine := 0.92 + 0.08 * sin(anim * 2.0 + x * 0.7 + y)
			draw_texture_rect_region(T_WATER, r, _quarter(T_WATER, x, y), Color(shine, shine, shine))
		ICE:
			draw_texture_rect(T_ICE, r, false)
		MUD:
			draw_texture_rect_region(T_MUD, r, _quarter(T_MUD, x, y))
		BASE:
			_draw_generator(r)


## Half of a container (two tiles wide); darker and cracked once half broken.
func _draw_crate(r: Rect2, side: int, col: int, hp: int) -> void:
	var t := TankArt.item("crate_" + "ABCD"[col])
	if t == null:
		draw_rect(r, Color("8a6a3a"))
		return
	var sz := t.get_size()
	var src := Rect2(0 if side == CRATE_L else sz.x * 0.5, 0, sz.x * 0.5, sz.y)
	var h := ts * minf(1.0, sz.y / (sz.x * 0.5))
	var dst := Rect2(r.position.x, r.position.y + (ts - h) * 0.5, ts, h)
	var hurt := hp <= CRATE_HP / 2
	draw_texture_rect_region(t, dst, src, Color(0.72, 0.68, 0.64) if hurt else Color.WHITE)
	if hurt:
		var c := dst.get_center()
		draw_polyline(PackedVector2Array([c + Vector2(-ts * 0.3, -h * 0.3), c + Vector2(-ts * 0.05, 0), c + Vector2(-ts * 0.15, h * 0.35)]),
			Color(0.1, 0.08, 0.06, 0.9), 2.0 * u)
		draw_polyline(PackedVector2Array([c + Vector2(-ts * 0.05, 0), c + Vector2(ts * 0.3, -h * 0.1)]), Color(0.1, 0.08, 0.06, 0.9), 2.0 * u)


func _bolt_points(a: Vector2, b: Vector2, r: RandomNumberGenerator) -> PackedVector2Array:
	var pts: Array = [a, b]
	var off := a.distance_to(b) * 0.22
	for it in 5:
		var np: Array = []
		for i in pts.size() - 1:
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			var dir := p1 - p0
			var perp := Vector2(-dir.y, dir.x).normalized()
			np.append(p0)
			np.append((p0 + p1) * 0.5 + perp * r.randf_range(-off, off))
		np.append(pts[pts.size() - 1])
		pts = np
		off *= 0.52
	return PackedVector2Array(pts)


func _bolt_layers(pts: PackedVector2Array, a: float, w: float) -> void:
	draw_polyline(pts, Color(0.35, 0.5, 1.0, 0.08 * a), 16.0 * u * w)
	draw_polyline(pts, Color(0.45, 0.7, 1.0, 0.22 * a), 7.0 * u * w)
	draw_polyline(pts, Color(0.7, 0.88, 1.0, 0.75 * a), 3.0 * u * w)
	draw_polyline(pts, Color(1, 1, 1, 0.95 * a), 1.3 * u * w)


func _lightning(a: Vector2, b: Vector2, sd: int, alpha: float, w: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = sd
	var main := _bolt_points(a, b, r)
	_bolt_layers(main, alpha, w)
	var n := main.size()
	for k in r.randi_range(1, 3):
		var start: Vector2 = main[r.randi_range(int(n * 0.2), int(n * 0.75))]
		var dir := (b - a).rotated(r.randf_range(-1.0, 1.0)) * r.randf_range(0.2, 0.45)
		_bolt_layers(_bolt_points(start, start + dir, r), alpha * 0.6, w * 0.55)
	draw_circle(b, ts * 0.16 * w, Color(0.6, 0.85, 1.0, 0.35 * alpha))
	draw_circle(b, ts * 0.06 * w, Color(1, 1, 1, 0.8 * alpha))


func _draw_generator(r: Rect2) -> void:
	var c := r.get_center()
	var s := ts
	var flick := 0.0
	for st in strikes:
		flick = maxf(flick, float(st["life"]) / float(st["max"]))
	draw_circle(c, s * (0.85 + 0.1 * flick), Color(0.35, 0.65, 1.0, 0.1 + 0.12 * flick))
	# painted generator, the same one cell; red flash when hit, brighter while it sends a strike
	var gm := Color(1.6, 0.6, 0.6) if gen_hit > 0.0 else Color(1, 1, 1).lerp(Color(1.35, 1.35, 1.5), flick)
	draw_texture_rect(UI_GEN, Rect2(c - Vector2(s, s) * 0.48, Vector2(s, s) * 0.96), false, gm)
	for k in GEN_MAX:
		var pc := Color("7cff6b") if k < gen_hp else Color(0.2, 0.2, 0.2)
		draw_rect(Rect2(c + Vector2(-0.4 + k * 0.165, -0.66) * s, Vector2(0.13, 0.07) * s), pc)


func _draw_bush(x: int, y: int) -> void:
	var r := _cell(x, y)
	# trees of the arena (CraftPix top-down trees): one kind per battle, hide tanks under them
	if arena.has("tree") and TankArt.draw_item(self, "%s_%d" % [str(arena["tree"]), tree_kind], r.get_center(), ts * 1.5):
		return
	var bc: Color = arena["bush"]
	for k in 5:
		var p := r.position + Vector2([0.28, 0.72, 0.5, 0.25, 0.75][k], [0.3, 0.3, 0.55, 0.78, 0.78][k]) * ts
		draw_circle(p, ts * 0.27, bc)
		draw_circle(p - Vector2(ts * 0.06, ts * 0.06), ts * 0.12, bc.lightened(0.25))


func _draw_bonus(c: Vector2, k: String) -> void:
	if TankArt.draw_item(self, k, c, ts * 0.95):
		return
	var s := ts * 0.42
	draw_rect(Rect2(c - Vector2(s, s), Vector2(s, s) * 2), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(c - Vector2(s, s), Vector2(s, s) * 2), Color("ffd35a"), false, 2.0 * u)
	match k:
		"repair":
			_heart(c, s * 0.55)
		"shield":
			draw_arc(c, s * 0.6, 0, TAU, 20, Color("9fd8ff"), 3.0 * u)
			draw_circle(c, s * 0.25, Color("9fd8ff"))
		"freeze":
			for a in 3:
				var v := Vector2(cos(a * PI / 3), sin(a * PI / 3)) * s * 0.7
				draw_line(c - v, c + v, Color("dff4ff"), 3.0 * u)
		"fort":
			draw_rect(Rect2(c - Vector2(s, s) * 0.55, Vector2(s, s) * 1.1), Color("aeb7c2"))
			draw_rect(Rect2(c - Vector2(s, s) * 0.3, Vector2(s, s) * 0.6), Color("e1ecf5"))
		"power":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.7), c + Vector2(s * 0.25, -s * 0.1), c + Vector2(s * 0.12, s * 0.7),
				c + Vector2(-s * 0.12, s * 0.7), c + Vector2(-s * 0.25, -s * 0.1)]), Color("ff6b3d"))
			draw_circle(c + Vector2(0, -s * 0.15), s * 0.12, Color("ffd35a"))
		"rapid":
			for j in 2:
				var o := Vector2((j - 0.5) * s * 0.5, 0)
				draw_polyline(PackedVector2Array([c + o + Vector2(-s * 0.18, -s * 0.45), c + o + Vector2(s * 0.12, 0),
					c + o + Vector2(-s * 0.18, s * 0.45)]), Color("ffd35a"), 3.0 * u)
		"speed":
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.15, -s * 0.7), c + Vector2(-s * 0.35, s * 0.1), c + Vector2(0, s * 0.1),
				c + Vector2(-s * 0.15, s * 0.7), c + Vector2(s * 0.35, -s * 0.1), c + Vector2(0, -s * 0.1)]), Color("7fdcff"))


## Every tank in the battle is a picture from TankArt; `mod` tints it (hit flash, frozen, blinking bonus carrier).
## Where a tank is drawn: pushed back along its gun for 0.15 s after a shot (recoil), then home again.
func _kicked(t: Dictionary) -> Vector2:
	var k := 1.0 - (anim - float(t.get("kick", -9.0))) / 0.15
	if k <= 0.0:
		return t["p"]
	return (t["p"] as Vector2) - DIRS[int(t["d"])] * 0.09 * k * k


func _draw_tank(p: Vector2, d: int, sprite: String, tread: float, mod: Color, scale: float) -> void:
	TankArt.draw(self, sprite, origin + p * ts, ts * HALF * 2.0 * scale, d * PI * 0.5, int(absf(tread) * 6.0), mod)


func _flame(c: Vector2, r: float, a: float) -> void:
	draw_circle(c + Vector2(0, r * 0.35), r * 0.55, Color(1.0, 0.45, 0.08, a))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.53, r * 0.25), c + Vector2(0, -r), c + Vector2(r * 0.53, r * 0.25)]),
		Color(1.0, 0.45, 0.08, a))
	draw_circle(c + Vector2(0, r * 0.45), r * 0.3, Color(1.0, 0.9, 0.4, a))


func _draw_controls() -> void:
	var dir := key_dir if key_dir >= 0 else move_dir
	var active := joy_finger >= 0
	var base := joy_base if active else pad_c
	var knob := joy_knob if active else pad_c
	var a := 1.0 if active else 0.5
	var ja := 0.65 + 0.35 * a
	draw_texture_rect(UI_JOY, Rect2(base - Vector2(pad_r, pad_r), Vector2(pad_r, pad_r) * 2.0), false, Color(1, 1, 1, ja))
	if dir >= 0:  # the pressed direction lights up
		var v: Vector2 = DIRS[dir]
		draw_circle(base + v * pad_r * 0.62, pad_r * 0.2, Color(0.6, 0.95, 1.0, 0.35))
	var kr := pad_r * 0.4
	draw_texture_rect(UI_KNOB, Rect2(knob - Vector2(kr, kr), Vector2(kr, kr) * 2.0), false, Color(1, 1, 1, ja))
	draw_circle(fire_c + Vector2(0, fire_r * 0.12), fire_r * 1.02, Color(0, 0, 0, 0.35))
	var fp := fire_c + Vector2(0, 4 * u if fire_held else 0.0)
	var fs := fire_r * (2.0 if not fire_held else 1.94)
	draw_texture_rect(UI_FIRE, Rect2(fp - Vector2(fs, fs) * 0.5, Vector2(fs, fs)), false, Color(1.15, 1.1, 1.1) if fire_held else Color.WHITE)

	var ready := super_charge >= 1.0
	var ss := super_r * 2.0
	var sp := 1.0 + (0.04 * sin(anim * 8.0) if ready else 0.0)  # ready: the button gently breathes
	draw_texture_rect(UI_SUPER, Rect2(super_c - Vector2(ss, ss) * 0.5 * sp, Vector2(ss, ss) * sp), false,
		Color.WHITE if ready else Color(0.5, 0.5, 0.55))
	if super_charge > 0.02 and not ready:  # charge fills around the gold rim
		draw_arc(super_c, super_r * 0.9, -PI / 2, -PI / 2 + TAU * super_charge, 40,
			Color("9fd8ff") if near_gen else Color("ffd35a"), 6.0 * u)
	var ma := 1.0 if mines_left > 0 else 0.35
	var mbs := mine_r * 2.1
	draw_texture_rect(UI_MINE_BTN, Rect2(mine_c - Vector2(mbs, mbs) * 0.5, Vector2(mbs, mbs)), false, Color(ma, ma, ma))
	var mb := mine_c + Vector2(mine_r * 0.72, -mine_r * 0.72)  # count badge on the rim
	draw_circle(mb, mine_r * 0.38, Color(0.04, 0.06, 0.2, 0.95))
	draw_arc(mb, mine_r * 0.38, 0, TAU, 24, Color("ffd35a"), 2.0 * u)
	_txt(str(mines_left), mb.x, mb.y + mine_r * 0.15, int(mine_r * 0.45), Color.WHITE)
	if FLAMER:
		var fa := 1.0 if fuel > 0.0 else 0.35
		var fls := flame_r * (2.1 if flame_on else 2.0)
		draw_texture_rect(UI_FLAME, Rect2(flame_c - Vector2(fls, fls) * 0.5, Vector2(fls, fls)), false,
			Color(1.2, 1.1, 1.0) if flame_on else Color(fa, fa, fa))
		draw_arc(flame_c, flame_r * 0.88, -PI / 2, -PI / 2 + TAU * clampf(fuel / Data.FUEL_MAX, 0.0, 1.0), 32, Color("ffb347"), 4.0 * u)


## The super tank is on the field (or about to enter): the game switches to the boss music.
func boss_alive() -> bool:
	for e in enemies:
		if int(e["type"]) == 5 and not bool(e.get("dead", false)):
			return true
	for s in spawns:
		if int(s["type"]) == 5:
			return true
	return false


## m:ss for the battle report.
static func clock(sec: float) -> String:
	var t := int(floor(sec))
	return "%d:%02d" % [t / 60, t % 60]


## Report rows: [label, value, color, number, format]. A "" value makes a small centered note line.
## number >= 0 is counted up on the result screen and shown with format ("time", or a % format string).
func report_rows() -> Array:
	var rows: Array = []
	var gold := Color("ffd35a")
	var white := Color(1, 1, 1, 0.92)
	var dim := Color(1, 1, 1, 0.6)
	var tm := float(st.get("time", 0.0))
	rows.append([_t("tk_r_time"), clock(tm), white, tm, "time"])
	if new_record:
		rows.append([_t("tk_r_record"), "", gold, -1, ""])
	elif best_time > 0.0:
		rows.append([_t("tk_r_best") % clock(best_time), "", dim, -1, ""])
	rows.append([_t("tk_r_kills"), "%d / %d" % [killed, total_enemies], white, killed, "%d / " + str(total_enemies)])
	var parts: Array = []
	for k in [["k_p", "tk_r_you"], ["k_a", "tk_r_ally"], ["k_mine", "tk_r_mines"], ["k_super", "tk_r_super"], ["k_flame", "tk_r_flame"]]:
		if int(st.get(k[0], 0)) > 0:
			parts.append("%s %d" % [_t(k[1]), int(st[k[0]])])
	if parts.size() > 1 or (parts.size() == 1 and int(st.get("k_p", 0)) != killed):
		rows.append([" · ".join(parts), "", dim, -1, ""])
	var deaths := int(st.get("deaths", 0))
	rows.append([_t("tk_r_deaths"), str(deaths), Color("ff8a80") if deaths > 0 else white, deaths, "%d"])
	if int(st.get("saves", 0)) > 0:
		rows.append([_t("tk_r_armor"), str(int(st["saves"])), white, int(st["saves"]), "%d"])
	var shots := int(st.get("shots", 0))
	if shots > 0:
		var acc := int(round(100.0 * minf(1.0, float(st.get("hits", 0)) / shots)))
		rows.append([_t("tk_r_acc"), "%d%%" % acc, white, acc, "%d%%"])
	rows.append([_t("tk_r_streak"), str(int(st.get("best_streak", 0))), white, int(st.get("best_streak", 0)), "%d"])
	var bp := int(st.get("b_p", 0))
	var ba := int(st.get("b_a", 0))
	if ba > 0:
		rows.append([_t("tk_r_bonus"), "%d · %s %d" % [bp, _t("tk_r_ally"), ba], white, bp, "%d · " + _t("tk_r_ally") + " " + str(ba)])
	else:
		rows.append([_t("tk_r_bonus"), str(bp), white, bp, "%d"])
	rows.append([_t("tk_r_walls"), str(int(st.get("walls", 0))), white, int(st.get("walls", 0)), "%d"])
	var g := maxi(0, gen_hp)
	rows.append([_t("tk_r_gen"), "%d / %d" % [g, GEN_MAX], Color("7cff6b") if gen_hp >= GEN_MAX else white, g, "%d / " + str(GEN_MAX)])
	if bool(st.get("boss", false)):
		rows.append(["✓ " + _t("tk_r_boss"), "", gold, -1, ""])
	return rows


const REPORT_T0 := 0.7      # the report starts after the title
const REPORT_ROW := 0.28    # one more row every this many seconds
const REPORT_COUNT := 0.45  # a row counts its number up over this time


## When the report is fully shown (the continue button appears; a tap before that skips to it).
func report_done_t() -> float:
	return REPORT_T0 + report_rows().size() * REPORT_ROW + REPORT_COUNT


func _row_value(r: Array, t: float) -> String:
	var num := float(r[3])
	if num < 0.0 or t >= REPORT_COUNT:
		return str(r[1])
	var k := clampf(t / REPORT_COUNT, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 2.0)
	if str(r[4]) == "time":
		return clock(num * k)
	return str(r[4]) % int(floor(num * k))


func _txt_at(s: String, x: float, y: float, w: float, size: int, col: Color, al: HorizontalAlignment) -> void:
	draw_string_outline(font, Vector2(x, y), s, al, w, size, int(size * 0.18), Color(0, 0, 0, col.a))
	draw_string(font, Vector2(x, y), s, al, w, size, col)


## Riveted armour button (glowing plate for the main action) with a stencil-white label.
func _mil_btn(r: Rect2, label: String, primary: bool) -> void:
	var tex: Texture2D = UI_PLATE_ON if primary else UI_PLATE
	var th_ := float(tex.get_height())
	var tw := float(tex.get_width())
	var k := r.size.y / th_
	var cap := th_ * 0.6
	var c0 := tw * 0.36
	var c1 := tw * 0.64
	var dc := cap * k
	var dm := (c1 - c0) * k
	var side := maxf(0.0, (r.size.x - dc * 2.0 - dm) * 0.5)
	var x := r.position.x
	draw_texture_rect_region(tex, Rect2(x, r.position.y, dc, r.size.y), Rect2(0, 0, cap, th_))
	draw_texture_rect_region(tex, Rect2(x + dc, r.position.y, side, r.size.y), Rect2(cap, 0, c0 - cap, th_))
	draw_texture_rect_region(tex, Rect2(x + dc + side, r.position.y, dm, r.size.y), Rect2(c0, 0, c1 - c0, th_))
	draw_texture_rect_region(tex, Rect2(x + dc + side + dm, r.position.y, side, r.size.y), Rect2(c1, 0, tw - cap - c1, th_))
	draw_texture_rect_region(tex, Rect2(r.end.x - dc, r.position.y, dc, r.size.y), Rect2(tw - cap, 0, cap, th_))
	var fs := int(minf(r.size.y * 0.38, 38 * u))
	var tw_ := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var room := r.size.x - dc * 1.6
	if tw_ > room and tw_ > 0.0:
		fs = maxi(int(fs * room / tw_), int(14 * u))
	var w := view.x * 2.0
	var pos := Vector2(r.get_center().x - w * 0.5, r.get_center().y + fs * 0.34)
	draw_string_outline(font, pos + Vector2(0, fs * 0.1), label, HORIZONTAL_ALIGNMENT_CENTER, w, fs, maxi(2, int(fs * 0.22)), Color(0.05, 0.04, 0.02))
	draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, w, fs, maxi(2, int(fs * 0.2)), Color(0.1, 0.08, 0.03))
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color("fff1c8"))


func _draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.7))
	var cx := view.x * 0.5
	var pw := minf(view.x - 60 * u, 560 * u)
	var top := view.y * 0.5 - 230 * u
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(0.11, 0.13, 0.08, 0.97)
	pb.set_corner_radius_all(int(12 * u))
	pb.border_color = Color(0.95, 0.72, 0.15, 0.8)
	pb.set_border_width_all(int(4 * u))
	draw_style_box(pb, Rect2(cx - pw * 0.5, top, pw, 460 * u))
	_txt(_t("tk_pause"), cx, top + 90 * u, int(60 * u), Color.WHITE)
	var bw := pw * 0.8
	pz_go = Rect2(cx - bw * 0.5, top + 150 * u, bw, 96 * u)
	pz_exit = Rect2(cx - bw * 0.5, top + 270 * u, bw, 96 * u)
	_mil_btn(pz_go, _t("tk_continue_battle"), true)
	_mil_btn(pz_exit, _t("tk_leave"), false)
	if not test_drive:
		_txt(_t("tk_leave_note") + ((" · −%d" % penalty) if penalty > 0 else ""), cx, pz_exit.end.y + 44 * u, int(23 * u), Color("ff8a80"))


func _draw_result() -> void:
	var a := clampf(end_t * 2.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.7 * a))
	var won := state == "won"
	var rows := report_rows()
	var rh := 50.0 * u
	var ph := rows.size() * rh + 30 * u
	var head := 190.0 * u
	var total := head + ph + 30 * u + 96 * u
	var top := maxf(20 * u, view.y * 0.5 - total * 0.5)
	var cx := view.x * 0.5
	_txt(_t("tk_win") if won else _t("tk_lose"), cx, top + 75 * u, int(76 * u), Color("7cff6b") if won else Color("ff6b6b"))
	if won and reward > 0:
		_txt("+%d" % reward, cx, top + 160 * u, int(60 * u), Color("ffd35a"))
	elif not won:
		_txt(_t("tk_lost_coins") % penalty if penalty > 0 else "0", cx, top + 160 * u, int(60 * u), Color("ff6b6b"))
	var pw := minf(view.x - 40 * u, 600 * u)
	var pr := Rect2(cx - pw * 0.5, top + head, pw, ph)
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(0.08, 0.1, 0.13, 0.92 * a)
	pb.set_corner_radius_all(int(18 * u))
	pb.border_color = Color(1, 1, 1, 0.12 * a)
	pb.set_border_width_all(int(2 * u))
	draw_style_box(pb, pr)
	var y := pr.position.y + 15 * u
	var pad := 26.0 * u
	for i in rows.size():
		var r: Array = rows[i]
		var rt := end_t - REPORT_T0 - i * REPORT_ROW
		if rt < 0.0:
			break
		var ra := a * clampf(rt / 0.15, 0.0, 1.0)
		var col: Color = r[2]
		col.a *= ra
		var ty := y + rh * 0.66 + (1.0 - clampf(rt / 0.15, 0.0, 1.0)) * 10 * u
		if str(r[1]) == "":
			_txt_at(str(r[0]), pr.position.x + pad, ty, pw - pad * 2, int(25 * u), col, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			if i > 0:
				draw_line(Vector2(pr.position.x + pad, y), Vector2(pr.end.x - pad, y), Color(1, 1, 1, 0.07 * ra), 1.0)
			_txt_at(str(r[0]), pr.position.x + pad, ty, pw - pad * 2, int(28 * u), Color(1, 1, 1, 0.75 * ra), HORIZONTAL_ALIGNMENT_LEFT)
			_txt_at(_row_value(r, rt), pr.position.x + pad, ty, pw - pad * 2, int(30 * u), col, HORIZONTAL_ALIGNMENT_RIGHT)
		y += rh
	var bw := 420.0 * u
	btn_rect = Rect2(cx - bw * 0.5, pr.end.y + 30 * u, bw, 96 * u)
	if end_t > report_done_t():
		_mil_btn(btn_rect, _t("tk_continue"), true)
