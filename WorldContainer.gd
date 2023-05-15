extends Control

func _unhandled_input(event):
    print("input ", event)
    $World._unhandled_input(event)
