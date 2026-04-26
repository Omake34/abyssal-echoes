extends Control

@onready var status_label: Label = %StatusLabel

func _on_signal_button_pressed() -> void:
	status_label.text = "Signal received! Time: " + str(Time.get_ticks_msec())
	print("Button was pressed and signal handled.")
