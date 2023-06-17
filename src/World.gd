@tool
extends MeshInstance3D
class_name VoxEditor

### nice-to-have list
# - remember VoxMat properties when editing
# - deform tool (modifying existing geometry vertex offsets)
# - "reset camera" button
# - scale setting for worldspace 1x1 voxel mode
# - background color setting
# - 1:1 pixel screenshot mode (orthographic, isometric)
# - importing real meshes somehow maybe?

var low_distortion_meshing : bool = false
func set_low_distortion_meshing(new_val : bool):
    low_distortion_meshing = new_val
    $Voxels.full_remesh()
    $VertEditPanel/Frame/VertEditViewport/Voxel.full_remesh()

class VoxMat extends RefCounted:
    enum TileMode {
        MODE_12x4,
        MODE_4x4,
        MODE_1x1,
        MODE_1x1_WORLD,
    }
    
    var textures : Array[Texture2D]
    
    var sides  : Texture2D
    var top    : Texture2D
    var bottom : Texture2D
    
    var transparent_mode : int = 0 # 0 : opaque, 1 : alpha scissor, 2 : actually transparent
    var transparent_inner_face_mode : int = 0 # 0 : show, 1 : don't show
    
    var tiling_mode = TileMode.MODE_12x4
    
    var subdivide_amount : Vector2
    var subdivide_coord : Vector2
    
    func _init(_sides : Texture2D, _top : Texture2D, _bottom : Texture2D, _transparent_mode : int, _transparent_inner_face_mode : int, _tiling_mode : int, _subdivide_amount : Vector2, _subdivide_coord : Vector2):
        if _bottom and _top and _bottom.get_image().compute_image_metrics(_top.get_image(), false).max == 0:
            _bottom = _top
            print("deduplicating texture...")
        if _bottom and _sides and _bottom.get_image().compute_image_metrics(_sides.get_image(), false).max == 0:
            _bottom = _sides
            print("deduplicating texture...")
        if _top and _sides and _top.get_image().compute_image_metrics(_sides.get_image(), false).max == 0:
            _top = _sides
            print("deduplicating texture...")
        
        textures.push_back(_sides)
        if _top != _sides:
            textures.push_back(_top)
        if _bottom != _top and _bottom != _sides:
            textures.push_back(_bottom)
        sides = _sides
        top = _top
        bottom = _bottom
        
        transparent_mode = _transparent_mode
        transparent_inner_face_mode = _transparent_inner_face_mode
        tiling_mode = _tiling_mode
        subdivide_amount = _subdivide_amount
        subdivide_coord = _subdivide_coord
    
    func encode() -> Dictionary:
        var pngs = []
        for tex in textures:
            pngs.push_back(Marshalls.raw_to_base64(tex.get_image().save_png_to_buffer()))
        var top_idx = textures.find(top)
        var sides_idx = textures.find(sides)
        var bottom_idx = textures.find(bottom)
        var vec_a = Helpers.vec2_to_array(subdivide_amount)
        var vec_b = Helpers.vec2_to_array(subdivide_coord)
        return {"type": "voxel", "pngs": pngs, "top_id" : top_idx, "sides_id": sides_idx, "bottom_id": bottom_idx, "transparent_mode" : transparent_mode, "transparent_inner_face_mode" : transparent_inner_face_mode, "tiling_mode" : tiling_mode, "subdivide_amount" : vec_a, "subdivide_coord" : vec_b}
    
    static func decode(dict : Dictionary):
        if not "type" in dict or dict.type == "voxel":
            var mode_a = dict.transparent_mode if "transparent_mode" in dict else 0
            var mode_b = dict.transparent_inner_face_mode if "transparent_inner_face_mode" in dict else 0
            var mode_c = dict.tiling_mode if "tiling_mode" in dict else 0
            var vec_a = Helpers.array_to_vec2(dict.subdivide_amount) if "subdivide_amount" in dict else Vector2.ONE
            var vec_b = Helpers.array_to_vec2(dict.subdivide_coord) if "subdivide_coord" in dict else Vector2()
            
            if "top" in dict: # old image-per-side format
                var top_image = Image.new()
                top_image.load_png_from_buffer(Marshalls.base64_to_raw(dict["top"]))
                var sides_image = Image.new()
                sides_image.load_png_from_buffer(Marshalls.base64_to_raw(dict["sides"]))
                var top_tex = ImageTexture.create_from_image(top_image)
                var sides_tex = ImageTexture.create_from_image(sides_image)
                return VoxMat.new(sides_tex, top_tex, top_tex, mode_a, mode_b, mode_c, vec_a, vec_b)
            else: # new index-per-side, image list format
                var images = []
                for img_base64 in dict.pngs:
                    var image = Image.new()
                    image.load_png_from_buffer(Marshalls.base64_to_raw(img_base64))
                    images.push_back(image)
                var top_tex = ImageTexture.create_from_image(images[dict.top_id])
                var sides_tex = ImageTexture.create_from_image(images[dict.sides_id])
                var bottom_tex = ImageTexture.create_from_image(images[dict.bottom_id])
                return VoxMat.new(sides_tex, top_tex, bottom_tex, mode_a, mode_b, mode_c, vec_a, vec_b)
            
        elif dict.type == "model":
            return ModelMat.decode(dict)
        elif dict.type == "decal":
            return DecalMat.decode(dict)

class DecalMat extends RefCounted:
    var tex : Texture2D
    var grid_size : Vector2
    var icon_coord : Vector2
    var current_coord : Vector2
    
    func _init(_tex : Texture2D, _grid_size : Vector2, _icon_coord : Vector2):
        tex = _tex
        grid_size = _grid_size
        icon_coord = _icon_coord
        current_coord = icon_coord
    
    func encode() -> Dictionary:
        var png = Marshalls.raw_to_base64(tex.get_image().save_png_to_buffer())
        return {
            "type": "decal",
            "tex": png,
            "grid_size": Helpers.vec2_to_array(grid_size),
            "icon_coord": Helpers.vec2_to_array(icon_coord),
            "current_coord": Helpers.vec2_to_array(current_coord)
        }
    
    static func decode(dict : Dictionary):
        if "type" in dict and dict.type == "decal":
            var image = Image.new()
            image.load_png_from_buffer(Marshalls.base64_to_raw(dict["tex"]))
            var new_tex = ImageTexture.create_from_image(image)
            var ret = DecalMat.new(
                new_tex,
                Helpers.array_to_vec2(dict.grid_size),
                Helpers.array_to_vec2(dict.icon_coord)
            )
            ret.current_coord = Helpers.array_to_vec2(dict.current_coord)
            return ret
        elif dict.type == "voxel":
            return VoxMat.decode(dict)

