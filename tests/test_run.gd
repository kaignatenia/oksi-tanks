extends SceneTree
## Headless test of Oksi Tanks: the shell (menu, garage, economy, save) and the battle mechanics.
## Run: godot --headless --path . --script res://tests/test_run.gd
## The battle-mechanics block is taken over unchanged from the Oksi Block test (tools/test_run.gd).

var game
var step := 0
var fails := 0


func _initialize() -> void:
	# Never touch a real save: start from an empty one.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://oksi_tanks_save.cfg"))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		fails += 1
		print("FAIL ", msg)


func _process(_delta: float) -> bool:
	step += 1
	if step == 3:
		shell_tests()
	elif step == 4:
		battle_start()
	elif step > 4 and step < 64:
		pass  # the battle runs for real for 60 frames
	elif step == 64:
		battle_end()
	elif step == 66:
		mechanics_tests()
	elif step == 67:
		super_tests()
	elif step == 68:
		wave4_tests()
	elif step == 70:
		save_tests()
	elif step > 72:
		print("TEST DONE, fails: ", fails)
		return true
	return false


func shell_tests() -> void:
	check(game.SAVE_PATH != "user://save.cfg" and ProjectSettings.get_setting("application/config/name") == "Oksi Tanks",
		"own app name and own save file (never Oksi Block's user://save.cfg)")
	check(game.screen == game.Screen.MENU and game.coins == game.Data.START_COINS and game.tank_stage == 1, "fresh start on the main menu")
	check(not ResourceLoader.exists("res://scripts/game.gd") and not ResourceLoader.exists("res://scripts/data.gd"), "no Oksi Block code in the project")
	game._on_button("m_battle")
	check(game.screen == game.Screen.GARAGE and game.garage_tab == "battle", "menu opens the battle setup")
	game._on_button("gstage_next")
	check(game.tank_stage == 1, "levels above the highest opened cannot be chosen")
	game._on_button("gdiff_next")
	check(game.tank_diff == "hard", "difficulty selector")
	game._on_button("gdiff_prev")
	game._on_button("gmap_next")
	check(game.tank_map == game.Data.TANK_MAPS[0], "map selector")
	game._on_button("gmap_prev")
	var lad := []
	for lv in [1, 10, 11, 20, 21, 100]:
		lad.append(game._tank_reward(lv))
	check(lad == [1, 1, 3, 3, 5, 50], "coins grow every 10 levels up to 50 at level 100 " + str(lad))
	game.tank_diff = "expert"
	check(game._tank_reward(100) == game.Data.TANK_MODE_CAP and game._tank_reward(11) == 6, "difficulty multiplies, the cap holds")
	game.tank_diff = "normal"
	# shop: not enough coins, then buy and equip
	game._on_button("gtab_tanks")
	game._on_button("sk_tanks_arctic")
	check(not game._has("tanks", "arctic") and game.coins == 0, "a tank cannot be bought without coins")
	game.coins = 1500
	game._on_button("sk_tanks_arctic")
	check(game._has("tanks", "arctic") and game.equipped["tanks"] == "arctic" and game.coins == 300, "a tank is bought for coins and equipped")
	game._on_button("sk_tanks_neon")
	check(not game._has("tanks", "neon") and game.coins == 300, "real-money tanks are not sold here until their Play products exist")
	game._on_button("sk_tanks_classic")
	check(game.equipped["tanks"] == "classic" and game.coins == 300, "an owned tank is equipped for free")
	game._on_button("sk_tanks_nonexistent")
	check(game.equipped["tanks"] == "classic", "an unknown tank id is ignored")
	game._on_button("gtab_arenas")
	game.coins = 1000
	game._on_button("sk_arenas_desert")
	check(game.equipped["arenas"] == "desert" and game.coins == 0, "arenas are bought and equipped")
	game.coins = 600
	game._on_button("gtab_upgrades")
	game._on_button("sup_gun")
	check(int(game.upgrades["gun"]) == 1 and game.coins == 0, "an upgrade is bought")
	game._on_button("sup_gun")
	check(int(game.upgrades["gun"]) == 1, "the next upgrade level needs more coins")
	check(not game._upgrade_list().has("ally") or game.HELPER_ENABLED, "no wingman upgrade while there is no wingman")
	game._on_button("tinfo_khaki")
	check(game.tank_info == "khaki", "tank ability panel opens")
	game._on_button("tinfo_close")
	game._on_button("tdrive_titan")
	check(game.tanks_node != null and game.tanks_node.perk == "titan" and game.tanks_node.test_drive, "test drive of a tank that is not owned")
	var c0: int = game.coins
	game.tanks_node.finished.emit(true)
	check(game.tanks_node == null and game.coins == c0 and game.tank_top == 1 and game.battles == 0, "a test drive pays nothing and changes no progress")


