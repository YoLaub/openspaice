extends Node
## Autoload ConfigService — réglages joueur persistés dans user://settings.cfg
## (ConfigFile). Couche "réglages joueur" de la config 3 couches.
## [Source: game-architecture.md#Configuration]
##
## STUB : accès get/set/save générique. La clé API BYOK (chiffrée) viendra en Épic 5.

const _PATH: String = "user://settings.cfg"

var _cfg: ConfigFile = ConfigFile.new()

func _ready() -> void:
	# Charge si présent ; l'absence du fichier au 1er lancement n'est pas une erreur.
	var err: int = _cfg.load(_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		Log.warn("ConfigService : échec de chargement de %s (err %d)" % [_PATH, err])

func get_value(section: String, key: String, default_value: Variant = null) -> Variant:
	return _cfg.get_value(section, key, default_value)

func set_value(section: String, key: String, value: Variant) -> void:
	_cfg.set_value(section, key, value)

func save() -> void:
	var err: int = _cfg.save(_PATH)
	if err != OK:
		Log.warn("ConfigService : échec de sauvegarde de %s (err %d)" % [_PATH, err])
