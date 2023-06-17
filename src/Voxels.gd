@tool
extends MeshInstance3D

func vec_to_array(vec : Vector3) -> Array:
    return [vec.x, vec.y, vec.z]

func array_to_vec(array : Array) -> Vector3:
    return Vector3(array[0], array[1], array[2])

@onready var editor = get_tree().get_nodes_in_group("VoxEditor")[0]

@onready var voxels = {Vector3(0, 0, 0) : editor.get_default_voxmat()}

func occluding_voxel_exists(p_position, source_mat):
    if has_voxel(p_position):
        if (get_voxel(p_position) == source_mat
        and source_mat.transparent_mode != 0
        and source_mat.transparent_inner_face_mode == 1):
            return true
        if get_voxel(p_position).transparent_mode == 0:
            return true
    return false

func occluding_face_exists(origin, p_position, source_mat):
    if !occluding_voxel_exists(p_position, source_mat):
        return false
    var dir = p_position - origin
    var other_a = Vector3.RIGHT if dir.abs() != Vector3.RIGHT else Vector3.UP
    var other_b = dir.cross(other_a)
    var matches = matching_edges_match(origin, p_position, other_a)
    matches = matches and matching_edges_match(origin, p_position, -other_a)
    matches = matches and matching_edges_match(origin, p_position,  other_b)
    matches = matches and matching_edges_match(origin, p_position, -other_b)
    return matches

@onready var decals = {}
@onready var models = {}

@onready var voxel_corners = {
}

func clear():
    voxels = {}
    decals = {}
    models = {}
    voxel_corners = {}

func dict_left(a : Dictionary, b : Dictionary) -> Dictionary:
    var ret = {}
    for key in a:
        if not key in b:
            ret[key] = a[key]
    return ret

func dict_right(a : Dictionary, b : Dictionary) -> Dictionary:
    return dict_left(b, a)

func dict_diff(a : Dictionary, b : Dictionary) -> Dictionary:
    var ret = {}
    for key in a.keys() + b.keys():
        if a.get(key) != b.get(key):
            ret[key] = [a.get(key), b.get(key)]
    return ret

func apply_diff_right(a : Dictionary, diff : Dictionary):
    for key in diff:
        var new = diff[key][1]
        if new == null and key in a:
            a.erase(key)
        else:
            a[key] = new

func apply_diff_left(a : Dictionary, diff : Dictionary):
    for key in diff:
        var old = diff[key][0]
        if old == null and key in a:
            a.erase(key)
        else:
            a[key] = old

var undo_buffer = []
var redo_buffer = []

func perform_undo():
    if undo_buffer.size() == 0:
        return
    
    var info = undo_buffer.pop_back()
    
    if "voxels" in info:
        apply_diff_left(voxels, info.voxels)
    if "decals" in info:
        apply_diff_left(decals, info.decals)
    if "models" in info:
        apply_diff_left(models, info.models)
    if "voxel_corners" in info:
        apply_diff_left(voxel_corners, info.voxel_corners)
    if "selection_data" in info:
        apply_diff_left(selection_data, info.selection_data)
    if "selection_start" in info:
        selection_start = info.selection_start[0]
    if "selection_end" in info:
        selection_end = info.selection_end[0]
    if "uv_data_cache" in info:
        apply_diff_left(uv_data_cache, info.uv_data_cache)
    if "voxel_data_cache" in info:
        apply_diff_left(voxel_data_cache, info.voxel_data_cache)
    
    redo_buffer.push_back(info)
    hinted_remesh()

func perform_redo():
    if redo_buffer.size() == 0:
        return
    
    var info = redo_buffer.pop_back()
    
    if "voxels" in info:
        apply_diff_right(voxels, info.voxels)
    if "decals" in info:
        apply_diff_right(decals, info.decals)
    if "models" in info:
        apply_diff_right(models, info.models)
    if "voxel_corners" in info:
        apply_diff_right(voxel_corners, info.voxel_corners)
    if "selection_data" in info:
        apply_diff_right(selection_data, info.selection_data)
    if "selection_start" in info:
        selection_start = info.selection_start[1]
    if "selection_end" in info:
        selection_end = info.selection_end[1]
    if "uv_data_cache" in info:
        apply_diff_right(uv_data_cache, info.uv_data_cache)
    if "voxel_data_cache" in info:
        apply_diff_right(voxel_data_cache, info.voxel_data_cache)
    
    undo_buffer.push_back(info)
    hinted_remesh()

var temp_world = {}
var operation_active = false
func start_operation():
    temp_world["voxels"] = voxels.duplicate(false)
    temp_world["decals"] = decals.duplicate(false)
    temp_world["models"] = models.duplicate(false)
    temp_world["voxel_corners"] = voxel_corners.duplicate(false)
    temp_world["selection_data"] = selection_data.duplicate(false)
    temp_world["selection_start"] = selection_start
    temp_world["selection_end"] = selection_end
    temp_world["uv_data_cache"] = uv_data_cache.duplicate(false)
    temp_world["voxel_data_cache"] = voxel_data_cache.duplicate(false)
    operation_active = true

func end_operation():
    if !operation_active:
        return
    
    # need to remesh to update caches
    hinted_remesh()
    
    var changed = {}
    
    var diff = dict_diff(temp_world.voxels, voxels)
    if diff.size() > 0:
        changed["voxels"] = diff
    
    diff = dict_diff(temp_world.decals, decals)
    if diff.size() > 0:
        changed["decals"] = diff
    
    diff = dict_diff(temp_world.models, models)
    if diff.size() > 0:
        changed["models"] = diff
    
    diff = dict_diff(temp_world.voxel_corners, voxel_corners)
    if diff.size() > 0:
        changed["voxel_corners"] = diff
    
    diff = dict_diff(temp_world.selection_data, selection_data)
    if diff.size() > 0:
        changed["selection_data"] = diff
    
    if temp_world.selection_start != selection_start:
        changed["selection_start"] = [temp_world.selection_start, selection_start]
    
    if temp_world.selection_end != selection_end:
        changed["selection_end"] = [temp_world.selection_end, selection_end]
    
    diff = dict_diff(temp_world.uv_data_cache, uv_data_cache)
    if diff.size() > 0:
        changed["uv_data_cache"] = diff
    
    diff = dict_diff(temp_world.voxel_data_cache, voxel_data_cache)
    if diff.size() > 0:
        changed["voxel_data_cache"] = diff
    
    if changed.size() > 0:
        undo_buffer.push_back(changed)
        if undo_buffer.size() > 1000:
            undo_buffer.pop_front()
        redo_buffer = []
    
    temp_world = {}
    operation_active = false