func battle_start() -> void:
	game.coins = 10
	game._on_button("gtab_battle")
	game._on_button("g_battle")
	check(game.tanks_node != null and game.tanks_node.mines_left == game.Data.MINES_MAX, "a battle starts with the standard mines")
	check(game.tanks_node.reward == game._tank_reward() and game.tanks_node.penalty == 1, "the battle shows the same reward and loss as the garage")
	check(game.tanks_node.perk == "classic" and game.tanks_node.player_sprite == game.TankArt.sprite_for_skin("classic"), "the equipped tank goes to battle")


func battle_end() -> void:
	var tk = game.tanks_node
	check(tk.state == "play" and tk.anim > 0.0, "the battle runs on its own (state %s)" % tk.state)
	check(game.mus_path.contains("battle_") or game.mus_path.contains("boss_"), "battle music in a battle (%s)" % game.mus_path)
	game._on_back()
	check(tk.paused, "Android back pauses the battle")
	tk.paused = false
	tk._kill_enemy({"p": Vector2(3, 3), "type": 5}, "p")
	tk.finished.emit(true)
	check(game.tanks_node == null and game.coins == 11 and game.tank_stage == 2 and game.tank_top == 2 and game.boss_kills == 1,
		"a win pays, opens the next level and counts the super tank (coins %d)" % game.coins)
	game._on_button("g_battle")
	game.tanks_node.finished.emit(false)
	check(game.coins == 10 and game.tank_stage == 2 and game.tank_top == 2, "a loss costs the shown penalty and keeps the level")
	game.coins = 0
	game._on_button("g_battle")
	check(game.tanks_node.penalty == 0, "the loss never goes below zero coins")
	game.tanks_node.finished.emit(false)
	check(game.coins == 0, "no negative coins")
	game._on_button("gstage_prev")
	check(game.tank_stage == 1, "an earlier level can be chosen")


func save_tests() -> void:
	game.coins = 4321
	game._save()
	var cf := ConfigFile.new()
	check(cf.load(game.SAVE_PATH) == OK and int(cf.get_value("meta", "version", 0)) == game.SAVE_VERSION, "save written with a version")
	cf.set_value("p", "owned_tanks", ["classic", "arctic", "hacked_tank"])
	cf.set_value("p", "equipped_tanks", "hacked_tank")
	cf.set_value("p", "tank_stage", 999)
	cf.set_value("p", "upgrades", {"armor": 99})
	cf.save(game.SAVE_PATH)
	var g2 = load("res://scenes/main.tscn").instantiate()
	root.add_child(g2)
	check(g2.coins == 4321 and g2.tank_top == 2 and g2._has("tanks", "arctic") and g2.equipped["arenas"] == "desert", "progress loads back")
	check(not g2._has("tanks", "hacked_tank") and g2.equipped["tanks"] == "classic" and g2.tank_stage == 2 and int(g2.upgrades["armor"]) == 3,
		"a damaged save is clamped to valid values")
	g2.queue_free()
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/en.json"))
	var gaps := []
	for l in game.Data.LANGS:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/%s.json" % l))
		for k in en:
			if not d.has(k):
				gaps.append(l + ":" + k)
	check(gaps.is_empty(), "every language has every text %s" % str(gaps.slice(0, 8)))


## Battle mechanics on live battles, taken over from the Oksi Block test (super game at 10 000 = level 1,
## the admin battle = level 4); setup() is called the same way the old game did.
func live_battle(stage: int, ups: Dictionary, helper := false) -> Node2D:
	var tk: Node2D = game._new_battle_node()
	root.add_child(tk)
	tk.setup(stage, game.font, game.Data.TANK_SKINS["classic"], game.Data.ARENAS["wasteland"], 1, game.Data.MINES_MAX, ups, false, helper)
	return tk


func drop(tk: Node2D) -> void:
	tk.get_parent().remove_child(tk)
	tk.free()


