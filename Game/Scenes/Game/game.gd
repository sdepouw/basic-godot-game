class_name Game
extends Node

@onready var _equation_board: EquationBoard = $EquationBoard
@onready var _bluey: BlueyAnswer = $BlueyAnswer
@onready var _hud: HUD = $HUD
@onready var _game_timer: Timer = $GameTimer
@onready var _countdown_timer: Timer = $CountdownTimer
@onready var _countdown_label: Label = $CountdownLabel
@onready var _pause_screen: PauseScreen = $PauseScreen
@onready var _game_over_canvas: GameOverCanvas = $GameOverCanvas
@onready var _wrong_sound: SoundEffect = $WrongSound
@onready var _correct_sound: SoundEffect = $CorrectSound
@onready var _new_high_score_sound: SoundEffect = $NewHighScoreSound
@onready var _score_keeper: ScoreKeeper = ScoreKeeper.new()

var _answer_to_hit: int:
  set(value):
    _answer_to_hit = value
    _bluey.set_answer(value)
var _game_on: bool

var _high_score_reached: bool = false

func _ready() -> void:
  _start_new_game()
  _toggle_game_piece_visibility(false)
  _game_over_canvas.hide()
  _score_keeper.score_updated.connect(_hud.update_score_display)

func _process(_delta: float) -> void:
  if _game_on:
    _hud.update_time_display(_game_timer.time_left)
  if !_countdown_timer.is_stopped():
    _countdown_label.text = str(ceili(_countdown_timer.time_left))

func _generate_new_equations() -> void:
  var equations: Array[Equation] = _equation_board.generate_unique_equations()
  _answer_to_hit = _pick_random_equation(equations).get_answer()

func _pick_random_equation(equations: Array[Equation]) -> Equation:
  return equations.pick_random()

func _toggle_game_piece_visibility(visible: bool) -> void:
  _game_on = visible
  for item: CanvasItem in get_tree().get_nodes_in_group("GamePieces"):
    item.visible = visible

func _start_new_game() -> void:
  _score_keeper.reset()
  _high_score_reached = false
  _hud.update_time_display(_game_timer.wait_time)
  _hud.update_high_score_display(HighScore.get_current_high_score())
  _game_over_canvas.hide()
  _generate_new_equations()
  await _run_countdown_async()
  _equation_board.toggle_cursor_sound(true)
  _toggle_game_piece_visibility(true)
  _game_timer.start()
  _pause_screen.can_pause = true

func _end_game() -> void:
  _pause_screen.can_pause = false
  _toggle_game_piece_visibility(false)
  _hud.show_game_end()
  _equation_board.toggle_cursor_sound(false)
  _equation_board.hide()
  var high_score_beaten: bool = _score_keeper.get_score() > HighScore.get_current_high_score()
  _game_over_canvas.show_game_over(high_score_beaten)
  if high_score_beaten:
    HighScore.save_new_high_score(_score_keeper.get_score())

func _on_board_equation_selected(equation: Equation) -> void:
  if !_game_on or equation == null:
    return
  if _answer_to_hit == equation.get_answer():
    _score_keeper.score_hit()
    if _score_keeper.get_score() > HighScore.get_current_high_score():
      if not _high_score_reached:
        _new_high_score_sound.play()
        _high_score_reached = true
      else:
        _correct_sound.play()
      _hud.update_high_score_display(_score_keeper.get_score(), true)
    else:
      _correct_sound.play()
  else:
    _wrong_sound.play()
    _score_keeper.score_miss()
    if _score_keeper.get_score() <= HighScore.get_current_high_score():
      _hud.update_high_score_display(HighScore.get_current_high_score(), false)
    else:
      _hud.update_high_score_display(_score_keeper.get_score(), true)
  _generate_new_equations()

func _on_game_timer_timeout() -> void:
  _end_game()

func _on_play_again_requested() -> void:
  _start_new_game()

func _run_countdown_async() -> void:
  _equation_board.show() # Allow preview of first set of equations
  _equation_board.reset_reticle_position()
  _countdown_label.show()
  _countdown_timer.start()
  await _countdown_timer.timeout
  _countdown_label.hide()

func _on_pause_screen_paused() -> void:
  _toggle_game_piece_visibility(false)
  _equation_board.hide()

func _on_pause_screen_unpaused() -> void:
  _toggle_game_piece_visibility(true)
  _equation_board.show()