func serialize() -> Dictionary:
    var mats = {}
    var save_mats = {}
    var mat_counter = 0
    
    for mat in editor.mats:
        if not mat in mats:
            mats[mat] = mat_counter
            save_mats[mat_counter] = mat.encode()
            mat_counter += 1
    
    var save_voxels = []
    for coord in voxels:
        var save_coord = vec_to_array(coord)
        var mat = voxels[coord]
        if not mat in mats:
            mats[mat] = mat_counter
            save_mats[mat_counter] = mat.encode()
            mat_counter += 1
        save_voxels.push_back([save_coord, mats[mat]])
    
    var save_corners = []
    for coord in voxel_corners:
        var save_coord = vec_to_array(coord)
        var bwuh = []
        for corner in voxel_corners[coord]:
            var from_corner = vec_to_array(corner)
            var to_corner = vec_to_array(voxel_corners[coord][corner])
            bwuh.push_back([from_corner, to_corner])
        save_corners.push_back([save_coord, bwuh])
    
    var save_decals = []
    for coord in decals:
        var save_coord = vec_to_array(coord)
        var bwuh = []
        for dir in decals[coord]:
            var save_dir = vec_to_array(dir)
            
            var mat = decals[coord][dir][0]
            if not mat in mats:
                mats[mat] = mat_counter
                save_mats[mat_counter] = mat.encode()
                mat_counter += 1
            
            var tile_coord = Helpers.vec2_to_array(decals[coord][dir][1])
            var orientation = decals[coord][dir][2]
            bwuh.push_back([save_dir, mats[mat], tile_coord, orientation])
        save_decals.push_back([save_coord, bwuh])
    
    var save_models = []
    for coord in models:
        var save_coord = vec_to_array(coord)
        var list = models[coord].duplicate()
        for i in list.size():
            if list[i] is Vector3:
                list[i] = vec_to_array(list[i])
            elif list[i] is Vector2:
                list[i] = Helpers.vec2_to_array(list[i])
        
        var mat = list[0]
        if not mat in mats:
            mats[mat] = mat_counter
            save_mats[mat_counter] = mat.encode()
            mat_counter += 1
        
        list[0] = mats[mat]
        #print(list[0])
        
        save_models.push_back([save_coord, list])
    
    #print(save_mats.keys())
    
    return {"voxels" : save_voxels, "decals" : save_decals, "models" : save_models, "mats" : save_mats, "corners" : save_corners}

func deserialize(data : Dictionary):
    voxel_corners = {}
    for vertex in data.corners:
        var vec = array_to_vec(vertex[0])
        voxel_corners[vec] = {}
        for corner in vertex[1]:
            var from_corner = array_to_vec(corner[0])
            var to_corner = array_to_vec(corner[1])
            voxel_corners[vec][from_corner] = to_corner
    
    var opened_mats = {}
    editor.mats = []
    var mat_keys : Array = data.mats.keys()
    mat_keys.sort()
    for mat_key in mat_keys:
        var mat = editor.VoxMat.decode(data.mats[mat_key])
        editor.mats.push_back(mat)
        opened_mats[int(mat_key)] = mat
    
    voxels = {}
    for voxel in data.voxels:
        var vec = array_to_vec(voxel[0])
        voxels[vec] = opened_mats[int(voxel[1])]
    
    decals = {}
    if "decals" in data:
        for info in data.decals:
            var coord = array_to_vec(info[0])
            var dirs = info[1]
            decals[coord] = {}
            for info2 in dirs:
                var dir = array_to_vec(info2[0])
                var mat = info2[1]
                var tile_coord = Helpers.array_to_vec2(info2[2])
                var orientation = 0
                if info2.size() > 3:
                    orientation = info2[3]
                decals[coord][dir] = [opened_mats[int(mat)], tile_coord, orientation]
    
    models = {}
    if "models" in data:
        for info in data.models:
            var coord = array_to_vec(info[0])
            var stuff = info[1]
            stuff[0] = opened_mats[int(stuff[0])]
            for i in range(0, stuff.size()):
                if stuff[i] is Array and stuff[i].size() == 3:
                    stuff[i] = array_to_vec(stuff[i])
                elif stuff[i] is Array and stuff[i].size() == 2:
                    stuff[i] = Helpers.array_to_vec2(stuff[i])
                elif stuff[i] is float:
                    stuff[i] = int(stuff[i])
            
            models[coord] = stuff
    
    full_remesh()
    
    editor.current_mat = editor.mats[0]
    
    editor.rebuild_mat_buttons()

func _ready():
    refresh_surface_mapping()
    remesh()

var is_dirty = false
func _process(_delta):
    if is_dirty:
        is_dirty = false
        
        var start = Time.get_ticks_usec()
        refresh_surface_mapping()
        var end = Time.get_ticks_usec()
        
        var time = (end-start)/1000000.0
        if time > 0.1:
            print("refresh time: ", time)
        
        start = Time.get_ticks_usec()
        remesh()
        end = Time.get_ticks_usec()
        
        time = (end-start)/1000000.0
        if time > 0.01:
            print("remesh time: ", time)
            var blocks = voxels.size() + decals.size() + models.size()
            print("block count: ", blocks)
            print("ms per block: ", time/blocks*1000)
            

const directions : Array[Vector3] = [
    Vector3.UP,
    Vector3.DOWN,
    Vector3.LEFT,
    Vector3.RIGHT,
    Vector3.FORWARD,
    Vector3.BACK,
]
const sides : Array[Vector3] = [
    Vector3.LEFT,
    Vector3.RIGHT,
    Vector3.FORWARD,
    Vector3.BACK,
]
const unsides : Array[Vector3] = [
    Vector3.UP,
    Vector3.DOWN,
]

var dir_verts = build_verts()

const bitmask_bindings = [1, 2, 4, 8, 16, 32, 64, 128, 256]
const BIND_TOPLEFT = 1
const BIND_TOP = 2
const BIND_TOPRIGHT = 4
const BIND_LEFT = 8
const BIND_CENTER = 16
const BIND_RIGHT = 32
const BIND_BOTTOMLEFT = 64
const BIND_BOTTOM = 128
const BIND_BOTTOMRIGHT = 256

const ref_verts : Array[Vector3] = [
    Vector3(-0.5, -0.5, -0.5),
    Vector3( 0.5, -0.5, -0.5),
    Vector3(-0.5,  0.5, -0.5),
    Vector3( 0.5,  0.5, -0.5),
]

const ref_uvs : Array[Vector2] = [
    Vector2(1.0, 0.0),
    Vector2(0.0, 0.0),
    Vector2(1.0, 1.0),
    Vector2(0.0, 1.0),
]

var bitmask_dirs = {
    BIND_TOPLEFT     : Vector2(-1, -1),
    BIND_LEFT        : Vector2(-1,  0),
    BIND_BOTTOMLEFT  : Vector2(-1,  1),
    
    BIND_TOP         : Vector2( 0, -1),
    BIND_CENTER      : Vector2( 0,  0),
    BIND_BOTTOM      : Vector2( 0,  1),
    
    BIND_TOPRIGHT    : Vector2( 1, -1),
    BIND_RIGHT       : Vector2( 1,  0),
    BIND_BOTTOMRIGHT : Vector2( 1,  1),
}

