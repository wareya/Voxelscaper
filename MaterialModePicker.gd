extends Control

signal done

func finish(which):
    emit_signal("done", which)
    queue_free()

func _ready():
    $Center/List/MakeVoxel.connect("pressed", Callable(self, "finish").bind("voxel"))
    $Center/List/MakeDecal.connect("pressed", Callable(self, "finish").bind("decal"))
    $Center/List/MakeModel.connect("pressed", Callable(self, "finish").bind("model"))
    $Center/List/Cancel.connect("pressed", Callable(self, "finish").bind("cancel"))

func _input(_event):
    if _event is InputEventKey:
        var event : InputEventKey = _event
        if event.pressed and event.keycode == KEY_ESCAPE:
            finish("cancel")
