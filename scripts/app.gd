## Oksi Tanks: the standalone tank game. This script is the shell around the battle (scripts/tanks.gd):
## main menu, garage (battle setup, tanks, upgrades, arenas), settings, economy, music and the save file.
## The battle itself is the same code as the Tanks mode of Oksi Block; it talks to the shell through
## setup() / properties / the `finished` signal only.
extends Node2D

const Data = preload("res://scripts/tank_data.gd")
const Tanks = preload("res://scripts/tanks.gd")
const TankArt = preload("res://scripts/tank_art.gd")
const UI_GARAGE_BG = preload("res://art/ui/garage_bg.jpg")
const UI_PLATE = preload("res://art/ui/tk_plate.png")
const UI_PLATE_ON = preload("res://art/ui/tk_plate_on.png")
const UI_COIN = preload("res://art/ui/coin.png")
const UI_BANNER = preload("res://art/ui/m_tanks_banner.png")

## Own save file. Oksi Block uses user://save.cfg in its own app folder; this name is different on purpose,
## so a desktop run or a shared folder can never read or overwrite the puzzle game's progress.
const SAVE_PATH := "user://oksi_tanks_save.cfg"
const SAVE_VERSION := 1
## The wingman comes with VIP in Oksi Block. Oksi Tanks has no VIP yet: no wingman, and its upgrade is hidden.
const HELPER_ENABLED := false
const LANG_NAMES := {"en": "English", "ru": "Русский", "es": "Español", "de": "Deutsch", "fr": "Français",
	"pt": "Português (Brasil)", "it": "Italiano", "tr": "Türkçe", "pl": "Polski", "id": "Bahasa Indonesia",
	"ja": "日本語", "ko": "한국어", "zh": "繁體中文"}
const MUSIC_FADE := 2.0

enum Screen { MENU, GARAGE, SETTINGS }

# ---- progress (saved)
var coins := Data.START_COINS
var owned := {"tanks": ["classic"], "arenas": ["wasteland"]}
var equipped := {"tanks": "classic", "arenas": "wasteland"}
var upgrades := {"armor": 0, "speed": 0, "power": 0, "gun": 0, "ally": 0}
var tank_stage := 1
var tank_top := 1
var tank_diff := "normal"
var tank_map := "random"
var tank_best := {}
var boss_kills := 0
var battles := 0
var wins := 0
# ---- settings (saved)
var lang := "en"
var opt_sfx := true
var opt_music := true
var opt_vibe := true
var vol := {}

# ---- runtime
var screen := Screen.MENU
var garage_tab := "battle"
var tank_info := ""
var tanks_node: Node2D = null
var tank_test := false
var font: Font
var view := Vector2(720, 1280)
var u := 1.0
var anim_t := 0.0
var buttons: Array = []
var pressed_id := ""
var press_pos := Vector2.ZERO
var moved := 0.0
var list_scroll := 0.0
var list_max := 0.0
var txt_max := 0.0
var toasts: Array = []
var sounds := {}
var sfx_pool: Array = []
var sfx_idx := 0
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var mus_cur: AudioStreamPlayer = null
var mus_place := ""
var mus_path := ""
var slider_key := ""
var exit_armed_until := 0.0
var _text := {}
var _text_en := {}
var sb := StyleBoxFlat.new()


func _ready() -> void:
	_load()
	if lang == "":
		lang = OS.get_locale_language()
		if lang == "in":
			lang = "id"
		if not LANG_NAMES.has(lang):
			lang = "en"
	_load_text()
	_make_font()
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)
	music_a = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	add_child(music_a)
	add_child(music_b)
	sounds["click"] = load("res://audio/ui/click.wav")
	sounds["coin"] = load("res://audio/ui/coin.wav")
	for n in ["shot", "shot_big", "explode", "explode_small", "ricochet", "brick", "armor", "hit", "mine", "charge", "reload"]:
		var path := "res://audio/tank/%s.wav" % n
		if ResourceLoader.exists(path):
			sounds["t_" + n] = load(path)
	AudioServer.set_bus_volume_db(0, _gain_db("master"))
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	view = get_viewport_rect().size
	u = minf(view.x / 720.0, view.y / 1280.0)
	queue_redraw()


# ---------------------------------------------------------------- text

func _load_text() -> void:
	_text = _read_json("res://i18n/%s.json" % lang)
	_text_en = _read_json("res://i18n/en.json")


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func t(key: String) -> String:
	if _text.has(key):
		return str(_text[key])
	return str(_text_en.get(key, key))


func _make_font() -> void:
	var fv := FontVariation.new()
	# Days One has no Turkish/Polish letters: those languages use Rubik ExtraBold for whole words.
	var rubik: Font = load("res://fonts/rubik_xb.ttf")
	fv.base_font = rubik if lang in ["tr", "pl"] else load("res://fonts/daysone.ttf")
	var order := ["ja", "zh", "ko"]
	if order.has(lang):
		order.erase(lang)
		order.push_front(lang)
	var fbs: Array[Font] = [rubik]
	for l in order:
		var path := "res://fonts/cjk_%s.otf" % l
		if ResourceLoader.exists(path):
			fbs.append(load(path))
	fv.fallbacks = fbs
	font = fv


