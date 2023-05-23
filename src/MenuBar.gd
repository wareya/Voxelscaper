extends HBoxContainer

func button_factory(text : String, which_signal : String, data : Array = []) -> BaseButton:
    var button = Button.new()
    button.flat = true
    button.text = text
    self.emit_signal.bindv([which_signal] + data)
    return button

signal file_open
signal file_save
signal file_save_as
signal file_export_resource
signal file_export_gltf

func pressed(id : int, which : PopupMenu):
    var selection = which.get_item_text(id)
    
    if which == $File.get_popup() and selection == "Open":
        emit_signal("file_open")
    elif which == $File.get_popup() and selection == "Save":
        emit_signal("file_save")
    elif which == $File.get_popup() and selection == "Save As":
        emit_signal("file_save_as")
    elif which == $File.get_popup() and selection == "Export Godot Mesh Resource":
        emit_signal("file_export_resource")
    elif which == $File.get_popup() and selection == "Export GLTF Model":
        emit_signal("file_export_gltf")
    
    if which == $Controls.get_popup() and id == 0:
        var idx = which.get_item_index(id)
        var on = which.is_item_checked(idx)
        on = !on
        which.set_item_checked(idx, on)
        editor.control_swap = on
    elif which == $Controls.get_popup() and id == 1:
        editor.show_controls()
    
    if which == $Edit.get_popup() and id == 0:
        editor.perform_undo()
    elif which == $Edit.get_popup() and id == 1:
        editor.perform_redo()

@onready var editor = get_tree().get_nodes_in_group("VoxEditor")[0]
func _ready():
    var file_popup : PopupMenu = $File.get_popup()
    file_popup.add_item("Save", 0)
    file_popup.add_item("Save As", 1)
    file_popup.add_item("Open", 2)
    file_popup.add_item("Export Godot Mesh Resource", 3)
    file_popup.add_item("Export GLTF Model", 4)
    file_popup.connect("index_pressed", Callable(self, "pressed").bind(file_popup))
    
    file_popup.set_item_accelerator(file_popup.get_item_index(0), KEY_MASK_CTRL | KEY_S)
    file_popup.set_item_accelerator(file_popup.get_item_index(1), KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_S)
    file_popup.set_item_accelerator(file_popup.get_item_index(2), KEY_MASK_CTRL | KEY_O)
    
    var edit_popup : PopupMenu = $Edit.get_popup()
    edit_popup.add_item("Undo", 0)
    edit_popup.add_item("Redo", 1)
    edit_popup.connect("index_pressed", Callable(self, "pressed").bind(edit_popup))
    edit_popup.set_item_accelerator(edit_popup.get_item_index(0), KEY_MASK_CTRL | KEY_Z)
    edit_popup.set_item_accelerator(edit_popup.get_item_index(1), KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_Z)
    
    var controls_popup : PopupMenu = $Controls.get_popup()
    controls_popup.hide_on_checkable_item_selection = false
    controls_popup.add_check_item("Swap Left/Right Click (MC Style)", 0)
    controls_popup.add_item("Show Controls", 1)
    controls_popup.connect("index_pressed", Callable(self, "pressed").bind(controls_popup))