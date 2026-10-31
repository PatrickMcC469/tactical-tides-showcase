## Simple sound manager: a small pool of AudioStreamPlayers for overlapping SFX plus a looping
## ocean ambient bed. Call Audio.play("key") from anywhere. Respects the Settings sound toggle.
extends Node

const DIR := "res://assests/audio/"
const SFX := {
	"fire": "cannon_fire_singleshot.ogg",
	"fire_charge": "play_for_short_second_before_shot_fire_audio.ogg",
	"hit": "direct_hit.ogg",
	"torpedo": "torpedo.ogg",
	"torpedo_hit": "torpedo_hit.ogg",
	"splash": "shot_missed.ogg",    # miss impact
	"flyover": "jet_flyover.ogg",   # carrier multi-shot + air strafe
	"move": "ship_movement.ogg",
	"mine_drop": "mine_drop_only_first_4seconds.ogg",
	"mine_sweep": "mine_sweep.ogg",
	"drone": "drone.ogg",
	"sonar": "sonar.ogg",
	"barrage": "incoming barage.ogg",
	"emp": "EMP.ogg",
	"versus": "versus_screen.ogg",   # cinematic sting for the VERSUS challenge reveal
	"win": "win.ogg",                # victory result screen
	"lose": "lose.ogg",              # defeat result screen
}
const AMBIENT := "ocean _lowVolume_background.ogg"

## Per-sound trim (dB) so the loud one-shots — cannon fire and direct hits especially — sit lower in
## the mix without editing every call site. Applied on top of any per-call volume_db.
const SFX_GAIN := {
	"fire": -8.0,          # shooting
	"hit": -7.0,           # taking damage
	"torpedo": -5.0,
	"torpedo_hit": -7.0,
	"flyover": -5.0,       # carrier strafe pass
	"barrage": -5.0,
	"splash": -3.0,        # miss
}

var _pool: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer
var _ambient_on := false   # the ocean bed only plays on the game screen, not everywhere
var _cache := {}

func _ready() -> void:
	for _i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = -20.0
	_ambient.finished.connect(func(): if _ambient_on and _enabled(): _ambient.play())   # loop
	add_child(_ambient)
	var amb := _load(AMBIENT)
	if amb != null:
		_ambient.stream = amb
	# No auto-play — the game screen calls start_ambient() so the waves aren't running everywhere.

## Play a one-shot sound by key (see SFX). No-op if sound is off or the key is unknown.
func play(key: String, volume_db: float = 0.0) -> void:
	if not _enabled():
		return
	var s := _load(SFX.get(key, ""))
	if s == null:
		return
	var p := _free_player()
	p.stream = s
	p.volume_db = volume_db + float(SFX_GAIN.get(key, 0.0))
	p.play()

## Play a sound after a delay (fire-and-forget; call without awaiting). Used to sequence the
## charge → shot → impact so they don't all fire at once.
func play_delayed(key: String, delay: float, volume_db: float = 0.0) -> void:
	if not _enabled():
		return
	await get_tree().create_timer(delay).timeout
	play(key, volume_db)

## Play a sound but stop it after `dur` seconds — used to run the fire alarm for a fixed window and
## cut it exactly when the shot fires (even if the alarm clip is longer). Fire-and-forget.
func play_for(key: String, dur: float, volume_db: float = 0.0) -> void:
	if not _enabled():
		return
	var s := _load(SFX.get(key, ""))
	if s == null:
		return
	var p := _free_player()
	p.stream = s
	p.volume_db = volume_db
	p.play()
	await get_tree().create_timer(dur).timeout
	if is_instance_valid(p) and p.playing and p.stream == s:
		p.stop()

## Start the ocean ambient bed — call when entering the game/battle screen.
func start_ambient() -> void:
	_ambient_on = true
	if _enabled() and _ambient.stream != null and not _ambient.playing:
		_ambient.play()

## Stop the ocean ambient — call when leaving the game screen.
func stop_ambient() -> void:
	_ambient_on = false
	_ambient.stop()

## Re-sync ambient + hush all SFX when the sound setting changes.
func apply_setting() -> void:
	if _enabled():
		if _ambient_on and _ambient.stream != null and not _ambient.playing:
			_ambient.play()
	else:
		_ambient.stop()
		for p in _pool:
			p.stop()

func _enabled() -> bool:
	return Settings.sound

func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[0]   # all busy → steal the first

func _load(file: String) -> AudioStream:
	if file == "":
		return null
	if _cache.has(file):
		return _cache[file]
	var path := DIR + file
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[file] = s
	return s
