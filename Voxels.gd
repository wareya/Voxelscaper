tool
extends MeshInstance

onready var editor = get_tree().get_nodes_in_group("VoxEditor")[0]

onready var voxels = {Vector3(0, 0, 0) : editor.get_default_voxmat()}

onready var voxel_corners = {   
}

func structify():
    var save_voxels = {}
    var mats = {}
    var save_mats = {}
    var mat_counter = 0
    for coord in voxels:
        var save_coord = [coord.x, coord.y, coord.z]
        var mat = voxels[coord]
        if not mat in mats:
            mats[mat] = mat_counter
            save_mats[mat_counter] = mat.encode()
            mat_counter += 1
        save_voxels[save_coord] = mats[mat]
    
    pass

func _ready():
    refresh_surface_mapping()
    remesh()

var is_dirty = false
func _process(delta):
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

func place_voxel(position : Vector3, material : VoxEditor.VoxMat, ramp_corners = []):
    voxels[position.round()] = material
    if ramp_corners.size() > 0:
        voxel_corners[position.round()] = ramp_corners.duplicate(true)
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

func remesh():
    mesh = ArrayMesh.new()
    
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
    
    #var owner = $StaticBody.get_shape_owners()[0]
    #$StaticBody.shape_owner_clear_shapes(owner)
    #$StaticBody.shape_owner_add_shape(owner, mesh.create_trimesh_shape())