const bitmask_stuff_12x4 : Array[int] = [
0,0,0, 0,0,0, 0,0,0, 0,0,0,   1,1,0, 0,0,0, 0,0,0, 0,1,1,   0,0,0, 0,1,0, 0,0,0, 0,0,0,
0,1,0, 0,1,1, 1,1,1, 1,1,0,   1,1,1, 1,1,1, 1,1,1, 1,1,1,   0,1,1, 1,1,1, 1,1,1, 1,1,0,
0,1,0, 0,1,0, 0,1,0, 0,1,0,   0,1,0, 0,1,1, 1,1,0, 0,1,0,   0,1,1, 1,1,1, 1,1,1, 1,1,0,

0,1,0, 0,1,0, 0,1,0, 0,1,0,   0,1,0, 0,1,1, 1,1,0, 0,1,0,   0,1,1, 0,1,1, 0,0,0, 1,1,0,
0,1,0, 0,1,1, 1,1,1, 1,1,0,   0,1,1, 1,1,1, 1,1,1, 1,1,0,   0,1,1, 1,1,1, 0,0,0, 1,1,1,
0,1,0, 0,1,0, 0,1,0, 0,1,0,   0,1,1, 1,1,1, 1,1,1, 1,1,0,   0,1,1, 1,1,0, 0,0,0, 1,1,0,

0,1,0, 0,1,0, 0,1,0, 0,1,0,   0,1,1, 1,1,1, 1,1,1, 1,1,0,   0,1,1, 1,1,1, 1,1,0, 1,1,0,
0,1,0, 0,1,1, 1,1,1, 1,1,0,   0,1,1, 1,1,1, 1,1,1, 1,1,0,   1,1,1, 1,1,1, 1,1,1, 1,1,0,
0,0,0, 0,0,0, 0,0,0, 0,0,0,   0,1,0, 0,1,1, 1,1,0, 0,1,0,   0,1,1, 1,1,1, 0,1,1, 1,1,0,

0,0,0, 0,0,0, 0,0,0, 0,0,0,   0,1,0, 0,1,1, 1,1,0, 0,1,0,   0,1,1, 1,1,1, 1,1,1, 1,1,0,
0,1,0, 0,1,1, 1,1,1, 1,1,0,   1,1,1, 1,1,1, 1,1,1, 1,1,1,   0,1,1, 1,1,1, 1,1,1, 1,1,0,
0,0,0, 0,0,0, 0,0,0, 0,0,0,   1,1,0, 0,0,0, 0,0,0, 0,1,1,   0,0,0, 0,0,0, 0,1,0, 0,0,0,
]

var bitmask_uvs_12x4 = build_uvs_12x4()

const bitmask_stuff_4x4 : Array[int] = [
0,0,0, 0,0,0, 0,0,0, 0,0,0,
0,1,0, 0,1,1, 1,1,1, 1,1,0,
0,1,0, 0,1,1, 1,1,1, 1,1,0,

0,1,0, 0,1,1, 1,1,1, 1,1,0,
0,1,0, 0,1,1, 1,1,1, 1,1,0,
0,1,0, 0,1,1, 1,1,1, 1,1,0,

0,1,0, 0,1,1, 1,1,1, 1,1,0,
0,1,0, 0,1,1, 1,1,1, 1,1,0,
0,0,0, 0,0,0, 0,0,0, 0,0,0,

0,0,0, 0,0,0, 0,0,0, 0,0,0,
0,1,0, 0,1,1, 1,1,1, 1,1,0,
0,0,0, 0,0,0, 0,0,0, 0,0,0,
]

var bitmask_uvs_4x4 = build_uvs_4x4()

const ref_corners : Array[Vector3] = [
    Vector3(-0.5, -0.5, -0.5),
    Vector3( 0.5, -0.5, -0.5),
    Vector3(-0.5,  0.5, -0.5),
    Vector3( 0.5,  0.5, -0.5),
    Vector3(-0.5, -0.5,  0.5),
    Vector3( 0.5, -0.5,  0.5),
    Vector3(-0.5,  0.5,  0.5),
    Vector3( 0.5,  0.5,  0.5),
]

const top_corners : Array[Vector3] = [
    Vector3(-0.5,  0.5, -0.5),
    Vector3( 0.5,  0.5, -0.5),
    Vector3(-0.5,  0.5,  0.5),
    Vector3( 0.5,  0.5,  0.5),
]

func has_voxel(coord : Vector3):
    return ("voxels" in selection_data and coord in selection_data.voxels) or coord in voxels
func get_voxel(coord : Vector3):
    if "voxels" in selection_data and coord in selection_data.voxels:
        return selection_data.voxels.get(coord)
    else:
        return voxels.get(coord)

func has_voxel_corner(coord : Vector3):
    return ("voxel_corners" in selection_data and coord in selection_data.voxel_corners) or coord in voxel_corners
func get_voxel_corner(coord : Vector3):
    if "voxel_corners" in selection_data and coord in selection_data.voxel_corners:
        return selection_data.voxel_corners.get(coord)
    else:
        return voxel_corners.get(coord)

func has_decal(coord : Vector3, dir : Vector3):
    return ("decals" in selection_data and coord in selection_data.decals and dir in selection_data.decals[coord]) or (coord in decals and dir in decals[coord])
func get_decal(coord : Vector3, dir : Vector3):
    if "decals" in selection_data and coord in selection_data.decals and dir in selection_data.decals[coord]:
        return selection_data.decals.get(coord)[dir]
    else:
        return decals.get(coord)[dir]

func has_model(coord : Vector3):
    return ("models" in selection_data and coord in selection_data.models) or coord in models
func get_model(coord : Vector3):
    if "models" in selection_data and coord in selection_data.models:
        return selection_data.models.get(coord)
    else:
        return models.get(coord)

func get_voxel_coords():
    var keys = {}
    for key in voxels:
        keys[key] = null
    if "voxels" in selection_data:
        for key in selection_data.voxels:
            keys[key] = null
    return keys.keys()

func get_voxel_corner_coords():
    var keys = {}
    for key in voxel_corners:
        keys[key] = null
    if "voxel_corners" in selection_data:
        for key in selection_data.voxel_corners:
            keys[key] = null
    return keys.keys()

func get_decal_coords():
    var keys = {}
    for key in decals:
        keys[key] = null
    if "decals" in selection_data:
        for key in selection_data.decals:
            keys[key] = null
    return keys.keys()

func get_decal_dirs(coord : Vector3):
    var keys = {}
    if coord in decals:
        for key in decals[coord]:
            keys[key] = null
    if "decals" in selection_data:
        if coord in selection_data.decals:
            for key in selection_data.decals[coord]:
                keys[key] = null
    return keys.keys()

