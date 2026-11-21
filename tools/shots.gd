extends SceneTree
## Screenshots of every Oksi Tanks screen (for design review before a build).
## Run: xvfb-run -s "-screen 0 720x1280x24" godot --path . --rendering-driver opengl3 --script res://tools/shots.gd
## Pictures go to user://shots/.

var game
var step := 0
var plan := [["menu", "m_menu"], ["garage_battle", "m_battle"], ["garage_tanks", "gtab_tanks"], ["garage_upgrades", "gtab_upgrades"],
	["garage_arenas", "gtab_arenas"], ["tank_info", "tinfo_khaki"], ["settings", "m_settings"], ["battle", "battle"]]
var idx := 0


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))


func _process(_d: float) -> bool:
	step += 1
	if step % 20 == 5:
		if idx >= plan.size():
			return true
		var a: String = plan[idx][1]
		game.tank_info = ""
		match a:
			"m_menu":
				game.screen = game.Screen.MENU
			"battle":
				game.screen = game.Screen.GARAGE
				game._launch_battle()
			_:
				if a.begins_with("gtab_") or a.begins_with("tinfo_"):
					game.screen = game.Screen.GARAGE
				game._on_button(a)
	elif step % 20 == 19:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("user://shots/%02d_%s.png" % [idx, plan[idx][0]]))
		idx += 1
	return false
