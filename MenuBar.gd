extends HBoxContainer


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

signal save_file

func button_factory(text : String, which_signal : String, data : Array = []) -> BaseButton:
    var button = Button.new()
    button.flat = true
    button.text = text
    button.connect("pressed", self, "emit_signal", [which_signal] + data)
    return button

func pressed(id : int, which : PopupMenu):
    var selection = which.get_item_text(id)
    print(selection)
    pass

# Called when the node enters the scene tree for the first time.
func _ready():
    var file_popup : PopupMenu = $File.get_popup()
    file_popup.add_item("Open")
    file_popup.connect("index_pressed", self, "pressed", [file_popup])
    #file_popup.add_child(button_factory("Open", "save_file"))


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#    pass
