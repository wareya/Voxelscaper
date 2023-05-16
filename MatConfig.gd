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
    side = image
    var tex = ImageTexture.new()
    tex.create_from_image(image, ImageTexture.FLAG_CONVERT_TO_LINEAR)
    $UI/Images/SideI.texture = tex
    
    side_mat = make_mat(tex)

var top = null
var top_mat : SpatialMaterial = null
func set_top(image):
    $UI/Images/TopL.text = "Top:"
    
    top = image
    var tex = ImageTexture.new()
    tex.create_from_image(image, ImageTexture.FLAG_CONVERT_TO_LINEAR)
    $UI/Images/TopI.texture = tex
    
    $UI/Images/Swap.visible = true
    $UI/Images/Done.visible = true
    
    top_mat = make_mat(tex)

signal done
func done():
    emit_signal("done", [$UI/Images/SideI.texture, $UI/Images/TopI.texture])
    queue_free()

func swap():
    var temp = side
    side = top
    top = temp
    
    temp = $UI/Images/SideI.texture
    $UI/Images/SideI.texture = $UI/Images/TopI.texture
    $UI/Images/TopI.texture = temp
    
    side_mat.albedo_texture = $UI/Images/SideI.texture
    top_mat.albedo_texture = $UI/Images/TopI.texture

func _ready():
    $UI/Images/Swap.connect("pressed", self, "swap")
    $UI/Images/Done.connect("pressed", self, "done")
    yield(get_tree(), "idle_frame")
    $UI/CubePreview.force_update()


func _process(_delta):
    $UI/CubePreview.inform_mats(side_mat, top_mat)