func super_tests() -> void:
	var tk := live_battle(1, game.upgrades)
	check(tk.mines_left == game.Data.MINES_MAX, "every battle starts with the standard mines")
	tk.super_charge = 1.0
	tk._fire_super()
	check(tk.super_charge == 0.0, "super shot fired")
	tk._drop_mine()
	check(tk.mines_used == 1, "mine placed")
	check(tk._path_next(Vector2(0.5, 0.5), tk.GEN) != Vector2i(-1, -1), "enemy pathfinding finds the generator")
	check(tk.total_enemies == 10, "10 enemies on level 1 (the old 10 000 super game)")
	var boss := {"id": 999, "p": Vector2(6.5, 3.5), "d": 2, "type": 5, "hp": 10, "maxhp": 10, "inv": 0.0, "hit": 0.0}
	tk.enemies.append(boss)
	var sb := {"o": 0, "hits": {}, "d": 2, "p": Vector2(6.5, 2.5)}
	for k in 8:
		tk._super_step(sb, Vector2(6.5, 3.0 + k * 0.1), 2)
	check(int(boss["hp"]) == 5, "one super shot takes half of the super tank (hp %d)" % int(boss["hp"]))
	for k in 4:
		tk._damage_enemy(boss, 1)
	check(int(boss["hp"]) == 1 and not boss.has("dead"), "super tank survives 9 normal hits in total")
	tk.enemies.erase(boss)
	# The boss comes with the last 3 tanks, and they enter even when the field is full.
	var keep_e: Array = tk.enemies.duplicate()
	var keep_s: Array = tk.spawns.duplicate()
	var keep_n: int = tk.to_spawn
	var keep_b: bool = tk.boss_out
	var dummy := {"p": Vector2(3.5, 9.5)}
	tk.enemies.clear()
	for k in tk.max_active - 1:
		tk.enemies.append(dummy)
	tk.spawns.clear()
	tk.to_spawn = 5
	tk.boss_out = false
	var kinds: Array = []
	for k in 12:
		if k == 2:
			tk.enemies.append(dummy)  # field full from now on
		tk.spawn_timer = 0.0
		tk._update_spawns(0.01)
		for sp in tk.spawns:
			kinds.append(int(sp["type"]))
		tk.spawns.clear()
	check(kinds.size() == 5 and kinds[1] == 5 and not kinds.slice(2).has(5) and kinds[0] != 5 and tk.to_spawn == 0,
		"super tank spawns with the last 3 enemies, who come in even over the limit (%s)" % str(kinds))
	var be := {"role": "breaker", "p": (tk.player["p"] as Vector2) + Vector2(1, 0), "goal": Vector2.ZERO}
	tk._update_goal(be)
	check(be["goal"] == tk.GEN, "super tank heads for the generator even right next to the player")
	tk.enemies = keep_e
	tk.spawns = keep_s
	tk.to_spawn = keep_n
	tk.boss_out = keep_b
	drop(tk)