# ---------------------------------------------------------------- save / load

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	coins = maxi(0, int(cf.get_value("p", "coins", coins)))
	for k in ["tanks", "arenas"]:
		var lst: Array = cf.get_value("p", "owned_" + k, owned[k])
		owned[k] = lst.filter(func(id): return _item_known(k, str(id)))
		if not (owned[k] as Array).has(_shop_base(k)[0][0]):
			(owned[k] as Array).push_front(_shop_base(k)[0][0])
		var eq := str(cf.get_value("p", "equipped_" + k, equipped[k]))
		equipped[k] = eq if (owned[k] as Array).has(eq) else str(owned[k][0])
	var ups: Dictionary = cf.get_value("p", "upgrades", {})
	for k in upgrades:
		upgrades[k] = clampi(int(ups.get(k, 0)), 0, 3)
	tank_top = clampi(int(cf.get_value("p", "tank_top", 1)), 1, Data.TANK_MODE_MAX_STAGE)
	tank_stage = clampi(int(cf.get_value("p", "tank_stage", 1)), 1, tank_top)
	tank_diff = str(cf.get_value("p", "tank_diff", "normal"))
	if not Data.TANK_DIFFS.has(tank_diff):
		tank_diff = "normal"
	tank_map = str(cf.get_value("p", "tank_map", "random"))
	if tank_map != "random" and not Data.TANK_MAPS.has(tank_map):
		tank_map = "random"
	tank_best = cf.get_value("p", "tank_best", {})
	boss_kills = int(cf.get_value("p", "boss_kills", 0))
	battles = int(cf.get_value("p", "battles", 0))
	wins = int(cf.get_value("p", "wins", 0))
	lang = str(cf.get_value("s", "lang", ""))
	opt_sfx = bool(cf.get_value("s", "sfx", true))
	opt_music = bool(cf.get_value("s", "music", true))
	opt_vibe = bool(cf.get_value("s", "vibe", true))
	vol = cf.get_value("s", "vol", {})


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "version", SAVE_VERSION)
	cf.set_value("p", "coins", coins)
	for k in ["tanks", "arenas"]:
		cf.set_value("p", "owned_" + k, owned[k])
		cf.set_value("p", "equipped_" + k, equipped[k])
	cf.set_value("p", "upgrades", upgrades)
	cf.set_value("p", "tank_stage", tank_stage)
	cf.set_value("p", "tank_top", tank_top)
	cf.set_value("p", "tank_diff", tank_diff)
	cf.set_value("p", "tank_map", tank_map)
	cf.set_value("p", "tank_best", tank_best)
	cf.set_value("p", "boss_kills", boss_kills)
	cf.set_value("p", "battles", battles)
	cf.set_value("p", "wins", wins)
	cf.set_value("s", "lang", lang)
	cf.set_value("s", "sfx", opt_sfx)
	cf.set_value("s", "music", opt_music)
	cf.set_value("s", "vibe", opt_vibe)
	cf.set_value("s", "vol", vol)
	cf.save(SAVE_PATH)


func _item_known(kind: String, id: String) -> bool:
	for it in _shop_base(kind):
		if str(it[0]) == id:
			return true
	return false


# ---------------------------------------------------------------- economy

func _shop_base(kind: String) -> Array:
	return Data.SHOP_TANKS if kind == "tanks" else Data.SHOP_ARENAS


func _price(kind: String, id: String) -> int:
	for it in _shop_base(kind):
		if str(it[0]) == id:
			return int(it[1])
	return 0


func _has(kind: String, id: String) -> bool:
	return (owned[kind] as Array).has(id)


func _helper() -> bool:
	return HELPER_ENABLED


func _upgrade_list() -> Array:
	return Data.UPGRADE_ORDER.filter(func(id): return id != "ally" or HELPER_ENABLED)


func _tank_power() -> int:
	return Tanks.power_of(upgrades, _helper())


## Coins for a win at the chosen level and difficulty (the same ladder as the Tanks mode of Oksi Block).
func _tank_reward(stage := -1) -> int:
	var st := clampi(tank_stage if stage < 1 else stage, 1, Data.TANK_MODE_MAX_STAGE)
	var base := int(Data.TANK_MODE_COINS[mini(int((st - 1) / float(Data.TANK_STEP_LEVELS)), Data.TANK_MODE_COINS.size() - 1)])
	return clampi(int(round(base * float(Data.TANK_DIFF[tank_diff]["reward"]))), 1, Data.TANK_MODE_CAP)


func _tank_penalty() -> int:
	return _tank_reward()


func _shop_pick(kind: String, id: String) -> void:
	if not _item_known(kind, id):
		return
	if not _has(kind, id):
		var price := _price(kind, id)
		if price < 0:
			# Real-money tanks need their own Google Play products in this app (not set up yet).
			_toast(t("paid_soon"))
			return
		if coins < price:
			_toast(t("not_enough"))
			return
		coins -= price
		(owned[kind] as Array).append(id)
		_sfx("coin")
	equipped[kind] = id
	_save()


func _buy_upgrade(id: String) -> void:
	var lv := int(upgrades.get(id, 0))
	if lv >= 3 or not _upgrade_list().has(id):
		return
	var price := int(Data.TANK_UPGRADES[id][lv])
	if coins < price:
		_toast(t("not_enough"))
		return
	coins -= price
	upgrades[id] = lv + 1
	_sfx("coin")
	_save()


# ---------------------------------------------------------------- battle

func _new_battle_node() -> Node2D:
	var tk: Node2D = Tanks.new()
	tk.tr_fn = Callable(self, "t")
	tk.sfx = Callable(self, "_sfx")
	tk.vibe = Callable(self, "_vibe")
	tk.sfx_on = opt_sfx
	tk.engine_gain_db = _gain_db("s_engine") - 5.0
	tk.fuel = Data.FUEL_MAX  # Inferno burns with its shells: the flamethrower always starts full
	return tk


func _launch_battle() -> void:
	tank_test = false
	tanks_node = _new_battle_node()
	add_child(tanks_node)
	tanks_node.diff = tank_diff
	tanks_node.map_style = tank_map if tank_map != "random" else Data.TANK_MAPS[randi() % Data.TANK_MAPS.size()]
	tanks_node.track_best = true
	tanks_node.best_time = float(tank_best.get(_best_key(), 0.0))
	var sk := str(equipped["tanks"])
	tanks_node.perk = sk
	tanks_node.setup(tank_stage, font, Data.TANK_SKINS[sk], Data.ARENAS[str(equipped["arenas"])], int(Data.TANK_TIER.get(sk, 1)),
		Data.MINES_MAX, upgrades, false, _helper())
	tanks_node.reward = _tank_reward()
	tanks_node.penalty = mini(coins, _tank_penalty())
	tanks_node.player_sprite = TankArt.sprite_for_skin(sk)
	tanks_node.finished.connect(_on_battle_done)
	queue_redraw()


