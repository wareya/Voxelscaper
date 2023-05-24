extends SubViewportContainer

@onready var editor = get_tree().get_nodes_in_group("VoxEditor")[0]
func inform_mat(mat):
    $SubViewport/Node3D/Camera3D.size = 1.75
    $SubViewport/Voxels.clear()
    $SubViewport/DirectionalLight3D.rotation_degrees.y = -90
    
    if mat is VoxEditor.VoxMat:
        editor.place_mat_at($SubViewport/Voxels, mat, Vector3(), Vector3.UP, false)
    elif mat is VoxEditor.ModelMat:
        $SubViewport/DirectionalLight3D.rotation_degrees.y = -80
        $SubViewport/Voxels.place_model(Vector3(), mat, (1<<4) | 1, 0, 0, 0, 0)
        $SubViewport/Node3D/Camera3D.size = 1.75
    elif mat is VoxEditor.DecalMat:
        editor.place_mat_at($SubViewport/Voxels, mat, Vector3(), Vector3.UP, false)
        $SubViewport/Node3D/Camera3D.size = 1.4
        $SubViewport/Node3D.rotation_degrees.x = -90.0
        $SubViewport/Node3D.rotation_degrees.y = 0.0
    
    $SubViewport/Voxels.full_remesh()
    
    $SubViewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func force_update():
    $SubViewport.render_target_update_mode = SubViewport.UPDATE_ONCE
