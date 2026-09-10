class_name SystemStation
extends RefCounted
## A dockable station. Ports trade commodities; starbases also sell ships
## and equipment (wiki/Glossary.md). Commodity profiles arrive with M2,
## faction ownership with M5.

var id: int = 0
## port | starbase.
var kind: String = ""
## Gameplay-space position on the XZ plane.
var position: Vector2 = Vector2.ZERO
