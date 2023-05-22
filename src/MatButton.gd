extends Button

var menu : PopupMenu = null
var delete_conf : ConfirmationDialog = null
func _init():
    menu = PopupMenu.new()
    menu.add_item("Delete Material", 0)
    menu.add_item("Edit Material", 1)
    menu.min_size = Vector2i()
    add_child(menu)
    
    delete_conf = ConfirmationDialog.new()
    delete_conf.dialog_autowrap = true
    delete_conf.dialog_text = """The material will be deleted from the material bar, but materials continue to exist if there is still geometry using them.

Materials that still have geometry will be restored if you save and reload your project.

Materials with no geometry will be deleted forever."""
    delete_conf.connect("confirmed", Callable(self, "delete_material"))
    add_child(delete_conf)
    
    menu.connect("id_pressed", Callable(self, "picked"))

var mat = null
func delete_material():
    editor.delete_mat(mat)

func picked(id : int):
    if id == 0:
        delete_conf.popup_centered_ratio(0.35)
    elif id == 1:
        editor.modify_mat(mat)

var editor = null
func _ready():
    editor = get_tree().get_nodes_in_group("VoxEditor")[0]
    editor.connect("hide_menus", Callable(menu, "hide"))


func _process(delta):
    var f = get_viewport().gui_get_focus_owner()
    if f and self != f and not is_ancestor_of(f):
        menu.hide()

func _gui_input(_event):
    if _event is InputEventMouseButton:
        var event : InputEventMouseButton = _event
        var r = get_rect()
        r.position *= 0.0
        if event.button_index == MOUSE_BUTTON_RIGHT and !event.pressed and r.has_point(event.position):
            menu.set_position(event.global_position + Vector2(get_window().position))
            menu.show()
            
            #var re = menu.get_viewport().get_visible_rect()
            #var r2 = menu.get_global_rect()
            #var bottomright = r2.end
            #var out_bottom = re.end - bottomright
            
            #if out_bottom.x < 0:
            #    menu.global_position.x -= r2.size.x
            #if out_bottom.y < 0:
            #    menu.global_position.y -= r2.size.y
            
            #re = menu.get_viewport_rect()
            #r2 = menu.get_global_rect()
            #var topleft = r2.position
            #var out_top = topleft - re.position
            
            #if out_top.x < 0:
            #    menu.global_position.x -= out_top.x
            #if out_top.y < 0:
            #    menu.global_position.y -= out_top.y
            