func wave4_tests() -> void:
	var tk := live_battle(4, {"armor": 0, "speed": 0, "power": 0, "gun": 0, "ally": 0})
	check(tk.total_enemies == 20 and tk.elvl == 2, "level-4 battle: 20 enemies, level 2")
	var g0: int = tk.gen_hp
	tk._hit_tile(6, 12, 0)
	check(tk.gen_hp == g0 - 1, "own shot damages the generator")
	tk.gen_hit = 0.0
	tk.player["p"] = Vector2(6.5, 1.5)
	tk.spawns.clear()
	tk.enemies.clear()
	tk.spawn_timer = 0.0
	for i in 3:
		tk._update_spawns(0.01)
		tk.spawn_timer = 0.0
	var near := false
	for sp in tk.spawns:
		near = near or (sp["p"] as Vector2).distance_to(tk.player["p"]) < 3.0
	check(tk.spawns.size() > 0 and not near, "enemies do not spawn next to a camping player")
	for sp in tk.spawns:
		sp["t"] = 1.0
	tk._update_spawns(0.01)
	check(tk.enemies.size() > 0 and float(tk.enemies[0]["inv"]) > 1.0, "fresh enemies have a spawn shield")
	var en: Dictionary = tk.enemies[0]
	en["role"] = "raider"
	en["p"] = Vector2(6.5, 7.5)
	en["react"] = 0.0
	en["shoot"] = 0.0
	tk.player["p"] = Vector2(0.5, 0.5)
	tk.bullets.clear()
	tk._update_goal(en)
	tk._update_enemies(0.05)
	check(en["goal"] == tk.GEN and tk.bullets.size() > 0 and int(tk.bullets[0]["d"]) == 2, "enemy unseen by player shells the generator")
	var hps := {}
	for ty in [0, 1, 3, 4, 2]:
		hps[ty] = tk.E_HP[ty]
	check(hps[0] == 1 and hps[1] == 1 and hps[3] == 1 and hps[4] == 2 and hps[2] == 3, "light 1 hit, medium 2, heavy 3")
	en["carrier"] = true
	en["inv"] = 0.0
	en["hp"] = 1
	var nb: int = tk.bonuses.size()
	tk._damage_enemy(en, 1)
	check(tk.bonuses.size() == nb + 1 and (tk.bonuses.back()["p"] as Vector2).distance_to(en["p"]) >= 0.0, "a flashing carrier drops a bonus somewhere on the map")
	tk._apply_bonus("rapid")
	check(float(tk.buffs["rapid"]) > 10.0, "temporary pick-up boosts the player")
	drop(tk)
	var t1 := live_battle(4, {"armor": 2, "speed": 0, "power": 0, "gun": 0, "ally": 0})
	check(t1.armor_max >= 2, "tank upgrades applied in battle")
	var e0: int = t1.elvl
	var t0: int = t1.total_enemies
	drop(t1)
	var tk2 := live_battle(4, {"armor": 3, "speed": 3, "power": 3, "gun": 3, "ally": 0}, true)
	check(tk2.elvl > e0 and tk2.total_enemies > t0, "enemies get stronger when the player tank is upgraded")
	check(tk2._ally_alive() and tk2.max_pb == 2 and tk2.gun_lvl == 3, "helper joins the battle, cannon upgrades apply")
	tk2._shoot(tk2.player, 0)
	check(int(tk2.bullets.back()["dmg"]) == 2, "cannon level 3 deals double damage")
	drop(tk2)