class ModelMat extends DecalMat:
    func _init(_tex : Texture2D, _grid_size : Vector2, _icon_coord : Vector2):
        super(_tex, _grid_size, _icon_coord)
        pass
    
    func encode() -> Dictionary:
        var png = Marshalls.raw_to_base64(tex.get_image().save_png_to_buffer())
        return {
            "type": "model",
            "tex": png,
            "grid_size": Helpers.vec2_to_array(grid_size),
            "icon_coord": Helpers.vec2_to_array(icon_coord),
            "current_coord": Helpers.vec2_to_array(current_coord)
        }
    
    static func decode(dict : Dictionary):
        if "type" in dict and dict.type == "model":
            var image = Image.new()
            image.load_png_from_buffer(Marshalls.base64_to_raw(dict["tex"]))
            var new_tex = ImageTexture.create_from_image(image)
            var ret = ModelMat.new(
                new_tex,
                Helpers.array_to_vec2(dict.grid_size),
                Helpers.array_to_vec2(dict.icon_coord)
            )
            ret.current_coord = Helpers.array_to_vec2(dict.current_coord)
            return ret
        elif dict.type == "voxel":
            return VoxMat.decode(dict)

var mats = [
    VoxMat.new(preload("res://art/brickwall.png"), preload("res://art/sandbrick.png"), preload("res://art/sandbrick.png"), 0, 0, 0, Vector2.ONE, Vector2()),
    VoxMat.new(preload("res://art/wood.png"), preload("res://art/sandwood.png"), preload("res://art/sandwood.png"), 0, 0, 0, Vector2.ONE, Vector2()),
    VoxMat.new(preload("res://art/grasswall.png"), preload("res://art/grass.png"), preload("res://art/dirtwall.png"), 0, 0, 0, Vector2.ONE, Vector2()),
]

func delete_mat(mat):
    if mats.size() == 1:
        return
    var i = mats.find(mat)
    if i >= 0:
        mats.remove_at(i)
    if mat == current_mat:
        current_mat = mats[max(0, i-1)]
    
    rebuild_mat_buttons()

func get_default_voxmat():
    return mats[0]

var current_mat = mats[0]

func set_current_mat(new_current):
    tool_mode = TOOL_MODE_MAT
    current_mat = new_current
    selection_start = null
    selection_end = null
    $Voxels.inform_selection(selection_start, selection_end)

func modify_mat(mat):
    if mat is VoxMat:
        var matconf = load("res://src/MatConfig.tscn").instantiate()
        add_child(matconf)
        matconf.set_mat(mat)
        
        var new_mat = await matconf.done
        if new_mat:
            mat.sides = new_mat[0]
            mat.top = new_mat[1]
            mat.bottom = new_mat[2]
            mat.transparent_mode = new_mat[3]
            mat.transparent_inner_face_mode = new_mat[4]
            mat.tiling_mode = new_mat[5]
            mat.subdivide_amount = new_mat[6]
            mat.subdivide_coord = new_mat[7]
    
    elif mat is DecalMat:
        var config = preload("res://src/DecalConfig.tscn").instantiate()
        add_child(config)
        config.set_mat(mat.tex)
        config.set_icon_coord(mat.icon_coord)
        config.set_grid_size(mat.grid_size)
        
        var info = await config.done
        if info:
            var new_mat = info[0]
            var grid_size = info[1]
            var icon_coord = info[2]
            
            mat.tex = new_mat
            mat.grid_size = grid_size
            mat.icon_coord = icon_coord
            mat.current_coord = icon_coord
    
    rebuild_mat_buttons()
    $Voxels.full_remesh()

func _on_files_dropped(files):
    var fname : String = files[0]
    var image = Image.new()
    var error = image.load(fname)
    
    if error and fname.ends_with(".json"):
        open_data_from(fname)
        return
    
    image.fix_alpha_edges()
    
    var existant = get_tree().get_nodes_in_group("MatConfig")
    if existant.size() > 0:
        existant[0].add_texture(image)
        return
    
    existant = get_tree().get_nodes_in_group("DecalConfig")
    if existant.size() > 0:
        existant[0].set_mat(image)
        return
    
    var picker = preload("res://src/MaterialModePicker.tscn").instantiate()
    add_child(picker)
    var which = await picker.done
    
    if which == "voxel":
        var matconf = load("res://src/MatConfig.tscn").instantiate()
        add_child(matconf)
        matconf.add_texture(image)
        
        var mat = await matconf.done
        if mat:
            add_mat(VoxMat.new(mat[0], mat[1], mat[2], mat[3], mat[4], mat[5], mat[6], mat[7]))
    
    elif which == "decal" or which == "model":
        var config = preload("res://src/DecalConfig.tscn").instantiate()
        config.set_mat(image)
        add_child(config)
        
        var info = await config.done
        if info:
            var mat = info[0]
            var grid_size = info[1]
            var icon_coord = info[2]
            if which == "decal":
                add_mat(DecalMat.new(mat, grid_size, icon_coord))
            elif which == "model":
                add_mat(ModelMat.new(mat, grid_size, icon_coord))
    
    elif which == "cancel":
        print("canceled")

func add_mat_button(mat):
    var button = Button.new()
    button.set_script(preload("res://src/MatButton.gd"))
    button.mat = mat
    $Mats/List.add_child(button)
    
    var preview = load("res://src/CubePreview.tscn").instantiate()
    preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(preview)
    preview.inform_mat(mat)
    
    button.custom_minimum_size = Vector2(64, 48)
    button.toggle_mode = true
    button.connect("pressed", Callable(self, "set_current_mat").bind(mat))

func rebuild_mat_buttons():
    for child in $Mats/List.get_children():
        child.hide()
        child.queue_free()
    
    for mat in mats:
        add_mat_button(mat)

func add_mat(mat):
    mats.push_back(mat)
    add_mat_button(mat)

func save_world_as_resource(fname):
    var m : Mesh = $Voxels.mesh.duplicate(true)
    var textures = {}
    for i in m.get_surface_count():
        var mat : StandardMaterial3D = m.surface_get_material(i).duplicate()
        var raw_stex : Texture2D = mat.albedo_texture
        if not raw_stex in textures:
            var stex = raw_stex.duplicate()
            var img = stex.get_image()
            var tex = ImageTexture.create_from_image(img)
            mat.albedo_texture = tex
            m.surface_set_material(i, mat)
            textures[raw_stex] = tex
        else:
            print("reusing texture...")
            mat.albedo_texture = textures[raw_stex]
            m.surface_set_material(i, mat)
    var _e = ResourceSaver.save(m, fname)

func save_map_resource():
    var dialog = FileDialog.new()
    dialog.unresizable = false
    dialog.access = FileDialog.ACCESS_FILESYSTEM
    dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    dialog.add_filter("*.tres ; Godot Resource File")
    dialog.current_file = "voxel_mesh.tres"
    add_child(dialog)
    dialog.popup_centered_ratio(0.5)
    
    dialog.connect("file_selected", Callable(self, "save_world_as_resource"))
    await dialog.visibility_changed
    dialog.queue_free()