## Free test drive of any tank (also one not bought yet): no reward, no loss, no progress.
func _test_drive(sk: String) -> void:
	if not Data.TANK_SKINS.has(sk):
		return
	tank_test = true
	tank_info = ""
	tanks_node = _new_battle_node()
	add_child(tanks_node)
	tanks_node.perk = sk
	tanks_node.test_drive = true
	tanks_node.setup(1, font, Data.TANK_SKINS[sk], Data.ARENAS[str(equipped["arenas"])], int(Data.TANK_TIER.get(sk, 1)), 0,
		upgrades, true)
	tanks_node.player_sprite = TankArt.sprite_for_skin(sk)
	tanks_node.finished.connect(_on_battle_done)


func _best_key() -> String:
	return "%s/%s" % [tanks_node.map_style if tanks_node else tank_map, tank_diff]


func _on_battle_done(win: bool) -> void:
	if tanks_node == null:
		return
	var test := tank_test
	if not test:
		battles += 1
		boss_kills += int(tanks_node.st.get("boss_p", 0))
		if win and tanks_node.track_best and tanks_node.new_record:
			tank_best[_best_key()] = snappedf(float(tanks_node.st.get("time", 0.0)), 0.01)
	tanks_node.queue_free()
	tanks_node = null
	tank_test = false
	if test:
		queue_redraw()
		return
	if win:
		wins += 1
		coins += _tank_reward()
		if tank_stage == tank_top:
			tank_top = mini(tank_top + 1, Data.TANK_MODE_MAX_STAGE)
		tank_stage = mini(tank_stage + 1, tank_top)
		_sfx("coin")
	else:
		var lost := mini(coins, _tank_penalty())
		coins -= lost
		if lost > 0:
			_toast("−%d" % lost)
	screen = Screen.GARAGE
	garage_tab = "battle"
	_save()
	queue_redraw()


# ---------------------------------------------------------------- sound

func _gain_db(key: String) -> float:
	if key == "":
		return 0.0
	var v := float(vol.get(key, Data.VOL_DEFAULT))
	if v <= 0.0:
		return -80.0
	if v > Data.VOL_DEFAULT:
		return (v - Data.VOL_DEFAULT) * 0.3
	return linear_to_db(v / Data.VOL_DEFAULT)


func _sfx(n: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not opt_sfx or not sounds.has(n) or sounds[n] == null:
		return
	var g := (_gain_db("s_tank") - 3.0) if n.begins_with("t_") else _gain_db("s_game")
	if g < -70.0:
		return
	var p: AudioStreamPlayer = sfx_pool[sfx_idx]
	sfx_idx = (sfx_idx + 1) % sfx_pool.size()
	p.stream = sounds[n]
	p.pitch_scale = pitch
	p.volume_db = vol_db + g
	p.play()


func _vibe(ms: int) -> void:
	if opt_vibe:
		Input.vibrate_handheld(ms)


func _wanted_music() -> String:
	if tanks_node:
		if tanks_node.state == "won":
			return "win"
		if tanks_node.state == "lost":
			return "lose"
		return "boss" if tanks_node.boss_alive() else "battle"
	return "garage"


func _place_db(place: String) -> float:
	return float(Data.MUSIC_DB.get(place, -6.0)) + _gain_db(str(Data.VOL_OF_PLACE.get(place, "")))


func _music_tick() -> void:
	if not opt_music:
		if mus_cur:
			music_a.stop()
			music_b.stop()
			mus_cur = null
			mus_place = ""
		return
	var want := _wanted_music()
	if want == mus_place and mus_cur and mus_cur.playing:
		return
	var list: Array = Data.MUSIC.get(want, [])
	if list.is_empty():
		return
	var quick: bool = Data.MUSIC_QUICK.has(want)
	mus_place = want
	mus_path = "res://audio/%s.ogg" % str(list[randi() % list.size()])
	var m = load(mus_path)
	if m is AudioStreamOggVorbis:
		m = (m as AudioStreamOggVorbis).duplicate()
		m.loop = true
	var nxt := music_b if mus_cur == music_a else music_a
	var old := mus_cur
	nxt.stop()
	nxt.stream = m
	nxt.volume_db = -40.0
	nxt.play()
	create_tween().tween_property(nxt, "volume_db", _place_db(want), 0.6 if quick else MUSIC_FADE)
	if old and old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -60.0, 1.2 if quick else MUSIC_FADE)
		tw.tween_callback(old.stop)
	mus_cur = nxt


# ---------------------------------------------------------------- loop / input

func _process(delta: float) -> void:
	anim_t += delta
	for tt in toasts:
		tt["t"] = float(tt["t"]) + delta
	if not toasts.is_empty() and float(toasts[0]["t"]) > 2.6:
		toasts.pop_front()
	_music_tick()
	if tanks_node == null:
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if tanks_node:
			tanks_node.pause()
		_save()


func _on_back() -> void:
	if tanks_node:
		tanks_node.pause()
		return
	if tank_info != "":
		tank_info = ""
	elif screen != Screen.MENU:
		screen = Screen.MENU
	elif Time.get_ticks_msec() / 1000.0 < exit_armed_until:
		_save()
		get_tree().quit()
	else:
		exit_armed_until = Time.get_ticks_msec() / 1000.0 + 2.5
		_toast(t("exit_again"))


