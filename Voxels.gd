tool
extends MeshInstance

func vec_to_array(vec : Vector3) -> Array:
    return [vec.x, vec.y, vec.z]

func array_to_vec(array : Array) -> Vector3:
    return Vector3(array[0], array[1], array[2])

onready var editor = get_tree().get_nodes_in_group("VoxEditor")[0]

onready var voxels = {Vector3(0, 0, 0) : editor.get_default_voxmat()}

onready var decals = {}
onready var models = {}

onready var voxel_corners = {
}

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
    
    redo_buffer.push_back(info)
    full_remesh()

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
    
    undo_buffer.push_back(info)
    full_remesh()

var temp_world = {}
var operation_active = false
func start_operation():
    temp_world["voxels"] = voxels.duplicate(false)
    temp_world["decals"] = decals.duplicate(false)
    temp_world["models"] = models.duplicate(false)
    temp_world["voxel_corners"] = voxel_corners.duplicate(false)
    operation_active = true

func end_operation():
    if !operation_active:
        return
    
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
    
    if changed.size() > 0:
        undo_buffer.push_back(changed)
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
        
        var start = OS.get_ticks_usec()
        refresh_surface_mapping()
        var end = OS.get_ticks_usec()
        
        var time = (end-start)/1000000.0
        if time > 0.1:
            print("refresh time: ", time)
        
        start = OS.get_ticks_usec()
        remesh()
        end = OS.get_ticks_usec()
        
        time = (end-start)/1000000.0
        if time > 0.1:
            print("remesh time: ", time)

var directions = [
    Vector3.UP,
    Vector3.DOWN,
    Vector3.LEFT,
    Vector3.RIGHT,
    Vector3.FORWARD,
    Vector3.BACK,
]
var sides = [
    Vector3.LEFT,
    Vector3.RIGHT,
    Vector3.FORWARD,
    Vector3.BACK,
]
var unsides = [
    Vector3.UP,
    Vector3.DOWN,
]

var decals_by_mat = {}
var models_by_mat = {}

var voxels_by_sides = {}
var voxels_by_top   = {}
func refresh_surface_mapping():
    voxels_by_sides = {}
    voxels_by_top   = {}
    for pos in voxels.keys():
        var vox = voxels[pos]
        if not voxels_by_sides.has(vox.sides):
            voxels_by_sides[vox.sides] = []
        voxels_by_sides[vox.sides].push_back(pos)
        
        if not voxels_by_top.has(vox.top):
            voxels_by_top[vox.top] = []
        voxels_by_top[vox.top].push_back(pos)
    
    decals_by_mat = {}
    for pos in decals.keys():
        for dir in decals[pos].keys():
            var decal = decals[pos][dir][0]
            if not decals_by_mat.has(decal):
                decals_by_mat[decal] = []
        
            decals_by_mat[decal].push_back([pos, dir])
    
    models_by_mat = {}
    for pos in models.keys():
        var mat = models[pos][0]
        if not models_by_mat.has(mat):
            models_by_mat[mat] = []
        
        models_by_mat[mat].push_back(pos)

var ref_verts = [
    Vector3(-0.5, -0.5, -0.5),
    Vector3( 0.5, -0.5, -0.5),
    Vector3(-0.5,  0.5, -0.5),
    Vector3( 0.5,  0.5, -0.5),
]

var ref_uvs = [
    Vector2(1.0, 0.0),
    Vector2(0.0, 0.0),
    Vector2(1.0, 1.0),
    Vector2(0.0, 1.0),
]

var uv_shrink = 0.99

func transform_point_on_cube(vert : Vector3, dir : Vector3) -> Vector3:
    if dir == Vector3.UP or dir == Vector3.DOWN:
        return Transform.IDENTITY.looking_at(dir, Vector3.FORWARD).xform(vert)
    else:
        return Transform.IDENTITY.looking_at(dir, Vector3.UP).xform(vert)

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

var dir_verts = build_verts()


