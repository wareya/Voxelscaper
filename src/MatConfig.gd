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
    update_display()

var top = null
var top_mat : StandardMaterial3D = null
func set_top(image):
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
    update_display()

var bottom = null
var bottom_mat : StandardMaterial3D = null
func set_bottom(image):
    if image is Image:
        bottom = image
        var tex = ImageTexture.create_from_image(image)
        $UI/Images/BottomI.texture = tex
        bottom_mat = make_mat(tex.duplicate())
    elif image is Texture2D:
        var tex = ImageTexture.create_from_image(image.get_image())
        $UI/Images/BottomI.texture = tex
        bottom = $UI/Images/BottomI.texture.get_image()
        bottom_mat = make_mat(image)
    update_display()

func set_mat(mat):
    set_side(mat.sides)
    set_top(mat.top)
    set_bottom(mat.bottom)
    
    $UI/Images/TilingMode.selected = mat.tiling_mode
    $UI/Images/Transparent.selected = mat.transparent_mode
    $UI/Images/TransparentMode.selected = mat.transparent_inner_face_mode
    
    $UI/Images/GridContainer/SubdivideX.value = mat.subdivide_amount.x
    $UI/Images/GridContainer/SubdivideY.value = mat.subdivide_amount.y
    $UI/Images/GridContainer/SubdivideXOffset.value = mat.subdivide_coord.x
    $UI/Images/GridContainer/SubdivideYOffset.value = mat.subdivide_coord.y
    
    update_display()

signal done
func do_done():
    var v1 = $UI/Images/Transparent.selected
    var v2 = $UI/Images/TransparentMode.selected
    var v3 = $UI/Images/TilingMode.selected
    var v4 = get_subdivide()
    var v5 = get_subdivide_offset()
    emit_signal("done", [$UI/Images/SideI.texture, $UI/Images/TopI.texture, $UI/Images/BottomI.texture, v1, v2, v3, v4, v5])
    queue_free()

func cancel():
    emit_signal("done", null)
    queue_free()

func swap():
    var temp = bottom
    bottom = top
    top = temp
    
    temp = $UI/Images/BottomI.texture
    $UI/Images/BottomI.texture = $UI/Images/TopI.texture
    $UI/Images/TopI.texture = temp
    
    temp = bottom_mat
    bottom_mat = top_mat
    top_mat = temp
    
    update_display()

func cycle():
    var temp = bottom
    bottom = side
    side = top
    top = temp
    
    temp = $UI/Images/BottomI.texture
    $UI/Images/BottomI.texture = $UI/Images/SideI.texture
    $UI/Images/SideI.texture = $UI/Images/TopI.texture
    $UI/Images/TopI.texture = temp
    
    temp = bottom_mat
    bottom_mat = side_mat
    side_mat = top_mat
    top_mat = temp
    
    update_display()

func _ready():
    $UI/Images/Swap.connect("pressed", Callable(self, "swap"))
    $UI/Images/Cycle.connect("pressed", Callable(self, "cycle"))
    $UI/Images/Done.connect("pressed", Callable(self, "do_done"))
    
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
    
    await get_tree().process_frame
    $UI/CubePreview.anchor_right = 1.0
    $UI/CubePreview.anchor_right = 0.0

func get_subdivide():
    return Vector2($UI/Images/GridContainer/SubdivideX.value, $UI/Images/GridContainer/SubdivideY.value)
func get_subdivide_offset():
    return Vector2($UI/Images/GridContainer/SubdivideXOffset.value, $UI/Images/GridContainer/SubdivideYOffset.value)

func get_mat_info():
    var v1 = $UI/Images/Transparent.selected
    var v2 = $UI/Images/TransparentMode.selected
    var v3 = $UI/Images/TilingMode.selected
    var v4 = get_subdivide()
    var v5 = get_subdivide_offset()
    return [v1, v2, v3, v4, v5]

func get_mat():
    var v1 = $UI/Images/Transparent.selected
    var v2 = $UI/Images/TransparentMode.selected
    var v3 = $UI/Images/TilingMode.selected
    var v4 = get_subdivide()
    var v5 = get_subdivide_offset()
    var mat = VoxEditor.VoxMat.new($UI/Images/SideI.texture, $UI/Images/TopI.texture, $UI/Images/BottomI.texture, v1, v2, v3, v4, v5)
    return mat

func update_display():
    var mat = get_mat()
    
    $UI/CubePreview.inform_mat(mat)
    
    $UI/Images/TopI.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
    $UI/Images/SideI.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
    
    $UI/Images/TransparentMode.visible = $UI/Images/Transparent.selected != 0

func add_texture(tex):
    trigger_picker(tex)

var picker = null
func trigger_picker(tex):
    picker = preload("res://src/VoxelSidePicker.tscn").instantiate()
    add_child(picker)
    var which = await picker.done
    if which == "top":
        set_top(tex)
    elif which == "bottom":
        set_bottom(tex)
    elif which == "side":
        set_side(tex)
    
    picker.queue_free()
    picker = null

func _input(_event):
    if _event is InputEventKey:
        var event : InputEventKey = _event
        if event.pressed and event.keycode == KEY_ESCAPE:
            if picker:
                picker.queue_free()
                picker = null
            else:
                cancel()


var prev_info = []
func _process(delta):
    var mat_info = get_mat_info()
    if mat_info != prev_info:
        update_display()
    prev_info = mat_info
    $UI/Images/Done.visible = side != null and top != null and bottom != null
