extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
    $Frame/VertEditViewport/Voxel
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    update()

var ref_verts = [
    Vector3(-0.5, -0.5, -0.5),
    Vector3( 0.5, -0.5, -0.5),
    Vector3(-0.5,  0.5, -0.5),
    Vector3( 0.5,  0.5, -0.5),
    Vector3(-0.5, -0.5,  0.5),
    Vector3( 0.5, -0.5,  0.5),
    Vector3(-0.5,  0.5,  0.5),
    Vector3( 0.5,  0.5,  0.5),
]

var vert_overrides = {}

func set_override(vert, new):
    vert_overrides[vert] = new

func get_override(vert):
    if vert in vert_overrides:
        return vert_overrides[vert]
    return vert

var drag_depth = 0.0
var drag_target = null
var drag_mode = false
var camera_mode = false

func _indirect_input(_event):
    var cam : Camera = $Frame/VertEditViewport/CameraHolder/VertEditCamera
    if _event.is_action_pressed("m1") and Input.is_action_just_pressed("m1"):
        drag_target = null
        
        var dist = 10000000.0
        for _vert in ref_verts:
            var vert = get_override(_vert)
            
            vert = (vert*rounding_amount).round()/rounding_amount
            
            var pos = cam.unproject_position(vert)
            var pos_dist = get_local_mouse_position().distance_to(pos)
            if pos_dist < dist and pos_dist < 8.0:
                var depth = -cam.global_transform.xform_inv(vert).z
                dist = pos_dist
                drag_target = _vert
                drag_depth = depth
        
        if drag_target:
            drag_mode = true
    elif !Input.is_action_pressed("m1"):
        if drag_target:
            var vert = get_override(drag_target)
            vert = (vert*rounding_amount).round()/rounding_amount
            set_override(drag_target, vert)
        
        prepare_overrides()
        
        drag_target = null
        drag_mode = false
    
    if _event.is_action_pressed("m3") and Input.is_action_just_pressed("m3"):
        print(_event.is_action_pressed("m3"))
        camera_mode = true
    elif !Input.is_action_pressed("m3"):
        camera_mode = false

    if _event is InputEventMouseMotion:
        var event : InputEventMouseMotion = _event
        
        if drag_mode:
            var vert = get_override(drag_target)
            var pos = cam.unproject_position(vert)
            var depth = drag_depth
            
            pos.x += event.relative.x
            pos.y += event.relative.y
            
            var rect = get_rect()
            pos.x = clamp(pos.x, 0.0, rect.size.x)
            pos.y = clamp(pos.y, 0.0, rect.size.y)
            
            var new_vert : Vector3 = cam.project_position(pos, depth)
            set_override(drag_target, new_vert)
            
            prepare_overrides()
            
        elif camera_mode:
            $Frame/VertEditViewport/CameraHolder.rotation_degrees.y -= 0.22 * event.relative.x
            $Frame/VertEditViewport/CameraHolder.rotation_degrees.x -= 0.22 * event.relative.y

class Sorter:
    func compare(a, b):
        return a[1] > b[1]

var prepared_overrides = []

func prepare_overrides():
    prepared_overrides = []
    for _vert in ref_verts:
        var vert = get_override(_vert)
        vert = (vert*rounding_amount).round()/rounding_amount
        
        if vert.x == 0.0:
            vert.x = 0.0
        if vert.y == 0.0:
            vert.y = 0.0
        if vert.z == 0.0:
            vert.z = 0.0
        
        if _vert != vert:
            prepared_overrides.push_back([_vert*2.0, vert*2.0])

var rounding_amount = 8.0

func _draw():
    var cam : Camera = $Frame/VertEditViewport/CameraHolder/VertEditCamera
    
    #var rect = get_global_rect()
    #rect.position -= rect_global_position
    #draw_rect(rect, Color.red, true)
    var target = null
    
    var dist = 10000000.0
    for _vert in ref_verts:
        var vert = get_override(_vert)
        
        vert = (vert*rounding_amount).round()/rounding_amount
        var pos = cam.unproject_position(vert)
        var pos_dist = get_local_mouse_position().distance_to(pos)
        if pos_dist < dist and pos_dist < 8.0:
            target = vert
            dist = pos_dist
    
    var verts = []
    for _vert in ref_verts:
        var vert = get_override(_vert)
        vert = (vert*rounding_amount).round()/rounding_amount
        var depth = -cam.global_transform.xform_inv(vert).z
        verts.push_back([vert, _vert, depth])
    
    var voxels = $Frame/VertEditViewport/Voxel
    #voxels.place_voxel(Vector3(), voxels.voxels.values()[0], overrides_copy)
    $Frame/VertEditViewport/Voxel.voxel_corners[Vector3()] = prepared_overrides.duplicate(true)
    $Frame/VertEditViewport/Voxel.remesh()
    
    verts.sort_custom(Sorter.new(), "compare")
    
    for _vert in verts:
        var vert = _vert[0]
        var pos = cam.unproject_position(vert)
        #cam.project_position(
        var color = Color(1.0, 0.5, 0.0)
        
        var pos_dist = get_local_mouse_position().distance_to(pos)
        if drag_target == _vert[1]:
            color = Color.aquamarine
            
        if vert == target and !drag_target:
            color = Color.yellow
        
        #draw_circle(pos, 4.0, color)
        draw_arc(pos, 2.0, 0.0, PI*2.01, 24.0, Color.black, 5.4, true)
        draw_arc(pos, 2.0, 0.0, PI*2.01, 24.0, color, 4.0, true)
    pass
