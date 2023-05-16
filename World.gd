tool
extends Spatial
class_name VoxEditor

### TODO LIST
# - save/load textual map format
# - deform tool
# - shape picking/eyedropper
# - material picking/eyedropper
# - deleting and modifying existing materials
# - billboard and biplane "meshes"
# - decals
# - save gltf (might need to port to godot 4)
# - importing real meshes somehow maybe?

class VoxMat extends Reference:
    var sides : Texture
    var top   : Texture
    
    func _init(_sides : Texture, _top : Texture):
        sides = _sides
        top = _top
    
    func encode() -> Dictionary:
        var top_png = top.get_data().save_png_to_buffer()
        var sides_png = sides.get_data().save_png_to_buffer()
        return {"top": top_png, "sides": sides_png}
    
    static func decode(dict : Dictionary) -> VoxMat:
        var top_image = Image.new()
        top_image.load_png_from_buffer(dict["top"])
        var sides_image = Image.new()
        sides_image.load_png_from_buffer(dict["sides"])
        var top_tex = ImageTexture.new()
        top_tex.create_from_image(top_image, ImageTexture.FLAG_CONVERT_TO_LINEAR)
        var sides_tex = ImageTexture.new()
        sides_tex.create_from_image(sides_image, ImageTexture.FLAG_CONVERT_TO_LINEAR)
        return VoxMat.new(sides_tex, top_tex)

var mats = [
    VoxMat.new(preload("res://art/brickwall.png"), preload("res://art/sandbrick.png")),
    VoxMat.new(preload("res://art/wood.png"), preload("res://art/sandwood.png")),
    VoxMat.new(preload("res://art/grasswall.png"), preload("res://art/grass.png")),
]

func get_default_voxmat():
    return mats[0]

var current_mat = mats[0]

func set_current_mat(new_current):
    current_mat = new_current 

func _on_files_dropped(files, _screen):
    var fname = files[0]
    var image = Image.new()
    image.load(fname)
    
    var existant = get_tree().get_nodes_in_group("MatConfig")
    if existant.size() > 0:
        existant[0].set_top(image)
        return
    
    var matconf = preload("res://MatConfig.tscn").instance()
    matconf.set_side(image)
    add_child(matconf)
    
    var mat = yield(matconf, "done")
    if mat:
        add_mat(VoxMat.new(mat[0], mat[1]))


func add_mat(mat : VoxMat):
    mats.push_back(mat)
    
    var button = Button.new()
    $Mats/List.add_child(button)
    
    var preview = preload("res://CubePreview.tscn").instance()
    preview.inform_mats(MatConfig.make_mat(mat.sides), MatConfig.make_mat(mat.top))
    preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    button.add_child(preview)
    button.rect_min_size = Vector2(64, 48)
    button.connect("pressed", self, "set_current_mat", [mat])

