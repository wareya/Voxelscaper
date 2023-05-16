extends HBoxContainer

func button_factory(text : String, which_signal : String, data : Array = []) -> BaseButton:
    var button = Button.new()
    button.flat = true
    button.text = text
    button.connect("pressed", self, "emit_signal", [which_signal] + data)
    return button

signal file_open
signal file_save

func pressed(id : int, which : PopupMenu):
    var selection = which.get_item_text(id)
    if which == $File.get_popup() and selection == "Open":
        emit_signal("file_open")
    elif which == $File.get_popup() and selection == "Save":
        emit_signal("file_save")

func _ready():
    var file_popup : PopupMenu = $File.get_popup()
    file_popup.add_item("Open")
    file_popup.add_item("Save")
    file_popup.connect("index_pressed", self, "pressed", [file_popup])
