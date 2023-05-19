extends Control

signal done

func finish(which):
    emit_signal("done", which)
    queue_free()

func _ready():
    $Center/List/MakeVoxel.connect("pressed", self, "finish", ["voxel"])
    $Center/List/MakeDecal.connect("pressed", self, "finish", ["decal"])
    $Center/List/MakeModel.connect("pressed", self, "finish", ["model"])
    $Center/List/Cancel.connect("pressed", self, "finish", ["cancel"])

func _input(_event):
    if _event is InputEventKey:
        var event : InputEventKey = _event
        if event.pressed and event.scancode == KEY_ESCAPE:
            finish("cancel")
