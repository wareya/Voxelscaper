extends Control
class_name DecalConfig

static func make_mat(decalmat):
    var mat = StandardMaterial3D.new()
    mat.params_diffuse_mode = StandardMaterial3D.DIFFUSE_LAMBERT
    mat.roughness = 1.0
    mat.albedo_texture = decalmat.tex
    mat.params_use_alpha_scissor = true
    
    var tex_size = decalmat.tex.get_size()
    var offset = (decalmat.icon_coord * decalmat.grid_size) / tex_size
    var scale = decalmat.grid_size/tex_size
    mat.uv1_scale = Vector3(scale.x, scale.y, 0) 
    mat.uv1_offset = Vector3(offset.x, offset.y, 0)
    
    return mat

var tex = null
func set_mat(image):
    if image is Image:
        tex = ImageTexture.create_from_image(image)
        print(tex)
        print(image.get_size())
        print(tex.get_size())
        $UI/Images/Texture2D.texture = tex
        $UI/DecalTypePreview.tex = tex
    elif image is Texture2D:
        tex = ImageTexture.create_from_image(image.get_image())
        $UI/Images/Texture2D.texture = tex
        $UI/DecalTypePreview.tex = tex
    else:
        print("?????")

func set_grid_size(vec : Vector2):
    $UI/DecalTypePreview.set_grid_size(vec)

func set_icon_coord(vec : Vector2):
    $UI/DecalTypePreview.icon_coord = vec

signal done
func do_done():
    emit_signal("done", [tex, $UI/DecalTypePreview.grid_size, $UI/DecalTypePreview.icon_coord])
    queue_free()

func cancel():
    emit_signal("done", null)
    queue_free()

func _ready():
    $UI/Images/Done.connect("pressed", Callable(self, "do_done"))
    await get_tree().process_frame
    $UI/Images/Cancel.connect("pressed", Callable(self, "cancel"))

func _input(_event):
    if _event is InputEventKey:
        var event : InputEventKey = _event
        if event.pressed and event.keycode == KEY_ESCAPE:
            cancel()