# Called when the node enters the scene tree for the first time.
func _ready():
    if Engine.editor_hint:
        return
        
    get_tree().connect("files_dropped", self, "_on_files_dropped")
    
    var mats_copy = mats
    mats = []
    for mat in mats_copy:
        add_mat(mat)
    
    
    $CameraHolder.scale = $CameraHolder.scale.normalized() * 2.0
    
    $ButtonPerspective.add_item("Orthographic", 0)
    $ButtonPerspective.add_item("Perspective (Orbit)", 1)
    $ButtonPerspective.add_item("Perspective (FPS)", 2)
    
    #$ButtonOrientation.add_item("Follow Face", 0)
    #$ButtonOrientation.add_item("Follow Camera", 1)
    #$ButtonOrientation.add_item("X axis (vertical)", 2)
    #$ButtonOrientation.add_item("Y axis (horizontal)", 3)
    #$ButtonOrientation.add_item("Z axis (vertical)", 4)
    
    $ButtonMode.add_item("Add", 0)
    $ButtonMode.add_item("Replace", 1)
    $ButtonMode.add_item("Add (vertical only)", 2)
    $ButtonMode.add_item("Add (horizontal only)", 3)
    
    $ButtonTool.add_item("Place", 0)
    $ButtonTool.add_item("Draw", 1)
    
    $ButtonWarp.add_item("Offset Drawing", 0)
    $ButtonWarp.add_item("Warp Mouse", 1)
    
    $ButtonGrid.add_item("Show Grid", 0)
    $ButtonGrid.add_item("Hide Grid", 1)
    $ButtonGrid.add_item("Grid When Drawing", 2)
    
    for vox in [
            [Vector3( 0, 0,  0), get_default_voxmat()],
            [Vector3( 1, 0,  0), get_default_voxmat()],
            [Vector3( 1, 0,  1), get_default_voxmat()],
            [Vector3( 0, 0,  1), get_default_voxmat()],
            [Vector3(-1, 0,  0), get_default_voxmat()],
            [Vector3(-1, 0, -1), get_default_voxmat()],
            [Vector3( 0, 0, -1), get_default_voxmat()],
            [Vector3(-1, 0,  1), get_default_voxmat()],
            [Vector3( 1, 0, -1), get_default_voxmat()],
        ]:
        $Voxels.place_voxel(vox[0], vox[1])

var draw_mode = false
var erase_mode = false
var camera_mode = false

onready var camera_intended_scale = $CameraHolder/Camera.size / 5.0

func estimate_viewport_mouse_scale():
    #var rect = get_viewport().get_visible_rect().size
    var size = get_viewport().size
    return 1.0/size.y


var lock_mode = 0
func _unhandled_input(_event):
    if Input.is_action_just_pressed("m1"):
        draw_mode = true
    elif !Input.is_action_pressed("m1"):
        draw_mode = false
    
    if Input.is_action_just_pressed("m2"):
        erase_mode = true
    elif !Input.is_action_pressed("m2"):
        erase_mode = false
    
    if Input.is_action_just_pressed("m3"):
        camera_mode = true
    elif !Input.is_action_pressed("m3"):
        camera_mode = false
        
    if _event is InputEventKey:
        var event : InputEventKey = _event
        if event.pressed and event.scancode == KEY_J:
            # stretched ortho
            if lock_mode == 0:
                lock_mode = 1
                $Voxels.scale.y = 1.0
                $Voxels.scale.x = 1.0 / sqrt(2.0)
                $Voxels.scale.z = 1.0
                $CameraHolder/Camera.size = get_viewport().size.y / 16.0 / 3.0 * cos(deg2rad(45))
                $CameraHolder.rotation_degrees.x = -45.0
                $CameraHolder.rotation_degrees.y = 0.0
            elif lock_mode == 1:
                lock_mode = 2
                $Voxels.scale.y = 1.0
                $Voxels.scale.x = 1.0
                $Voxels.scale.z = 1.0 / sqrt(2.0)
                $CameraHolder/Camera.size = get_viewport().size.y / 16.0 / 3.0 * cos(deg2rad(45))
                $CameraHolder.rotation_degrees.x = -45.0
                $CameraHolder.rotation_degrees.y = 90.0
            elif lock_mode == 2:
                lock_mode = 3
                $Voxels.scale.y = 1.0
                $Voxels.scale.x = 1.0 / sqrt(2.0)
                $Voxels.scale.z = 1.0
                $CameraHolder/Camera.size = get_viewport().size.y / 16.0 / 3.0 * cos(deg2rad(45))
                $CameraHolder.rotation_degrees.x = -45.0
                $CameraHolder.rotation_degrees.y = 180.0
            elif lock_mode == 3:
                lock_mode = 4
                $Voxels.scale.y = 1.0
                $Voxels.scale.x = 1.0
                $Voxels.scale.z = 1.0 / sqrt(2.0)
                $CameraHolder/Camera.size = get_viewport().size.y / 16.0 / 3.0 * cos(deg2rad(45))
                $CameraHolder.rotation_degrees.x = -45.0
                $CameraHolder.rotation_degrees.y = 270.0
            else:
                var cos_30 = cos(deg2rad(30))
                var cos_45 = cos(deg2rad(45))
                
                $Voxels.scale.y = cos_45 / cos_30
                $Voxels.scale.x = 1.0
                $Voxels.scale.z = 1.0
                
                $CameraHolder/Camera.size = get_viewport().size.y / 16.0 / 3.0 * cos_45
                $CameraHolder.rotation_degrees.x = -30.0
                # isometric
                if lock_mode == 4:
                    lock_mode = 5
                    $CameraHolder.rotation_degrees.y = -45
                elif lock_mode == 5:
                    lock_mode = 6
                    $CameraHolder.rotation_degrees.y = 45
                elif lock_mode == 6:
                    lock_mode = 7
                    $CameraHolder.rotation_degrees.y = 135
                elif lock_mode == 7:
                    lock_mode = 8
                    $CameraHolder.rotation_degrees.y = -135
                else:
                    $Voxels.scale.y = 1.0
                    $Voxels.scale.x = 1.0
                    $Voxels.scale.z = 1.0
                    # default
                    lock_mode = 0
                    $CameraHolder.rotation_degrees.y = -45
                    $CameraHolder/Camera.size = 5.0 * camera_intended_scale
                pass
    
    estimate_viewport_mouse_scale()
    
    if _event is InputEventMouseButton:
        
        $Voxels.scale.y = 1.0
        $Voxels.scale.x = 1.0
        $Voxels.scale.z = 1.0
        
        var event : InputEventMouseButton = _event
        if $ButtonPerspective.selected == 2:
            var dir = $CameraHolder/Camera.global_transform.basis.xform(Vector3.FORWARD) 
            if event.button_index == 4:
                $CameraHolder.global_transform.origin += dir
            if event.button_index == 5:
                $CameraHolder.global_transform.origin -= dir
            print(dir)
        else:
            if event.button_index == 4:
                camera_intended_scale /= 1.1
            if event.button_index == 5:
                camera_intended_scale *= 1.1
            camera_intended_scale = clamp(camera_intended_scale, 0.1, 10)
        
        if $CameraHolder.scale.length() > 0.001:
            $CameraHolder.scale = Vector3.ONE.normalized() * camera_intended_scale
        $CameraHolder/Camera.size = 5.0 * camera_intended_scale

