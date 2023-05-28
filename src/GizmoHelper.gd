extends Control

var coords = []
func inform_gizmos(array : Array):
    coords = array
    queue_redraw()

func _draw():
    var camera = get_viewport().get_camera_3d()
    var icon = preload("res://art/Splotter.tres")
    var icon_size = icon.get_size()
    var offset = -icon_size/2.0
    for info in coords:
        var coord = info[0]
        var color = info[1]
        if camera.is_position_behind(coord):
            continue
        var coord_2d = camera.unproject_position(coord)
        draw_texture(icon, coord_2d + offset, color)