func get_model_coords():
    var keys = {}
    for key in models:
        keys[key] = null
    if "models" in selection_data:
        for key in selection_data.models:
            keys[key] = null
    return keys.keys()

var decals_by_mat = {}
var models_by_mat = {}
var voxels_by_mat = {}
func refresh_surface_mapping():
    voxels_by_mat = {}
    for pos in get_voxel_coords():
        var mat = get_voxel(pos)
        if not voxels_by_mat.has(mat):
            voxels_by_mat[mat] = []
        voxels_by_mat[mat].push_back(pos)
    
    decals_by_mat = {}
    for pos in get_decal_coords():
        for dir in get_decal_dirs(pos):
            var decal = get_decal(pos, dir)[0]
            if not decals_by_mat.has(decal):
                decals_by_mat[decal] = []
            decals_by_mat[decal].push_back([pos, dir])
    
    models_by_mat = {}
    for pos in get_model_coords():
        var mat = get_model(pos)[0]
        if not models_by_mat.has(mat):
            models_by_mat[mat] = []
        models_by_mat[mat].push_back(pos)


var selection_data = {}
var selection_start = null
var selection_end = null
func inform_selection(new_start, new_end, _source = null):
    var old_start = selection_start
    var old_end = selection_end
    if selection_start != new_start or selection_end != new_end:
        start_operation()
        apply_selection()
        selection_start = new_start
        selection_end = new_end
        if selection_start != null and selection_end != null:
            lift_selection_data()
        end_operation()
        
        if selection_start == null or selection_end == null:
            if old_start != null and old_end != null:
                var old_aabb = AABB(old_start, old_end - old_start)
                dirtify_cache_range(old_aabb)
        elif old_start != null and old_end != null:
            var old_aabb = AABB(old_start, old_end - old_start)
            var new_aabb = AABB(selection_start, selection_end - selection_start).merge(old_aabb)
            dirtify_cache_range(new_aabb)
        else:
            var aabb = AABB(selection_start, selection_end - selection_start)
            dirtify_cache_range(aabb)

func move_selection(offset : Vector3):
    if offset == Vector3():
        return
    var old_aabb = AABB(selection_start, selection_end - selection_start)
    var new_tables = {}
    for table_name in selection_data:
        var table = selection_data[table_name]
        new_tables[table_name] = {}
        for coord in table:
            new_tables[table_name][coord + offset] = table[coord]
    selection_data = new_tables
    is_dirty = true
    var new_aabb = AABB(selection_start, selection_end - selection_start).merge(old_aabb)
    dirtify_cache_range(new_aabb)

func lift_selection_data():
    selection_data = {}
    for z in range(selection_start.z, selection_end.z+1):
        for y in range(selection_start.y, selection_end.y+1):
            for x in range(selection_start.x, selection_end.x+1):
                var coord = Vector3(x, y, z).round()
                if coord in voxels:
                    if not "voxels" in selection_data:
                        selection_data["voxels"] = {}
                    selection_data.voxels[coord] = voxels[coord]
                    voxels.erase(coord)
                if coord in voxel_corners:
                    if not "voxel_corners" in selection_data:
                        selection_data["voxel_corners"] = {}
                    selection_data.voxel_corners[coord] = voxel_corners[coord]
                    voxel_corners.erase(coord)
                if coord in decals:
                    if not "decals" in selection_data:
                        selection_data["decals"] = {}
                    selection_data.decals[coord] = decals[coord]
                    decals.erase(coord)
                if coord in models:
                    if not "models" in selection_data:
                        selection_data["models"] = {}
                    selection_data.models[coord] = models[coord]
                    models.erase(coord)
    is_dirty = true

func apply_selection():
    for table_name in selection_data:
        var table = selection_data[table_name]
        if table_name == "voxels":
            for coord in table:
                voxels[coord] = table[coord]
        elif table_name == "decals":
            for coord in table:
                for dir in table[coord]:
                    if not coord in decals:
                        decals[coord] = {}
                    decals[coord][dir] = table[coord][dir]
        elif table_name == "models":
            for coord in table:
                models[coord] = table[coord]
        elif table_name == "voxel_corners":
            for coord in table:
                voxel_corners[coord] = table[coord]
    selection_data = {}
    is_dirty = true

var uv_shrink = 0.99

func transform_point_on_cube(vert : Vector3, dir : Vector3) -> Vector3:
    if dir == Vector3.UP or dir == Vector3.DOWN:
        return Transform3D.IDENTITY.looking_at(dir, Vector3.FORWARD) * (vert)
    else:
        return Transform3D.IDENTITY.looking_at(dir, Vector3.UP) * (vert)

func transform_2d_point_on_cube(vert : Vector2, dir : Vector3) -> Vector3:
    return transform_point_on_cube(Vector3(-vert.x, -vert.y, 0.0), dir)

func build_verts():
    var verts = {}
    for dir in directions:
        var new_face = []
        for vert in ref_verts:
            new_face.push_back(transform_point_on_cube(vert, dir))
        verts[dir] = new_face
    return verts



func generate_bitmask_dirs_by_dir():
    var dirs = {}
    for dir in directions:
        var these_dirs = bitmask_dirs.duplicate()
        for binding in these_dirs:
            these_dirs[binding] = transform_2d_point_on_cube(these_dirs[binding], dir)
        dirs[dir] = these_dirs
    return dirs

var bitmask_dirs_by_dir = generate_bitmask_dirs_by_dir()

func get_bitmask_bit(tile : Vector2, which : int, pool : Array):
    var bit = tile * 3
    @warning_ignore("integer_division")
    var stride = pool.size() / 3 / 3 / 4
    if which == BIND_BOTTOM or which == BIND_BOTTOMLEFT or which == BIND_BOTTOMRIGHT:
        bit.y += 2
    elif which == BIND_CENTER or which == BIND_LEFT or which == BIND_RIGHT:
        bit.y += 1
    if which == BIND_RIGHT or which == BIND_BOTTOMRIGHT or which == BIND_TOPRIGHT:
        bit.x += 2
    elif which == BIND_CENTER or which == BIND_BOTTOM or which == BIND_TOP:
        bit.x += 1
    return pool[bit.x + bit.y*stride*3]


func get_tile_bitmask_12x4(tile : Vector2):
    var bitmask = 0
    for bit in bitmask_bindings:
        if get_bitmask_bit(tile, bit, bitmask_stuff_12x4):
            bitmask |= bit
    return bitmask

func build_uvs_12x4():
    var uvs = {}
    for y in range(4):
        for x in range(12):
            uvs[get_tile_bitmask_12x4(Vector2(x, y))] = Vector2(x, y)
    return uvs