func save_world_as_gltf(fname):
    #var m : Mesh = $Voxels.mesh.duplicate(true)
    var state = GLTFState.new()
    state.create_animations = false
    var gltf = GLTFDocument.new()
    gltf.append_from_scene($Voxels, state)
    gltf.write_to_filesystem(state, fname)
    #for i in m.get_surface_count():
    #    var mat : StandardMaterial3D = m.surface_get_material(i).duplicate(true)
    #    var stex : Texture2D = mat.albedo_texture.duplicate(true)
    #    var img = stex.get_image()
    #    var tex = ImageTexture.create_from_image(img)
    #    mat.albedo_texture = tex
    #    m.surface_set_material(i, mat)
    #var _e = ResourceSaver.save(m, fname)

func save_map_gltf():
    var dialog = FileDialog.new()
    dialog.unresizable = false
    dialog.access = FileDialog.ACCESS_FILESYSTEM
    dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    dialog.add_filter("*.glb ; Binary GLTF 2.0 File")
    dialog.current_file = "voxel_mesh.glb"
    add_child(dialog)
    dialog.popup_centered_ratio(0.5)
    
    dialog.connect("file_selected", save_world_as_gltf)
    await dialog.visibility_changed
    dialog.queue_free()

func perform_undo():
    $Voxels.perform_undo()
    selection_start = $Voxels.selection_start
    selection_end = $Voxels.selection_end
func perform_redo():
    $Voxels.perform_redo()
    selection_start = $Voxels.selection_start
    selection_end = $Voxels.selection_end

func start_operation():
    $Voxels.start_operation()
func end_operation():
    $Voxels.end_operation()

func get_sun():
    return $DirectionalLight3D
func get_env():
    return get_world_3d().environment
func reset_camera():
    $CameraHolder.rotation_degrees = Vector3(-30, -45, 0)
    $CameraHolder/Camera3D.projection = Camera3D.PROJECTION_ORTHOGONAL
    $CameraHolder/Camera3D.size = 10
    camera_intended_scale = $CameraHolder/Camera3D.size / 5.0
    $CameraHolder.scale = Vector3.ONE.normalized() * camera_intended_scale
    $CameraHolder.position = Vector3(0, 1, 0)
    $ButtonPerspective.selected = 0

func _ready():
    if Engine.is_editor_hint():
        return
    
    #$Button.connect("pressed", self, "bwuhuhuh")
    
    #get_tree().connect(SceneTree.file
    get_tree().get_root().files_dropped.connect(self._on_files_dropped)
    #get_tree().connect("files_dropped", Callable(self, "_on_files_dropped"))
    
    var mats_copy = mats
    mats = []
    for mat in mats_copy:
        add_mat(mat)
    
    $CameraHolder.scale = $CameraHolder.scale.normalized() * 2.0
    
    $ButtonPerspective.add_item("Orthographic", 0)
    $ButtonPerspective.add_item("Perspective (Orbit)", 1)
    $ButtonPerspective.add_item("Perspective (FPS)", 2)
    
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
    
    $MenuBar.connect("file_save", Callable(self, "default_save"))
    $MenuBar.connect("file_save_as", Callable(self, "save_map"))
    $MenuBar.connect("file_export_resource", Callable(self, "save_map_resource"))
    $MenuBar.connect("file_export_gltf", Callable(self, "save_map_gltf"))
    $MenuBar.connect("file_open", Callable(self, "open_map"))
    
    $Mat2dOrientation.add_item("0 deg", 0)
    $Mat2dOrientation.add_item("90 deg", 1)
    $Mat2dOrientation.add_item("180 deg", 2)
    $Mat2dOrientation.add_item("270 deg", 3)
    $Mat2dOrientation.add_item("0 deg flip", 4)
    $Mat2dOrientation.add_item("90 deg flip", 5)
    $Mat2dOrientation.add_item("180 deg flip", 6)
    $Mat2dOrientation.add_item("270 deg flip", 7)
    $Mat2dOrientation.selected = 0
    
    $ModelMatchFloor.add_item("no", 0)
    $ModelMatchFloor.add_item("yes", 1)
    $ModelMatchFloor.add_item("yes (tilt)", 2)
    $ModelMatchFloor.add_item("yes (warp)", 3)
    $ModelMatchFloor.selected = 0
    
    $ButtonSelect.pressed.connect(self.start_select)
    $ButtonMove.pressed.connect(self.start_move)

func start_select():
    tool_mode = TOOL_MODE_NEW_SELECT

func start_move():
    tool_mode = TOOL_MODE_MOVE_SELECT

func default_save():
    if prev_save_target != "":
        var data = $Voxels.serialize()
        save_data_to(prev_save_target, data)
    else:
        save_map()

var prev_save_target = ""
func save_data_to(fname, data):
    prev_save_target = fname
    
    var out = FileAccess.open(fname, FileAccess.WRITE)
    var text = JSON.stringify(data, " ")
    out.store_string(text)
    out.close()

func save_map():
    var data = $Voxels.serialize()
    
    var dialog = FileDialog.new()
    dialog.unresizable = false
    dialog.access = FileDialog.ACCESS_FILESYSTEM
    dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    dialog.add_filter("*.json ; Voxel Map JSON Files")
    dialog.current_file = "voxel_map.json"
    add_child(dialog)
    dialog.popup_centered_ratio(0.5)
    
    dialog.connect("file_selected", Callable(self, "save_data_to").bind(data))
    await dialog.visibility_changed
    dialog.queue_free()

func open_data_from(fname):
    #print("bieueaf")
    prev_save_target = fname
    
    var file = FileAccess.open(fname, FileAccess.READ)
    var json = file.get_as_text()
    file.close()
    var test_json_conv = JSON.new()
    var error = test_json_conv.parse(json)
    var result = test_json_conv.get_data()
    if !error:
        $Voxels.deserialize(result)
        reset_camera()
    else:
        var dialog = AcceptDialog.new()
        dialog.dialog_text = "File is malformed, failed to open."
        dialog.popup_centered_ratio(0.5)
        dialog.queue_free()
        await dialog.visibility_changed

func open_map():
    var dialog = FileDialog.new()
    dialog.unresizable = false
    dialog.access = FileDialog.ACCESS_FILESYSTEM
    dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    dialog.add_filter("*.json ; Voxel Map JSON Files")
    add_child(dialog)
    dialog.popup_centered_ratio(0.5)
    
    dialog.connect("file_selected", Callable(self, "open_data_from"))
    await dialog.visibility_changed
    dialog.queue_free()

var draw_mode = false
var erase_mode = false
var camera_mode = false

