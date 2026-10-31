# Tactical Tides

A turn-based naval strategy game for two players, a reimagining of Battleship. It has a 20×20 board, ships that move and rotate, special abilities that charge over time, and powerups. Matches are asynchronous: you take your turn, and your friend plays theirs whenever they open the app.

**Status: in development** · Godot 4.6 and GDScript · Mobile first, Steam planned · Wandering Turtle Games

> This repository is a **source-code sample** for portfolio review. Art, scenes, and backend credentials are not included. See [NOTICE.md](NOTICE.md).

---

## Highlights

- **Authoritative server ("never trust the client"):** A headless Godot referee re-runs every submitted turn through the same rules code the client uses. Illegal moves, uncharged abilities, out-of-turn actions, and tampered requests are rejected, and the server never sends the client the enemy fleet's positions.
- **Rules separated from UI:** All game rules live in `scripts/game/` with no UI dependencies. The same code runs on phones, the server, and headless tests, and the planned Steam port only needs a new UI.
- **Ships are data, abilities are classes:** A ship is a row of stats (health, movement, reload, and charge tiers, plus ability IDs). Each of the 14 abilities extends a shared `Ability` interface, so adding a ship means adding data, and adding an ability means adding one file.
- **Backend:** An HTTP referee with input validation, per-session rate limiting, and invite-code matchmaking. It's backed by Supabase Postgres, containerized with Docker, and deployed on Google Cloud Run. An end-to-end headless test runs the real game client against the live server.
- **Fair monetization by design:** Cosmetics only. No pay-to-win, no loot boxes, and nothing random for sale. Purchases and currency are checked on the server so they can't be faked on the device.

## Architecture

```
scripts/
├─ game/              THE RULES — pure logic, no UI
│  ├─ rules/          board, 5×5 sectors, ship state, game state, tier tables
│  ├─ data/           ship catalog (ships defined as data)
│  ├─ abilities/      one small class per fire/special ability
│  ├─ effects/        persistent effects: mines, drones, barrages
│  └─ net/            turn encoding, referee, local and Supabase match stores, HTTP client
├─ server/            headless HTTP referee and server integration tests
├─ ui/                THE SCREENS — board, turn, placement, store, rewards, invites
└─ tools/             editor build helpers
```

### How a turn is validated

```gdscript
# scripts/game/net/referee.gd (simplified)
static func apply(gs: GameState, turn: Turn) -> Dictionary:
    if turn.player != gs.current_player:
        return _fail("not this player's turn")
    # 1) replay the optional move step by step: bounds, collisions, movement points
    # 2) run the special through Ability.execute(): charged? legal target?
    # 3) run the fire action, then return the hits and sunk ships
```

If any step fails, the whole turn is rejected, so a modified client can't produce an illegal result.

## Testing

`scripts/server/` includes headless integration tests for authentication, match creation and joining, daily rewards, purchases, ad-reward verification, ship-sinking resolution, and player-name handling.

## Tech

Godot 4.6 · GDScript · Supabase (Postgres, Auth) · Docker · Google Cloud Run · Codemagic CI/CD · AI-assisted development with Claude Code