func get_tile_bitmask_4x4(tile : Vector2):
    var bitmask = 0
    for bit in bitmask_bindings:
        if get_bitmask_bit(tile, bit, bitmask_stuff_4x4):
            bitmask |= bit
    return bitmask

func build_uvs_4x4():
    var uvs = {}
    for y in range(4):
        for x in range(4):
            uvs[get_tile_bitmask_4x4(Vector2(x, y))] = Vector2(x, y)
    return uvs

func get_decal_uv_scale(i : int) -> Transform2D:
    var ret : Transform2D = Transform2D.IDENTITY
    
    var trans = Transform2D(0, Vector2(-0.5, -0.5))
    ret = trans * ret
    if i >= 4:
        ret = ret.scaled(Vector2(-1, 1))
    ret = ret.rotated(PI*0.5 * (i%4))
    ret = trans.affine_inverse() * ret
    
    return ret

func place_decal(p_position : Vector3, dir : Vector3, material : VoxEditor.DecalMat, scale_id : int):
    p_position = p_position.round()
    if not p_position in decals:
        decals[p_position] = {}
    
    decals[p_position] = decals[p_position].duplicate(false)
    decals[p_position][dir] = [material, material.current_coord, scale_id%8]
    is_dirty = true

func erase_decal(p_position : Vector3, dir : Vector3):
    p_position = p_position.round()
    if p_position in decals:
        decals[p_position] = decals[p_position].duplicate(false)
        decals[p_position].erase(dir.round())
        if decals[p_position].size() == 0:
            decals.erase(p_position)
    
    is_dirty = true

func place_model(p_position : Vector3, material : VoxEditor.DecalMat, mode_id : int, floor_mode : int, offset_x : int, offset_y : int, offset_z : int):
    p_position = p_position.round()
    if not p_position in models:
        models[p_position] = {}
    
    models[p_position] = [material, material.current_coord, mode_id, floor_mode, offset_x, offset_y, offset_z]
    is_dirty = true

func erase_model(p_position : Vector3):
    models.erase(p_position.round())
    is_dirty = true

func place_voxel(p_position : Vector3, material : VoxEditor.VoxMat, ramp_corners = {}):
    p_position = p_position.round()
    voxels[p_position] = material
    if ramp_corners.size() > 0:
        voxel_corners[p_position] = ramp_corners.duplicate(true)
    elif voxel_corners.has(p_position):
        voxel_corners.erase(p_position)
    is_dirty = true
    
    dirtify_cache(p_position)

func erase_voxel(p_position : Vector3):
    if voxels.size() <= 1:
        print("can't erase the last voxel!")
        return
    voxels.erase(p_position.round())
    if voxel_corners.has(p_position.round()):
        voxel_corners.erase(p_position.round())
    is_dirty = true
    
    dirtify_cache(p_position)

func dirtify_at_exact(pos : Vector3):
    for dir in directions:
        var key = [pos, dir]
        if key in uv_data_cache:
            uv_data_cache.erase(key)
        if key in voxel_data_cache:
            voxel_data_cache.erase(key)

func dirtify_cache(p_position : Vector3):
    for z in [-1, 0, 1]:
        for y in [-1, 0, 1]:
            for x in [-1, 0, 1]:
                var pos = (p_position + Vector3(x, y, z)).round()
                dirtify_at_exact(pos)

func dirtify_cache_range(position_range : AABB):
    position_range = position_range.grow(2.0)
    var start = position_range.position
    var end = position_range.end + Vector3.ONE
    for pos_z in range(start.z, end.z):
        for pos_y in range(start.y, end.y):
            for pos_x in range(start.x, end.x):
                dirtify_at_exact(Vector3(pos_x, pos_y, pos_z))

func face_is_shifted(pos, face_normal):
    if !has_voxel_corner(pos):
        return false
    for corner in get_voxel_corner(pos):
        if corner.dot(face_normal) > 0.0:
            return true
    return false

func face_is_disconnected(pos, face_normal, test_dir):
    if !has_voxel_corner(pos):
        return false
    for corner in get_voxel_corner(pos):
        if corner.dot(test_dir) > 0.0:
            var new = get_voxel_corner(pos)[corner]
            var offset = new - corner
            if (offset * face_normal).length_squared() == 0.0:
                return true
    return false


func get_effective_vert(pos, vert):
    if !has_voxel_corner(pos):
        return vert
    for corner in get_voxel_corner(pos):
        if vert.round() == corner:
            return get_voxel_corner(pos)[corner]
    return vert

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

func matching_edges_match(pos, next_pos, dir):
    var axis = next_pos - pos
    var cross = axis.cross(dir)
    
    if axis.length() > 1:
        # diagonal case
        var near_a = pos + get_effective_vert(pos, dir + axis)
        var far_a = next_pos + get_effective_vert(next_pos, dir - axis) + axis
        
        if not near_a.distance_squared_to(far_a) < 0.001:
            return false
        
        var axis_a = axialize(axis)
        var axis_b = axis - axis_a
        if not matching_edges_match(pos + axis_a, next_pos, dir):
            return false
        if not matching_edges_match(pos + axis_b, next_pos, dir):
            return false
        return true
    else:
        # axial case
        var near_a = get_effective_vert(pos, dir + axis + cross)
        var near_b = get_effective_vert(pos, dir + axis - cross)
        var far_a = get_effective_vert(next_pos, dir - axis + cross) + axis*2.0
        var far_b = get_effective_vert(next_pos, dir - axis - cross) + axis*2.0
        
        return near_a.distance_squared_to(far_a) < 0.001 and near_b.distance_squared_to(far_b) < 0.001
    
var uv_data_cache = {}
var voxel_data_cache = {}

func full_remesh():
    uv_data_cache = {}
    voxel_data_cache = {}
    refresh_surface_mapping()
    remesh()

func hinted_remesh():
    refresh_surface_mapping()
    remesh()

func undistort_array_quads(verts, tex_uvs, normals, indexes):
    var old_indexes = indexes
    indexes = PackedInt32Array()
    var i = 0
    var face_count = 0
    while i < verts.size():
        var a = (verts[i + 0] + verts[i + 3])/2.0
        var b = (verts[i + 1] + verts[i + 2])/2.0
        if a.distance_to(b) > 0.1:
            var vert_sum = verts[i + 0] + verts[i + 1] + verts[i + 2] + verts[i + 3]
            verts.insert(i + 4, vert_sum / 4.0)
            var uv_sum = tex_uvs[i + 0] + tex_uvs[i + 1] + tex_uvs[i + 2] + tex_uvs[i + 3]
            tex_uvs.insert(i + 4, uv_sum / 4.0)
            var normal_sum = normals[i + 0] + normals[i + 1] + normals[i + 2] + normals[i + 3]
            normals.insert(i + 4, (normal_sum / 4.0).normalized())
            for v in [[0, 1, 4], [1, 3, 4], [3, 2, 4], [2, 0, 4]]:
                indexes.push_back(i + v[0])
                indexes.push_back(i + v[1])
                indexes.push_back(i + v[2])
            i += 5
        else:
            var diff = i - face_count*4
            for j in 6:
                indexes.push_back(old_indexes[face_count*6 + j] + diff)
            i += 4
        face_count += 1
    return indexes