@onready var camera_intended_scale = $CameraHolder/Camera3D.size / 5.0

func estimate_viewport_mouse_scale():
    #var rect = get_viewport().get_visible_rect().size
    var size = get_viewport().size
    return 1.0/size.y

func do_pick_material():
    var view_rect : Rect2 = get_viewport().get_visible_rect()
    var m_pos : Vector2 = get_viewport().get_mouse_position()
    var cast_start : Vector3 = $CameraHolder/Camera3D.project_ray_origin(m_pos)
    var cast_normal : Vector3 = $CameraHolder/Camera3D.project_ray_normal(m_pos)
    
    if !view_rect.has_point(m_pos):
        return
    
    var raw_collision_point = null
    var hit_collision_point = null
    var collision_normal = null
    
    var collision_data = raycast_voxels(cast_start, cast_normal * 100.0, 1)
    
    if collision_data:
        collision_normal = collision_data[1]
        raw_collision_point = collision_data[0]
        hit_collision_point = (raw_collision_point - collision_normal*0.5).round()
        hit_collision_point = hit_collision_point + Vector3.ONE - Vector3.ONE # flush unsigned zeroes
        
        var check_order = []
        if current_mat is VoxMat:
            check_order = [$Voxels.decals, $Voxels.voxels, $Voxels.models]
        elif current_mat is ModelMat:
            check_order = [$Voxels.decals, $Voxels.models, $Voxels.voxels]
        elif current_mat is DecalMat:
            check_order = [$Voxels.decals, $Voxels.voxels, $Voxels.models]
        
        for pool in check_order:
            if hit_collision_point in pool:
                var hit = pool[hit_collision_point]
                if pool == $Voxels.voxels:
                    current_mat = hit
                    break
                elif pool == $Voxels.decals:
                    if collision_normal in hit:
                        current_mat = hit[collision_normal][0]
                        current_mat.current_coord = hit[collision_normal][1]
                    else:
                        current_mat = hit.values()[0][0]
                        current_mat.current_coord = hit.values()[0][1]
                    break
                elif pool == $Voxels.models:
                    current_mat = hit[0]
                    current_mat.current_coord = hit[1]
                    $ModelWiden.button_pressed = hit[2] & 1
                    $ModelSpacing.value = (hit[2] >> 1) & 7
                    $ModelTurnCount.value = ((hit[2] >> 4) & 3) + 1
                    $ModelRotationX.value = (hit[2] >> 6) & 7
                    $ModelRotationY.value = (hit[2] >> 9) & 7
                    $ModelRotationZ.value = (hit[2] >> 12) & 7
                    
                    $ModelMatchFloor.selected = hit[3]
                    $ModelOffsetX.value = hit[4]
                    $ModelOffsetY.value = hit[5]
                    $ModelOffsetZ.value = hit[6]
                    
                    break

func do_pick_vert_warp():
    var view_rect : Rect2 = get_viewport().get_visible_rect()
    var m_pos : Vector2 = get_viewport().get_mouse_position()
    var cast_start : Vector3 = $CameraHolder/Camera3D.project_ray_origin(m_pos)
    var cast_normal : Vector3 = $CameraHolder/Camera3D.project_ray_normal(m_pos)
    
    if !view_rect.has_point(m_pos):
        return
    
    var raw_collision_point = null
    var hit_collision_point = null
    var collision_normal = null
    
    var collision_data = raycast_voxels(cast_start, cast_normal * 100.0, 1)
    
    if collision_data:
        collision_normal = collision_data[1]
        raw_collision_point = collision_data[0]
        hit_collision_point = (raw_collision_point - collision_normal*0.5).round()
        hit_collision_point = hit_collision_point + Vector3.ONE - Vector3.ONE # flush unsigned zeroes
        
        if hit_collision_point in $Voxels.voxels:
            if hit_collision_point in $Voxels.voxel_corners:
                $VertEditPanel.set_overrides($Voxels.voxel_corners[hit_collision_point])
            else:
                $VertEditPanel.set_overrides({})

var lock_mode = 0
var input_pick_mode = false
signal hide_menus
var control_swap = false
var main_just_pressed = false
var sub_just_pressed = false
func _unhandled_input(_event):
    $VertEditPanel/Frame/VertEditViewport.handle_input_locally = false
    
    if _event is InputEventMouseButton:
        emit_signal("hide_menus")
        var f2 = $Mats.get_viewport().gui_get_focus_owner()
        if f2:
            f2.release_focus()
    
    var main = "m1"
    var sub = "m2"
    if control_swap:
        main = "m2"
        sub = "m1"
    
    if Input.is_action_pressed("alt"):
        input_pick_mode = true
        if Input.is_action_just_pressed("m1"):
            do_pick_material()
        elif Input.is_action_just_pressed("m2"):
            do_pick_vert_warp()
    else:
        input_pick_mode = false
        if Input.is_action_just_pressed(main):
            main_just_pressed = true
            draw_mode = true
            start_operation()
        elif !Input.is_action_pressed(main):
            draw_mode = false
            last_collision_point = null
        
        if Input.is_action_just_pressed(sub):
            sub_just_pressed = true
            erase_mode = true
            start_operation()
        elif !Input.is_action_pressed(sub):
            erase_mode = false
            last_collision_point = null
    
    if Input.is_action_just_pressed("m3"):
        camera_mode = true
    elif !Input.is_action_pressed("m3"):
        camera_mode = false
    
    if draw_mode or erase_mode or camera_mode:
        $VertEditPanel/Frame/VertEditViewport.handle_input_locally = true
    
    if _event is InputEventKey:
        var event : InputEventKey = _event
        if event.is_pressed() and event.keycode == KEY_J:
            # stretched ortho
            if lock_mode == 0:
                lock_mode = 1
                $Voxels.scale.y = 1.0
                $Voxels.scale.x = 1.0 / sqrt(2.0)
                $Voxels.scale.z = 1.0
                $CameraHolder/Camera3D.size = get_viewport().size.y / 16.0 / 3.0 * cos(deg_to_rad(45))
                $CameraHolder.rotation_degrees.x = -45.0
                $CameraHolder.rotation_degrees.y = 0.0
            elif lock_mode == 1:
                lock_mode = 2
                $Voxels.scale.y = 1.0
                $Voxels.scale.x = 1.0
                $Voxels.scale.z = 1.0 / sqrt(2.0)
                $CameraHolder/Camera3D.size = get_viewport().size.y / 16.0 / 3.0 * cos(deg_to_rad(45))
                $CameraHolder.rotation_degrees.x = -45.0
                $CameraHolder.rotation_degrees.y = 90.0
            elif lock_mode == 2:
                lock_mode = 3
                $Voxels.scale.y = 1.0
                $Voxels.scale.x = 1.0 / sqrt(2.0)
                $Voxels.scale.z = 1.0
                $CameraHolder/Camera3D.size = get_viewport().size.y / 16.0 / 3.0 * cos(deg_to_rad(45))
                $CameraHolder.rotation_degrees.x = -45.0
                $CameraHolder.rotation_degrees.y = 180.0
            elif lock_mode == 3:
                lock_mode = 4
                $Voxels.scale.y = 1.0
                $Voxels.scale.x = 1.0
                $Voxels.scale.z = 1.0 / sqrt(2.0)
                $CameraHolder/Camera3D.size = get_viewport().size.y / 16.0 / 3.0 * cos(deg_to_rad(45))
                $CameraHolder.rotation_degrees.x = -45.0
                $CameraHolder.rotation_degrees.y = 270.0
            else:
                var cos_30 = cos(deg_to_rad(30))
                var cos_45 = cos(deg_to_rad(45))
                
                $Voxels.scale.y = cos_45 / cos_30
                $Voxels.scale.x = 1.0
                $Voxels.scale.z = 1.0
                
                $CameraHolder/Camera3D.size = get_viewport().size.y / 16.0 / 3.0 * cos_45
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
                    $CameraHolder/Camera3D.size = 5.0 * camera_intended_scale
                pass
    
    estimate_viewport_mouse_scale()
    
    if _event is InputEventMouseButton:
        
        $Voxels.scale.y = 1.0
        $Voxels.scale.x = 1.0
        $Voxels.scale.z = 1.0
        
        var event : InputEventMouseButton = _event
        if event.is_pressed():
            if $ButtonPerspective.selected == 2:
                var dir = $CameraHolder/Camera3D.global_transform.basis * (Vector3.FORWARD)
                if event.button_index == 4:
                    $CameraHolder.global_transform.origin += dir
                if event.button_index == 5:
                    $CameraHolder.global_transform.origin -= dir
            else:
                if event.button_index == 4:
                    camera_intended_scale /= 1.2
                if event.button_index == 5:
                    camera_intended_scale *= 1.2
                camera_intended_scale = clamp(camera_intended_scale, 0.1, 10)
        
        if $CameraHolder.scale.length() > 0.001:
            $CameraHolder.scale = Vector3.ONE.normalized() * camera_intended_scale
        $CameraHolder/Camera3D.size = 5.0 * camera_intended_scale