func mechanics_tests() -> void:
	var mk = game.Tanks.new()
	var maps_ok := true
	for st in game.Data.TANK_MAPS:
		for sd in 25:
			mk.map_style = st
			mk.stage = 1 + sd % 10
			mk.rng.seed = sd * 31 + 7
			mk._gen_map()
			if not mk._reachable() or mk.style() != st:
				maps_ok = false
			for yy in mk.N:
				for xx in mk.N:
					if int(mk.tiles[yy * mk.N + xx]) != int(mk.tiles[yy * mk.N + mk.N - 1 - xx]):
						maps_ok = false  # every map is mirror-symmetric
	mk.free()
	check(maps_ok, "all %d battle maps generate symmetric, with a path to the base" % game.Data.TANK_MAPS.size())
	var bk = game.Tanks.new()
	bk.stage = 3
	bk.rng.seed = 99
	bk._gen_map()
	bk.player = {"p": Vector2(4.5, 12.5), "dead": true}
	var home_n := 0
	for i in 200:
		bk.bonuses.clear()
		bk._spawn_bonus()
		if not bk.bonuses.is_empty() and (bk.bonuses[0]["p"] as Vector2).y >= bk.BONUS_HOME_ROW:
			home_n += 1
	bk.free()
	check(home_n >= 150, "most bonuses appear on the player's half (%d of 200)" % home_n)
	var we = game.Tanks.wave(3, 4, "easy")
	var wn = game.Tanks.wave(3, 4, "normal")
	var wx = game.Tanks.wave(3, 4, "expert")
	check(int(we["enemies"]) < int(wn["enemies"]) and int(wn["enemies"]) < int(wx["enemies"]) and int(we["elvl"]) <= int(wn["elvl"]) and int(wn["elvl"]) < int(wx["elvl"]),
		"difficulty changes enemy count and level")
	var arts_ok := true
	for ty in 6:
		if game.TankArt.tex("e%d" % ty, 0) == null or game.TankArt.tex("e%d" % ty, 1) == null:
			arts_ok = false
	for sk in game.Data.TANK_SKINS:
		if game.TankArt.tex(game.TankArt.sprite_for_skin(sk), 0) == null:
			arts_ok = false
	for ar in game.Data.ARENAS.values():
		if game.TankArt.item(str(ar.get("ground", ""))) == null or game.TankArt.item(str(ar.get("tree", "")) + "_1") == null or game.TankArt.item(str(ar.get("tree", "")) + "_3") == null:
			arts_ok = false
	check(arts_ok, "every enemy type, skin and arena has its pictures")
	var miss := ""
	for l in ["ja", "zh", "ko"]:
		var f: Font = load("res://fonts/cjk_%s.otf" % l)
		var src := FileAccess.get_file_as_string("res://i18n/%s.json" % l) + str(game.LANG_NAMES[l])
		for ch in src:
			if ch.unicode_at(0) > 0x2E7F and not f.has_char(ch.unicode_at(0)):
				miss += ch
	check(miss == "", "shipped CJK fonts hold every Japanese, Chinese and Korean character the game shows %s" % miss)
	var rk = game.Tanks.new()
	game.get_tree().root.add_child(rk)
	rk.setup(2, ThemeDB.fallback_font, [], {}, 1, 0, {}, false, false)
	rk.enemies.append({"p": rk.PLAYER_SPAWN, "type": 1, "dead": false})
	rk.player["dead"] = true
	var rp = rk._respawn_point()
	check(rp != null and (rp as Vector2).distance_to(rk.PLAYER_SPAWN) >= 1.0, "player respawns elsewhere when an enemy blocks his spawn point")
	rk.enemies.clear()
	rk.get_parent().remove_child(rk)
	rk.free()
	check(game.Tanks.power_of({"armor": 1, "speed": 1, "power": 1, "gun": 1, "ally": 3}, false) == 4, "helper upgrades do not make enemies stronger")
	var ak = game.Tanks.new()
	game.get_tree().root.add_child(ak)
	ak.setup(2, ThemeDB.fallback_font, [], {}, 1, 0, {"ally": 3}, false, true)
	check(ak._ally_alive() and int(ak.ally["hp"]) == ak.ALLY_HP + 3, "upgraded helper joins with more armour")
	ak.queue_free()
	game.tank_diff = "hard"
	check(game._tank_reward(21) == int(round(5 * 1.5)), "hard Tanks win pays x1.5")
	game.tank_diff = "normal"
	# Battle report: kills by source, deaths, shots, bonuses, time.
	var rk2 = game.Tanks.new()
	rk2.tr_fn = Callable(game, "t")
	game.get_tree().root.add_child(rk2)
	rk2.setup(3, ThemeDB.fallback_font)
	rk2._kill_enemy({"p": Vector2(3, 3), "type": 1}, "p")
	rk2._kill_enemy({"p": Vector2(3, 3), "type": 5}, "mine")
	rk2._kill_enemy({"p": Vector2(3, 3), "type": 1}, "a")
	rk2._apply_bonus("shield", "a")
	rk2.st["time"] = 102.4
	rk2.lives = 3
	rk2.armor = 0
	rk2._player_hit()
	check(int(rk2.st["k_p"]) == 1 and int(rk2.st["k_mine"]) == 1 and int(rk2.st["k_a"]) == 1 and bool(rk2.st["boss"]) and int(rk2.st["b_a"]) == 1
		and int(rk2.st["deaths"]) == 1 and int(rk2.st["best_streak"]) == 2 and int(rk2.st["streak"]) == 0, "battle report counts kills, bonuses, deaths and streaks")
	check(rk2.clock(102.4) == "1:42" and rk2.report_rows().size() >= 8, "battle report rows")
	var rr: Array = rk2.report_rows()[0]
	check(rk2._row_value(rr, 0.0) == "0:00" and rk2._row_value(rr, 5.0) == "1:42" and rk2.report_done_t() > 2.0, "report numbers count up, then the button shows")
	rk2.track_best = true
	rk2.best_time = 90.0
	rk2._finish(true)
	check(not rk2.new_record, "a slower win is not a record")
	rk2.get_parent().remove_child(rk2)
	rk2.free()
	# Tank abilities.
	var pk = game.Tanks.new()
	pk.perk = "pulse"
	game.get_tree().root.add_child(pk)
	pk.setup(3, ThemeDB.fallback_font)
	var fresh := {"id": 900, "p": Vector2(6.5, 3.5), "d": 2, "type": 1, "hp": 1.0, "maxhp": 1, "inv": 3.0, "dead": false, "hit": 0.0}
	pk.enemies.append(fresh)
	pk.player["p"] = Vector2(6.5, 6.5)
	pk.player["d"] = 0
	for x in range(3, 7):
		pk.tiles[x * pk.N + 6] = pk.EMPTY
	pk._shoot(pk.player, 0)
	var lz: Dictionary = pk.bullets.back()
	pk.bullets.append({"p": Vector2(6.5, 5.0), "d": 2, "o": 1, "src": {}, "sp": 0.0, "dead": false, "dmg": 1.0})
	for i in 20:
		pk._update_bullets(0.03)
	check(bool(lz.get("laser", false)) and is_equal_approx(float(lz["dmg"]), 1.5) and bool(fresh["dead"]), "Pulse laser melts a shell and kills through a spawn shield")
	pk.get_parent().remove_child(pk)
	pk.free()
	var pt = game.Tanks.new()
	pt.perk = "titan"
	game.get_tree().root.add_child(pt)
	pt.setup(3, ThemeDB.fallback_font)
	pt._shoot(pt.player, 0)
	check(bool(pt.bullets.back().get("zap", false)) and is_equal_approx(float(pt.bullets.back()["dmg"]), 1.5) and pt.fire_cd < 0.26 / 1.4, "Titan electric shot: x1.5 damage and fire rate")
	pt.perk = "amphibia"
	pt.tiles[5 * pt.N + 5] = pt.WATER
	var wet := Vector2(5.5, 5.5)
	check(not pt._blocked(wet, pt.player) and pt._blocked(wet, null), "Amphibia drives over water, others cannot")
	pt.perk = "khaki"
	pt.tiles[11 * pt.N + 2] = pt.BUSH
	pt.player["p"] = Vector2(2.5, 11.5)
	pt.player["dead"] = false
	pt._update_player(0.01)
	pt._update_danger()
	check(pt.camo and not pt.danger.has(1), "Khaki in the forest is hidden: no line of fire for enemies to avoid")
	pt.perk = "inferno"
	pt.fuel = 1.0
	pt.player["p"] = Vector2(6.5, 8.5)
	pt.player["d"] = 0
	pt.tiles[7 * pt.N + 6] = pt.EMPTY
	pt.tiles[6 * pt.N + 6] = pt.EMPTY
	var burn := {"id": 901, "p": Vector2(6.5, 7.3), "d": 2, "type": 2, "hp": 3.0, "maxhp": 3, "inv": 0.0, "dead": false, "hit": 0.0}
	pt.enemies = [burn]
	pt._shell_hit({"o": 0, "fire": true}, burn)
	pt.freeze_t = 99.0
	for i in 4:
		pt._update_enemies(0.5)
	check(float(burn["hp"]) < 3.0, "Inferno shells set an enemy on fire")
	# Neon: dark shells kill any regular tank in one hit and leave slowing fog
	pt.perk = "neon"
	var big := {"id": 902, "p": Vector2(6.5, 4.5), "d": 2, "type": 2, "hp": 3.0, "maxhp": 3, "inv": 0.0, "dead": false, "hit": 0.0}
	pt.enemies = [big]
	pt.bullets = [{"p": Vector2(6.5, 4.9), "d": 0, "o": 0, "src": {}, "sp": 1.0, "dead": false, "dmg": 1.0, "dark": true}]
	pt.freeze_t = 0.0
	pt._update_bullets(0.05)
	check(bool(big["dead"]) and pt.fogs.size() == 1, "Neon dark shell kills a heavy tank with one hit and leaves fog")
	# Arctic: three ice hits freeze an enemy
	var ic := {"id": 903, "p": Vector2(3.5, 3.5), "d": 2, "type": 2, "hp": 30.0, "maxhp": 30, "inv": 0.0, "dead": false, "hit": 0.0}
	for i in 3:
		pt._shell_hit({"o": 0, "ice": true}, ic)
	check(float(ic.get("frz", 0.0)) > 0.0 and float(ic["slow"]) > 0.0, "Arctic ice shells slow and then freeze")
	# Twin: alternating barrels
	pt.perk = "twin"
	pt.bullets.clear()
	pt.player["p"] = Vector2(6.5, 8.5)
	pt.player["d"] = 0
	pt._shoot(pt.player, 0)
	pt._shoot(pt.player, 0)
	check(absf(float(pt.bullets[0]["p"].x) - float(pt.bullets[1]["p"].x)) > 0.3, "Twin fires from left and right barrels in turn")
	# Katyusha: every 3rd shot is a volley of three
	pt.perk = "katyusha"
	pt.bullets.clear()
	pt.shot_n = 2
	pt._shoot(pt.player, 0)
	check(pt.bullets.size() == 3, "Katyusha fires a volley of three on the 3rd shot")
	pt.get_parent().remove_child(pt)
	pt.free()