func _input(event: InputEvent) -> void:
	if tanks_node:
		return  # the battle reads its own touches
	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.pressed:
			moved = 0.0
			press_pos = te.position
			pressed_id = _button_at(te.position)
			if pressed_id.begins_with("vol_"):
				slider_key = pressed_id.trim_prefix("vol_")
				_slider_set(te.position.x)
		else:
			var id := _button_at(te.position)
			if slider_key != "":
				slider_key = ""
				_save()
			elif id != "" and id == pressed_id:
				_sfx("click")
				_on_button(id)
			pressed_id = ""
	elif event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		if slider_key != "":
			_slider_set(de.position.x)
			return
		moved += absf(de.relative.y)
		if _scrollable():
			list_scroll = clampf(list_scroll - de.relative.y, 0.0, list_max)
		if moved > 18.0 * u:
			pressed_id = ""


func _scrollable() -> bool:
	return screen == Screen.GARAGE and garage_tab in ["tanks", "arenas"] and tank_info == ""


func _button_at(p: Vector2) -> String:
	for i in range(buttons.size() - 1, -1, -1):
		if (buttons[i]["rect"] as Rect2).has_point(p):
			return str(buttons[i]["id"])
	return ""


func _slider_set(x: float) -> void:
	var r := _slider_rect(slider_key)
	vol[slider_key] = int(round(clampf((x - r.position.x) / r.size.x, 0.0, 1.0) * 100.0))
	AudioServer.set_bus_volume_db(0, _gain_db("master"))
	if mus_cur and mus_place != "":
		mus_cur.volume_db = _place_db(mus_place)


func _on_button(id: String) -> void:
	match id:
		"back":
			_on_back()
			return
		"m_battle":
			screen = Screen.GARAGE
			garage_tab = "battle"
		"m_garage":
			screen = Screen.GARAGE
			garage_tab = "tanks"
		"m_settings":
			screen = Screen.SETTINGS
		"g_battle":
			_launch_battle()
		"gstage_prev":
			tank_stage = maxi(1, tank_stage - 1)
		"gstage_next":
			if tank_stage < tank_top:
				tank_stage += 1
			else:
				_toast(t("tk_stage_locked") % tank_stage)
		"gmap_prev", "gmap_next":
			var maps: Array = ["random"] + Data.TANK_MAPS
			tank_map = str(maps[posmod(maps.find(tank_map) + (1 if id.ends_with("next") else -1), maps.size())])
		"gdiff_prev", "gdiff_next":
			tank_diff = str(Data.TANK_DIFFS[posmod(Data.TANK_DIFFS.find(tank_diff) + (1 if id.ends_with("next") else -1), Data.TANK_DIFFS.size())])
		"tinfo_close":
			tank_info = ""
		"opt_sfx":
			opt_sfx = not opt_sfx
		"opt_music":
			opt_music = not opt_music
		"opt_vibe":
			opt_vibe = not opt_vibe
		"lang_prev", "lang_next":
			var ls: Array = Data.LANGS
			lang = str(ls[posmod(ls.find(lang) + (1 if id.ends_with("next") else -1), ls.size())])
			_load_text()
			_make_font()
		_:
			if id.begins_with("gtab_"):
				garage_tab = id.trim_prefix("gtab_")
				list_scroll = 0.0
			elif id.begins_with("sk_tanks_"):
				_shop_pick("tanks", id.trim_prefix("sk_tanks_"))
			elif id.begins_with("sk_arenas_"):
				_shop_pick("arenas", id.trim_prefix("sk_arenas_"))
			elif id.begins_with("sup_"):
				_buy_upgrade(id.trim_prefix("sup_"))
			elif id.begins_with("tinfo_"):
				tank_info = id.trim_prefix("tinfo_")
			elif id.begins_with("tdrive_"):
				_test_drive(id.trim_prefix("tdrive_"))
			return
	_save()
	queue_redraw()


func _toast(text: String) -> void:
	for tt in toasts:
		if str(tt["text"]) == text:
			return
	if toasts.size() < 5:
		toasts.append({"text": text, "t": 0.0})


# ---------------------------------------------------------------- drawing helpers

func _rbox(r: Rect2, col: Color, rad: float, border: Color = Color(0, 0, 0, 0), bw: float = 0.0) -> void:
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	sb.bg_color = col
	sb.set_corner_radius_all(int(minf(rad, minf(r.size.x, r.size.y) * 0.5)))
	sb.set_border_width_all(int(bw))
	sb.border_color = border
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _txt(s: String, cx: float, baseline: float, size: int, color: Color, outline: int = 0) -> void:
	var lim := txt_max if txt_max > 0.0 else view.x - 40.0 * u
	var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if tw > lim and tw > 0.0:
		size = maxi(int(size * lim / tw), 10)
	var w := view.x * 2.0
	var pos := Vector2(cx - w * 0.5, baseline)
	if outline > 0:
		draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, outline, Color(0, 0, 0, 0.85))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, color)


## Cartoon 3D text: a thick dark edge, a darker "side" under it (depth) and a bright face on top.
func _txt3d(s: String, cx: float, baseline: float, size: int, face: Color, edge: Color) -> void:
	var w := view.x * 2.0
	var pos := Vector2(cx - w * 0.5, baseline)
	var ow := maxi(2, int(size * 0.2))
	draw_string_outline(font, pos + Vector2(0, size * 0.11), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, ow, edge.darkened(0.3))
	draw_string(font, pos + Vector2(0, size * 0.11), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, edge)
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, ow, edge)
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, face)


