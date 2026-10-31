## Post-game coin rewards — the ONE source of truth for the reward table, shared by the client
## (the spin wheel shows these segments) and the SERVER (the referee rolls from them). The amount is
## decided server-side with the match RNG so a tampered client can't pick its own payout; the wheel
## is just an animation that lands on the server's number.
class_name Rewards
extends RefCounted

## Winner's wheel: coin value + weight. Small amounts common, 1000 a rare jackpot (~230 avg).
const SEGMENTS := [
	{"coins": 50, "weight": 26},
	{"coins": 100, "weight": 24},
	{"coins": 200, "weight": 20},
	{"coins": 300, "weight": 14},
	{"coins": 500, "weight": 10},
	{"coins": 1000, "weight": 6},
]
const CONSOLATION := 40   # participation reward for the loser

## Roll a winner's reward using the given RNG (the referee passes the match's server-side rng).
static func roll(rng: RandomNumberGenerator) -> int:
	var total := 0
	for s in SEGMENTS:
		total += int(s.weight)
	var r := rng.randi_range(0, total - 1)
	var acc := 0
	for s in SEGMENTS:
		acc += int(s.weight)
		if r < acc:
			return int(s.coins)
	return int(SEGMENTS[-1].coins)

## The wheel segment index for a coin value (so the wheel can land on a server-given amount).
static func index_of(coins: int) -> int:
	for i in SEGMENTS.size():
		if int(SEGMENTS[i].coins) == coins:
			return i
	return 0
