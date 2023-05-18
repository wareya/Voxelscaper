extends OptionButton

func _gui_input(event : InputEvent):
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == 4:
            selected = (selected - 1 + get_item_count()) % get_item_count()
        elif event.button_index == 5:
            selected = (selected + 1) % get_item_count()
