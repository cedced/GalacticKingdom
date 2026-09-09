# Economy and Shops

## Purpose
Prices that move for reasons players can learn and exploit. Shops that feel like places, not menus.

## Player-facing rules
- Ports show buy and sell prices per commodity. Prices drift with local supply and demand.
- Haggling: choose an offer percentage. Success chance depends on faction standing and a hidden port disposition. Failed haggles cool down.
- Starbases sell hulls, weapons, shields, colony pods. Their stock is finite and restocks over time.
- Selling large volumes crashes the local price. Buying large volumes raises it. Recovery takes real time.
- NPC traders move goods between ports, slowly arbitraging away obvious routes.

## Data model
- `Commodity { id, base_price, volatility, category, volume_per_unit }`. Launch set is the eight colony commodities (see planets.md) so colonies and ports speak the same language.
- Passengers are a special non-stackable cargo tied to taxi quests.
- `PortMarket { station_id, inventory: {commodity: {qty, target_qty}}, disposition, last_tick_at }`
- Price = `base_price * f(qty / target_qty)` where f is a clamped inverse curve, times an event multiplier.

## Algorithms
- Economy tick every 60 s: each port moves `qty` toward `target_qty` by a production/consumption rate; NPC trader routes are scored by expected profit minus danger and a random ship dispatched on the best few.
- Trades are validated on the server against the price at the moment of the trade, not the price the client displayed.

## Tuning knobs
`economy.tick_s`, `economy.price_curve_k`, `economy.npc_trader_count`, `economy.haggle_base_chance`, `economy.restock_hours`.

## Interactions
- Galaxy generator sets initial targets from resources.
- Events apply multipliers (blockade, shortage, boom).
- Factions set tariffs by standing.
- Planets feed supply into nearby ports.

## Open questions
- Player-owned shops or market orders.
- Credit sinks beyond ships and shields (insurance, port fees, pollution cleanup already counts).
- Haggle success feeding experience (the original does this; small but fun).

## Test plan
- Price curve monotonic and bounded.
- Simulation harness: run 30 in-game days headless, assert no commodity goes to zero or infinity.
- NPC traders reduce price variance between connected ports over time.