var bitmask_stuff = [
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

func get_bitmask_bit(tile : Vector2, which : int):
    var bit = tile * 3
    if which == TileSet.BIND_BOTTOM or which == TileSet.BIND_BOTTOMLEFT or which == TileSet.BIND_BOTTOMRIGHT:
        bit.y += 2
    elif which == TileSet.BIND_CENTER or which == TileSet.BIND_LEFT or which == TileSet.BIND_RIGHT:
        bit.y += 1
    if which == TileSet.BIND_RIGHT or which == TileSet.BIND_BOTTOMRIGHT or which == TileSet.BIND_TOPRIGHT:
        bit.x += 2
    elif which == TileSet.BIND_CENTER or which == TileSet.BIND_BOTTOM or which == TileSet.BIND_TOP:
        bit.x += 1
    return bitmask_stuff[bit.x + bit.y*12*3]

const bitmask_bindings = [1, 2, 4, 8, 16, 32, 64, 128, 256]

var bitmask_dirs = {
    TileSet.BIND_TOPLEFT     : Vector2(-1, -1),
    TileSet.BIND_LEFT        : Vector2(-1,  0),
    TileSet.BIND_BOTTOMLEFT  : Vector2(-1,  1),
    
    TileSet.BIND_TOP         : Vector2( 0, -1),
    TileSet.BIND_CENTER      : Vector2( 0,  0),
    TileSet.BIND_BOTTOM      : Vector2( 0,  1),
    
    TileSet.BIND_TOPRIGHT    : Vector2( 1, -1),
    TileSet.BIND_RIGHT       : Vector2( 1,  0),
    TileSet.BIND_BOTTOMRIGHT : Vector2( 1,  1),
}

func generate_bitmask_dirs_by_dir():
    var dirs = {}
    for dir in directions:
        var these_dirs = bitmask_dirs.duplicate()
        for binding in these_dirs:
            these_dirs[binding] = transform_2d_point_on_cube(these_dirs[binding], dir)
        dirs[dir] = these_dirs
    return dirs

var bitmask_dirs_by_dir = generate_bitmask_dirs_by_dir()

func get_tile_bitmask(tile : Vector2):
    var bitmask = 0
    for bit in bitmask_bindings:
        if get_bitmask_bit(tile, bit):
            bitmask |= bit
    return bitmask

func build_uvs():
    var uvs = {}
    for y in range(4):
        for x in range(12):
            uvs[get_tile_bitmask(Vector2(x, y))] = Vector2(x, y)
    return uvs

var bitmask_uvs = build_uvs()

func get_decal_uv_scale(i : int) -> Transform2D:
    var ret : Transform2D = Transform2D.IDENTITY
    
    var trans = Transform2D(0, Vector2(-0.5, -0.5))
    ret = trans * ret
    if i >= 4:
        ret = ret.scaled(Vector2(-1, 1))
    ret = ret.rotated(PI*0.5 * (i%4))
    ret = trans.affine_inverse() * ret
    
    return ret

func place_decal(position : Vector3, dir : Vector3, material : VoxEditor.DecalMat, scale_id : int):
    position = position.round()
    if not position in decals:
        decals[position] = {}
    
    decals[position] = decals[position].duplicate(false)
    decals[position][dir] = [material, material.current_coord, scale_id%8]
    is_dirty = true

func erase_decal(position : Vector3, dir : Vector3):
    position = position.round()
    if position in decals:
        decals[position].erase(dir.round())
        if decals[position].size() == 0:
            decals.erase(position)
    
    is_dirty = true

func place_model(position : Vector3, material : VoxEditor.DecalMat, mode_id : int, floor_mode : int, offset_x : int, offset_y : int, offset_z : int):
    position = position.round()
    if not position in models:
        models[position] = {}
    
    models[position] = [material, material.current_coord, mode_id, floor_mode, offset_x, offset_y, offset_z]
    is_dirty = true

func erase_model(position : Vector3):
    models.erase(position.round())
    is_dirty = true

func place_voxel(position : Vector3, material : VoxEditor.VoxMat, ramp_corners = []):
    position = position.round()
    voxels[position] = material
    if ramp_corners.size() > 0:
        voxel_corners[position] = ramp_corners.duplicate(true)
    elif voxel_corners.has(position):
        voxel_corners.erase(position)
    is_dirty = true
    
    dirtify_bitmask(position)

func erase_voxel(position : Vector3):
    if voxels.size() <= 1:
        print("can't erase the last voxel!")
        return
    voxels.erase(position.round())
    if voxel_corners.has(position.round()):
        voxel_corners.erase(position.round())
    is_dirty = true
    
    dirtify_bitmask(position)

func dirtify_bitmask(position : Vector3):
    for z in [-1, 0, 1]:
        for y in [-1, 0, 1]:
            for x in [-1, 0, 1]:
                var key = (position + Vector3(x, y, z)).round()
                if key in uv_data_cache:
                    uv_data_cache.erase(key)

func face_is_shifted(pos, face_normal):
    if !pos in voxel_corners:
        return false
    for corner in voxel_corners[pos]:
        if corner.dot(face_normal) > 0.0:
            return true
    return false

func face_is_disconnected(pos, face_normal, test_dir):
    if !pos in voxel_corners:
        return false
    for corner in voxel_corners[pos]:
        # FIXME replace with actual sew test
        if corner.dot(test_dir) > 0.0:
            var new = voxel_corners[pos][corner]
            var offset = new - corner
            if (offset * face_normal).length_squared() == 0.0:
                return true
    return false

var ref_corners = [
    Vector3(-0.5, -0.5, -0.5),
    Vector3( 0.5, -0.5, -0.5),
    Vector3(-0.5,  0.5, -0.5),
    Vector3( 0.5,  0.5, -0.5),
    Vector3(-0.5, -0.5,  0.5),
    Vector3( 0.5, -0.5,  0.5),
    Vector3(-0.5,  0.5,  0.5),
    Vector3( 0.5,  0.5,  0.5),
]

var top_corners = [
    Vector3(-0.5,  0.5, -0.5),
    Vector3( 0.5,  0.5, -0.5),
    Vector3(-0.5,  0.5,  0.5),
    Vector3( 0.5,  0.5,  0.5),
]

func get_effective_vert(pos, vert):
    if !pos in voxel_corners:
        return vert
    for corner in voxel_corners[pos]:
        if vert.round() == corner:
            return voxel_corners[pos][corner]
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

func full_remesh():
    uv_data_cache = {}
    refresh_surface_mapping()
    remesh()

func add_decals(mesh):
    for mat in decals_by_mat.keys():
        var texture = mat.tex
        var tex_size = texture.get_size()
        var grid_size = mat.grid_size
        
        var material = SpatialMaterial.new()
        material.roughness = 1.0
        material.params_diffuse_mode |= SpatialMaterial.DIFFUSE_LAMBERT
        material.albedo_texture = texture
        material.params_use_alpha_scissor = true
        
        var verts = PoolVector3Array()
        var tex_uvs = PoolVector2Array()
        var normals = PoolVector3Array()
        var indexes = PoolIntArray()
        
        for decal in decals_by_mat[mat]:
            var pos = decal[0]
            var dir = decal[1]
            
            var tile_coord = decals[pos][dir][1]
            var orientation_id = decals[pos][dir][2]
            var uv_xform = get_decal_uv_scale(orientation_id)
            #print(uv_xform)
            #print(orientation_id)
            
            var unit_uv = grid_size/tex_size
            var uvs = ref_uvs.duplicate()
            
            var index_base = verts.size()
            
            var vox_corners = voxel_corners[pos] if pos in voxel_corners else []
            
            for i in range(uvs.size()):
                uvs[i] = uv_xform.xform(uvs[i])
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
            
        var arrays = []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = verts
        arrays[Mesh.ARRAY_TEX_UV] = tex_uvs
        arrays[Mesh.ARRAY_NORMAL] = normals
        arrays[Mesh.ARRAY_INDEX]  = indexes
        if arrays[Mesh.ARRAY_VERTEX].size() > 0:
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            mesh.surface_set_material(mesh.get_surface_count() - 1, material)

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

func add_models(mesh):
    for mat in models_by_mat.keys():
        var texture = mat.tex
        var tex_size = texture.get_size()
        var grid_size = mat.grid_size
        
        var material = SpatialMaterial.new()
        material.roughness = 1.0
        material.params_diffuse_mode |= SpatialMaterial.DIFFUSE_LAMBERT
        material.albedo_texture = texture
        material.params_use_alpha_scissor = true
        material.params_cull_mode = SpatialMaterial.CULL_DISABLED
        
        var verts = PoolVector3Array()
        var tex_uvs = PoolVector2Array()
        var normals = PoolVector3Array()
        var indexes = PoolIntArray()
        
        for model in models_by_mat[mat]:
            var pos = model
            var tile_coord = models[pos][1]
            var mode_id = models[pos][2]
            var floor_mode = models[pos][3]
            var offset_x = models[pos][4]
            var offset_y = models[pos][5]
            var offset_z = models[pos][6]
            
            var unit_uv = grid_size/tex_size
            var uvs = ref_uvs.duplicate()
            
            var index_base = verts.size()
            
            var below = pos + Vector3(0, -1, 0)
            var vox_corners = voxel_corners[below] if below in voxel_corners else {}
            
            var pure_offset = Vector3()
            var normal = Vector3.UP
            var tangent = Vector3.FORWARD
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
                    tangent = (dx_a + dx_b).normalized()
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
            
            var bitangent = tangent.cross(normal)
            var rot : Transform = Transform(Basis(bitangent, normal, tangent), Vector3())
            var rot2 : Transform = Transform(Basis(Vector3(rot_x, rot_y, rot_z)), Vector3())
            var xform : Transform = Transform.IDENTITY
            xform = xform * Transform(Basis.IDENTITY, Vector3(0, -0.5, 0))
            xform = xform * rot
            xform = xform * rot2
            xform = xform * Transform(Basis.IDENTITY, Vector3(0, 0.5, 0))
            
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
                var a = verts_temp[i/4*4 + 0] - verts_temp[i/4*4 + 3]
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
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            mesh.surface_set_material(mesh.get_surface_count() - 1, material)

func add_voxels(mesh):
    var face_tex = []
    for tex in voxels_by_sides.keys():
        face_tex.push_back([tex, true, voxels_by_sides[tex]])
    for tex in voxels_by_top.keys():
        face_tex.push_back([tex, false, voxels_by_top[tex]])
    
    for info in face_tex:
        var texture = info[0]
        
        var material = SpatialMaterial.new()
        material.roughness = 1.0
        material.params_diffuse_mode |= SpatialMaterial.DIFFUSE_LAMBERT
        material.albedo_texture = texture
        
        var verts = PoolVector3Array()
        var tex_uvs = PoolVector2Array()
        var normals = PoolVector3Array()
        var indexes = PoolIntArray()
        
        var is_side = info[1]
        
        var list = info[2]
        
        var start = OS.get_ticks_usec()
        
        for pos in list:
            var vox = voxels[pos]
            var vox_corners = voxel_corners[pos] if pos in voxel_corners else []
            for dir in sides if is_side else unsides:
                if voxels.has(pos+dir) and !face_is_shifted(pos+dir, -dir) and !face_is_shifted(pos, dir):
                    continue
                
                var unit_uv = Vector2(1.0/12.0, 1/4.0)
                var uvs = ref_uvs.duplicate()
                if pos in uv_data_cache and dir in uv_data_cache[pos]:
                    uvs = uv_data_cache[pos][dir]
                else:
                    var bitmask = 0
                    
                    for bit in bitmask_bindings:
                        var test_dir = bitmask_dirs_by_dir[dir][bit]
                        if test_dir == Vector3():
                            continue
                        var neighbor_pos = pos + test_dir
                        var neighbor = voxels.get(neighbor_pos)
                        var neighbor_test = neighbor and (neighbor.sides if is_side else neighbor.top) == (vox.sides if is_side else vox.top)
                        
                        var is_match = false
                        if neighbor_test:
                            is_match = matching_edges_match(pos, neighbor_pos, dir)
                        
                        if neighbor_test and is_match:
                            bitmask |= bit
                        if voxels.get(neighbor_pos + dir):
                            bitmask &= ~bit
                        # FIXME handle floor-wall transitions better if material asks for it
                    
                    bitmask |= TileSet.BIND_CENTER
                    
                    var smart_bind_sets = {
                        TileSet.BIND_TOPLEFT     : TileSet.BIND_TOP    | TileSet.BIND_LEFT,
                        TileSet.BIND_TOPRIGHT    : TileSet.BIND_TOP    | TileSet.BIND_RIGHT,
                        TileSet.BIND_BOTTOMLEFT  : TileSet.BIND_BOTTOM | TileSet.BIND_LEFT,
                        TileSet.BIND_BOTTOMRIGHT : TileSet.BIND_BOTTOM | TileSet.BIND_RIGHT,
                    }
                    for bind in smart_bind_sets.keys():
                        var other = smart_bind_sets[bind]
                        if bitmask & other != other:
                            bitmask &= ~bind
                    for i in range(uvs.size()):
                        uvs[i].x = lerp(0.5, uvs[i].x, uv_shrink)
                        uvs[i].y = lerp(0.5, uvs[i].y, uv_shrink)
                        
                        uvs[i].y = 1.0-uvs[i].y
                        
                        
                        if bitmask in bitmask_uvs:
                            uvs[i] += bitmask_uvs[bitmask]
                        else:
                            uvs[i] += bitmask_uvs[TileSet.BIND_CENTER]
                        
                        uvs[i] = unit_uv * uvs[i]
                    
                    if not pos in uv_data_cache:
                        uv_data_cache[pos] = {}
                    uv_data_cache[pos][dir] = uvs
                
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
                
                for i in [0, 1, 2, 3]:
                    tex_uvs.push_back(uvs[i])
                    var vert = dir_verts[dir][i]
                    
                    var b = (vert*2.0).round()
                    if b in vox_corners:
                        vert = vox_corners[b]/2.0
                    
                    verts.push_back(vert + pos)
                    normals.push_back(normal)
                
                for i in order:
                    indexes.push_back(i + index_base)
        
        var end = OS.get_ticks_usec()
        
        var arrays = []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = verts
        arrays[Mesh.ARRAY_TEX_UV] = tex_uvs
        arrays[Mesh.ARRAY_NORMAL] = normals
        arrays[Mesh.ARRAY_INDEX]  = indexes
        if arrays[Mesh.ARRAY_VERTEX].size() > 0:
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            mesh.surface_set_material(mesh.get_surface_count() - 1, material)
        
        var time = (end-start)/1000000.0
        if time > 0.01:
            print("dummy  time: ", time)
    

func remesh():
    mesh = ArrayMesh.new()
    
    add_decals(mesh)
    add_models(mesh)
    add_voxels(mesh)