func _input(_event):
    estimate_viewport_mouse_scale()
    
    if _event is InputEventMouseMotion:
        var event : InputEventMouseMotion = _event
        if !camera_mode:
            return
        if event.shift_pressed:
            var upwards = $CameraHolder/Camera3D.global_transform.basis * Vector3.UP
            var rightwards = $CameraHolder/Camera3D.global_transform.basis * Vector3.RIGHT
            var speed = camera_intended_scale * estimate_viewport_mouse_scale() * 5.0
            $CameraHolder.global_transform.origin += event.relative.y * upwards * speed
            $CameraHolder.global_transform.origin += event.relative.x * -rightwards * speed
        else:
            $CameraHolder.rotation_degrees.y -= 0.22 * event.relative.x
            $CameraHolder.rotation_degrees.x -= 0.22 * event.relative.y

var prev_fps_mode = false

func update_camera():
    if $ButtonPerspective.selected == 0:
        $CameraHolder/Camera3D.projection = Camera3D.PROJECTION_ORTHOGONAL
    else:
        $CameraHolder/Camera3D.projection = Camera3D.PROJECTION_PERSPECTIVE
    
    var fps_mode = $ButtonPerspective.selected == 2
    
    if fps_mode and !prev_fps_mode:
        var forwards = $CameraHolder.global_transform.basis * (Vector3.FORWARD)
        $CameraHolder.scale = Vector3.ONE
        $CameraHolder/Camera3D.transform.origin.z = 0
        $CameraHolder.global_transform.origin -= forwards * 10 #6.0 * camera_intended_scale
    elif !fps_mode and prev_fps_mode:
        var forwards = $CameraHolder.global_transform.basis * (Vector3.FORWARD)
        $CameraHolder.scale = Vector3.ONE.normalized() * camera_intended_scale
        $CameraHolder/Camera3D.transform.origin.z = 10
        $CameraHolder.global_transform.origin += forwards * 10#* 6.0 * camera_intended_scale
    
    prev_fps_mode = $ButtonPerspective.selected == 2

var ref_point = null
var ref_normal = null

func ray_point_distance_squared(ray_origin : Vector3, ray_normal : Vector3, point : Vector3):
    return ray_normal.normalized().cross(point - ray_origin).length_squared()

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
func cube_ray_intersection(cube_origin : Vector3, ray_origin : Vector3, ray_normal : Vector3, max_distance : float) -> Variant:
    for dir in directions:
        var stuff = face_ray_intersection(cube_origin + dir*0.5, dir, ray_origin, ray_normal, max_distance)
        if stuff != null:
            return stuff
    return null

func raycast_voxels(ray_origin : Vector3, ray_normal : Vector3, hit_mode : int = 0) -> Variant:
    #var ray_end = ray_origin + ray_normal
    #var num_steps = ceil(ray_normal.length() + 0.5) # ensure each step is at least slightly smaller than 1.0 units
    #ray_normal = ray_normal / num_steps
    #var tested = {}
    #for i in range(num_steps):
    if true:
        #var rounded = ray_origin.round()
        var closest = null
        #var remaining_distance = ray_normal.length() * (num_steps - i)
        var distance_limit = ray_normal.length()
        #for z in [1, 0]: for y in [1, 0]: for x in [1, 0]:
        #    var offset = (rounded + Vector3(x, y, z)*ray_normal.sign()).round()
        var is_decal = current_mat is DecalMat and not current_mat is ModelMat
        var is_model = current_mat is ModelMat
        
        var to_iter = []
        if hit_mode == 0:
            to_iter = (
                $Voxels.voxels.keys() +
                ($Voxels.models.keys() if is_model else []) +
                ($Voxels.decals.keys() if is_decal else [])
            )
        elif hit_mode == 1:
            to_iter = $Voxels.voxels.keys() + $Voxels.models.keys() + $Voxels.decals.keys()
        
        for voxel in to_iter:
            var offset = voxel.round() + Vector3.ONE - Vector3.ONE
            if ray_point_distance_squared(ray_origin, ray_normal, offset) > 2.0*2.0:
                continue
            #if offset in tested:
            #    continue
            #tested[offset] = null
            #if $Voxels.voxels.has(offset):
            var collision_data = cube_ray_intersection(offset, ray_origin, ray_normal, distance_limit)
            if collision_data != null:
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

func show_controls():
    $ControlsExplanation.modulate.a = 1.0

