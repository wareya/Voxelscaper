extends SpinBox

func _gui_input(event : InputEvent):
    if get_viewport().gui_get_focus_owner() and is_ancestor_of(get_viewport().gui_get_focus_owner()):
        return
    if event is InputEventMouseButton and event.is_pressed():
        if event.button_index == 4:
            value += step
        elif event.button_index == 5:
            value -= step
        value = clamp(value, min_value, max_value)
        get_tree().get_root().set_input_as_handled()
