extends Control
class_name MatConfig

static func make_mat(tex):
    var mat = SpatialMaterial.new()
    mat.params_diffuse_mode = SpatialMaterial.DIFFUSE_LAMBERT
    mat.roughness = 1.0
    mat.albedo_texture = tex
    return mat

var side = null
var side_mat : SpatialMaterial = null
func set_side(image):
    if image is Image:
        side = image
        var tex = ImageTexture.new()
        tex.create_from_image(image, 0)
        $UI/Images/SideI.texture = tex
        side_mat = make_mat(tex.duplicate())
    elif image is Texture:
        var tex = ImageTexture.new()
        tex.create_from_image(image.get_data(), 0)
        $UI/Images/SideI.texture = tex
        side = $UI/Images/SideI.texture.get_data()
        side_mat = make_mat(image)

var top = null
var top_mat : SpatialMaterial = null
func set_top(image):
    $UI/Images/TopL.text = "Top:"
    
    $UI/Images/Swap.visible = true
    $UI/Images/Done.visible = true
    
    if image is Image:
        top = image
        var tex = ImageTexture.new()
        tex.create_from_image(image, 0)
        $UI/Images/TopI.texture = tex
        top_mat = make_mat(tex.duplicate())
    elif image is Texture:
        var tex = ImageTexture.new()
        tex.create_from_image(image.get_data(), 0)
        $UI/Images/TopI.texture = tex
        top = $UI/Images/TopI.texture.get_data()
        top_mat = make_mat(image)

signal done
func done():
    var v1 = $UI/Images/Transparent.selected
    var v2 = $UI/Images/TransparentMode.selected
    emit_signal("done", [$UI/Images/SideI.texture, $UI/Images/TopI.texture, v1, v2])
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
    $UI/Images/Swap.connect("pressed", self, "swap")
    $UI/Images/Done.connect("pressed", self, "done")
    yield(get_tree(), "idle_frame")
    $UI/CubePreview.anchor_right = 1.0
    $UI/CubePreview.anchor_right = 0.0
    $UI/Images/Cancel.connect("pressed", self, "cancel")
    
    $UI/Images/Transparent.add_item("Opaque", 0)
    $UI/Images/Transparent.add_item("Alpha Scissor", 1)
    $UI/Images/Transparent.add_item("Transparent", 2)
    
    $UI/Images/TransparentMode.add_item("Show Inner Faces", 0)
    $UI/Images/TransparentMode.add_item("Hide Inner Faces", 1)


func _process(_delta):
    $UI/CubePreview.inform_mats(side_mat, top_mat)
    
    $UI/Images/Transparent.visible = top != null
    $UI/Images/TransparentMode.visible = $UI/Images/Transparent.selected != 0 and top != null

func _input(_event):
    if _event is InputEventKey:
        var event : InputEventKey = _event
        if event.pressed and event.scancode == KEY_ESCAPE:
            cancel()
