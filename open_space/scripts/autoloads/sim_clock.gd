extends Node
## Autoload SimClock — horloge logique de simulation basse fréquence (~3 Hz),
## découplée du rendu 60 FPS. Permet aux agents (et plus tard au LLM) de
## "réfléchir" sur plusieurs ticks sans bloquer l'affichage.
## [Source: game-architecture.md#Decision-Summary D3 ; ADR-3]
##
## Story 1.2 : l'émission de ticks est ACTIVE — la simulation tourne enfin.
## SimClock ne porte AUCUNE logique métier : il ne fait qu'émettre simulation_tick
## à cadence fixe. La pause, les vitesses x1/x2/x3 et les journées ouvrées arrivent
## en Story 1.3 (mise à l'échelle/gel du temps ajoutés ici sans toucher aux agents).

## Émis à cadence fixe (~3 Hz) tant que l'horloge tourne. tick_delta = durée d'un tick.
signal simulation_tick(tick_delta: float)

const TICK_HZ: float = 3.0
const TICK_INTERVAL: float = 1.0 / TICK_HZ

var running: bool = false

var _accumulator: float = 0.0

func start() -> void:
	running = true

func stop() -> void:
	running = false

func _process(delta: float) -> void:
	if not running:
		return
	_accumulator += delta
	while _accumulator >= TICK_INTERVAL:
		_accumulator -= TICK_INTERVAL
		simulation_tick.emit(TICK_INTERVAL)
