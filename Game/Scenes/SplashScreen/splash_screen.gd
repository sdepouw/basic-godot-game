class_name SplashScreen
extends Node

func _ready() -> void:
  await get_tree().create_timer(1.5).timeout
  EventBus.load_main_menu.emit()