func _input(_event):
    estimate_viewport_mouse_scale()
    
    if _event is InputEventMouseMotion:
        if !camera_mode:
            return
        var event : InputEventMouseMotion = _event
        if event.shift:
            print(event.relative.x)
            var upwards = $CameraHolder/Camera.global_transform.basis.xform(Vector3.UP)
            var rightwards = $CameraHolder/Camera.global_transform.basis.xform(Vector3.RIGHT)
            var speed = camera_intended_scale * estimate_viewport_mouse_scale() * 5.0
            $CameraHolder.global_transform.origin += event.relative.y * upwards * speed
            $CameraHolder.global_transform.origin += event.relative.x * -rightwards * speed
        else:
            $CameraHolder.rotation_degrees.y -= 0.22 * event.relative.x
            $CameraHolder.rotation_degrees.x -= 0.22 * event.relative.y

var prev_fps_mode = false

func update_camera():
    if $ButtonPerspective.selected == 0:
        $CameraHolder/Camera.projection = Camera.PROJECTION_ORTHOGONAL
    else:
        $CameraHolder/Camera.projection = Camera.PROJECTION_PERSPECTIVE
    
    var fps_mode = $ButtonPerspective.selected == 2
    
    if fps_mode and !prev_fps_mode:
        var forwards = $CameraHolder.global_transform.basis.xform(Vector3.FORWARD)
        $CameraHolder.scale = Vector3.ONE
        $CameraHolder/Camera.transform.origin.z = 0
        $CameraHolder.global_transform.origin -= forwards * 10 #6.0 * camera_intended_scale
    elif !fps_mode and prev_fps_mode:
        var forwards = $CameraHolder.global_transform.basis.xform(Vector3.FORWARD)
        $CameraHolder.scale = Vector3.ONE.normalized() * camera_intended_scale
        $CameraHolder/Camera.transform.origin.z = 10
        $CameraHolder.global_transform.origin += forwards * 10#* 6.0 * camera_intended_scale
    
    prev_fps_mode = $ButtonPerspective.selected == 2

