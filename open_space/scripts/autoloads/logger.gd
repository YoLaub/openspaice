extends Node
## Autoload Logger — journalisation transverse (cross-cutting).
## Niveaux ERROR / WARN / INFO / DEBUG ; DEBUG no-op en build release.
## Sortie : console + fichier texte sous user://logs/.
## [Source: game-architecture.md#Logging]
##
## Note : enregistré comme singleton autoload "Logger". Pas de `class_name`
## pour éviter le conflit nom autoload ↔ classe globale en Godot 4.

enum Level { ERROR, WARN, INFO, DEBUG }

const _LEVEL_NAMES: Array[String] = ["ERROR", "WARN", "INFO", "DEBUG"]
const _LOG_DIR: String = "user://logs/"

var _file: FileAccess = null

func _ready() -> void:
	_open_log_file()
	info("Logger initialisé")

func _open_log_file() -> void:
	DirAccess.make_dir_recursive_absolute(_LOG_DIR)
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = "%ssession_%s.log" % [_LOG_DIR, stamp]
	_file = FileAccess.open(path, FileAccess.WRITE)

func error(msg: String) -> void:
	_write(Level.ERROR, msg)

func warn(msg: String) -> void:
	_write(Level.WARN, msg)

func info(msg: String) -> void:
	_write(Level.INFO, msg)

func debug(msg: String) -> void:
	if OS.is_debug_build():
		_write(Level.DEBUG, msg)

func _write(level: int, msg: String) -> void:
	var line: String = "[%s] [%s] %s" % [
		Time.get_time_string_from_system(), _LEVEL_NAMES[level], msg
	]
	match level:
		Level.ERROR:
			push_error(line)
		Level.WARN:
			push_warning(line)
		_:
			print(line)
	if _file != null:
		_file.store_line(line)
		_file.flush()
