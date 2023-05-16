extends HBoxContainer

func button_factory(text : String, which_signal : String, data : Array = []) -> BaseButton:
    var button = Button.new()
    button.flat = true
    button.text = text
    button.connect("pressed", self, "emit_signal", [which_signal] + data)
    return button

signal file_open
signal file_save
signal file_save_as

func pressed(id : int, which : PopupMenu):
    var selection = which.get_item_text(id)
    if which == $File.get_popup() and selection == "Open":
        emit_signal("file_open")
    elif which == $File.get_popup() and selection == "Save":
        emit_signal("file_save")
    elif which == $File.get_popup() and selection == "Save As":
        emit_signal("file_save_as")

func _ready():
    var file_popup : PopupMenu = $File.get_popup()
    file_popup.add_item("Save", 0)
    file_popup.add_item("Save As", 1)
    file_popup.add_item("Open", 2)
    file_popup.connect("index_pressed", self, "pressed", [file_popup])
    
    file_popup.set_item_accelerator(file_popup.get_item_index(0), KEY_MASK_CTRL | KEY_S)
    file_popup.set_item_accelerator(file_popup.get_item_index(1), KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_S)
    file_popup.set_item_accelerator(file_popup.get_item_index(2), KEY_MASK_CTRL | KEY_O)