func add_decals(p_mesh):
    for mat in decals_by_mat.keys():
        var texture = mat.tex
        var tex_size = texture.get_size()
        var grid_size = mat.grid_size
        
        var material = StandardMaterial3D.new()
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        material.roughness = 1.0
        material.diffuse_mode = StandardMaterial3D.DIFFUSE_LAMBERT
        material.albedo_texture = texture
        material.params_use_alpha_scissor = true
        
        var verts = PackedVector3Array()
        var tex_uvs = PackedVector2Array()
        var normals = PackedVector3Array()
        var indexes = PackedInt32Array()
        
        for decal in decals_by_mat[mat]:
            var pos = decal[0]
            var dir = decal[1]
            
            var decal_data = get_decal(pos, dir)
            var tile_coord = decal_data[1]
            var orientation_id = decal_data[2]
            var uv_xform = get_decal_uv_scale(orientation_id)
            #print(uv_xform)
            #print(orientation_id)
            
            var unit_uv = grid_size/tex_size
            var uvs = ref_uvs.duplicate()
            
            var index_base = verts.size()
            
            var vox_corners = get_voxel_corner(pos) if has_voxel_corner(pos) else {}
            
            for i in range(uvs.size()):
                uvs[i] = uv_xform * (uvs[i])
                uvs[i].x = lerp(0.5, uvs[i].x, uv_shrink)
                uvs[i].y = lerp(0.5, uvs[i].y, uv_shrink)
                uvs[i].y = 1.0-uvs[i].y
                uvs[i] *= unit_uv
                uvs[i] += (tile_coord*grid_size)/tex_size
            
            var normal = dir
            var order = [0, 1, 2, 2, 1, 3]
            if vox_corners.size() > 0:
                var temp = []
                for i in [0, 1, 2, 3]:
                    var vert = dir_verts[dir][i]
                    
                    var b = (vert*2.0).round()
                    if b in vox_corners:
                        vert = vox_corners[b]/2.0
                    
                    temp.push_back(vert)
                
                var dist_a = temp[0].distance_squared_to(temp[3])
                var dist_b = temp[1].distance_squared_to(temp[2])
                
                if dist_b > dist_a:
                    order = [0, 1, 3, 3, 2, 0]
                
                normal = -(temp[3] - temp[0]).cross(temp[2] - temp[1])
            
            for i in [0, 1, 2, 3]:
                tex_uvs.push_back(uvs[i])
                var vert = dir_verts[dir][i]
                 
                var b = (vert*2.0).round()
                if b in vox_corners:
                    vert = vox_corners[b]/2.0
                
                verts.push_back(vert + pos + normal*0.0005)
                normals.push_back(normal)
                
            for i in order:
                indexes.push_back(i + index_base)
        
        if editor.low_distortion_meshing:
            indexes = undistort_array_quads(verts, tex_uvs, normals, indexes)
        
        var arrays = []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = verts
        arrays[Mesh.ARRAY_TEX_UV] = tex_uvs
        arrays[Mesh.ARRAY_NORMAL] = normals
        arrays[Mesh.ARRAY_INDEX]  = indexes
        if arrays[Mesh.ARRAY_VERTEX].size() > 0:
            p_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            p_mesh.surface_set_material(p_mesh.get_surface_count() - 1, material)

func _add_model_quad(verts, uvs, normals, normal_sign = 1.0, angle = 0.0, x_scale = 1.0, z_offset = 0.0):
    for i in [0, 1, 2, 3]:
        uvs.push_back(Vector2(1.0 - ref_uvs[i].x, ref_uvs[i].y))
        
        var vert : Vector3 = ref_verts[i] * Vector3(x_scale, 1, z_offset)
        var normal : Vector3 = Vector3(0, 0, -1) * normal_sign
        vert = vert.rotated(Vector3.UP, angle)
        normal = normal.rotated(Vector3.FORWARD, angle)
        
        verts.push_back(vert)
        normals.push_back(normal)

func model_get_verts_etc(mode_id : int):
    var verts = []
    var uvs = []
    var normals = []
    var indexes = []
    
    var widen = mode_id & 1
    var spacing = (mode_id >> 1) & 7
    var turns = ((mode_id >> 4) & 3) + 1
    #var rot_x = ((mode_id >> 6) & 7)
    #var rot_y = ((mode_id >> 9) & 7)
    #var rot_z = ((mode_id >> 12) & 7)
    
    var width = 1.0 if !widen else sqrt(2.0)
    var current_angle = 0.0# + rot_y * PI*0.25
    for _turn in turns:
        var base = verts.size()
        _add_model_quad(verts, uvs, normals, 1.0, current_angle, width, spacing * 0.25 * 0.998)
        for i in [0, 1, 2, 2, 1, 3]:
            indexes.push_back(i + base)
        
        if spacing > 0:
            base = verts.size()
            _add_model_quad(verts, uvs, normals, 1.0, current_angle, width, -spacing * 0.25 * 0.998)
            for i in [0, 1, 2, 2, 1, 3]:
                indexes.push_back(i + base)
        
        current_angle += PI / float(turns)
    
    return [verts, uvs, normals, indexes]

