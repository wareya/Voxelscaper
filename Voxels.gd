tool
extends MeshInstance

onready var editor = get_tree().get_nodes_in_group("VoxEditor")[0]

onready var voxels = {
    Vector3( 0, 0,  0) : editor.get_default_voxmat(),
    Vector3( 1, 0,  0) : editor.get_default_voxmat(),
    Vector3( 1, 0,  1) : editor.get_default_voxmat(),
    Vector3( 0, 0,  1) : editor.get_default_voxmat(),
    Vector3(-1, 0,  0) : editor.get_default_voxmat(),
    Vector3(-1, 0, -1) : editor.get_default_voxmat(),
    Vector3( 0, 0, -1) : editor.get_default_voxmat(),
    Vector3(-1, 0,  1) : editor.get_default_voxmat(),
    Vector3( 1, 0, -1) : editor.get_default_voxmat(),
}

onready var voxel_corners = {   
}

func _ready():
    refresh_surface_mapping()
    remesh()

var is_dirty = false
func _process(delta):
    if is_dirty:
        is_dirty = false
        refresh_surface_mapping()
        remesh()

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

var bitmask_bindings = [1, 2, 4, 8, 16, 32, 64, 128, 256]

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
    

func erase_voxel(position : Vector3):
    if voxels.size() <= 1:
        print("can't erase the last voxel!")
        return
    voxels.erase(position.round())
    if voxel_corners.has(position.round()):
        voxel_corners.erase(position.round())
    is_dirty = true


func face_is_shifted(pos, face_normal):
    if !pos in voxel_corners:
        return false
    for corner in voxel_corners[pos]:
        if corner[0].dot(face_normal) > 0.0:
            return true
    return false

func remesh():
    #print(bitmask_uvs)
    #print(bitmask_uvs[Vector2(0, 0)])
    mesh = ArrayMesh.new()
    
    var face_tex = []
    for tex in voxels_by_sides.keys():
        face_tex.push_back([tex, true, voxels_by_sides[tex]])
    for tex in voxels_by_top.keys():
        face_tex.push_back([tex, false, voxels_by_top[tex]])
    
    for info in face_tex:
        var texture = info[0]
        var surface_builder = SurfaceTool.new()
        surface_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
        var material = SpatialMaterial.new()
        material.albedo_texture = texture
        
        var is_side = info[1]
        
        var list = info[2]
        
        for pos in list:
            var vox = voxels[pos]
            var vox_corners = voxel_corners[pos] if pos in voxel_corners else []
            for dir in sides if is_side else unsides:
                if voxels.has(pos+dir) and !face_is_shifted(pos+dir, -dir) and !face_is_shifted(pos, dir):
                    continue
                var unit_uv = Vector2(1.0/12.0, 1/4.0)
                var uvs = ref_uvs.duplicate()
                for i in range(uvs.size()):
                    uvs[i].x = lerp(0.5, uvs[i].x, uv_shrink)
                    uvs[i].y = lerp(0.5, uvs[i].y, uv_shrink)
                    
                    uvs[i].y = 1.0-uvs[i].y
                    var bitmask = 0
                    for bit in bitmask_bindings:
                        var neighbor_pos = pos + bitmask_dirs_by_dir[dir][bit]
                        var neighbor = voxels.get(neighbor_pos)
                        if neighbor and (neighbor.sides if is_side else neighbor.top) == (vox.sides if is_side else vox.top):
                            bitmask |= bit
                        if voxels.get(neighbor_pos + dir) and !face_is_shifted(neighbor_pos + dir, -dir) and !face_is_shifted(pos, dir):
                            bitmask &= ~bit
                        # FIXME handle floor-wall transitions
                    
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
                    
                    #if bitmask & TileSet.BIND_TOPLEFT and (bitmask & TileSet.BIND_LEFT or bitmask & TileSet.BIND_TOP):
                    #    bitmask |= TileSet.BIND_LEFT
                    #    bitmask |= TileSet.BIND_TOP
                    if bitmask in bitmask_uvs:
                        uvs[i] += bitmask_uvs[bitmask]
                    else:
                        uvs[i] += bitmask_uvs[TileSet.BIND_CENTER]
                    #if is_side:
                    #    uvs[i] += bitmask_uvs[511] # all bindings
                    #else:
                    #    uvs[i] += bitmask_uvs[TileSet.BIND_CENTER]
                    uvs[i] = unit_uv * uvs[i]
                
                #for i in [0, 2, 1, 1, 2, 3]:
                for i in [0, 1, 2, 2, 1, 3]:
                    surface_builder.add_uv(uvs[i])
                    var vert = dir_verts[dir][i]
                    for etc in vox_corners:
                        if (vert*2.0).round() == etc[0]:
                            vert = etc[1]/2.0
                    surface_builder.add_vertex(vert + pos)
                    
        surface_builder.generate_normals()
        var arrays = surface_builder.commit_to_arrays()
        if arrays[ArrayMesh.ARRAY_FORMAT_VERTEX].size() > 0:
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            mesh.surface_set_material(mesh.get_surface_count() - 1, material)
    
    #var owner = $StaticBody.get_shape_owners()[0]
    #$StaticBody.shape_owner_clear_shapes(owner)
    #$StaticBody.shape_owner_add_shape(owner, mesh.create_trimesh_shape())