# 0 = material, 1 = new selection, 2 = tweak selection, 3 = move, 4 = paste
enum {
    TOOL_MODE_MAT,
    TOOL_MODE_NEW_SELECT,
    TOOL_MODE_SELECT,
    TOOL_MODE_MOVE_SELECT,
    TOOL_MODE_PASTE_SELECT,
}
var tool_mode = TOOL_MODE_MAT
var selection_start = null
var selection_end = null

func reset_selection():
    selection_start = null
    selection_end = null
    tool_mode = TOOL_MODE_NEW_SELECT
    $Voxels.inform_selection(selection_start, selection_end)

var f = 1.0
func _process(delta):
    #print(face_ray_intersection(Vector3(), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(-2, 0, 0)))
    if Engine.is_editor_hint():
        return
    update_camera()
    $GizmoHelper.inform_gizmos([])
    
    #if not f is float:
    #    f = 1.0
    #f = lerp(f, delta, 1.0 - pow(0.1, delta))
    #FPS.text = str(snapped(1.0/f, 0.01))
    
    var mod_speed = 0.1
    if Input.is_mouse_button_pressed(1) or Input.is_mouse_button_pressed(2) or Input.is_mouse_button_pressed(3):
        mod_speed = 1.0
    
    $ControlsExplanation.modulate.a = move_toward($ControlsExplanation.modulate.a, 0.0, delta*mod_speed)
    
    if $ButtonPerspective.selected == 2:
        var forwards = $CameraHolder/Camera3D.global_transform.basis * (Vector3.FORWARD)
        var rightwards = $CameraHolder/Camera3D.global_transform.basis * (Vector3.RIGHT)
        if Input.is_action_pressed("ui_up"):
            $CameraHolder.global_transform.origin += forwards * delta * 16.0
        if Input.is_action_pressed("ui_down"):
            $CameraHolder.global_transform.origin -= forwards * delta * 16.0
        if Input.is_action_pressed("ui_right"):
            $CameraHolder.global_transform.origin += rightwards * delta * 16.0
        if Input.is_action_pressed("ui_left"):
            $CameraHolder.global_transform.origin -= rightwards * delta * 16.0
    
    var i = 0
    var mat_index = mats.find(current_mat)
    for button in $Mats/List.get_children():
        button.button_pressed = false
        if i == mat_index:
            button.button_pressed = true
        i += 1
    
    $VertEditPanel.visible = current_mat is VoxMat
    
    $Mat2dTilePicker.visible = current_mat is DecalMat # want it for models too
    $Mat2dOrientation.visible = current_mat is DecalMat and not current_mat is ModelMat # but not this
    
    $ModelAdvanced.visible = current_mat is ModelMat
    $ModelMatchFloor.visible = current_mat is ModelMat
    
    $ModelTurnCount.visible = current_mat is ModelMat
    $ModelSpacing.visible = current_mat is ModelMat
    $ModelRotationX.visible = current_mat is ModelMat and $ModelAdvanced.button_pressed
    $ModelRotationY.visible = current_mat is ModelMat
    $ModelRotationZ.visible = current_mat is ModelMat and $ModelAdvanced.button_pressed
    $ModelWiden.visible = current_mat is ModelMat and $ModelAdvanced.button_pressed
    
    $ModelOffsetX.visible = current_mat is ModelMat and $ModelAdvanced.button_pressed
    $ModelOffsetY.visible = current_mat is ModelMat and $ModelAdvanced.button_pressed
    $ModelOffsetZ.visible = current_mat is ModelMat and $ModelAdvanced.button_pressed
    
    if current_mat is DecalMat:
        $Mat2dTilePicker.tex = current_mat.tex
        $Mat2dTilePicker.grid_size = current_mat.grid_size
        $Mat2dTilePicker.icon_coord = current_mat.current_coord
        $Mat2dTilePicker.think()
        current_mat.current_coord = $Mat2dTilePicker.icon_coord
    
    #tool_mode = TOOL_MODE_NEW_SELECT
    
    if tool_mode == TOOL_MODE_MAT:
        handle_voxel_input()
    
    if $Voxels.operation_active and !draw_mode and !erase_mode:
        end_operation()
    
    if tool_mode == TOOL_MODE_NEW_SELECT:
        $ButtonSelect.button_pressed = true
        handle_new_selection()
        if Input.is_action_just_pressed("ui_cancel"):
            reset_selection()
    elif tool_mode == TOOL_MODE_SELECT:
        $ButtonSelect.button_pressed = true
        handle_adjust_selection()
        if Input.is_action_just_pressed("ui_cancel"):
            reset_selection()
    else:
        $ButtonSelect.button_pressed = false
    
    if tool_mode == TOOL_MODE_MOVE_SELECT:
        handle_adjust_selection(true) 
        $ButtonMove.button_pressed = true
        if Input.is_action_just_pressed("ui_cancel"):
            reset_selection()
    else:
        $ButtonMove.button_pressed = false
    
    main_just_pressed = false
    sub_just_pressed = false

func distance_point_line(line_a : Vector2, line_b : Vector2, point : Vector2) -> float:
    var diff = line_b - line_a
    var point_offset = point - line_a
    var top = abs(diff.x * point_offset.y - diff.y * point_offset.x)
    var bottom = diff.length()
    return top/bottom

func closest_point_line(line_a : Vector2, line_b : Vector2, point : Vector2):
    var dist = distance_point_line(line_a, line_b, point)
    var diff = line_b - line_a
    var adjust = Vector2(diff.y, -diff.x).normalized() * dist
    var cand_a = point + adjust
    var cand_b = point - adjust
    if cand_a.distance_squared_to(line_a) < cand_b.distance_squared_to(line_a):
        return cand_a
    else:
        return cand_b

func handle_new_selection():
    #var alt_offset = !(current_mat is VoxMat or current_mat is ModelMat)
    var info = fully_handle_raycast(false, true)
    if info == null:
        return
    #var cast_start = info[0]
    #var cast_normal = info[1]
    #var raw_collision_point = info[2]
    var collision_normal = info[3]
    #var m_pos = info[4]
    if main_just_pressed:
        start_operation()
        selection_start = collision_point
        selection_end = collision_point
        ref_point = collision_point
        ref_normal = collision_normal
    elif draw_mode:
        selection_end = collision_point
    else:
        if selection_start != null and selection_end != null:
            var aabb = AABB(selection_start, Vector3())
            aabb.end = selection_end
            aabb = aabb.abs()
            selection_start = aabb.position
            selection_end = aabb.end
            tool_mode = TOOL_MODE_SELECT
            $Voxels.inform_selection(selection_start, selection_end)
            end_operation()
    
    if selection_start != null:
        $CursorBox.show()
        $CursorBox.global_position = (selection_start + selection_end) / 2.0
        $CursorBox.scale = (selection_end - selection_start).abs() + Vector3(0.1, 0.1, 0.1) + Vector3.ONE
    else:
        $CursorBox.hide()

