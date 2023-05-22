class_name Helpers

static func vec2_to_array(vec : Vector2) -> Array:
    return [vec.x, vec.y]

static func array_to_vec2(array : Array) -> Vector2:
    return Vector2(array[0], array[1])