var ref_point = null
var ref_normal = null

func ray_point_distance(ray_origin : Vector3, ray_normal : Vector3, point : Vector3):
    return ray_normal.normalized().cross(point - ray_origin).length()

func ray_plane_intersection (
    ray_origin : Vector3, ray_normal : Vector3,
    plane_origin : Vector3, plane_normal : Vector3,
    range_limit : float = -1
):
    ray_origin -= plane_origin
    
    var denom = plane_normal.dot(ray_normal)
    if abs(denom) <= 0:
        return null

    var dist = plane_normal.dot(ray_origin) / -denom;

    if dist <= 0.0:
        return null
    if range_limit >= 0.0 and dist > range_limit:
        return null

    return ray_origin + plane_origin + dist * ray_normal;

var draw_use_offset = false
var m_warp_amount = Vector2()

# cast ray into unit face (-0.5 ~ 0.5 extents), return whether intersects
func face_ray_intersection(face_origin : Vector3, face_normal : Vector3, ray_origin : Vector3, ray_normal : Vector3, max_distance : float):
    var ray_length = ray_normal.length()
    ray_normal /= ray_length
    
    var denom = ray_normal.dot(face_normal)
    if denom >= 0.0:
        return null
    
    var axial_distance = face_normal.dot(face_origin - ray_origin)
    var collision_distance = axial_distance / denom
    
    var new_origin = collision_distance * ray_normal + ray_origin
    
    if new_origin.distance_squared_to(ray_origin) > max_distance*max_distance:
        return null
    
    var test_origin = (new_origin - face_origin).abs() * 2.0
    
    if test_origin.x <= 1.0 and test_origin.y <= 1.0 and test_origin.z <= 1.0:
        return [new_origin, face_normal]
    
    return null

const directions = [
    Vector3.UP,
    Vector3.DOWN,
    Vector3.LEFT,
    Vector3.RIGHT,
    Vector3.FORWARD,
    Vector3.BACK,
]
func cube_ray_intersection(cube_origin : Vector3, ray_origin : Vector3, ray_normal : Vector3, max_distance : float):
    for dir in directions:
        var stuff = face_ray_intersection(cube_origin + dir*0.5, dir, ray_origin, ray_normal, max_distance)
        if stuff != null:
            return stuff
    return null