func add_models(p_mesh):
    for mat in models_by_mat.keys():
        var texture = mat.tex
        var tex_size = texture.get_size()
        var grid_size = mat.grid_size
        
        var material = StandardMaterial3D.new()
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        material.roughness = 1.0
        material.diffuse_mode = StandardMaterial3D.DIFFUSE_LAMBERT
        material.albedo_texture = texture
        material.params_use_alpha_scissor = true
        material.params_cull_mode = StandardMaterial3D.CULL_DISABLED
        
        var verts = PackedVector3Array()
        var tex_uvs = PackedVector2Array()
        var normals = PackedVector3Array()
        var indexes = PackedInt32Array()
        
        for model in models_by_mat[mat]:
            var pos = model
            var model_data = get_model(pos)
            var tile_coord = model_data[1]
            var mode_id = model_data[2]
            var floor_mode = model_data[3]
            var offset_x = model_data[4]
            #var offset_y = model_data[5]
            var offset_z = model_data[6]
            
            var unit_uv = grid_size/tex_size
            #var uvs = ref_uvs.duplicate()
            
            var index_base = verts.size()
            
            var below = pos + Vector3(0, -1, 0)
            var vox_corners = get_voxel_corner(below) if has_voxel_corner(below) else {}
            
            var pure_offset = Vector3()
            var normal = Vector3.UP
            var orthogonal = Vector3.FORWARD
            if (floor_mode == 1 or floor_mode == 2) and vox_corners.size() > 0:
                var corners = top_corners.duplicate()
                for i in 4:
                    corners[i] = get_effective_vert(below, corners[i]*2.0)
                
                var dist_a = (corners[0] - corners[3]).length()
                var dist_b = (corners[1] - corners[2]).length()
                var mid = ((corners[0] + corners[3]) if dist_b > dist_a else (corners[1] + corners[2]))/2.0
                
                if floor_mode == 2:
                    normal = (-(corners[3] - corners[0]).cross(corners[2] - corners[1])).normalized()
                    
                    # front and right vectors, which might be skew
                    var tx_a : Vector3 = (corners[0] + corners[1] - corners[2] - corners[3]).normalized()
                    var tx_b : Vector3 = (corners[0] + corners[2] - corners[1] - corners[3]).normalized()
                    # diagonals of those two vectors, which will not be skew
                    var dx_a : Vector3 = (tx_a + tx_b).normalized()
                    var dx_b : Vector3 = (tx_a - tx_b).normalized()
                    # diagonal of those diagonals, which will not be skew
                    orthogonal = (dx_a + dx_b).normalized()
                    # (the normalizations are responsible for this working properly)
                
                pure_offset = mid * 0.5 - Vector3(0, 0.5, 0)
            
            var corners = top_corners.duplicate()
            if floor_mode == 3:
                for i in 4:
                    corners[i] -= get_effective_vert(below, corners[i]*2.0) * 0.5
            for i in corners.size():
                corners[i] *= Vector3(1.0, 1.0, 1.0)
            
            pure_offset.x += offset_x / 8.0 * 0.998
            pure_offset.z += offset_z / 8.0 * 0.998
            
            var rot_x = float((mode_id >> 6) & 7) / 4.0 * PI
            var rot_y = float((mode_id >> 9) & 7) / 4.0 * PI
            var rot_z = float((mode_id >> 12) & 7) / 4.0 * PI
            
            var bitangent = orthogonal.cross(normal)
            var rot : Transform3D = Transform3D(Basis(bitangent, normal, orthogonal), Vector3())
            var rot2 : Transform3D = Transform3D(Basis.from_euler(Vector3(rot_x, rot_y, rot_z)), Vector3())
            var xform : Transform3D = Transform3D.IDENTITY
            xform = xform * Transform3D(Basis.IDENTITY, Vector3(0, -0.5, 0))
            xform = xform * rot
            xform = xform * rot2
            xform = xform * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0))
            
            var stuff = model_get_verts_etc(mode_id)
            
            #print(corners)
            
            var verts_temp = []
            for i in stuff[0].size():
                var uv = stuff[1][i]
                
                uv.x = lerp(0.5, uv.x, uv_shrink)
                uv.y = lerp(0.5, uv.y, uv_shrink)
                uv.y = 1.0-uv.y
                uv *= unit_uv
                uv += (tile_coord*grid_size)/tex_size
                
                var vert = stuff[0][i]
                vert = xform * vert
                if floor_mode == 3:
                    var t_x = vert.x + 0.5
                    var t_z = vert.z + 0.5
                    var x_a = lerp(corners[0], corners[1], t_x)
                    var x_b = lerp(corners[2], corners[3], t_x)
                    var vert_offset = lerp(x_a, x_b, t_z)
                    #print(vert, vert_offset)
                    vert -= vert_offset
                vert = vert + pos + pure_offset
                verts_temp.push_back(vert)
                verts.push_back(vert)
                tex_uvs.push_back(uv)
            
            for i in verts_temp.size():
                @warning_ignore("integer_division")
                var a = verts_temp[i/4*4 + 0] - verts_temp[i/4*4 + 3]
                @warning_ignore("integer_division")
                var b = verts_temp[i/4*4 + 1] - verts_temp[i/4*4 + 2]
                var model_normal = -a.cross(b).normalized()
                normals.push_back(model_normal)
            
            for i in stuff[3].size():
                indexes.push_back(stuff[3][i] + index_base)
            
        var arrays = []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = verts
        arrays[Mesh.ARRAY_TEX_UV] = tex_uvs
        arrays[Mesh.ARRAY_NORMAL] = normals
        arrays[Mesh.ARRAY_INDEX]  = indexes
        if arrays[Mesh.ARRAY_VERTEX].size() > 0:
            p_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            p_mesh.surface_set_material(p_mesh.get_surface_count() - 1, material)

