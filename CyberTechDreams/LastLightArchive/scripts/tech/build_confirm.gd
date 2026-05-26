extends Window

signal confirmed
signal cancelled

@onready var message_label: Label = $VBox/MessageLabel
@onready var confirm_btn: Button = $VBox/ButtonRow/ConfirmBtn
@onready var cancel_btn: Button = $VBox/ButtonRow/CancelBtn


func setup(item_name: String, cost: int, have: int) -> void:
	var short: int = cost - have

	if short > 0:
		message_label.text = (
			"%s costs %d scrap.\nYou have %d. You need %d more."
			% [item_name, cost, have, short]
		)
		confirm_btn.visible = false
		cancel_btn.text = "Close"
	else:
		message_label.text = (
			"%s costs %d scrap.\nYou have %d. Build?"
			% [item_name, cost, have]
		)
		confirm_btn.visible = true
		cancel_btn.text = "Cancel"


func _on_confirm_pressed() -> void:
	confirmed.emit()
	queue_free()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()


func _on_close_requested() -> void:
	cancelled.emit()
	queue_free()