func raycast_voxels(ray_origin : Vector3, ray_normal : Vector3):
    #var ray_end = ray_origin + ray_normal
    #var num_steps = ceil(ray_normal.length() + 0.5) # ensure each step is at least slightly smaller than 1.0 units
    #ray_normal = ray_normal / num_steps
    #var tested = {}
    #for i in range(num_steps):
    if true:
        var rounded = ray_origin.round()
        var closest = null
        #var remaining_distance = ray_normal.length() * (num_steps - i)
        var distance_limit = ray_normal.length()
        #for z in [1, 0]: for y in [1, 0]: for x in [1, 0]:
        #    var offset = (rounded + Vector3(x, y, z)*ray_normal.sign()).round()
        for voxel in $Voxels.voxels:
            var offset = voxel.round() + Vector3.ONE - Vector3.ONE
            if ray_point_distance(ray_origin, ray_normal, offset) > 2.0:
                continue
            #if offset in tested:
            #    continue
            #tested[offset] = null
            #if $Voxels.voxels.has(offset):
            var collision_data = cube_ray_intersection(offset, ray_origin, ray_normal, distance_limit)
            if collision_data:
                var distance = ray_origin.distance_to(collision_data[0])
                if closest == null or distance < closest[1]:
                    closest = [collision_data, distance, offset]
        if closest != null:
            var ret = closest[0]
            var offset = closest[2]
            ret[0].x = clamp(ret[0].x, offset.x - 0.499, offset.x + 0.499)
            ret[0].y = clamp(ret[0].y, offset.y - 0.499, offset.y + 0.499)
            ret[0].z = clamp(ret[0].z, offset.z - 0.499, offset.z + 0.499)
            
            return ret
        ray_origin += ray_normal
    return null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    #print(face_ray_intersection(Vector3(), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(-2, 0, 0)))
    if Engine.editor_hint:
        return
    update_camera()
    
    if $ButtonPerspective.selected == 2:
        var forwards = $CameraHolder/Camera.global_transform.basis.xform(Vector3.FORWARD)
        var rightwards = $CameraHolder/Camera.global_transform.basis.xform(Vector3.RIGHT)
        if Input.is_action_pressed("ui_up"):
            $CameraHolder.global_transform.origin += forwards * delta * 16.0
        if Input.is_action_pressed("ui_down"):
            $CameraHolder.global_transform.origin -= forwards * delta * 16.0
        if Input.is_action_pressed("ui_right"):
            $CameraHolder.global_transform.origin += rightwards * delta * 16.0
        if Input.is_action_pressed("ui_left"):
            $CameraHolder.global_transform.origin -= rightwards * delta * 16.0
    
    handle_voxel_input()