## Armour plate with a riveted bracket in the middle (the same plate slicing as the Oksi Block tank screens).
func _plate5(tex: Texture2D, r: Rect2, mod: Color = Color.WHITE) -> void:
	var th_ := float(tex.get_height())
	var tw := float(tex.get_width())
	var k := r.size.y / th_
	var cap := th_ * 0.6
	var c0 := tw * 0.36
	var c1 := tw * 0.64
	var dc := cap * k
	var dm := (c1 - c0) * k
	if r.size.x < dc * 2.0 + dm + 8.0:
		dc = minf(dc, r.size.x * 0.5)
		draw_texture_rect_region(tex, Rect2(r.position, Vector2(dc, r.size.y)), Rect2(0, 0, cap, th_), mod)
		draw_texture_rect_region(tex, Rect2(r.position.x + dc, r.position.y, r.size.x - 2.0 * dc, r.size.y), Rect2(cap, 0, tw - 2.0 * cap, th_), mod)
		draw_texture_rect_region(tex, Rect2(r.end.x - dc, r.position.y, dc, r.size.y), Rect2(tw - cap, 0, cap, th_), mod)
		return
	var side := (r.size.x - dc * 2.0 - dm) * 0.5
	var x := r.position.x
	var y := r.position.y
	var h := r.size.y
	draw_texture_rect_region(tex, Rect2(x, y, dc, h), Rect2(0, 0, cap, th_), mod)
	draw_texture_rect_region(tex, Rect2(x + dc, y, side, h), Rect2(cap, 0, c0 - cap, th_), mod)
	draw_texture_rect_region(tex, Rect2(x + dc + side, y, dm, h), Rect2(c0, 0, c1 - c0, th_), mod)
	draw_texture_rect_region(tex, Rect2(x + dc + side + dm, y, side, h), Rect2(c1, 0, tw - cap - c1, th_), mod)
	draw_texture_rect_region(tex, Rect2(r.end.x - dc, y, dc, h), Rect2(tw - cap, 0, cap, th_), mod)


func _btn(id: String, r: Rect2, label: String, primary: bool = true, enabled: bool = true) -> void:
	var rr := r
	if pressed_id == id:
		rr.position.y += 4 * u
	_plate5(UI_PLATE_ON if primary and enabled else UI_PLATE, rr, Color.WHITE if enabled else Color(0.55, 0.55, 0.55))
	var size := int(minf(r.size.y * 0.42, 46 * u))
	if label == "‹" or label == "›":
		size = int(r.size.y * 0.62)
	var room := r.size.x - 28 * u
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if tw > room and tw > 0.0:
		size = maxi(int(size * room / tw), int(14 * u))
	var col := Color.WHITE if enabled else Color(0.85, 0.85, 0.8, 0.75)
	_txt3d(label, rr.get_center().x, rr.get_center().y + size * 0.3 - r.size.y * 0.04, size, col, Color("1c1408") if primary else Color("10140a"))
	if enabled:
		buttons.append({"id": id, "rect": r})


func _round_btn(id: String, c: Vector2, r: float, label: String) -> void:
	draw_circle(c + Vector2(0, r * 0.15), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, Color("3b4a2a"))
	draw_arc(c, r, 0, TAU, 24, Color("c9a640"), maxf(2.0, 3 * u))
	_txt(label, c.x, c.y + r * 0.4, int(r * 1.1), Color.WHITE)
	buttons.append({"id": id, "rect": Rect2(c - Vector2(r, r) * 1.2, Vector2(r, r) * 2.4)})


func _coin(c: Vector2, r: float) -> void:
	var rr := r * 1.12
	draw_texture_rect(UI_COIN, Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false)


## Text followed by a coin, centered together.
func _txt_coin(s: String, cx: float, baseline: float, size: int, color: Color, outline: int = 0) -> void:
	var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var r := size * 0.42
	var shift := r + 6 * u
	_txt(s, cx - shift, baseline, size, color, outline)
	_coin(Vector2(cx - shift + tw * 0.5 + 8 * u + r, baseline - size * 0.36), r)


func _coins_pill(right: float, cy: float) -> void:
	var s := str(coins)
	var size := int(34 * u)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 90 * u
	var r := Rect2(right - w, cy - 32 * u, w, 64 * u)
	_rbox(r, Color(0, 0, 0, 0.55), 32 * u, Color("c9a640"), 3 * u)
	_coin(Vector2(r.position.x + 34 * u, cy), 22 * u)
	_txt(s, r.position.x + 56 * u + (w - 70 * u) * 0.5, cy + 12 * u, size, Color("ffe08a"))


func _tank_icon(c: Vector2, s: float, sprite: String) -> void:
	TankArt.draw(self, sprite, c + Vector2(0, s * 0.07), s * 0.8, PI * 0.5, 0, Color(0, 0, 0, 0.35))
	TankArt.draw(self, sprite, c, s * 0.8, PI * 0.5, 0)


func _backdrop() -> void:
	var sc := maxf(view.x / UI_GARAGE_BG.get_width(), view.y / UI_GARAGE_BG.get_height())
	var org := (view - Vector2(UI_GARAGE_BG.get_width(), UI_GARAGE_BG.get_height()) * sc) * 0.5
	draw_texture_rect(UI_GARAGE_BG, Rect2(org, Vector2(UI_GARAGE_BG.get_width(), UI_GARAGE_BG.get_height()) * sc), false, Color(0.8, 0.8, 0.8))


func _title_bar(title: String) -> void:
	_btn("back", Rect2(30 * u, 40 * u, 190 * u, 70 * u), "‹ " + t("back"), false)
	_coins_pill(view.x - 30 * u, 75 * u)
	_txt(title, view.x * 0.5, 200 * u, int(64 * u), Color("f3e7c4"), int(10 * u))


## A "‹ value ›" row: buttons <id>_prev / <id>_next around a label.
func _selector(id: String, r: Rect2, label: String) -> void:
	_rbox(r, Color(0, 0, 0, 0.35), 16 * u)
	var bw := r.size.y * 1.1
	_btn(id + "_prev", Rect2(r.position, Vector2(bw, r.size.y)), "‹", false)
	_btn(id + "_next", Rect2(r.end.x - bw, r.position.y, bw, r.size.y), "›", false)
	var keep := txt_max
	txt_max = r.size.x - bw * 2.2
	_txt(label, r.get_center().x, r.get_center().y + 10 * u, int(28 * u), Color("f3e7c4"))
	txt_max = keep


