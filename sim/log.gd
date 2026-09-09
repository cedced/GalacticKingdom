class_name Log
extends RefCounted
## Structured logging facade (CLAUDE.md Section 6).
## The bare print() below is the single sanctioned print in gameplay code;
## everything else must go through Log.info/warn/error.


static func info(system: String, message: String, context: Dictionary = {}) -> void:
	_write("INFO", system, message, context)


static func warn(system: String, message: String, context: Dictionary = {}) -> void:
	_write("WARN", system, message, context)


static func error(system: String, message: String, context: Dictionary = {}) -> void:
	_write("ERROR", system, message, context)


static func _write(level: String, system: String, message: String, context: Dictionary) -> void:
	var suffix: String = "" if context.is_empty() else " " + JSON.stringify(context)
	print("[%s][%s] %s%s" % [level, system, message, suffix])
