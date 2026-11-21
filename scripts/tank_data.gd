## Oksi Tanks game data: tanks, arenas, upgrades, difficulty, music. Taken over from Oksi Block (scripts/data.gd).
extends RefCounted

# Coin price of each next level (3 levels per upgrade).
const TANK_UPGRADES := {"armor": [500, 1500, 5000], "speed": [400, 1200, 4000], "power": [500, 1500, 5000],
	"gun": [600, 2000, 6000], "ally": [800, 2500, 6000]}
const UPGRADE_ORDER := ["armor", "speed", "power", "gun", "ally"]
# Free Tanks mode: a win pays and a loss costs the same coins; they grow every TANK_STEP_LEVELS levels
# (levels 1-10: 1, 11-20: 3, ... 91-100: 50), times the difficulty factor, never above TANK_MODE_CAP (VIP doubles wins only).
const TANK_MODE_COINS := [1, 3, 5, 8, 12, 17, 23, 30, 40, 50]
const TANK_STEP_LEVELS := 10
const TANK_MODE_CAP := 50
# Tanks mode difficulty: enemy level shift, enemy count factor, coin factor.
const TANK_DIFFS := ["easy", "normal", "hard", "expert"]
const TANK_DIFF := {
	# speed: the whole battle runs this much faster (game time); normal is a little calmer than before
	"easy": {"elvl": -2, "count": 0.7, "reward": 0.5, "speed": 0.78}, "normal": {"elvl": 0, "count": 1.0, "reward": 1.0, "speed": 0.88},
	"hard": {"elvl": 2, "count": 1.25, "reward": 1.5, "speed": 0.98}, "expert": {"elvl": 4, "count": 1.5, "reward": 2.0, "speed": 1.08},
}
# Battle maps (tanks.gd _gen_map); the super game takes them in turn, the Tanks mode lets the player choose.
const TANK_MAPS := ["classic", "city", "fortress", "river", "forest", "maze", "steel", "ice"]
const TANK_MODE_MAX_STAGE := 100  # = TANK_MODE_COINS.size() * TANK_STEP_LEVELS
# Every tank has its own ability (tanks.gd: perk); TANK_UPGRADES improve any tank. Price -1 = real money (TANK_NEON_ID).
#  khaki: hidden from enemies in the forest · arctic: drives on ice without sliding and across water
#  inferno: flamethrower with a fuel tank refilled in the garage · titan: electric shells (x1.5 damage, x1.5 fire rate)
#  neon: laser (x1.5 damage, x1.5 fire rate, melts enemy shells, pierces spawn shields)
# Strength by country: USA first, USSR second, Germany third; Titan and Neon (real money) above all.
const SHOP_TANKS := [["classic", 0], ["arctic", 1200], ["inferno", 1500], ["khaki", 1500], ["ricochet", 1800],
	["guardian", 2000], ["tiger", 2200], ["samurai", 2400], ["bear", 2500], ["ninja", 2800], ["amphibia", 3000],
	["mirage", 3200], ["panther", 3500], ["dragon", 3800], ["pulse", 4200], ["thunder", 4500], ["katyusha", 5000],
	["twin", 6000], ["titan", -1], ["neon", -1]]
const TANK_TIER := {"classic": 1, "arctic": 2, "inferno": 2, "khaki": 2, "ricochet": 2, "guardian": 3, "tiger": 3,
	"samurai": 3, "bear": 3, "ninja": 3, "amphibia": 4, "mirage": 4, "panther": 4, "dragon": 4, "pulse": 4,
	"thunder": 5, "katyusha": 5, "twin": 5, "titan": 5, "neon": 6}