# ---------------------------------------------------------------- screens

func _draw() -> void:
	buttons.clear()
	if tanks_node:
		return  # the battle draws the whole screen
	_backdrop()
	match screen:
		Screen.MENU:
			_draw_menu()
		Screen.GARAGE:
			_draw_garage()
		Screen.SETTINGS:
			_draw_settings()
	if tank_info != "":
		_draw_tank_info()
	_draw_toasts()


func _draw_menu() -> void:
	var cx := view.x * 0.5
	_coins_pill(view.x - 30 * u, 75 * u)
	var bw := minf(view.x - 80 * u, 640 * u)
	var bh := bw * UI_BANNER.get_height() / float(UI_BANNER.get_width())
	draw_texture_rect(UI_BANNER, Rect2(cx - bw * 0.5, 150 * u, bw, bh), false)
	_txt3d(t("app_title"), cx, 150 * u + bh + 110 * u, int(84 * u), Color("ffd35a"), Color("3a2508"))
	_tank_icon(Vector2(cx, 150 * u + bh + 260 * u + sin(anim_t * 2.0) * 4 * u), 220 * u, TankArt.sprite_for_skin(str(equipped["tanks"])))
	var y := view.y - 470 * u
	var w := view.x - 160 * u
	_btn("m_battle", Rect2(cx - w * 0.5, y, w, 110 * u), t("menu_battle"))
	_btn("m_garage", Rect2(cx - w * 0.5, y + 135 * u, w, 96 * u), t("menu_garage"), false)
	_btn("m_settings", Rect2(cx - w * 0.5, y + 255 * u, w, 96 * u), t("settings"), false)
	_txt(t("tk_stage") % tank_top + " · " + t("tk_r_boss") + ": %d" % boss_kills, cx, view.y - 50 * u, int(22 * u), Color(1, 1, 1, 0.6))


func _draw_garage() -> void:
	var top := 340.0 * u
	match garage_tab:
		"tanks", "arenas":
			_draw_shop_grid(garage_tab, top)
			_cover_top(top - 14 * u)
		"upgrades":
			_draw_upgrades(top)
		_:
			_draw_garage_battle(top)
	_title_bar(t("menu_garage"))
	var tabs := ["battle", "tanks", "upgrades", "arenas"]
	var tw := (view.x - 40 * u) / 4.0
	for i in tabs.size():
		_btn("gtab_" + tabs[i], Rect2(20 * u + i * tw + 3 * u, 240 * u, tw - 6 * u, 66 * u), t("tab_" + tabs[i]), garage_tab == tabs[i])


func _cover_top(cut: float) -> void:
	if list_scroll <= 0.0:
		return
	var sc := maxf(view.x / UI_GARAGE_BG.get_width(), view.y / UI_GARAGE_BG.get_height())
	var org := (view - Vector2(UI_GARAGE_BG.get_width(), UI_GARAGE_BG.get_height()) * sc) * 0.5
	draw_texture_rect_region(UI_GARAGE_BG, Rect2(0, 0, view.x, cut), Rect2(-org.x / sc, -org.y / sc, view.x / sc, cut / sc), Color(0.8, 0.8, 0.8))
	draw_rect(Rect2(0, cut, view.x, 6 * u), Color(0, 0, 0, 0.2))


func _draw_garage_battle(top: float) -> void:
	var cx := view.x * 0.5
	var ar: Dictionary = Data.ARENAS[str(equipped["arenas"])]
	var pr := Rect2(40 * u, top, view.x - 80 * u, 250 * u)
	_rbox(Rect2(pr.position + Vector2(0, 8 * u), pr.size), Color(0, 0, 0, 0.35), 22 * u)
	_rbox(pr, ar.get("bg", Color("0d1014")), 22 * u, Color("b8902a"), 5 * u)
	for i in 6:
		draw_rect(Rect2(pr.position.x + 30 * u + i * (pr.size.x - 60 * u) / 6.0, pr.end.y - 46 * u, (pr.size.x - 60 * u) / 6.0 - 6 * u, 26 * u),
			ar.get("brick", Color("b5532b")))
	_tank_icon(pr.get_center() + Vector2(0, sin(anim_t * 3.0) * 3 * u - 20 * u), 150 * u, TankArt.sprite_for_skin(str(equipped["tanks"])))
	var y := pr.end.y + 60 * u
	var sw := view.x - 120 * u
	_selector("gstage", Rect2(cx - sw * 0.5, y - 44 * u, sw, 64 * u), t("tk_stage") % tank_stage + " / %d" % Data.TANK_MODE_MAX_STAGE)
	var w := Tanks.wave(tank_stage, _tank_power(), tank_diff)
	y += 52 * u
	_txt(t("tk_wave") % [int(w["enemies"]), int(w["elvl"])], cx, y, int(26 * u), Color(1, 1, 1, 0.7))
	y += 24 * u
	_selector("gmap", Rect2(cx - sw * 0.5, y, sw, 64 * u), t("tk_map") + ": " + t("map_" + tank_map))
	y += 74 * u
	_selector("gdiff", Rect2(cx - sw * 0.5, y, sw, 64 * u), t("tk_diff") + ": " + t("diff_" + tank_diff))
	y += 112 * u
	_txt_coin(t("tk_win_rule") % _tank_reward(), cx, y, int(32 * u), Color("5fd35a"), int(5 * u))
	y += 44 * u
	_txt_coin(t("tk_lose_rule") % _tank_penalty(), cx, y, int(28 * u), Color("ff8a80"), int(4 * u))
	y += 50 * u
	_txt(t("tk_mines_std") % Data.MINES_MAX, cx, y, int(24 * u), Color(1, 1, 1, 0.7))
	var bw := view.x - 120 * u
	_btn("g_battle", Rect2(cx - bw * 0.5, minf(y + 40 * u, view.y - 140 * u), bw, 100 * u), t("tk_start"))