var gizmo_drag_dir = Vector3()
var gizmo_drag_dir_unrounded = null
func handle_adjust_selection(move_not_adjust : bool = false):
    if selection_start == null or selection_end == null:
        return
    
    var cam : Camera3D = $CameraHolder/Camera3D as Camera3D
    var mouse_pos = $GizmoHelper.get_local_mouse_position()
    
    if main_just_pressed:
        start_operation()
    
    if !draw_mode:
        gizmo_drag_dir = Vector3()
        gizmo_drag_dir_unrounded = null
    
    var old_selection_start = selection_start
    var old_selection_end = selection_end
    
    var aabb = AABB(selection_start, Vector3())
    aabb = aabb.abs()
    aabb = aabb.expand(selection_end)
    aabb.position -= Vector3.ONE * 0.5
    aabb.end += Vector3.ONE
    aabb = aabb.abs()
    var start = aabb.position
    var end = aabb.end
    
    var dirs = directions.duplicate()
    var gizmos = []
    for dir in dirs:
        var t = dir*0.5 + Vector3(0.5, 0.5, 0.5)
        var pos_x = lerp(start.x, end.x, t.x)
        var pos_y = lerp(start.y, end.y, t.y)
        var pos_z = lerp(start.z, end.z, t.z)
        
        var coord = Vector3(pos_x, pos_y, pos_z)
        var raw_coord = coord
        if gizmo_drag_dir_unrounded != null and dir == gizmo_drag_dir:
            coord = gizmo_drag_dir_unrounded
        
        var pos = cam.unproject_position(coord)
        var pos_dist = mouse_pos.distance_to(pos)
        
        var cam_pos = cam.global_position
        var cam_rot = cam.global_transform.basis.get_euler()
        var xform = Transform3D(Basis.from_euler(cam_rot), cam_pos)
        var depth = -(coord * xform).z
        gizmos.push_back([coord, pos_dist, pos, depth, Color.ORANGE, dir, raw_coord])
    
    gizmos.sort_custom(func compare(a, b): return a[1] < b[1])
    
    if gizmos[0][1] < 8.0:
        if main_just_pressed:
            gizmo_drag_dir = gizmos[0][5]
        gizmos[0][4] = Color.YELLOW
    
    var did_adjust = false
    
    var gizmos_dict = {}
    for gizmo in gizmos:
        gizmos_dict[gizmo[5]] = gizmo
    if gizmo_drag_dir in gizmos_dict:
        var gizmo = gizmos_dict[gizmo_drag_dir]
        gizmo[4] = Color.CYAN
        
        var affected_dir = gizmo_drag_dir
        var pos = gizmo[2]
        var old_pos = pos
        var pos2 = cam.unproject_position(gizmo[0] + gizmo_drag_dir)
        var depth = gizmo[3]
        pos = closest_point_line(old_pos, pos2, $GizmoHelper.get_local_mouse_position())
        var rect = $GizmoHelper.get_rect()
        
        var old_coord = gizmo[0]
        var old_rounded = (gizmo[0] + gizmo_drag_dir*0.5).round() - gizmo_drag_dir*0.5
        var new_coord : Vector3 = cam.project_position(pos, depth)
        # limit movement to only the handle's direction component
        new_coord = old_coord + (new_coord - old_coord).project(gizmo_drag_dir)
        # apply movement if it wouldn't put the node behind the camera
        if !cam.is_position_behind(new_coord):
            var opposite_gizmo = gizmos_dict[-gizmo_drag_dir]
            var opposite_coord = opposite_gizmo[0]
            var n = (new_coord - opposite_coord - gizmo_drag_dir).normalized()
            if n.dot(gizmo_drag_dir) > 0.99 or move_not_adjust:
                gizmo[0] = new_coord
            gizmo_drag_dir_unrounded = gizmo[0]
            var temp_rounded = (gizmo[0] + gizmo_drag_dir*0.5).round() - gizmo_drag_dir*0.5
            gizmo[0] = gizmo[0] * (Vector3.ONE-gizmo_drag_dir.abs()) + temp_rounded*gizmo_drag_dir.abs()
            var diff = (gizmo[0] - old_rounded) * (gizmo_drag_dir.abs())
            if diff.length() != 0:
                did_adjust = true
            if move_not_adjust:
                opposite_gizmo[0] += diff
    
    var new_aabb = AABB(gizmos[0][0], Vector3())
    for info in gizmos:
        new_aabb = new_aabb.expand(info[0])
    new_aabb.end -= Vector3.ONE * 1.1
    new_aabb.position += Vector3.ONE * 0.51
    new_aabb = new_aabb.abs()
    
    selection_start = new_aabb.position.round()
    selection_end = new_aabb.end.round()
    
    if old_selection_start != selection_start or old_selection_end != selection_end:
        if !move_not_adjust:
            $Voxels.inform_selection(selection_start, selection_end)
        else:
            $Voxels.move_selection(selection_start - old_selection_start)
    
    if !draw_mode:
        end_operation()
    
    gizmos.sort_custom(func compare(a, b): return a[3] > b[3])
    gizmos = gizmos.map(func f(f): return [f[0], f[4]])
    
    $GizmoHelper.inform_gizmos(gizmos)
    
    $CursorBox.global_position = (selection_start + selection_end) / 2.0
    $CursorBox.scale = selection_end - selection_start + Vector3(0.1, 0.1, 0.1) + Vector3.ONE
    $CursorBox.visible = true

func place_mat_at(voxels, mat, point, normal, use_overrides : bool = true):
    if mat is VoxMat:
        if use_overrides:
            voxels.place_voxel(point, mat, $VertEditPanel.prepared_overrides)
        else:
            voxels.place_voxel(point, mat)
    elif mat is ModelMat:
        var info = (
            (int($ModelWiden.button_pressed)) |
            (int($ModelSpacing.value) << 1) |
            (int($ModelTurnCount.value - 1) << 4) |
            (int($ModelRotationX.value) << 6) |
            (int($ModelRotationY.value) << 9) |
            (int($ModelRotationZ.value) << 12)
        )
        var floor_mode = $ModelMatchFloor.selected
        var offset_x = $ModelOffsetX.value
        var offset_y = $ModelOffsetY.value
        var offset_z = $ModelOffsetZ.value
        voxels.place_model(point, mat, info, floor_mode, offset_x, offset_y, offset_z)
    elif mat is DecalMat:
        var idx = $Mat2dOrientation.selected
        voxels.place_decal(point, normal, mat, idx)

