extends Control

@onready var editor = get_tree().get_nodes_in_group("VoxEditor")[0]

func _ready():
    var sun : DirectionalLight3D = editor.get_sun()
    $SunColor.color = sun.light_color
    $SunColor/HSlider.value = sun.rotation_degrees.y
    $SunColor/HSlider2.value = fmod(-sun.rotation_degrees.x + 90, 180) - 90
    var env : Environment = editor.get_env()
    $AmbientColor.color = env.ambient_light_color
    $BackgroundColor.color = env.background_color

func _process(delta: float) -> void:
    var sun : DirectionalLight3D = editor.get_sun()
    sun.light_color = $SunColor.color
    sun.rotation_degrees.y = $SunColor/HSlider.value
    sun.rotation_degrees.x = -$SunColor/HSlider2.value
    var env : Environment = editor.get_env()
    env.ambient_light_color = $AmbientColor.color
    env.background_color = $BackgroundColor.color
