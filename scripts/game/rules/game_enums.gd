## Global enums for Tactical Tides.
## These are the vocabulary the whole "brain" (rules + data) speaks. Pure data — no UI here.
class_name GameEnums
extends RefCounted

## Movement tiers — see Tiers.movement_points() / Tiers.rotation_rule().
enum Movement { SLOW, MED, FAST, AGILE }

## Reload tiers — turns between shots. See Tiers.reload_turns().
enum Reload { SHORT, MEDIUM, LONG }

## Special-charge tiers — turns to charge a special. See Tiers.charge_threshold().
enum Charge { SHORT, MEDIUM, LONG, VERY_LONG }

## Cosmetic rarity (shop). Pure prestige — NEVER affects gameplay (Golden Rule #10).
enum Rarity { COMMON, RARE, EPIC, LEGENDARY, MYTHIC }

## What kind of action an Ability is.
enum AbilityKind { FIRE, SPECIAL }

## Direction a ship faces (its footprint extends this way from its origin cell).
enum Facing { NORTH, EAST, SOUTH, WEST }

## What an ability asks the player to target. Lets the future UI know what to request.
## SECTOR is the key one for Active Radar & Barrage Zone — they pick a whole 5x5 zone.
enum TargetKind { SINGLE_SPOT, MULTI_SPOT, LINE, CROSS, POINT, SECTOR }

## Collectible powerups (spawn every 4 turns, page 10).
enum PowerupKind { RAPID_RELOAD, REPAIR, MOVEMENT, OVERCLOCK, MINE_SWEEP }