# Tanks sold for real money: Play one-time product id -> [tank, price shown until Google Play reports the local one].
const TANK_PRODUCTS := {"tank_neon": ["neon", "$14.99"], "tank_titan": ["titan", "$2.99"]}
const FUEL_MAX := 5.0                 # seconds of flame in a full Inferno tank
const MINES_MAX := 5
const SHOP_ARENAS := [["wasteland", 0], ["desert", 1000], ["snow", 1000], ["night", 1500]]
const TANK_SKINS := {
	"classic": [Color("e8c547"), Color(0, 0, 0, 0)], "khaki": [Color("7d8a4a"), Color("4a5530")],
	"arctic": [Color("e6eef5"), Color("6f9fd0")], "inferno": [Color("3a3a3a"), Color("e0472b")],
	"neon": [Color("1e2a4a"), Color("4ff3ff")], "titan": [Color("5a5f6a"), Color("ffd35a")],
	"bear": [Color("4f7a2a"), Color("d63a2a")], "katyusha": [Color("7cb342"), Color("e53935")],
	"amphibia": [Color("6b8f3a"), Color("2f8f8a")], "twin": [Color("8a9a3a"), Color("ffffff")],
	"tiger": [Color("70757d"), Color("c9ced6")], "panther": [Color("7d838c"), Color("c9ced6")],
	"thunder": [Color("454a52"), Color("ffcc00")], "ricochet": [Color("6f8f3a"), Color("d9c27a")],
	"guardian": [Color("8f8a3a"), Color("39b6ff")], "samurai": [Color("e8e8ec"), Color("d6202a")],
	"ninja": [Color("26262b"), Color("e0202a")], "mirage": [Color("2a4fbf"), Color("b48cff")],
	"dragon": [Color("b51f1f"), Color("ffc23a")], "pulse": [Color("e8e8ee"), Color("ff3cc8")],
}
const ARENAS := {
	"wasteland": {"ground": "ground_wasteland", "tree": "tree_wasteland", "floor": Color(0.95, 0.95, 0.95), "bg": Color("0d1014"), "frame": Color("2d5bff"), "brick": Color("8a5cf0"), "mortar": Color("2a1650"),
		"steel": Color("aeb7c2"), "bush": Color("2f8f3a"), "water": Color("1f5fbf")},
	"desert": {"ground": "ground_desert", "tree": "tree_desert", "floor": Color(1.0, 0.92, 0.8), "bg": Color("3a2c1a"), "frame": Color("7a6038"), "brick": Color("c98a4b"), "mortar": Color("6b4524"),
		"steel": Color("b9aa90"), "bush": Color("7b8a3a"), "water": Color("2f7f9a")},
	"snow": {"ground": "ground_snow", "tree": "tree_snow", "floor": Color(1, 1, 1), "bg": Color("2a3644"), "frame": Color("9fb8d0"), "brick": Color("a8b8c8"), "mortar": Color("5d6d80"),
		"steel": Color("e1ecf5"), "bush": Color("e8f2fa"), "water": Color("4f8fd0")},
	"night": {"ground": "ground_night", "tree": "tree_night", "floor": Color(0.5, 0.55, 0.6), "bg": Color("05060f"), "frame": Color("2a2f6e"), "brick": Color("6a3ab0"), "mortar": Color("251248"),
		"steel": Color("4ff3ff"), "bush": Color("1f6f5a"), "water": Color("1a3fa0")},
}
## Original title and author of every track: shown when a track starts and in Settings.
const MUSIC_INFO := {
	"menu_01_forest": ["Forest", "syncopika"],
	"blocks_01_awake": ["Awake! (megaWall-10)", "cynicmusic"],
	"blocks_02_old_tower_inn": ["The Old Tower Inn", "RandomMind"],
	"blocks_03_pleasant_creek": ["Pleasant Creek", "Matthew Pablo"],
	"blocks_04_world_map": ["World Map", "Scott Elliott"],
	"garage_01_dark_descent": ["Dark Descent", "Matthew Pablo"],
	"garage_02_space_dimensions": ["Space Dimensions (8bit)", "Matthew Pablo"],
	"garage_03_thrust_sequence": ["Thrust Sequence", "Matthew Pablo"],
	"garage_04_vilified": ["Vilified", "Matthew Pablo"],
	"battle_01_blackmoor_tides": ["Blackmoor Tides", "Matthew Pablo"],
	"battle_02_blackmoor_tides_no_chants": ["Blackmoor Tides (No Chants)", "Matthew Pablo"],
	"battle_03_railjet": ["RailJet", "Deceased Superior Technician"],
	"battle_04_countdown": ["Countdown", "Alexandr Zhelanov"],
	"boss_01_fight_them_until_we_cant": ["Fight Them Until We Can't", "Zander Noriega"],
	"boss_02_battle_theme_1": ["Battle Theme 1", "Alexandr Zhelanov"],
	"boss_03_battle_theme_2": ["Battle Theme 2", "Alexandr Zhelanov"],
	"boss_04_battle_theme_3": ["Battle Theme 3", "Alexandr Zhelanov"],
	"boss_05_battle_theme_4": ["Battle Theme 4", "Alexandr Zhelanov"],
	"boss_06_battle_theme_5": ["Battle Theme 5", "Alexandr Zhelanov"],
	"win_01_xeon_theme": ["Xeon Theme Remastered", "bart"],
	"lose_01_dark_descent_extended": ["Dark Descent (Extended Cut)", "Matthew Pablo"],
}
const VOL_DEFAULT := 70
const MUSIC_QUICK := ["battle", "win", "lose", "boss"]  # these cut in quickly instead of a slow crossfade
const MUSIC_DB := {"menu": -10.0, "blocks": -11.0, "garage": -6.0, "battle": 0.0, "boss": 0.0, "win": -2.0, "lose": -2.0}  # battles are loud: music must cut through

# Music by place (app.gd _wanted_music); files audio/music/<place>_<nn>_<name>.ogg, credits in audio/music/CREDITS.md.
const MUSIC := {
	"garage": ["music/garage_01_dark_descent", "music/garage_02_space_dimensions", "music/garage_03_thrust_sequence", "music/garage_04_vilified"],
	"battle": ["music/battle_01_blackmoor_tides", "music/battle_02_blackmoor_tides_no_chants", "music/battle_03_railjet", "music/battle_04_countdown"],
	"boss": ["music/boss_01_fight_them_until_we_cant", "music/boss_02_battle_theme_1", "music/boss_03_battle_theme_2",
		"music/boss_04_battle_theme_3", "music/boss_05_battle_theme_4", "music/boss_06_battle_theme_5"],
	"win": ["music/win_01_xeon_theme"],
	"lose": ["music/lose_01_dark_descent_extended"],
}
# Sound settings sliders (0..100, VOL_DEFAULT = the designed level).
const VOL_KEYS := ["master", "m_garage", "m_battle", "m_boss", "m_end", "s_game", "s_tank", "s_engine"]
const VOL_OF_PLACE := {"garage": "m_garage", "battle": "m_battle", "boss": "m_boss", "win": "m_end", "lose": "m_end"}
const LANGS := ["ru", "en", "es", "de", "fr", "it", "pt", "pl", "tr", "id", "ja", "ko", "zh"]
const START_COINS := 0

