class_name Game
extends Node

# TODO: Finite State Machine instead of bool _gameOn?
# Game is new -> started <-> paused, started -> stopped, stopped -> new

# TODO: Each match also rewards a cheese? ('flip' equation card?)
# Could show equations instead of numbers, and then a cheese is (sometimes) revealed
# TODO: More complex scoring
# - Timer for each move (3-5 seconds, counts as Miss if timer expires)
# - Randomly find cheese. Guarantee cheese every 10th get
#   - Increase timer to 60 seconds
# - At end, each found cheese adds to score
#   - Each found cheese is worth 500 points
#   - "Favorite Cheese" (user option), worth double
#   - Game Over screen shows raw score, then cheese tally for total
#   - Update high score live (only persist it at end of tally)
# TODO: Sound/Animation when scoring
# TODO: Sound/Animation/Congrats on new high score

@onready var _events: GameEvents = $GameEvents
@onready var _target1: Target = $Target1
@onready var _target2: Target = $Target2
@onready var _target3: Target = $Target3
@onready var _target4: Target = $Target4
@onready var _target5: Target = $Target5
@onready var _target6: Target = $Target6
@onready var _reticle: Sprite2D = $Reticle
@onready var _currentlyHeldThing: Label = $CurrentlyHeldThing;
@onready var _hud: HUD = $HUD
@onready var _gameTimer: Timer = $GameTimer
@onready var _countdownTimer: Timer = $CountdownTimer
@onready var _countdownLabel: Label = $CountdownLabel

var _maxX: int
var _maxY: int
var _targets: Array
var _targetsFlattened: Array[Target]
var _currentTarget: Vector2
var _answer_to_hit: int:
  set(value):
    _answer_to_hit = value
    _currentlyHeldThing.text = str(value)
var _gameOn: bool

# Scoring
var _current_score: int:
  set(value):
    _current_score = max(value, 0)
    _hud.update_score_display(_current_score)
var _current_streak: int:
  set(value):
    _current_streak = value
    _hud.update_streak_display(_current_streak, _on_notable_streak())
func _on_notable_streak() -> bool:
  return _current_streak > 2

## Gets the Target that the reticle is currently selecting
func _getCurrentTarget() -> Target:
  return _targets[_currentTarget.y][_currentTarget.x]

func _ready() -> void:
  _targets.append([_target1, _target2, _target3])
  _targets.append([_target4, _target5, _target6])
  _targetsFlattened = [_target1, _target2, _target3, _target4, _target5, _target6]
  var firstSet: Array = _targets[0]
  _maxX = firstSet.size() - 1
  _maxY = _targets.size() - 1
  _events.game_started.emit()
  HighScore.updated.connect(_hud.update_high_score_display)
  _hud.update_high_score_display(HighScore.get_current_high_score())

func _process(_delta: float) -> void:
  if _gameOn:
    _hud.update_time_display(_gameTimer.time_left)
  if !_countdownTimer.is_stopped():
    _countdownLabel.text = str(ceili(_countdownTimer.time_left))

func generate_new_targets() -> void:
  for target: Target in _targetsFlattened:
    var current_answer: int = target.generate_new_equation()
    # Guarantee all answers are unique
    while _targetsFlattened.filter(func (element: Target) -> bool: return element.get_answer() == current_answer).size() > 1:
      current_answer = target.generate_new_equation()
  var selectedTarget: Target = _targetsFlattened.pick_random()
  _answer_to_hit = selectedTarget.get_answer()

func _toggle_game_piece_visibility(gamePiecesVisible: bool) -> void:
  _gameOn = gamePiecesVisible
  for item: CanvasItem in get_tree().get_nodes_in_group("GamePieces"):
    item.visible = gamePiecesVisible

func _toggle_game_over_visibility(visible: bool) -> void:
  for item: CanvasItem in get_tree().get_nodes_in_group("GameOverPieces"):
    item.visible = visible

func _on_game_started() -> void:
  _current_score = 0
  _current_streak = 0
  _currentTarget = Vector2.ZERO
  _hud.update_time_display(_gameTimer.wait_time)
  _toggle_game_over_visibility(false)
  await _run_countdown_async()
  _toggle_game_piece_visibility(true)
  _reticle.position = _getCurrentTarget().position
  generate_new_targets()
  _gameTimer.start()

func _on_game_ended() -> void:
  _toggle_game_piece_visibility(false)
  _toggle_game_over_visibility(true)
  if _current_score > HighScore.get_current_high_score():
    HighScore.save_new_high_score(_current_score)

func _on_player_shoot() -> void:
  if !_gameOn:
    return
  if _answer_to_hit == _getCurrentTarget().get_answer():
    _current_streak += 1
    const BASE_SCORE: int = 100
    if _on_notable_streak():
      var streak_bonus: int = ceili(BASE_SCORE * _current_streak * 0.15)
      _current_score += BASE_SCORE + streak_bonus
    else:
      _current_score += 100
  else:
    _current_score -= 50
    _current_streak = 0
  generate_new_targets()

func _on_player_moved(direction: Globals.Direction) -> void:
  if !_gameOn:
    return
  var new_position: Vector2 = _get_new_reticle_position(direction)
  _currentTarget = new_position
  _reticle.position = _getCurrentTarget().position

func _get_new_reticle_position(direction: Globals.Direction) -> Vector2:
  var new_position: Vector2 = _currentTarget
  if direction == Globals.Direction.LEFT: new_position.x -= 1
  if direction == Globals.Direction.RIGHT: new_position.x += 1
  if direction == Globals.Direction.DOWN: new_position.y += 1
  if direction == Globals.Direction.UP: new_position.y -= 1
  if new_position.x > _maxX: new_position.x = 0
  if new_position.x < 0: new_position.x = _maxX;
  if new_position.y > _maxY: new_position.y = 0;
  if new_position.y < 0: new_position.y = _maxY;
  return new_position

func _on_game_timer_timeout() -> void:
  _events.game_ended.emit()

func _on_main_menu_button_pressed() -> void:
  EventBus.load_main_menu.emit()

func _run_countdown_async() -> void:
  _countdownLabel.show()
  _countdownTimer.start()
  await _countdownTimer.timeout
  _countdownLabel.hide()
