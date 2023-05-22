extends Control
class_name MatConfig

static func make_mat(tex):
    var mat = StandardMaterial3D.new()
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    mat.params_diffuse_mode = StandardMaterial3D.DIFFUSE_LAMBERT
    mat.roughness = 1.0
    mat.albedo_texture = tex
    return mat

var side = null
var side_mat : StandardMaterial3D = null
func set_side(image):
    if image is Image:
        side = image
        var tex = ImageTexture.create_from_image(image)
        $UI/Images/SideI.texture = tex
        side_mat = make_mat(tex.duplicate())
    elif image is Texture2D:
        var tex = ImageTexture.create_from_image(image.get_image())
        $UI/Images/SideI.texture = tex
        side = $UI/Images/SideI.texture.get_image()
        side_mat = make_mat(image)

var top = null
var top_mat : StandardMaterial3D = null
func set_top(image):
    $UI/Images/TopL.text = "Top:"
    
    $UI/Images/Swap.visible = true
    $UI/Images/Done.visible = true
    
    if image is Image:
        top = image
        var tex = ImageTexture.create_from_image(image)
        $UI/Images/TopI.texture = tex
        top_mat = make_mat(tex.duplicate())
    elif image is Texture2D:
        var tex = ImageTexture.create_from_image(image.get_image())
        $UI/Images/TopI.texture = tex
        top = $UI/Images/TopI.texture.get_image()
        top_mat = make_mat(image)

signal done
func do_done():
    var v1 = $UI/Images/Transparent.selected
    var v2 = $UI/Images/TransparentMode.selected
    var v3 = $UI/Images/TilingMode.selected
    emit_signal("done", [$UI/Images/SideI.texture, $UI/Images/TopI.texture, v1, v2, v3])
    queue_free()

func cancel():
    emit_signal("done", null)
    queue_free()

func swap():
    var temp = side
    side = top
    top = temp
    
    temp = $UI/Images/SideI.texture
    $UI/Images/SideI.texture = $UI/Images/TopI.texture
    $UI/Images/TopI.texture = temp
    
    temp = side_mat.albedo_texture
    side_mat.albedo_texture = top_mat.albedo_texture
    top_mat.albedo_texture = temp

func _ready():
    $UI/Images/Swap.connect("pressed", Callable(self, "swap"))
    $UI/Images/Done.connect("pressed", Callable(self, "do_done"))
    await get_tree().process_frame
    $UI/CubePreview.anchor_right = 1.0
    $UI/CubePreview.anchor_right = 0.0
    $UI/Images/Cancel.connect("pressed", Callable(self, "cancel"))
    
    $UI/Images/Transparent.add_item("Opaque", 0)
    $UI/Images/Transparent.add_item("Alpha Scissor", 1)
    $UI/Images/Transparent.add_item("Transparent", 2)
    
    $UI/Images/TransparentMode.add_item("Show Inner Faces", 0)
    $UI/Images/TransparentMode.add_item("Hide Inner Faces", 1)
    
    $UI/Images/TilingMode.add_item("12x4 Autotile", 0)
    $UI/Images/TilingMode.add_item("4x4 Autotile", 1)
    $UI/Images/TilingMode.add_item("1x1 Local", 2)
    $UI/Images/TilingMode.add_item("1x1 World", 3)


func _process(_delta):
    var v1 = $UI/Images/Transparent.selected
    var v2 = $UI/Images/TransparentMode.selected
    var v3 = $UI/Images/TilingMode.selected
    var mat = VoxEditor.VoxMat.new($UI/Images/SideI.texture, $UI/Images/TopI.texture, v1, v2, v3)
    $UI/CubePreview.inform_mat(mat)
    
    $UI/Images/TopI.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
    $UI/Images/SideI.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
    
    $UI/Images/Transparent.visible = top != null
    $UI/Images/TransparentMode.visible = $UI/Images/Transparent.selected != 0 and top != null

func _input(_event):
    if _event is InputEventKey:
        var event : InputEventKey = _event
        if event.pressed and event.keycode == KEY_ESCAPE:
            cancel()
