extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed:PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        push_error("SMOKE: main scene could not be loaded")
        quit(2)
        return
    var root:Node = packed.instantiate()
    root.process_mode = Node.PROCESS_MODE_ALWAYS
    get_root().add_child(root)
    # Headless CI does not need real rendering frames. Advance the simulation directly
    # so the smoke test is deterministic and cannot stall waiting for a display frame.
    for i in range(8):
        root.call("_simulate", 1.0)
    var kingdoms:Array = root.get("kingdoms")
    var people:Array = root.get("people")
    var buildings:Array = root.get("buildings")
    var nature:Array = root.get("nature")
    var armies:Array = root.get("armies")
    var age:int = int(root.get("world_age"))
    if kingdoms.size() != 4:
        push_error("SMOKE: expected 4 kingdoms, got %s" % kingdoms.size())
        quit(3)
        return
    if people.size() < 80:
        push_error("SMOKE: population simulation did not initialize")
        quit(4)
        return
    if buildings.size() < 60:
        push_error("SMOKE: city building layer did not initialize")
        quit(5)
        return
    if nature.size() < 100:
        push_error("SMOKE: natural world layer did not initialize")
        quit(6)
        return
    if age < 2:
        push_error("SMOKE: autonomous simulation did not advance")
        quit(7)
        return
    if armies.size() == 0:
        push_warning("SMOKE: no war emerged during short smoke window; simulation still valid")
    print("GODWORLD_SMOKE_OK age=%s kingdoms=%s people=%s buildings=%s nature=%s armies=%s" % [age, kingdoms.size(), people.size(), buildings.size(), nature.size(), armies.size()])
    root.queue_free()
    quit(0)
