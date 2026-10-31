## Canonical cosmetic-skin data: the ships, the themes (in rarity order), per-ship display names,
## rarity → price/colour, and the fleet BUNDLES. Both the Ship Skins shop and the Bundles shop read
## from here so prices/names/rarities can never drift apart. Ownership/coins live in Cosmetics.
class_name Skins
extends RefCounted

# SHIPS row = [id, label, art_dir, file_prefix].
const SHIPS: Array = [
	[&"battleship", "Battleship", "battleship", "battleship"],
	[&"aircraft_carrier", "Aircraft Carrier", "aircraft_carrier", "air"],
	[&"cruiser", "Cruiser", "cruiser", "cru"],
	[&"destroyer", "Destroyer", "destroyer", "des"],
	[&"submarine", "Submarine", "sub", "sub"],
	[&"drone_ship", "Drone Ship", "drone", "drone"],
]

## Fixed theme order = the rarity ladder from the concept sheets.
const THEME_ORDER: Array[String] = [
	"default", "steel", "blue", "desert", "artic", "inferno", "gold", "neptune", "void", "celestial"]
const THEME_RARITY := {
	"default": "COMMON", "steel": "COMMON", "blue": "RARE", "desert": "RARE",
	"artic": "EPIC", "inferno": "EPIC", "gold": "LEGENDARY", "neptune": "LEGENDARY",
	"void": "MYTHIC", "celestial": "MYTHIC",
}
const RARITY_PRICE := {"COMMON": 250, "RARE": 500, "EPIC": 1000, "LEGENDARY": 2500, "MYTHIC": 5000}
const RARITY_COLOR := {
	"COMMON": Color(0.68, 0.73, 0.80), "RARE": Color(0.25, 0.66, 0.96),
	"EPIC": Color(0.71, 0.42, 1.0), "LEGENDARY": Color(0.95, 0.69, 0.20),
	"MYTHIC": Color(1.0, 0.35, 0.30),
}
## Water/wake tint per theme — the ripples off a ship take on its skin's character (icy for artic,
## fiery for inferno, cosmic for void, etc.). Default is blue. Falls back to the rarity colour.
const WAKE_COLOR := {
	"default": Color(0.30, 0.56, 1.0), "steel": Color(0.52, 0.66, 0.82),
	"blue": Color(0.24, 0.66, 1.0), "desert": Color(0.42, 0.78, 0.70),
	"artic": Color(0.62, 0.90, 1.0), "inferno": Color(1.0, 0.46, 0.22),
	"gold": Color(0.98, 0.78, 0.34), "neptune": Color(0.18, 0.82, 0.70),
	"void": Color(0.62, 0.42, 1.0), "celestial": Color(0.86, 0.56, 1.0),
}
## Per-ship display names by theme. Battleship/Carrier/Submarine are from their concept sheets;
## Cruiser/Destroyer/Drone are from the pre-rename art filenames (verify when their sheets land).
const SKIN_NAMES := {
	&"battleship": {
		"default": "Default", "steel": "Steel Titan", "blue": "Deep Blue", "desert": "Desert Storm",
		"artic": "Arctic Hunter", "inferno": "Inferno", "gold": "Golden Admiral",
		"neptune": "Neptune's Wrath", "void": "Void Commander", "celestial": "Celestial Guardian",
	},
	&"aircraft_carrier": {
		"default": "Default", "steel": "Steel Titan", "blue": "Ocean Guard", "desert": "Desert Hawk",
		"artic": "Arctic Sentinel", "inferno": "Inferno Flight", "gold": "Golden Eagle",
		"neptune": "Neptune's Wrath", "void": "Void Commander", "celestial": "Celestial Wing",
	},
	&"cruiser": {
		"default": "Default", "steel": "Steel Guard", "blue": "Ocean Strike", "desert": "Desert Vigil",
		"artic": "Arctic Reaper", "inferno": "Inferno Blade", "gold": "Golden Tide",
		"neptune": "Nightmare", "void": "Void Hunter", "celestial": "Celestial Guard",
	},
	&"destroyer": {
		"default": "Default", "steel": "Steel Guard", "blue": "Ocean Strike", "desert": "Desert Vigil",
		"artic": "Arctic Reaper", "inferno": "Inferno Blade", "gold": "Golden Tide",
		"neptune": "Nightmare", "void": "Void Hunter", "celestial": "Celestial Guard",
	},
	&"submarine": {
		"default": "Default", "steel": "Stealth Black", "blue": "Ocean Hunter", "desert": "Silent Depths",
		"artic": "Arctic Wraith", "inferno": "Inferno Tide", "gold": "Golden Shadow",
		"neptune": "Abyssal Core", "void": "Void Stalker", "celestial": "Celestial Nemesis",
	},
	&"drone_ship": {
		"default": "Default", "steel": "Steel Night", "blue": "Ocean Tech", "desert": "Sandstorm",
		"artic": "Polar Surveillance", "inferno": "Inferno Unit", "gold": "Golden Eye",
		"neptune": "Phantom", "void": "Void Probe", "celestial": "Celestial Orbiter",
	},
}

## Fleet bundles = one theme across all six ships (default is free, so no bundle). Buying a bundle
## is discounted vs the six skins individually, and skins you already own drop off the price.
const BUNDLE_THEMES: Array[String] = [
	"steel", "blue", "desert", "artic", "inferno", "gold", "neptune", "void", "celestial"]
const BUNDLE_NAMES := {
	"steel": "Steel Fleet", "blue": "Deep Blue Fleet", "desert": "Desert Fleet",
	"artic": "Arctic Fleet", "inferno": "Inferno Fleet", "gold": "Golden Armada",
	"neptune": "Neptune's Fleet", "void": "Void Armada", "celestial": "Celestial Fleet",
}
const BUNDLE_DISCOUNT := 0.25   # 25% off buying the fleet's six skins individually

static func rarity_of(theme: String) -> String:
	return THEME_RARITY.get(theme, "RARE")

## Per-ship price for a theme (0 for the free default).
static func skin_price(theme: String) -> int:
	return 0 if theme == "default" else int(RARITY_PRICE.get(rarity_of(theme), 500))

static func skin_key(prefix: String, theme: String) -> String:
	return "%s_%s" % [prefix, theme]

## The theme baked into a skin key ("<prefix>_<theme>"), matched against known themes so prefixes with
## underscores are safe. Empty/unknown key -> "default".
static func theme_of(key: String) -> String:
	for t in THEME_ORDER:
		if key == t or key.ends_with("_" + t):
			return t
	return "default"

## The wake tint for a theme (falls back to the rarity colour, then default blue).
static func wake_color(theme: String) -> Color:
	return WAKE_COLOR.get(theme, RARITY_COLOR.get(rarity_of(theme), WAKE_COLOR["default"]))

## The skin key a given ship would use for a theme (looks up the ship's file prefix).
static func key_for(ship_id: String, theme: String) -> String:
	for s in SHIPS:
		if String(s[0]) == ship_id:
			return skin_key(String(s[3]), theme)
	return ""

## The six skin keys that make up a theme's fleet bundle.
static func theme_keys(theme: String) -> Array:
	var out: Array = []
	for s in SHIPS:
		out.append(skin_key(String(s[3]), theme))
	return out

static func skin_name(ship_id: StringName, theme: String) -> String:
	var per: Dictionary = SKIN_NAMES.get(ship_id, {})
	return String(per.get(theme, theme.capitalize()))
