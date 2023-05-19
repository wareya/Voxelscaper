extends SpinBox

func _gui_input(event : InputEvent):
    if get_focus_owner() and is_a_parent_of(get_focus_owner()):
        return
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == 4:
            value += step
        elif event.button_index == 5:
            value -= step
        value = clamp(value, min_value, max_value)
