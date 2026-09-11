extends SceneTree

func _init() -> void:
    var script:Script = load("res://scripts/main.gd") as Script
    if script == null:
        push_error("SMOKE: main script could not be loaded")
        quit(2)
        return
    var root:Node2D = Node2D.new()
    root.set_script(script)
    root.call("_generate_world")
    root.call("_spawn_civilizations")
    for i in range(4):
        root.set("time_accum", 1.1)
        root.call("_simulate", 1.1)
    var kingdoms:Array = root.get("kingdoms")
    var people:Array = root.get("people")
    var buildings:Array = root.get("buildings")
    var nature:Array = root.get("nature")
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
    print("GODWORLD_SMOKE_OK age=%s kingdoms=%s people=%s buildings=%s nature=%s" % [age, kingdoms.size(), people.size(), buildings.size(), nature.size()])
    quit(0)