func add_voxels(p_mesh):
    var face_tex = []
    for mat in voxels_by_mat.keys():
        face_tex.push_back([[mat.sides, mat], "side", voxels_by_mat[mat]])
        face_tex.push_back([[mat.top, mat], "top", voxels_by_mat[mat]])
        face_tex.push_back([[mat.bottom, mat], "bottom", voxels_by_mat[mat]])
    
    for info in face_tex:
        var texture = info[0][0]
        var mat : VoxEditor.VoxMat = info[0][1]
        
        var material = StandardMaterial3D.new()
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        material.roughness = 1.0
        material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
        material.albedo_texture = texture
        
        if mat.transparent_mode == 1:
            material.params_use_alpha_scissor = true
        elif mat.transparent_mode == 2:
            material.flags_transparent = true
        
        var dirs = []
        if info[1] == "side":
            dirs = sides.duplicate()
        elif info[1] == "top":
            dirs = [Vector3.UP]
        else:
            dirs = [Vector3.DOWN]
        
        var verts = PackedVector3Array()
        var tex_uvs = PackedVector2Array()
        var normals = PackedVector3Array()
        var indexes = PackedInt32Array()
        
        var is_side = info[1]
        
        var list = info[2]
        
        var start = Time.get_ticks_usec()
        
        for pos in list:
            var found_cache = false
            for dir in dirs:
                var key = [pos, dir]
                if key in voxel_data_cache:
                    found_cache = true
                    if voxel_data_cache[key] != null:
                        var data = voxel_data_cache[key]
                        var self_verts = data[0]
                        var self_normals = data[1]
                        var self_tex_uvs = data[2]
                        var self_indexes = data[3]
                        
                        var index_base = verts.size()
                        
                        verts.append_array(self_verts)
                        normals.append_array(self_normals)
                        tex_uvs.append_array(self_tex_uvs)
                        
                        for val in self_indexes:
                            indexes.push_back(val + index_base)
            
            if found_cache:
                continue
            
            var vox = get_voxel(pos)
            var vox_corners = get_voxel_corner(pos) if has_voxel_corner(pos) else {}
            for dir in dirs:
                var cache_key = [pos, dir]
                if occluding_face_exists(pos, pos+dir, vox):
                    voxel_data_cache[cache_key] = null
                    continue
                
                var uvs : Array[Vector2] = []
                if cache_key in uv_data_cache:
                    uvs = uv_data_cache[cache_key]
                else:
                    uvs = ref_uvs.duplicate()
                    var bitmask = 0
                    
                    for bit in bitmask_bindings:
                        var test_dir = bitmask_dirs_by_dir[dir][bit]
                        if test_dir == Vector3():
                            continue
                        var neighbor_pos = pos + test_dir
                        var neighbor = get_voxel(neighbor_pos)
                        var neighbor_test = neighbor and (neighbor.sides if is_side else neighbor.top) == (vox.sides if is_side else vox.top)
                        
                        var is_match = false
                        if neighbor_test:
                            is_match = matching_edges_match(pos, neighbor_pos, dir)
                        
                        if neighbor_test and is_match:
                            bitmask |= bit
                        if get_voxel(neighbor_pos + dir) and occluding_face_exists(neighbor_pos, neighbor_pos + dir, vox):
                            bitmask &= ~bit
                    
                    bitmask |= BIND_CENTER
                    
                    var smart_bind_sets = {
                        BIND_TOPLEFT     : BIND_TOP    | BIND_LEFT,
                        BIND_TOPRIGHT    : BIND_TOP    | BIND_RIGHT,
                        BIND_BOTTOMLEFT  : BIND_BOTTOM | BIND_LEFT,
                        BIND_BOTTOMRIGHT : BIND_BOTTOM | BIND_RIGHT,
                    }
                    for bind in smart_bind_sets.keys():
                        var other = smart_bind_sets[bind]
                        # disable corner if either edge disabled
                        if bitmask & other != other:
                            bitmask &= ~bind
                        # enable corner if both edges enabled and 4x4 mode
                        if mat.tiling_mode == VoxEditor.VoxMat.TileMode.MODE_4x4:
                            if bitmask & other == other:
                                bitmask |= bind
                    
                    for i in range(uvs.size()):
                        uvs[i].x = lerp(0.5, uvs[i].x, uv_shrink)
                        uvs[i].y = lerp(0.5, uvs[i].y, uv_shrink)
                        
                        uvs[i].y = 1.0-uvs[i].y
                        
                        if mat.tiling_mode == VoxEditor.VoxMat.TileMode.MODE_12x4:
                            if bitmask in bitmask_uvs_12x4:
                                uvs[i] += bitmask_uvs_12x4[bitmask]
                            else:
                                uvs[i] += bitmask_uvs_12x4[BIND_CENTER]
                            uvs[i] = Vector2(1.0/12.0, 1/4.0) * uvs[i]
                        elif mat.tiling_mode == VoxEditor.VoxMat.TileMode.MODE_4x4:
                            if bitmask in bitmask_uvs_4x4:
                                uvs[i] += bitmask_uvs_4x4[bitmask]
                            else:
                                uvs[i] += bitmask_uvs_4x4[BIND_CENTER]
                            uvs[i] = Vector2(1.0/4.0, 1/4.0) * uvs[i]
                        
                        uvs[i] /= mat.subdivide_amount
                        uvs[i] += mat.subdivide_coord/mat.subdivide_amount
                    
                    uv_data_cache[cache_key] = uvs
                
                # swap triangulation order if we're warped and need to swap to connect-shortest
                # also recalculate normal for warped faces
                var normal = dir
                var order = [0, 1, 2, 2, 1, 3]
                if vox_corners.size() > 0:
                    var temp = []
                    for i in [0, 1, 2, 3]:
                        var vert = dir_verts[dir][i]
                        
                        var b = (vert*2.0).round()
                        if b in vox_corners:
                            vert = vox_corners[b]/2.0
                        
                        temp.push_back(vert)
                    
                    var dist_a = temp[0].distance_squared_to(temp[3])
                    var dist_b = temp[1].distance_squared_to(temp[2])
                    
                    if dist_b > dist_a:
                        order = [0, 1, 3, 3, 2, 0]
                    
                    normal = -(temp[3] - temp[0]).cross(temp[2] - temp[1])
                
                var index_base = verts.size()
                
                var self_verts = PackedVector3Array()
                var self_tex_uvs = PackedVector2Array()
                var self_normals = PackedVector3Array()
                var self_indexes = PackedInt32Array()
                
                for i in [0, 1, 2, 3]:
                    var uv = uvs[i]
                    var vert = dir_verts[dir][i]
                    
                    var b = (vert*2.0).round()
                    if b in vox_corners:
                        vert = vox_corners[b]/2.0
                    
                    if mat.tiling_mode == VoxEditor.VoxMat.TileMode.MODE_1x1_WORLD:
                        if dir.abs() == Vector3.UP:
                            uv = Vector2(vert.x, vert.z) + Vector2(0.5, 0.5)
                        elif dir.abs() == Vector3.RIGHT:
                            uv = Vector2(vert.z * -sign(dir.x), -vert.y) + Vector2(0.5, 0.5)
                        else:
                            uv = Vector2(vert.x * sign(dir.z), -vert.y) + Vector2(0.5, 0.5)
                        
                        uv.x = lerp(0.5, uv.x, uv_shrink)
                        uv.y = lerp(0.5, uv.y, uv_shrink)
                        
                        if dir.abs() == Vector3.UP:
                            uv -= Vector2(pos.x, pos.z)
                        elif dir.abs() == Vector3.RIGHT:
                            uv -= Vector2(pos.z * -sign(dir.x), -pos.y)
                        else:
                            uv -= Vector2(pos.x * sign(dir.z), -pos.y)
                        
                        uv /= mat.subdivide_amount
                        uv += mat.subdivide_coord/mat.subdivide_amount
                    
                    self_verts.push_back(vert + pos)
                    self_normals.push_back(normal)
                    self_tex_uvs.push_back(uv)
                
                verts.append_array(self_verts)
                normals.append_array(self_normals)
                tex_uvs.append_array(self_tex_uvs)
                
                for i in order:
                    indexes.push_back(i + index_base)
                    self_indexes.push_back(i)
                
                voxel_data_cache[cache_key] = [self_verts, self_normals, self_tex_uvs, self_indexes]
        
        var end = Time.get_ticks_usec()
        
        if editor.low_distortion_meshing:
            indexes = undistort_array_quads(verts, tex_uvs, normals, indexes)
                    
        var arrays = []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = verts
        arrays[Mesh.ARRAY_TEX_UV] = tex_uvs
        arrays[Mesh.ARRAY_NORMAL] = normals
        arrays[Mesh.ARRAY_INDEX]  = indexes
        if arrays[Mesh.ARRAY_VERTEX].size() > 0:
            p_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            p_mesh.surface_set_material(p_mesh.get_surface_count() - 1, material)
        
        var time = (end-start)/1000000.0
        if time > 0.01:
            print("dummy  time: ", time)
    

func remesh():
    mesh = ArrayMesh.new()
    
    add_decals(mesh)
    add_models(mesh)
    add_voxels(mesh)
