extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

func axialize(n : Vector3) -> Vector3:
    n = n.normalized()
    var closest_dist_sq = n.distance_squared_to(Vector3.UP)
    var ret = Vector3.UP
    for dir in [Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
        var d2 = n.distance_squared_to(dir)
        if d2 < closest_dist_sq:
            closest_dist_sq = d2
            ret = dir
    return ret

func flush_negative_zero(n : Vector3) -> Vector3:
    if n.x == 0.0:
        n.x = 0.0
    if n.y == 0.0:
        n.y = 0.0
    if n.z == 0.0:
        n.z = 0.0
    return n

func action(which):
    var cam : Camera = $Frame/VertEditViewport/CameraHolder/VertEditCamera
    
    #print()
    
    var copy = {}
    for vert in ref_verts:
        copy[vert] = get_override(vert)
    
    var right : Vector3 = axialize(cam.global_transform.basis.xform(Vector3.RIGHT))
    var up : Vector3 = axialize(cam.global_transform.basis.xform(Vector3.UP))
    var front : Vector3 = axialize(cam.global_transform.basis.xform(Vector3.FORWARD))
    
    if which == "left" or which == "right":
        var _sign = -1.0 if which == "left" else 1.0
        for vert in ref_verts:
            var modified = copy[vert.rotated(front, -PI*0.5*_sign).round()*0.5]
            var new_modified = (modified as Vector3).rotated(front, PI*0.5*_sign)
            #print(vert, " ", modified, " ", new_modified)
            set_override(vert, new_modified)
    
    if which == "fliph" or which == "flipv":
        var _dir : Vector3 = (-up.abs()) if which == "flipv" else (-right.abs())
        #print("dir:")
        #print(_dir)
        _dir = Vector3.ONE - Vector3.ONE*_dir.abs() + _dir
        #print(_dir)
        for vert in ref_verts:
            var opposite = vert * _dir
            var modified = copy[opposite] * _dir
            #print(vert, " ", modified)
            set_override(vert, modified)
    
    if which == "reset":
        for vert in ref_verts:
            set_override(vert, vert)
    
    if which == "resetcam":
        $Frame/VertEditViewport/CameraHolder.rotation_degrees = $"../CameraHolder".rotation_degrees
    
    for vert in vert_overrides.keys():
        vert_overrides[vert] = (vert_overrides[vert]*rounding_amount).round()/rounding_amount
    
    prepare_overrides()


# Called when the node enters the scene tree for the first time.
func _ready():
    $Buttons/Left.connect("pressed", self, "action", ["left"])
    $Buttons/Right.connect("pressed", self, "action", ["right"])
    $Buttons/FlipH.connect("pressed", self, "action", ["fliph"])
    $Buttons/FlipV.connect("pressed", self, "action", ["flipv"])
    $Buttons/Reset.connect("pressed", self, "action", ["reset"])
    $Buttons/ResetCamera.connect("pressed", self, "action", ["resetcam"])
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    var cam : Camera = $Frame/VertEditViewport/CameraHolder/VertEditCamera
    var front : Vector3 = axialize(cam.global_transform.basis.xform(Vector3.FORWARD))
    $Frame/VertEditViewport/Grid.global_translation = -front*0.51
    if front.abs() != Vector3.UP:
        $Frame/VertEditViewport/Grid.look_at(-front, Vector3.UP)
    else:
        $Frame/VertEditViewport/Grid.look_at(-front, Vector3.FORWARD)
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

func set_overrides(list):
    print(vert_overrides)
    print(list)
    vert_overrides = {}
    for k in list:
        vert_overrides[k*0.5] = list[k]*0.5
    prepare_overrides()
    update()

func set_override(vert, new):
    vert_overrides[vert] = new

func get_override(vert):
    if vert in vert_overrides:
        return vert_overrides[vert]
    return vert

var drag_depth = 0.0
var drag_target = null
var drag_initial_value = null
var drag_mode = false
var camera_mode = false

func _indirect_input(_event):
    if !visible:
        return
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
            drag_initial_value = get_override(drag_target)
            drag_mode = true
    elif !Input.is_action_pressed("m1"):
        if drag_target:
            var vert = get_override(drag_target)
            vert = (vert*rounding_amount).round()/rounding_amount
            set_override(drag_target, vert)
        
        prepare_overrides()
        
        drag_initial_value = null
        drag_target = null
        drag_mode = false
    
    if _event.is_action_pressed("m3") and Input.is_action_just_pressed("m3"):
        #print(_event.is_action_pressed("m3"))
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
            var cam_normal = cam.project_ray_normal(pos)
            
            if $Frame/VertEditViewport/PlaneLock.pressed:
                var front : Vector3 = axialize(cam.global_transform.basis.xform(Vector3.FORWARD))
                #var positive = front.abs()
                var diff = drag_initial_value*front - new_vert*front
                
                # positive = on screen side of intended plane, negative = opposite
                var dist = diff.x + diff.y + diff.z
                
                var normal_locked = cam_normal * front
                var normal_lock_dist = normal_locked.x + normal_locked.y + normal_locked.z
                cam_normal /= normal_lock_dist
                
                var fudge = dist * cam_normal
                
                new_vert += fudge
            
            new_vert.x = clamp(new_vert.x, -1.0, 1.0)
            new_vert.y = clamp(new_vert.y, -1.0, 1.0)
            new_vert.z = clamp(new_vert.z, -1.0, 1.0)
            
            set_override(drag_target, new_vert)
            
            prepare_overrides()
            
        elif camera_mode:
            $Frame/VertEditViewport/CameraHolder.rotation_degrees.y -= 0.22 * event.relative.x
            $Frame/VertEditViewport/CameraHolder.rotation_degrees.x -= 0.22 * event.relative.y

class Sorter:
    func compare(a, b):
        return a[1] > b[1]

var prepared_overrides = {}

func prepare_overrides():
    prepared_overrides = {}
    for _vert in ref_verts:
        var vert = get_override(_vert)
        vert = (vert*rounding_amount).round()/rounding_amount
        
        #if drag_target == _vert and $Frame/VertEditViewport/PlaneLock.pressed:
        #    var cam : Camera = $Frame/VertEditViewport/CameraHolder/VertEditCamera
        #    
        #    var front : Vector3 = axialize(cam.global_transform.basis.xform(Vector3.FORWARD))
        #    var positive = front.abs()
        #    var negative = Vector3.ONE - positive
        #    print(positive, negative)
        #    vert = vert * negative + drag_initial_value * positive
        #    print(drag_initial_value, vert)
        
        vert = flush_negative_zero(vert)
        
        if _vert != vert:
            prepared_overrides[_vert*2.0] = vert*2.0
    
    #print()
    #for v in prepared_overrides:
    #    print(v)

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
    voxels.voxel_corners[Vector3()] = prepared_overrides.duplicate(true)
    voxels.remesh()
    
    verts.sort_custom(Sorter.new(), "compare")
    
    for _vert in verts:
        var vert = _vert[0]
        var pos = cam.unproject_position(vert)
        #cam.project_position(
        var color = Color(1.0, 0.5, 0.0)
        
        #var pos_dist = get_local_mouse_position().distance_to(pos)
        if drag_target == _vert[1]:
            color = Color.aquamarine
            
        if vert == target and !drag_target:
            color = Color.yellow
        
        #draw_circle(pos, 4.0, color)
        draw_arc(pos, 2.0, 0.0, PI*2.01, 24, Color.black, 5.4, true)
        draw_arc(pos, 2.0, 0.0, PI*2.01, 24, color, 4.0, true)
    pass
