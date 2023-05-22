extends Control

var tex_size = Vector2(1, 1)
var rect = Rect2(Vector2(), Vector2(1, 1))
var new_rect = Rect2(Vector2(), Vector2(1, 1))
var tile_count = Vector2(1, 1)

var tex : Texture2D = null
var grid_size = Vector2(16, 16)
var icon_coord = Vector2(0, 0)

var next_coord = null

var my_scale = 1.0
var offset = Vector2()

func _init():
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC

func _input(_event):
    if !visible:
        return
    
    if _event is InputEventMouse:
        var pos : Vector2 = get_local_mouse_position()
        if !rect.has_point(pos):
            return
    
    if _event is InputEventMouseButton:
        var event : InputEventMouseButton = _event
        if event.button_index == 1 and event.is_pressed():
            var pos : Vector2 = get_local_mouse_position()
            pos -= new_rect.position
            pos /= new_rect.size
            pos *= tex_size
            pos /= grid_size
            pos = pos.floor()
            var old_pos = pos
            pos.x = clamp(pos.x, 0, tile_count.x-1)
            pos.y = clamp(pos.y, 0, tile_count.y-1)
            if pos == old_pos:
                next_coord = pos
        
        elif event.button_index == 5 and event.is_pressed():
            my_scale /= sqrt(sqrt(2.0))
            get_tree().get_root().set_input_as_handled()
        elif event.button_index == 4 and event.is_pressed():
            my_scale *= sqrt(sqrt(2.0))
            get_tree().get_root().set_input_as_handled()
    
    if _event is InputEventMouseMotion:
        var event : InputEventMouseMotion = _event
        if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
            offset += event.relative / my_scale

func think():
    tex_size = tex.get_size()
    rect = get_rect()
    rect.position = Vector2()
    rect.position += Vector2(8, 8)
    rect.size -= Vector2(16, 16)
    
    var aspect_ratio = rect.size.x / rect.size.y
    var tex_aspect_ratio = tex_size.x / tex_size.y
    
    var scale_x = 1
    var scale_y = 1
    
    if aspect_ratio > tex_aspect_ratio:
        scale_x = tex_aspect_ratio/aspect_ratio
    else:
        scale_y = aspect_ratio/tex_aspect_ratio
    
    new_rect = rect
    new_rect.size.x *= scale_x
    new_rect.size.y *= scale_y
    new_rect.position.x += (rect.size.x - new_rect.size.x)/2.0
    new_rect.position.y += (rect.size.y - new_rect.size.y)/2.0
    
    var unscaled_rect = new_rect
    
    new_rect.size *= my_scale
    
    new_rect.position += offset*my_scale
    
    new_rect.position += (rect.size/2.0 - unscaled_rect.position)
    new_rect.position -= (rect.size/2.0 - unscaled_rect.position)*my_scale
    
    grid_size.x = min(grid_size.x, tex_size.x)
    grid_size.y = min(grid_size.y, tex_size.y)
    
    tile_count = (tex_size/grid_size).floor()
    
    if next_coord != null:
        icon_coord = next_coord
        next_coord = null
    
    queue_redraw()

var prev_tex = null
var nonlinear_tex = null

func _draw():
    if prev_tex != tex:
        var image = tex.get_image()
        nonlinear_tex = ImageTexture.create_from_image(image)
        prev_tex = tex
        my_scale = 1.0
        offset = Vector2()
    
    if nonlinear_tex:
        draw_texture_rect(nonlinear_tex, new_rect, false)
    
    var top_left = new_rect.position
    var top_right = new_rect.position + new_rect.size * Vector2(1, 0)
    var bottom_left = new_rect.position + new_rect.size * Vector2(0, 1)
    var bottom_right = new_rect.position + new_rect.size
    
    for x in range(grid_size.x, tex_size.x, grid_size.x):
        var i = x / tex_size.x
        draw_line(lerp(top_left, top_right, i), lerp(bottom_left, bottom_right, i), Color(0.5, 0.5, 0.5, 64.0), 1.0)
    
    for y in range(grid_size.y, tex_size.y, grid_size.y):
        var i = y / tex_size.y
        draw_line(lerp(top_left, bottom_left, i), lerp(top_right, bottom_right, i), Color(0.5, 0.5, 0.5, 64.0), 1.0)
    
    var icon_pos = Rect2(icon_coord, new_rect.size/tile_count)
    icon_pos.position *= new_rect.size/tile_count
    icon_pos.position += new_rect.position
    draw_rect(icon_pos, Color(0.0, 0.5, 1.0, 0.35))
    
    
