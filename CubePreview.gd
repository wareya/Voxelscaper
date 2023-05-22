extends ViewportContainer

onready var editor = get_tree().get_nodes_in_group("VoxEditor")[0]
func inform_mat(mat):
    $Viewport/Spatial/Camera.size = 1.75
    $Viewport/Voxels.clear()
    $Viewport/DirectionalLight.rotation_degrees.y = -90
    
    if mat is VoxEditor.VoxMat:
        editor.place_mat_at($Viewport/Voxels, mat, Vector3(), Vector3.UP)
    elif mat is VoxEditor.ModelMat:
        $Viewport/DirectionalLight.rotation_degrees.y = -80
        $Viewport/Voxels.place_model(Vector3(), mat, (1<<4) | 1, 0, 0, 0, 0)
        $Viewport/Spatial/Camera.size = 1.75
    elif mat is VoxEditor.DecalMat:
        editor.place_mat_at($Viewport/Voxels, mat, Vector3(), Vector3.UP)
        $Viewport/Spatial/Camera.size = 1.4
        $Viewport/Spatial.rotation_degrees.x = -90.0
        $Viewport/Spatial.rotation_degrees.y = 0.0
    
    $Viewport/Voxels.full_remesh()

func force_update():
    $Viewport.update_worlds()