func _draw_shop_grid(kind: String, top: float) -> void:
	var items := _shop_base(kind)
	var margin := 40.0 * u
	var cw := (view.x - margin * 3) * 0.5
	var ch := cw * 0.82
	list_max = maxf(0.0, top + ceilf(items.size() / 2.0) * (ch + 28 * u) + 20 * u - view.y)
	list_scroll = clampf(list_scroll, 0.0, list_max)
	for i in items.size():
		var id: String = items[i][0]
		var price := int(items[i][1])
		var r := Rect2(margin + (i % 2) * (cw + margin), top + int(i / 2.0) * (ch + 28 * u) - list_scroll, cw, ch)
		if r.end.y < top - 40 * u or r.position.y > view.y:
			continue
		var on: bool = str(equipped[kind]) == id
		var have := _has(kind, id)
		# olive armour cards with a brass edge, the chosen one glows orange
		_rbox(r, Color(0.13, 0.15, 0.09, 0.93), 14 * u, Color("ff9a1f") if on else Color("8a7a3a"), (5 if on else 2) * u)
		var pc := r.position + Vector2(cw * 0.5, ch * (0.3 if kind == "tanks" else 0.36))
		if kind == "tanks":
			_tank_icon(pc, cw * 0.32, TankArt.sprite_for_skin(id))
		else:
			var ar: Dictionary = Data.ARENAS[id]
			var ps := cw * 0.16
			var o := pc - Vector2(ps * 2, ps * 0.5)
			draw_rect(Rect2(o - Vector2(4, 4) * u, Vector2(ps * 4, ps) + Vector2(8, 8) * u), ar["frame"])
			var cols := [ar["bg"], ar["brick"], ar["steel"], ar["bush"]]
			for k in 4:
				draw_rect(Rect2(o + Vector2(k * ps, 0), Vector2(ps, ps)), cols[k])
		var sy := r.position.y + ch * 0.9
		var name := t(("tank_" if kind == "tanks" else "ar_") + id)
		if kind == "tanks":
			_txt(name, r.get_center().x, r.position.y + ch * 0.64, int(28 * u), Color("f3e7c4"))
			var keep := txt_max
			txt_max = r.size.x - 16 * u
			_txt(t("tag_" + id), r.get_center().x, r.position.y + ch * 0.78, int(21 * u), Color("ffd35a") if id == "neon" else Color(1, 1, 1, 0.65))
			txt_max = keep
			sy = r.position.y + ch * 0.93
		else:
			_txt(name, r.get_center().x, r.position.y + ch * 0.72, int(28 * u), Color("f3e7c4"))
		if on:
			_txt(t("selected"), r.get_center().x, sy, int(24 * u), Color("ff9a1f"))
		elif have:
			_txt(t("select"), r.get_center().x, sy, int(24 * u), Color("ff9a1f"))
		elif price < 0:
			_txt(t("paid_soon"), r.get_center().x, sy, int(20 * u), Color("ffd54a"))
		else:
			var pw := font.get_string_size(str(price), HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * u)).x
			_coin(Vector2(r.get_center().x + 10 * u - pw * 0.5 - 20 * u, sy - 9 * u), 14 * u)
			_txt(str(price), r.get_center().x + 10 * u, sy, int(26 * u), Color.WHITE if coins >= price else Color(1, 1, 1, 0.5))
		if r.get_center().y > top:
			if not on:
				buttons.append({"id": "sk_" + kind + "_" + id, "rect": r})
			if kind == "tanks":
				_round_btn("tinfo_" + id, r.position + Vector2(36 * u, 36 * u), 22 * u, "i")
				_round_btn("tdrive_" + id, r.position + Vector2(cw - 36 * u, 36 * u), 22 * u, "▶")


func _draw_upgrades(top: float) -> void:
	_txt(t("up_title"), view.x * 0.5, top + 20 * u, int(26 * u), Color(1, 1, 1, 0.7))
	var list := _upgrade_list()
	var accent := Color("ff9a1f")
	for i in list.size():
		var id: String = list[i]
		var lv := int(upgrades[id])
		var r := Rect2(40 * u, top + 45 * u + i * 128 * u, view.x - 80 * u, 118 * u)
		_rbox(r, Color(0.13, 0.15, 0.09, 0.93), 14 * u, Color("8a7a3a"), 2 * u)
		var c := r.position + Vector2(70 * u, 59 * u)
		draw_circle(c, 44 * u, Color("3b4a2a"))
		match id:
			"armor":
				draw_arc(c, 26 * u, -PI * 0.9, -PI * 0.1, 16, accent, 9 * u)
				draw_arc(c, 26 * u, PI * 0.1, PI * 0.9, 16, accent, 9 * u)
			"speed":
				for k in 2:
					var o := Vector2((k - 0.5) * 22, 0) * u
					draw_polyline(PackedVector2Array([c + o + Vector2(-10, -20) * u, c + o + Vector2(10, 0) * u, c + o + Vector2(-10, 20) * u]), accent, 8 * u)
			"power":
				draw_arc(c, 26 * u, 0, TAU, 24, accent, 6 * u)
				draw_line(c, c + Vector2(0, -18) * u, accent, 5 * u)
				draw_line(c, c + Vector2(13, 6) * u, accent, 5 * u)
			"ally":
				_tank_icon(c, 52 * u, "ally")
			_:
				draw_rect(Rect2(c + Vector2(-30, -9) * u, Vector2(46, 18) * u), accent)
				draw_rect(Rect2(c + Vector2(14, -13) * u, Vector2(14, 26) * u), accent)
				draw_circle(c + Vector2(-20, 0) * u, 14 * u, accent)
		var tx := r.position.x + 135 * u
		var room := r.size.x - 135 * u - 200 * u
		draw_string(font, Vector2(tx, r.position.y + 46 * u), t("up_" + id), HORIZONTAL_ALIGNMENT_LEFT, room, int(30 * u), Color("f3e7c4"))
		draw_string(font, Vector2(tx, r.position.y + 78 * u), t("up_" + id + "_d"), HORIZONTAL_ALIGNMENT_LEFT, room, int(20 * u), Color(1, 1, 1, 0.65))
		for k in 3:
			_rbox(Rect2(tx + k * 44 * u, r.position.y + 92 * u, 36 * u, 14 * u), accent if k < lv else Color(1, 1, 1, 0.2), 7 * u)
		var br := Rect2(r.end.x - 175 * u, r.position.y + 28 * u, 155 * u, 62 * u)
		if lv >= 3:
			_txt(t("up_max"), br.get_center().x, br.get_center().y + 10 * u, int(28 * u), accent)
		else:
			var price := int(Data.TANK_UPGRADES[id][lv])
			_btn("sup_" + id, br, "   " + str(price), true, coins >= price)
			_coin(Vector2(br.position.x + 38 * u, br.get_center().y), 16 * u)
	_btn("tdrive_" + str(equipped["tanks"]), Rect2(40 * u, top + 55 * u + list.size() * 128 * u, view.x - 80 * u, 86 * u),
		"▶ " + t("test_drive"), false)