func fully_handle_raycast(alt_offset : bool, always_succeed : bool = false):
    var view_rect : Rect2 = get_viewport().get_visible_rect()
    var m_pos : Vector2 = get_viewport().get_mouse_position()
    var cast_start : Vector3 = $CameraHolder/Camera3D.project_ray_origin(m_pos)
    var cast_normal : Vector3 = $CameraHolder/Camera3D.project_ray_normal(m_pos)
    
    if !view_rect.has_point(m_pos):
        return null
    
    var raw_collision_point = null
    collision_point = null
    var collision_normal = null
    
    var start = Time.get_ticks_usec()
    var mode = 1 if input_pick_mode else 0
    var collision_data = raycast_voxels(cast_start, cast_normal * 100.0, mode)
    var end = Time.get_ticks_usec()
    
    var time = (end-start)/1000000.0
    if time > 0.1:
        print("raycast time: ", time)
    
    if collision_data:
        collision_normal = collision_data[1]
        raw_collision_point = collision_data[0]
        collision_point = (raw_collision_point - collision_normal*0.5).round()
        # get rid of negative zero
        collision_point = collision_point + Vector3.ONE - Vector3.ONE
    
    if !draw_mode and !erase_mode:
        ref_point = null
        ref_normal = null
        draw_use_offset = false
    
    if ref_point:
        var offset = ref_normal*0.5
        if draw_use_offset and !alt_offset:
            offset += -ref_normal
        var new_point = ray_plane_intersection(cast_start, cast_normal, ref_point + offset, ref_normal)
        if new_point:
            raw_collision_point = new_point
            collision_point = (new_point - offset).round()
            collision_normal = ref_normal
        else:
            collision_point = null
            collision_normal = null
    
    return [cast_start, cast_normal, raw_collision_point, collision_normal, m_pos]

var collision_point = null
var last_collision_point = null
func handle_voxel_input():
    var alt_offset = !(current_mat is VoxMat or current_mat is ModelMat)
    var info = fully_handle_raycast(alt_offset)
    if info == null:
        return
    #var cast_start = info[0]
    var cast_normal = info[1]
    var raw_collision_point = info[2]
    var collision_normal = info[3]
    var m_pos = info[4]
    
    var draw_type = $ButtonMode.selected
    if alt_offset:
        draw_type = 0
    
    if collision_point != null:
        $CursorBox.show()
        $CursorBox.scale = Vector3(1.1, 1.1, 1.1)
        $CursorBox.global_position = collision_point
        if alt_offset and ref_point != null:
            $CursorBox.global_transform.origin += collision_normal
        if current_mat is DecalMat and not current_mat is ModelMat:
            var positive = collision_normal.abs()
            var negative : Vector3 = Vector3.ONE - positive
            $CursorBox.scale *= negative.lerp(Vector3.ONE, 0.2)
            $CursorBox.global_transform.origin -= collision_normal*0.4
        
        if $ButtonGrid.selected == 0 or ($ButtonGrid.selected == 2 and draw_mode):
            $Grid.show()
            $Grid.global_transform.origin = collision_point + collision_normal*0.501
            if draw_use_offset and !alt_offset:
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
            if draw_type == 0:
                $CursorBox.global_transform.origin += collision_normal
            elif draw_type == 2 and abs(collision_normal.y) != 0.0:
                $CursorBox.global_transform.origin += collision_normal
            elif draw_type == 3 and abs(collision_normal.y) == 0.0:
                $CursorBox.global_transform.origin += collision_normal
        
    else:
        $CursorBox.hide()
        $Grid.hide()
    
    if draw_mode and collision_normal != null and collision_point != null:
        var new_point = collision_point
        
        if ref_point == null:
            if draw_type == 0:
                new_point += collision_normal
            elif draw_type == 2 and abs(collision_normal.y) != 0.0:
                new_point += collision_normal
            elif draw_type == 3 and abs(collision_normal.y) == 0.0:
                new_point += collision_normal
        
        if new_point != last_collision_point:
            if current_mat is VoxMat or current_mat is ModelMat:
                place_mat_at($Voxels, current_mat, new_point, collision_normal)
            elif current_mat is DecalMat:
                collision_point = collision_point + Vector3.ONE - Vector3.ONE
                place_mat_at($Voxels, current_mat, collision_point, collision_normal)
        
        last_collision_point = new_point
        
        if $ButtonTool.selected == 0:
            draw_mode = false
        elif ref_point == null:
            ref_point = new_point
            if alt_offset:
                ref_point = collision_point
            ref_normal = collision_normal
            if draw_type == 0:
                if $ButtonWarp.selected == 0:
                    draw_use_offset = true
                else:
                    var pos_1 = $CameraHolder/Camera3D.unproject_position(raw_collision_point)
                    var pos_2 = $CameraHolder/Camera3D.unproject_position(raw_collision_point + ref_normal)
                    m_warp_amount = pos_2 - pos_1
                    get_viewport().warp_mouse(m_pos + m_warp_amount)
            if draw_type == 2:
                var x_ish = abs(cast_normal.x) > abs(cast_normal.z)
                if x_ish:
                    ref_normal = Vector3(sign(-cast_normal.x), 0, 0)
                else:
                    ref_normal = Vector3(0, 0, sign(-cast_normal.z))
            if draw_type == 3:
                ref_normal = Vector3(0, -sign(cast_normal.y), 0)
            if (draw_type == 2 or draw_type == 3) and $ButtonWarp.selected == 1 and collision_normal != ref_normal:
                var norm = ref_normal.abs()
                var un_norm = Vector3.ONE - norm
                var offset_point_centered = new_point + ref_normal * 0.5
                var offset_point = offset_point_centered * norm + raw_collision_point * un_norm
                offset_point = offset_point.lerp(offset_point_centered, 0.1)
                var pos_1 = $CameraHolder/Camera3D.unproject_position(raw_collision_point)
                var pos_2 = $CameraHolder/Camera3D.unproject_position(offset_point)
                m_warp_amount = pos_2 - pos_1
                get_viewport().warp_mouse(m_pos + m_warp_amount)
    
    if erase_mode and collision_normal != null and collision_point != null:
        var new_point = collision_point
        if new_point != last_collision_point:
            if current_mat is VoxMat:
                $Voxels.erase_voxel(new_point)
            elif current_mat is ModelMat:
                $Voxels.erase_model(new_point)
            elif current_mat is DecalMat:
                $Voxels.erase_decal(new_point, collision_normal)
        
        last_collision_point = new_point
        
        if $ButtonTool.selected == 0:
            erase_mode = false
        elif ref_point == null:
            ref_point = new_point
            ref_normal = collision_normal
            if draw_type == 2:
                var x_ish = abs(cast_normal.x) > abs(cast_normal.z)
                if x_ish:
                    ref_normal = Vector3(sign(-cast_normal.x), 0, 0)
                else:
                    ref_normal = Vector3(0, 0, sign(-cast_normal.z))
            if draw_type == 3:
                ref_normal = Vector3(0, -sign(cast_normal.y), 0)

func _draw():
    pass
