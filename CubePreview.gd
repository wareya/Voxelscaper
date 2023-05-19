extends ViewportContainer

func inform_mats(side_mat, top_mat):
    $Viewport/Spatial/Camera.size = 3.3
    $Viewport/Spatial.rotation_degrees.x = -30.0
    $Viewport/Spatial.rotation_degrees.y = -45.0
    
    $Viewport/DirectionalLight.rotation_degrees.y = -90
    
    $Viewport/SideA.visible = true
    $Viewport/SideB.visible = true
    $Viewport/SideC.visible = true
    
    $Viewport/SideA.translation = Vector3(0, 0, 1)
    $Viewport/SideA.rotation_degrees = Vector3(0, 0, 0)
    $Viewport/SideA.scale = Vector3.ONE
    $Viewport/SideC.translation = Vector3(-1, 0, 0)
    $Viewport/SideC.rotation_degrees = Vector3(0, -90, 0)
    $Viewport/SideC.scale = Vector3.ONE
    
    $Viewport/SideA.material_override = side_mat
    $Viewport/SideB.material_override = top_mat
    $Viewport/SideC.material_override = side_mat
    
    if side_mat:
        side_mat.uv1_scale = Vector3(1/12.0, 1/4.0, 0.0)
        side_mat.uv1_offset = Vector3(0/12.0, 3/4.0, 0.0)
    if top_mat:
        top_mat.uv1_scale = Vector3(1/12.0, 1/4.0, 0.0)
        top_mat.uv1_offset = Vector3(0/12.0, 3/4.0, 0.0)

func inform_decal(mat):
    $Viewport/Spatial/Camera.size = 2.2
    var actual_mat = DecalConfig.make_mat(mat)
    $Viewport/Spatial.rotation_degrees.x = 0.0
    $Viewport/Spatial.rotation_degrees.y = -90.0
    
    $Viewport/DirectionalLight.rotation_degrees.y = -90
    
    $Viewport/SideA.visible = true
    $Viewport/SideB.visible = true
    $Viewport/SideC.visible = true
    
    $Viewport/SideA.translation = Vector3(0, 0, 1)
    $Viewport/SideA.rotation_degrees = Vector3(0, 0, 0)
    $Viewport/SideA.scale = Vector3.ONE
    $Viewport/SideC.translation = Vector3(-1, 0, 0)
    $Viewport/SideC.rotation_degrees = Vector3(0, -90, 0)
    $Viewport/SideC.scale = Vector3.ONE
    
    $Viewport/SideA.material_override = actual_mat
    $Viewport/SideB.material_override = actual_mat
    $Viewport/SideC.material_override = actual_mat

func inform_model(mat):
    $Viewport/Spatial/Camera.size = 3.3
    var actual_mat = DecalConfig.make_mat(mat)
    $Viewport/Spatial.rotation_degrees.x = -30.0
    $Viewport/Spatial.rotation_degrees.y = -45.0
    
    $Viewport/DirectionalLight.rotation_degrees.y = -80
    
    $Viewport/SideA.visible = true
    $Viewport/SideB.visible = false
    $Viewport/SideC.visible = true
    
    $Viewport/SideA.translation = Vector3(0, 0, 0)
    $Viewport/SideA.rotation_degrees = Vector3(0, 0, 0)
    $Viewport/SideA.scale = Vector3(sqrt(2), 1, 1)
    $Viewport/SideC.translation = Vector3(0, 0, 0)
    $Viewport/SideC.rotation_degrees = Vector3(0, -90, 0)
    $Viewport/SideC.scale = Vector3(sqrt(2), 1, 1)
    
    $Viewport/SideA.material_override = actual_mat
    $Viewport/SideB.material_override = actual_mat
    $Viewport/SideC.material_override = actual_mat

func force_update():
    $Viewport.update_worlds()
