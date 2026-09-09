# Inspiration: Starport: Galactic Empires

What the original does, described at the pattern level so we can decide what to keep, change, or drop. Sources: starportgame.com (home, information, gallery), StrategyWiki, community wikis. This page is reference, not spec. Decisions live in the system pages.

Legend: **Keep** = adopt as-is in spirit. **Adapt** = keep the idea, change the shape. **Drop** = not for us. **?** = undecided, tracked in a system page's Open questions.

## Presentation and controls

| Original | Verdict | Notes |
|---|---|---|
| 2D top-down, sprite ships, circular planets and ports | Adapt | We render 3D at a fixed iso angle. Same readability, cheaper art per angle. |
| Arrow keys thrust and turn, CTRL primary, TAB secondary | Keep | Rebindable, plus mouse-relative option. |
| "Enter mode" toggle; enterable objects get a white halo | Keep | Great affordance. Halo becomes an outline shader. |
| Shield bar (blue, left) and energy bar (red, right) across the top | Keep | Colors and placement are muscle memory for veterans. |
| Six quick-buttons on each side of the screen | Adapt | Same idea, modern layout. |
| Cargo shown as a grid of boxes on the right | Keep | Slot grid, one commodity per slot. |
| Galaxy map with red lanes for police space, green for plotted route, GoTo autopilot | Keep | Autopilot cancels on any manual input. |
| Top-of-screen pull-down menu, ESC to open | Adapt | Modern menu, same categories. |
| In-game encyclopedia (StarPedia) | Keep | Generated from `data/` so it never goes stale. |
| IRC-style chat, `/tell`, `/shout`, `/help` | Keep | Plus corp channel and system channel. |

## Pacing and persistence

| Original | Verdict | Notes |
|---|---|---|
| Warp fuel accrues in real time, online or offline, with a cap (roughly 2000 start, 5000 cap, ~1 per 2 min) | Keep | Numbers become tuning knobs. |
| Jumps cost ~10 fuel scaled by ship; landing and docking cost 1 | Keep | |
| Persistent real time: log out anywhere and your ship stays in the world | Adapt | "Sleepers" on planets or in open space can be attacked. Safe logout only when docked or in safe space. We keep this but add a grace timer for disconnects. |
| Two shard types: Rebang (resets every ~2 weeks, top 10 get medals) and Permaverse (never resets) | Adapt | Strong idea for retention. Support both via shard config from day one. |
| Shields do not regenerate; buy at ports | Keep | |
| Energy regenerates | Keep | |

## Progression

| Original | Verdict | Notes |
|---|---|---|
| Experience from kills, first visits to ports, taxi and escort missions, haggling, and colonist morale over time | Keep | Colony-driven XP is the main ladder. |
| Reputation is a separate good/evil axis: rises from fighting the opposite alignment, missions, housing colonists, funding bounties | Adapt | Becomes per-faction standing plus a global lawful/outlaw score. See factions.md. |
| Character attributes (e.g. Wisdom reduces fuel per jump) | ? | Light attribute system could work. Decide by M2. |
| Titles by rank | Keep | |
| Bounties on pirates posted at police stations | Keep | |
| Artifacts of alien tech found on planets, including uncolonizable gas giants and tiny worlds | Keep | Exploration reward; some artifacts are ship modules. |

## Ships and equipment

| Original | Verdict | Notes |
|---|---|---|
| Ships bought at only four places in the galaxy | Keep | Starbases are rare on purpose. |
| Hulls with cargo holds and hardware bays | Keep | Hardpoints by type. |
| Ship "specials" (cloak, anti-grav bomb, surface missiles) | Keep | Modeled as built-in secondary or hull trait. |
| Scanners (e.g. neutrino scanner reveals colony contents) and counter-buildings that hide them | Keep | Intel vs. counter-intel loop is good design. |
| Corporate flagship for the corp leader | Keep | |
| Premium ship for real money that is lost on death with partial insurance refund | Drop | Pay-for-power. We monetize cosmetics only, if at all. |
| Admiral Tokens buy fuel, nukes, credits | Drop | Same reason. |

## Combat

| Original | Verdict | Notes |
|---|---|---|
| Police-controlled (U.N.) systems near Earth: no PvP, police respond to aggression | Keep | Our "Concord" safe space. |
| Everything outside is open PvP | Keep | |
| Enemies include ships, planetary defenses, space-anchored turrets | Keep | |
| Projectiles, smart missiles, exotic energy weapons | Keep | Damage types. |
| Nukes as consumables | ? | Powerful consumables tend to become the meta. Decide in M3. |

## Planets and colonies

| Original | Verdict | Notes |
|---|---|---|
| 11 planet types, 9 colonizable; gas giants and tiny worlds are not | Keep | Biomes. |
| Each biome has a population growth tendency, resource profile, pollution rate, and one unique building | Keep | Best part of the original design. Our biome data mirrors this shape. |
| Three "Paradise" worlds per shard with no pollution and an XP-doubling shrine | Keep | Contested super-planets drive endgame conflict. |
| Colonists assigned to construction; buildings consume resources from a refinery stockpile | Keep | |
| Government types trade off morale, production, growth (Democracy, Anarchy, Prison, etc.) | Keep | |
| Morale, taxes, pollution as ongoing management | Keep | Pollution needs cleanup spending. |
| Research per planet | Adapt | Fold into a colony tech tree. |
| Defenses: flak cannon, laser cannon, mines, solar cannon | Keep | |
| Invasion by surface missiles and ships with surface weapons | Adapt | Orbital layer first, then ground layer. See planets.md. |
| Eight commodities: metal ore, anaerobes, medicine, organics, oil, uranium, equipment, spice | Adapt | Starting commodity set. Rename freely, keep the count small. |
| Resource converter building (turn any resource plus uranium into another) | Keep | |

## Economy

| Original | Verdict | Notes |
|---|---|---|
| Ports buy and sell; haggle by choosing an offer percentage | Keep | |
| Passengers and taxi missions | Keep | First quest type. |
| Real-money credits | Drop | |

## What the original lacks that we add

- Procedural galaxy per shard.
- Simulated NPC traffic driving prices.
- Generated quests and galaxy events from world state.
- Named factions with territory and diplomacy, not just good vs. evil.
- Modern netcode with prediction and lag compensation.
