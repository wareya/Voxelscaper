extends Control

signal done

func finish(which):
    emit_signal("done", which)
    queue_free()

func _ready():
    $Center/List/Top.connect("pressed", Callable(self, "finish").bind("top"))
    $Center/List/Side.connect("pressed", Callable(self, "finish").bind("side"))
    $Center/List/Bottom.connect("pressed", Callable(self, "finish").bind("bottom"))
    $Center/List/Cancel.connect("pressed", Callable(self, "finish").bind("cancel"))

func _input(_event):
    if _event is InputEventKey:
        var event : InputEventKey = _event
        if event.pressed and event.keycode == KEY_ESCAPE:
            finish("cancel")