func _panel(h: float) -> Rect2:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.6))
	var pw := minf(view.x * 0.86, 600.0 * u)
	var r := Rect2((view.x - pw) * 0.5, (view.y - h) * 0.5, pw, h)
	_rbox(Rect2(r.position + Vector2(0, 14 * u), r.size), Color(0, 0, 0, 0.35), 24 * u)
	_rbox(r, Color(0.13, 0.15, 0.09, 0.97), 22 * u, Color("b8902a"), 6 * u)
	txt_max = pw - 48.0 * u
	return r


## The ability panel of a tank (opened with the "i" on its card).
func _draw_tank_info() -> void:
	buttons.clear()  # the panel is modal
	var cx := view.x * 0.5
	var lines: PackedStringArray = t("tperk_" + tank_info).split("|")
	var p := _panel((470 + lines.size() * 46) * u)
	var bw := p.size.x * 0.76
	_tank_icon(Vector2(cx, p.position.y + 100 * u), 130 * u, TankArt.sprite_for_skin(tank_info))
	_txt(t("tank_" + tank_info), cx, p.position.y + 215 * u, int(42 * u), Color("f3e7c4"), int(6 * u))
	_txt(t("tag_" + tank_info), cx, p.position.y + 258 * u, int(24 * u), Color("ff9a1f"))
	var y := p.position.y + 312 * u
	for ln in lines:
		_txt("• " + ln, cx, y, int(25 * u), Color.WHITE)
		y += 46 * u
	y += 10 * u
	_btn("tdrive_" + tank_info, Rect2(cx - bw * 0.5, y, bw * 0.49, 80 * u), "▶ " + t("tinfo_try"), false)
	_btn("tinfo_close", Rect2(cx + bw * 0.01, y, bw * 0.49, 80 * u), t("tinfo_close"), true)
	txt_max = 0.0


const SLIDERS := ["master", "m_garage", "m_battle", "m_boss", "m_end", "s_tank", "s_engine"]


func _slider_rect(key: String) -> Rect2:
	var i := SLIDERS.find(key)
	return Rect2(80 * u, 760 * u + i * 66 * u, view.x - 160 * u, 18 * u)


func _draw_settings() -> void:
	_title_bar(t("settings"))
	var cx := view.x * 0.5
	var w := view.x - 120 * u
	_selector("lang", Rect2(cx - w * 0.5, 280 * u, w, 70 * u), t("language") + ": " + str(LANG_NAMES.get(lang, lang)))
	var opts := [["opt_music", "music", opt_music], ["opt_sfx", "sounds", opt_sfx], ["opt_vibe", "vibration", opt_vibe]]
	for i in opts.size():
		var on: bool = opts[i][2]
		_btn(str(opts[i][0]), Rect2(cx - w * 0.5, 380 * u + i * 96 * u, w, 80 * u), t(str(opts[i][1])) + ": " + (t("on") if on else t("off")), on)
	_txt(t("snd_volume"), cx, 720 * u, int(30 * u), Color("f3e7c4"))
	for key in SLIDERS:
		var r := _slider_rect(key)
		var v := float(vol.get(key, Data.VOL_DEFAULT)) / 100.0
		draw_string(font, r.position - Vector2(0, 10 * u), t("vol_" + key), HORIZONTAL_ALIGNMENT_LEFT, r.size.x, int(20 * u), Color(1, 1, 1, 0.75))
		_rbox(r, Color(0, 0, 0, 0.5), 9 * u)
		_rbox(Rect2(r.position, Vector2(r.size.x * v, r.size.y)), Color("ff9a1f"), 9 * u)
		draw_circle(Vector2(r.position.x + r.size.x * v, r.get_center().y), 16 * u, Color("ffd35a"))
		buttons.append({"id": "vol_" + key, "rect": r.grow(22 * u)})


func _draw_toasts() -> void:
	if toasts.is_empty():
		return
	var s := str(toasts[0]["text"])
	var size := int(28 * u)
	var tw := minf(font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 60 * u, view.x - 40 * u)
	var r := Rect2((view.x - tw) * 0.5, view.y - 230 * u, tw, 70 * u)
	_rbox(r, Color(0, 0, 0, 0.8), 35 * u, Color("c9a640"), 2 * u)
	var keep := txt_max
	txt_max = tw - 40 * u
	_txt(s, view.x * 0.5, r.get_center().y + 10 * u, size, Color.WHITE)
	txt_max = keep
