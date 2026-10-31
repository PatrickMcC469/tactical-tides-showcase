## Canonical coin-pack products: product id -> coins granted. MUST match the product IDs created in
## App Store Connect / Google Play (and the amounts shown in the coin store art). The referee reads
## this when RevenueCat webhooks a validated purchase, so the player gets exactly what they bought.
class_name CoinProducts
extends RefCounted

const COINS := {
	"coins_500": 500,
	"coins_1200": 1200,
	"coins_2500": 2500,
	"coins_5000": 5000,
	"coins_10000": 10000,
}

## Coins for a product id, or 0 if unknown (unknown products are ignored — never granted).
static func coins_for(product_id: String) -> int:
	return int(COINS.get(product_id, 0))