func handle_voxel_input():
    var view_rect : Rect2 = get_viewport().get_visible_rect()
    var m_pos : Vector2 = get_viewport().get_mouse_position()
    var cast_start : Vector3 = $CameraHolder/Camera.project_ray_origin(m_pos)
    var cast_normal : Vector3 = $CameraHolder/Camera.project_ray_normal(m_pos)
    
    if !view_rect.has_point(m_pos):
        return
    
    var raw_collision_point = null
    var collision_point = null
    var collision_normal = null
    
    var start = OS.get_ticks_usec()
    var collision_data = raycast_voxels(cast_start, cast_normal * 100.0)
    var end = OS.get_ticks_usec()
    
    var time = (end-start)/1000000.0
    if time > 0.1:
        print("raycast time: ", time)
    
    #if cast.is_colliding():
    if collision_data:
        #collision_normal = cast.get_collision_normal()
        #raw_collision_point = cast.get_collision_point()
        collision_normal = collision_data[1]
        raw_collision_point = collision_data[0]
        collision_point = (raw_collision_point - collision_normal*0.5).round()
        # get rid of negative zero
        collision_point = collision_point + Vector3.ONE - Vector3.ONE
    #cast.queue_free()
    
    if !draw_mode and !erase_mode:
        ref_point = null
        ref_normal = null
        draw_use_offset = false
        #if m_warp_amount != Vector2():
        #    get_viewport().warp_mouse(m_pos - m_warp_amount)
        #    m_warp_amount = Vector2()
    
    if ref_point:
        var offset = ref_normal*0.5
        if draw_use_offset:
            offset += -ref_normal
        var new_point = ray_plane_intersection(cast_start, cast_normal, ref_point + offset, ref_normal)
        if new_point:
            raw_collision_point = new_point
            collision_point = (new_point - offset).round()
            collision_normal = ref_normal
        else:
            collision_point = null
            collision_normal = null
    
    if collision_point != null:
        var origin = collision_point if ref_point == null else ref_point
        var normal = collision_normal if ref_normal == null else ref_normal
        
        $CursorBox.show()
        $CursorBox.global_transform.origin = collision_point
        
        if $ButtonGrid.selected == 0 or ($ButtonGrid.selected == 2 and draw_mode):
            $Grid.show()
            $Grid.global_transform.origin = collision_point + collision_normal*0.501
            if draw_use_offset:
                $Grid.global_transform.origin -= collision_normal
            
            if abs(collision_normal.x) > 0.8:
                $Grid.axis = 0
                $Grid.modulate = Color(1.0, 0.2, 0.2)
            elif abs(collision_normal.y) > 0.8:
                $Grid.axis = 1
                $Grid.modulate = Color(0.4, 0.8, 0.4)
            else:
                $Grid.axis = 2
                $Grid.modulate = Color(0.1, 0.3, 0.8)
        else:
            $Grid.hide()
        
        if ref_point == null:
            if $ButtonMode.selected == 0:
                $CursorBox.global_transform.origin += collision_normal
            elif $ButtonMode.selected == 2 and abs(collision_normal.y) != 0.0:
                $CursorBox.global_transform.origin += collision_normal
            elif $ButtonMode.selected == 3 and abs(collision_normal.y) == 0.0:
                $CursorBox.global_transform.origin += collision_normal
        
    else:
        $CursorBox.hide()
        $Grid.hide()
    
    if draw_mode and collision_normal != null and collision_point != null:
        var new_point = collision_point
        
        if ref_point == null:
            if $ButtonMode.selected == 0:
                new_point += collision_normal
            elif $ButtonMode.selected == 2 and abs(collision_normal.y) != 0.0:
                new_point += collision_normal
            elif $ButtonMode.selected == 3 and abs(collision_normal.y) == 0.0:
                new_point += collision_normal
        
        var asdf =  [
            [Vector3( 1,  1,  1), Vector3( 1,  0,  1)],
            [Vector3(-1,  1,  1), Vector3(-1,  0,  1)],
        ]
        var asdf2 =  [
            [Vector3( 1,  1, -1), Vector3( 1,  0, -1)],
            [Vector3(-1,  1, -1), Vector3(-1,  0, -1)],
            [Vector3( 1,  1,  1), Vector3( 1, -1,  1)],
            [Vector3(-1,  1,  1), Vector3(-1, -1,  1)],
        ]
        #$Voxels.place_voxel(new_point, current_mat, [[Vector3(1.0, 1.0, 1.0), Vector3(1.0, 0.25, 1.0)]])
        #$Voxels.place_voxel(new_point, current_mat, [])
        $Voxels.place_voxel(new_point, current_mat, $VertEditPanel.prepared_overrides)
        
        if $ButtonTool.selected == 0:
            draw_mode = false
        elif ref_point == null:
            ref_point = new_point
            ref_normal = collision_normal
            if $ButtonMode.selected == 0:
                if $ButtonWarp.selected == 0:
                    draw_use_offset = true
                else:
                    var pos_1 = $CameraHolder/Camera.unproject_position(raw_collision_point)
                    var pos_2 = $CameraHolder/Camera.unproject_position(raw_collision_point + ref_normal)
                    m_warp_amount = pos_2 - pos_1
                    get_viewport().warp_mouse(m_pos + m_warp_amount)
            if $ButtonMode.selected == 2:
                var x_ish = abs(cast_normal.x) > abs(cast_normal.z)
                if x_ish:
                    ref_normal = Vector3(sign(-cast_normal.x), 0, 0)
                else:
                    ref_normal = Vector3(0, 0, sign(-cast_normal.z))
            if $ButtonMode.selected == 3:
                ref_normal = Vector3(0, -sign(cast_normal.y), 0)
    
    if erase_mode and collision_normal != null and collision_point != null:
        var new_point = collision_point
        $Voxels.erase_voxel(new_point)
        
        if $ButtonTool.selected == 0:
            erase_mode = false
        elif ref_point == null:
            ref_point = new_point
            ref_normal = collision_normal
            if $ButtonMode.selected == 2:
                var x_ish = abs(cast_normal.x) > abs(cast_normal.z)
                if x_ish:
                    ref_normal = Vector3(sign(-cast_normal.x), 0, 0)
                else:
                    ref_normal = Vector3(0, 0, sign(-cast_normal.z))
            if $ButtonMode.selected == 3:
                ref_normal = Vector3(0, -sign(cast_normal.y), 0)
    
    
    
