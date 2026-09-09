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

## Server -> client.
signal welcomed(entity_id: int)
signal snapshot_received(tick: int, ships: Dictionary)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_intent(thrust: float, turn: float) -> void:
	intent_received.emit(multiplayer.get_remote_sender_id(), thrust, turn)


## Tells a fresh peer which snapshot entity is its own ship. Entity ids are
## server-assigned and distinct from ENet peer ids (peers reconnect and NPCs
## have no peer at all).
@rpc("authority", "call_remote", "reliable")
func receive_welcome(entity_id: int) -> void:
	welcomed.emit(entity_id)


## Full state every tick, keyed by entity id; values are ShipState.pack()
## arrays. Deltas are a later optimization (wiki/systems/networking.md).
@rpc("authority", "call_remote", "unreliable_ordered")
func receive_snapshot(tick: int, ships: Dictionary) -> void:
	snapshot_received.emit(tick, ships)
