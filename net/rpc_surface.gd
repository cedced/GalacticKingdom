class_name RpcSurface
extends Node
## The complete client<->server wire surface. Both entry scenes instance this
## node at the same path ("/root/Main/Rpc"), so the RPC tables cannot drift —
## Godot matches RPCs by node path, method name, and config, and a mismatch
## silently drops messages. Pure transport: every method just re-emits its
## payload as a signal for whichever side hosts the logic; the emitting end's
## own copy of a method simply has no listeners.

## Client -> server.
signal intent_received(peer_id: int, thrust: float, turn: float)
signal jump_requested(peer_id: int, to_system_id: int)

## Server -> client.
signal welcomed(payload: Dictionary)
signal snapshot_received(tick: int, ships: Dictionary)
signal jumped(system_id: int, fuel: float)
signal jump_denied(reason: String, fuel: float)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_intent(thrust: float, turn: float) -> void:
	intent_received.emit(multiplayer.get_remote_sender_id(), thrust, turn)


## Asks to jump through the current system's gate to a neighboring system.
## The server re-derives everything else (gate, distance, fuel) itself.
@rpc("any_peer", "call_remote", "reliable")
func request_jump(to_system_id: int) -> void:
	jump_requested.emit(multiplayer.get_remote_sender_id(), to_system_id)


## First message after connecting: which snapshot entity is this peer's ship
## (entity ids are server-assigned and distinct from ENet peer ids), the
## galaxy seed the client regenerates the map from, and the fuel contract.
## Keys: entity_id, galaxy_seed, system_id, fuel, fuel_cap, fuel_per_minute.
@rpc("authority", "call_remote", "reliable")
func receive_welcome(payload: Dictionary) -> void:
	welcomed.emit(payload)


## The jump went through: the peer's ship now lives in system_id and its
## authoritative fuel (post-cost) is attached.
@rpc("authority", "call_remote", "reliable")
func receive_jump(system_id: int, fuel: float) -> void:
	jumped.emit(system_id, fuel)


@rpc("authority", "call_remote", "reliable")
func receive_jump_denied(reason: String, fuel: float) -> void:
	jump_denied.emit(reason, fuel)


## Full state every tick, keyed by entity id; values are ShipState.pack()
## arrays. Deltas are a later optimization (wiki/systems/networking.md).
@rpc("authority", "call_remote", "unreliable_ordered")
func receive_snapshot(tick: int, ships: Dictionary) -> void:
	snapshot_received.emit(tick, ships)
