extends SubViewportContainer

@onready var editor = get_tree().get_nodes_in_group("VoxEditor")[0]
func inform_mat(mat):
    $SubViewport/Node3D/Camera3D.size = 1.75
    $SubViewport/Voxels.clear()
    $SubViewport/DirectionalLight3D.rotation_degrees.y = -90
    if !input_locked:
        $SubViewport/DirectionalLight3D.rotation_degrees = Vector3(-30, -45 - 90, 0)
    
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

@export var input_locked = true
var camera_mode = false
func _gui_input(_event):
    if !visible or input_locked:
        return
    var cam : Camera3D = $SubViewport/Node3D/Camera3D
    
    if _event.is_action_pressed("m3") and Input.is_action_just_pressed("m3"):
        #print(_event.is_action_pressed("m3"))
        camera_mode = true
    elif !Input.is_action_pressed("m3"):
        camera_mode = false

    if _event is InputEventMouseMotion:
        var event : InputEventMouseMotion = _event
        if camera_mode:
            cam.get_parent().rotation_degrees.y -= 0.22 * event.relative.x
            cam.get_parent().rotation_degrees.x -= 0.22 * event.relative.y
            force_update()
