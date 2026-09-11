extends Node2D

# GodWorld v15 — Autonomous living-world simulation.
# Renderer and simulation are intentionally separated: terrain is cached, while people,
# animals, buildings, resources, borders, cities and armies are dynamic layers.

const WORLD_W := 180
const WORLD_H := 110
const PIXEL := 8
const WORLD_PX := Vector2(WORLD_W * PIXEL, WORLD_H * PIXEL)
const MAX_PEOPLE := 220
const MAX_ANIMALS := 55
const MAX_TREES := 260
const MAX_RESOURCE_NODES := 70
const KINGDOM_COLORS := [Color("#4d78d6"), Color("#b85c55"), Color("#6ba66d"), Color("#b58a55")]
const SPECIES := [
    {"name":"البشر","trait":"متوازنون","speed":1.0,"growth":1.0,"tech":1.0},
    {"name":"الألف","trait":"غابات + زراعة","speed":1.05,"growth":1.15,"tech":1.05},
    {"name":"الأقزام","trait":"مناجم + معادن","speed":0.9,"growth":0.95,"tech":1.3},
    {"name":"الأورك","trait":"قتال + توسع","speed":1.12,"growth":1.05,"tech":0.85}
]

var rng := RandomNumberGenerator.new()
var atlas: Texture2D
var world_tex: ImageTexture
var world_img: Image
var terrain := []
var heightmap := []
var buildings := []
var people := []
var animals := []
var nature := []
var resource_nodes := []
var kingdoms := []
var armies := []
var roads := []
var particles := []
var selected_kingdom := 0
var world_age := 1
var gold := 220
var faith := 80
var paused := false
var sim_speed := 1.0
var cam := Vector2.ZERO
var zoom := 1.0
var dragging := false
var touch_points: Dictionary = {}
var touch_last_positions: Dictionary = {}
var pinch_active := false
var pinch_distance := 0.0
var pinch_center := Vector2.ZERO
var primary_touch_id := -1
var is_portrait := false
var time_accum := 0.0
var event_text := "بدأت الحياة في العالم"
var event_timer := 4.0

func _ready() -> void:
    rng.seed = 90427
    atlas = load("res://assets/godworld_atlas.png") as Texture2D
    _generate_world()
    _spawn_civilizations()
    _build_world_texture()
    cam = Vector2(WORLD_PX.x * 0.5, WORLD_PX.y * 0.5)
    var viewport: Viewport = get_viewport()
    if not viewport.size_changed.is_connected(_on_viewport_size_changed):
        viewport.size_changed.connect(_on_viewport_size_changed)
    _on_viewport_size_changed()
    queue_redraw()

func _generate_world() -> void:
    terrain.clear(); heightmap.clear(); roads.clear()
    for y in range(WORLD_H):
        var row := []
        var hrow := []
        for x in range(WORLD_W):
            var nx := float(x) / float(WORLD_W) - 0.5
            var ny := float(y) / float(WORLD_H) - 0.5
            var island := 1.0 - min(1.0, sqrt(nx*nx*1.7 + ny*ny*1.45) * 1.7)
            var n := _noise(x, y)
            var h := island * 0.9 + n * 0.7
            hrow.append(h)
            var t := 0
            if h < 0.23: t = 0
            elif h < 0.30: t = 1
            elif h < 0.50: t = 2
            elif h < 0.64: t = 3
            elif h < 0.78: t = 4
            else: t = 5
            if t == 2 and _noise(x+51, y+91) > 0.66: t = 3
            row.append(t)
        terrain.append(row); heightmap.append(hrow)
    for cy in [34, 73]:
        for cx in [52, 126]:
            for y in range(max(0,cy-7), min(WORLD_H,cy+8)):
                for x in range(max(0,cx-9), min(WORLD_W,cx+10)):
                    var dx := float(x-cx)/9.0; var dy := float(y-cy)/7.0
                    if dx*dx + dy*dy < 0.72 and terrain[y][x] >= 2:
                        terrain[y][x] = 0

func _noise(x:int, y:int) -> float:
    var a := sin(float(x)*0.073 + cos(float(y)*0.041))*0.5+0.5
    var b := sin(float(x+y)*0.031)*0.5+0.5
    var c := cos(float(x)*0.017 - float(y)*0.083)*0.5+0.5
    return (a*0.48+b*0.30+c*0.22)

func _spawn_civilizations() -> void:
    kingdoms.clear(); buildings.clear(); people.clear(); animals.clear(); armies.clear(); nature.clear(); resource_nodes.clear()
    _spawn_world_nature()
    var starts := [Vector2i(48,43), Vector2i(123,40), Vector2i(58,77), Vector2i(119,77)]
    for i in range(4):
        var s := starts[i]
        var k := {"name": ["مملكة نورا","إمبراطورية فالور","غابات إيلارا","قبائل غاروك"][i], "species": i, "color": KINGDOM_COLORS[i], "city": s, "pop": 22 + i*4, "food": 80.0, "wood": 55.0, "ore": 30.0, "gold": 20.0, "tech": 1.0 + i*0.15, "war": 0.0, "border": 14.0, "alive": true, "city_level": 1, "prosperity": 0.0, "morale": 70.0}
        kingdoms.append(k)
        _make_city(i, s)
        for j in range(20 + i*4):
            _spawn_person(i, s, j % 5 == 0)
        if i == 0 or i == 2:
            for j in range(12): _spawn_animal(i, s)
    for i in range(4):
        for j in range(i+1,4):
            if i == 0 and j == 3: continue
            _make_road(kingdoms[i]["city"], kingdoms[j]["city"])

func _spawn_world_nature() -> void:
    var attempts := 0
    while nature.size() < MAX_TREES and attempts < MAX_TREES * 8:
        attempts += 1
        var p := Vector2i(rng.randi_range(3, WORLD_W-4), rng.randi_range(3, WORLD_H-4))
        if _is_land(p) and terrain[p.y][p.x] == 3:
            var clear := true
            for n in nature:
                if Vector2(n["pos"]).distance_to(Vector2(p)) < 2.2:
                    clear = false
                    break
            if clear:
                nature.append({"pos":p,"variant":rng.randi_range(0,2),"phase":rng.randf_range(0,TAU)})
    attempts = 0
    while resource_nodes.size() < MAX_RESOURCE_NODES and attempts < MAX_RESOURCE_NODES * 8:
        attempts += 1
        var p := Vector2i(rng.randi_range(4, WORLD_W-5), rng.randi_range(4, WORLD_H-5))
        if _is_land(p) and terrain[p.y][p.x] >= 2:
            var kind := "wood"
            if terrain[p.y][p.x] >= 4: kind = "ore"
            elif rng.randf() < 0.35: kind = "food"
            resource_nodes.append({"pos":p,"kind":kind,"amount":rng.randi_range(30,90)})

func _make_city(k:int, c:Vector2i) -> void:
    _add_building(k, c, "castle", 2)
    var radius := 7
    for n in range(20):
        var ang := rng.randf_range(0, TAU); var r := rng.randf_range(3.0, radius)
        var p := c + Vector2i(round(cos(ang)*r), round(sin(ang)*r))
        if _is_land(p):
            var kind := "house"
            if n % 7 == 0: kind = "farm"
            elif n % 11 == 0: kind = "mine"
            _add_building(k,p,kind,0)

func _add_building(k:int, p:Vector2i, kind:String, level:int) -> void:
    buildings.append({"kingdom":k,"pos":p,"kind":kind,"level":level,"hp":100.0})

func _make_road(a:Vector2i,b:Vector2i) -> void:
    var steps := maxi(abs(b.x-a.x),abs(b.y-a.y))
    for i in range(steps+1):
        var t := 0.0 if steps == 0 else float(i)/float(steps)
        var p := Vector2i(round(lerp(float(a.x),float(b.x),t)), round(lerp(float(a.y),float(b.y),t)))
        if _is_land(p): roads.append(p)

func _spawn_person(k:int, origin:Vector2i, soldier:bool) -> void:
    var p := Vector2(origin) + Vector2(rng.randf_range(-8,8),rng.randf_range(-8,8))
    people.append({"kingdom":k,"pos":p,"target":p,"soldier":soldier,"phase":rng.randf_range(0,TAU),"life":rng.randf_range(40,100),"task":0})

func _spawn_animal(k:int, origin:Vector2i) -> void:
    animals.append({"kingdom":k,"pos":Vector2(origin)+Vector2(rng.randf_range(-12,12),rng.randf_range(-12,12)),"phase":rng.randf_range(0,TAU)})

func _is_land(p:Vector2i) -> bool:
    return p.x >= 1 and p.x < WORLD_W-1 and p.y >= 1 and p.y < WORLD_H-1 and terrain[p.y][p.x] >= 2

func _build_world_texture() -> void:
    world_img = Image.create(WORLD_W*PIXEL, WORLD_H*PIXEL, false, Image.FORMAT_RGBA8)
    for y in range(WORLD_H):
        for x in range(WORLD_W):
            var t:int = terrain[y][x]
            var base := Color("#285b7a")
            if t == 1: base = Color("#d6bd7b")
            elif t == 2: base = Color("#68a866")
            elif t == 3: base = Color("#3f8553")
            elif t == 4: base = Color("#78836c")
            elif t == 5: base = Color("#565b62")
            var v := int((_noise(x*3,y*5)-0.5)*18.0)
            var c := Color8(clampi(int(base.r*255)+v,0,255),clampi(int(base.g*255)+v,0,255),clampi(int(base.b*255)+v,0,255),255)
            var px := x*PIXEL; var py := y*PIXEL
            world_img.fill_rect(Rect2i(px,py,PIXEL,PIXEL),c)
            if t >= 2 and t <= 4 and _noise(x+13,y+29) > 0.79:
                world_img.set_pixel(px+2,py+2,Color("#86b873"))
                world_img.set_pixel(px+5,py+5,Color("#4f8d55"))
    world_tex = ImageTexture.create_from_image(world_img)

func _process(delta:float) -> void:
    time_accum += delta
    if not paused:
        var dt := delta * sim_speed
        _simulate(dt)
    event_timer -= delta
    if event_timer <= 0:
        _make_event()
        event_timer = rng.randf_range(6.0,11.0)
    queue_redraw()

func _simulate(dt:float) -> void:
    if time_accum > 1.0:
        time_accum = 0.0; world_age += 1
        for k in kingdoms:
            if not k["alive"]: continue
            var growth:float = 0.35 * SPECIES[k["species"]]["growth"]
            k["food"] += 2.2 + k["pop"]*0.06
            k["wood"] += 1.2
            k["ore"] += 0.8 * SPECIES[k["species"]]["tech"]
            k["gold"] += 0.6 + k["pop"]*0.015
            if k["food"] > k["pop"]*2.2 and rng.randf() < growth*0.12 and k["pop"] < 70:
                k["pop"] += 1; _spawn_person(kingdoms.find(k),Vector2i(k["city"]),false)
            k["tech"] += 0.002 * SPECIES[k["species"]]["tech"]
            k["prosperity"] += 0.25 + k["tech"] * 0.03
            if k["prosperity"] > 100.0 and k["city_level"] < 5:
                k["prosperity"] -= 100.0
                k["city_level"] += 1
                _upgrade_city(kingdoms.find(k))
                event_text = str(k["name"]) + " ارتقت إلى مدينة من المستوى " + str(k["city_level"])
            k["morale"] = clamp(float(k["morale"]) + (1.0 if k["food"] > k["pop"] else -1.0), 15.0, 100.0)
            k["border"] = min(38.0, 13.0 + k["pop"]*0.18 + k["city_level"]*2.0)
        _strategic_tick()
    for p in people: _move_person(p,dt)
    for a in animals:
        a["phase"] += dt*2.0
        if rng.randf() < dt*0.08: a["pos"] += Vector2(rng.randf_range(-2,2),rng.randf_range(-2,2))
    for army in armies: _move_army(army,dt)
    for q in particles: q["life"] -= dt

func _upgrade_city(k:int) -> void:
    if k < 0 or k >= kingdoms.size(): return
    var c:Vector2i = kingdoms[k]["city"]
    var level:int = kingdoms[k]["city_level"]
    var extra := 4 + level * 2
    for n in range(extra):
        var ang := rng.randf_range(0.0, TAU)
        var radius := rng.randf_range(6.0, 12.0 + level * 2.0)
        var p := c + Vector2i(round(cos(ang)*radius), round(sin(ang)*radius))
        if _is_land(p):
            var kind := "house"
            if n % 9 == 0: kind = "farm"
            elif n % 13 == 0: kind = "mine"
            elif n % 17 == 0 and level >= 3: kind = "castle"
            _add_building(k,p,kind,level)
    for n in range(2 + level): _spawn_person(k,c,n % 4 == 0)

func _move_person(p:Dictionary,dt:float) -> void:
    p["life"] -= dt * (0.05 if not p["soldier"] else 0.035)
    if p["life"] <= 0:
        p["life"] = rng.randf_range(55,100); p["pos"] = Vector2(kingdoms[p["kingdom"]]["city"])
    if p["pos"].distance_to(p["target"]) < 1.5 or rng.randf() < dt*0.25:
        var c:Vector2 = Vector2(kingdoms[p["kingdom"]]["city"])
        var r := 10.0 if not p["soldier"] else 14.0
        p["target"] = c + Vector2(rng.randf_range(-r,r),rng.randf_range(-r,r))
    var dir:Vector2 = p["target"]-p["pos"]
    if dir.length() > 0.2:
        p["pos"] += dir.normalized()*dt*(3.0 if p["soldier"] else 2.0)*SPECIES[kingdoms[p["kingdom"]]["species"]]["speed"]

func _strategic_tick() -> void:
    for i in range(kingdoms.size()):
        for j in range(i+1,kingdoms.size()):
            var a:Dictionary = kingdoms[i]; var b:Dictionary = kingdoms[j]
            var dist:float = Vector2(a["city"]).distance_to(Vector2(b["city"]))
            if dist < 90.0 and rng.randf() < 0.10:
                if rng.randf() < 0.34:
                    a["war"] = min(100.0,float(a["war"])+10.0); b["war"] = min(100.0,float(b["war"])+10.0)
                    if not _army_exists(i,j): _create_army(i,j)
                    event_text = str(a["name"]) + " و " + str(b["name"]) + " دخلا في حرب"
                else:
                    a["gold"] += 10.0; b["gold"] += 10.0
                    a["morale"] = min(100.0,float(a["morale"])+2.0); b["morale"] = min(100.0,float(b["morale"])+2.0)

func _army_exists(a:int,b:int) -> bool:
    for army in armies:
        if (army["owner"] == a and army["enemy"] == b) or (army["owner"] == b and army["enemy"] == a): return true
    return false

func _create_army(owner:int,enemy:int) -> void:
    var k:Dictionary = kingdoms[owner]
    armies.append({"owner":owner,"enemy":enemy,"pos":Vector2(k["city"]),"target":Vector2(kingdoms[enemy]["city"]),"size":7+int(k["pop"]/10),"phase":0.0,"combat":false})

func _move_army(a:Dictionary,dt:float) -> void:
    a["phase"] += dt*4.0
    var d:Vector2 = a["target"]-a["pos"]
    if d.length() > 2.0:
        a["pos"] += d.normalized()*dt*5.0
    else:
        a["combat"] = true
        var target:int = a["enemy"]
        var attacker:int = a["owner"]
        var atk_power:float = float(a["size"]) * SPECIES[kingdoms[attacker]["species"]]["tech"] * (float(kingdoms[attacker]["morale"])/70.0)
        var def_power:float = float(kingdoms[target]["pop"]) * 0.22 * (float(kingdoms[target]["morale"])/70.0)
        if rng.randf() < dt * clamp(atk_power / max(1.0, atk_power + def_power), 0.02, 0.22):
            kingdoms[target]["pop"] = max(8,int(kingdoms[target]["pop"])-rng.randi_range(1,3))
            kingdoms[target]["morale"] = max(10.0,float(kingdoms[target]["morale"])-5.0)
        if rng.randf() < dt*0.12: a["size"] = max(2,int(a["size"])-1)
        if kingdoms[target]["pop"] <= 9 or rng.randf() < dt*0.035:
            kingdoms[target]["war"] = max(0.0,float(kingdoms[target]["war"])-25.0)
            kingdoms[attacker]["gold"] += 18.0
            event_text = str(kingdoms[attacker]["name"]) + " صدّ هجومًا على " + str(kingdoms[target]["name"])
            armies.erase(a)

func _make_event() -> void:
    var choices := ["سوق جديد ازدهر","رحلة استكشاف عبر الغابة","مزرعة جديدة بُنيت","عروق خام ظهرت قرب المدينة","تجمع جنود على الحدود","مهرجان شعبي رفع المعنويات"]
    event_text = choices[rng.randi_range(0,choices.size()-1)]
    if rng.randf() < 0.18: faith = min(100,faith+2)

func _draw() -> void:
    var size:Vector2 = get_viewport_rect().size
    is_portrait = size.y > size.x * 1.08
    draw_rect(Rect2(Vector2.ZERO,size),Color("#101827"))
    var panel_h:float = 74.0 if not is_portrait else 102.0
    var world_rect := Rect2(0,panel_h,size.x,size.y-panel_h)
    _draw_world(world_rect)
    _draw_ui(size,panel_h)

func _draw_world(r:Rect2) -> void:
    var scale:=zoom
    var center:=r.get_center()
    var world_size:=WORLD_PX*scale
    var dest:=Rect2(center - cam*scale + Vector2(WORLD_PX.x*scale*0.5,WORLD_PX.y*scale*0.5),world_size)
    draw_texture_rect(world_tex,dest,false)
    _draw_roads(dest,scale)
    _draw_territories(dest,scale)
    _draw_dynamic_entities(dest,scale)

func _world_to_screen(p:Vector2,dest:Rect2)->Vector2: return dest.position + p*zoom

func _draw_roads(dest:Rect2,scale:float) -> void:
    for p in roads:
        var q:=_world_to_screen(Vector2(p*PIXEL),dest)+Vector2(4,4)*scale
        draw_rect(Rect2(q-Vector2(2,1)*scale,Vector2(4,2)*scale),Color("#b38a5c"))

func _draw_territories(dest:Rect2,scale:float) -> void:
    for k in kingdoms:
        var c:=_world_to_screen(Vector2(k["city"]*PIXEL)+Vector2(4,4),dest)
        var rad:float=float(k["border"])*PIXEL*scale
        draw_arc(c,rad,0,TAU,48,Color(k["color"],0.20),max(1.0,2.0*scale))
        draw_arc(c,rad-3*scale,0,TAU,48,Color(k["color"],0.08),max(1.0,5.0*scale))

func _draw_dynamic_entities(dest:Rect2,scale:float) -> void:
    for n in nature:
        var tree_pos:=_world_to_screen(Vector2(n["pos"]*PIXEL)+Vector2(4,4),dest)
        var tree_src:=Rect2(int(n["variant"])*16,0,16,16)
        draw_texture_rect_region(atlas,Rect2(tree_pos-Vector2(8,14)*scale,Vector2(16,16)*scale),tree_src)
    for node in resource_nodes:
        var node_pos:=_world_to_screen(Vector2(node["pos"]*PIXEL)+Vector2(4,4),dest)
        var node_color:=Color("#b8a05a")
        if node["kind"] == "wood": node_color=Color("#78a65b")
        elif node["kind"] == "food": node_color=Color("#d4b85c")
        draw_circle(node_pos,2.5*scale,node_color)
    for b in buildings:
        var pos:=_world_to_screen(Vector2(b["pos"]*PIXEL)+Vector2(4,4),dest)
        var row:=_atlas_row(String(b["kind"]))
        var src:=Rect2((int(b["level"]) % 3)*16,row*16,16,16)
        draw_texture_rect_region(atlas,Rect2(pos-Vector2(8,8)*scale,Vector2(16,16)*scale),src)
    for a in animals:
        var pos:=_world_to_screen(a["pos"]*PIXEL+Vector2(4,4),dest)
        var src:=Rect2((int(abs(float(a["phase"]))) % 3)*16,10*16,16,16)
        draw_texture_rect_region(atlas,Rect2(pos-Vector2(7,7)*scale,Vector2(14,14)*scale),src)
    for p in people:
        var pos:=_world_to_screen(p["pos"]*PIXEL+Vector2(4,4),dest)
        var row:=8 if p["soldier"] else 7
        var col:=int(fmod(abs(float(p["phase"]))*0.5,3.0))
        var src:=Rect2(col*16,row*16,16,16)
        draw_texture_rect_region(atlas,Rect2(pos-Vector2(7,10)*scale,Vector2(14,16)*scale),src)
    for a in armies:
        var pos:=_world_to_screen(a["pos"]*PIXEL+Vector2(4,4),dest)
        var c:=kingdoms[a["owner"]]["color"]
        draw_circle(pos,8*scale,Color(c,0.25)); draw_circle(pos,5*scale,c)
        for n in range(min(8,int(a["size"]))):
            var off:=Vector2(cos(n*0.8+a["phase"]),sin(n*0.8+a["phase"]))*10*scale
            draw_circle(pos+off,2.3*scale,Color("#e8e0c8"))

func _atlas_row(kind:String)->int:
    if kind=="tree": return 0
    if kind=="house": return 1
    if kind=="farm": return 2
    if kind=="mine": return 3
    if kind=="castle": return 4
    if kind=="ruin": return 5
    return 1

func _draw_ui(size:Vector2,panel_h:float) -> void:
    draw_rect(Rect2(0,0,size.x,panel_h),Color("#172236"))
    draw_line(Vector2(0,panel_h),Vector2(size.x,panel_h),Color("#31445f"),2)
    var title:Font = ThemeDB.fallback_font
    draw_string(title,Vector2(16,28),"GODWORLD",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#f4e7c3"))
    draw_string(title,Vector2(16,52),"عالم حي • عصر "+str(world_age),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#9eb2c9"))
    var stats := "ذهب "+str(gold)+"   إيمان "+str(faith)+"   حضارات "+str(kingdoms.size())
    draw_string(title,Vector2(170,31),stats,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#d7e2ef"))
    draw_string(title,Vector2(170,53),event_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#9fb6a0"))
    var btn:=Rect2(size.x-112,12,96,48)
    draw_rect(btn,Color("#253550"),true); draw_rect(btn,Color("#49627e"),false,2)
    draw_string(title,btn.position+Vector2(12,21),"⏯ "+("تشغيل" if paused else "إيقاف"),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#f0f4f7"))
    draw_string(title,btn.position+Vector2(12,39),"سرعة "+str(snapped(sim_speed,0.1)),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#9eb2c9"))
    if is_portrait:
        draw_string(title,Vector2(16,panel_h-28),"اسحب بإصبع واحد • إصبعان للتكبير • العالم يتطور تلقائيًا",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#93a8c0"))
    if kingdoms.size() > 0:
        var k:Dictionary = kingdoms[selected_kingdom % kingdoms.size()]
        var card:=Rect2(size.x-188,size.y-88,176,72)
        if is_portrait: card=Rect2(10,size.y-88,176,72)
        draw_rect(card,Color("#142033",0.92),true); draw_rect(card,Color(k["color"],0.75),false,2)
        draw_string(title,card.position+Vector2(10,18),str(k["name"]),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#f4e7c3"))
        draw_string(title,card.position+Vector2(10,37),"سكان "+str(k["pop"])+"  مدينة Lv"+str(k["city_level"]),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#c9d6e5"))
        draw_string(title,card.position+Vector2(10,55),"ذهب "+str(int(k["gold"]))+"  تقنية "+str(snapped(k["tech"],0.1)),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#9eb2c9"))

func _input(e:InputEvent)->void:
    if e is InputEventScreenTouch:
        if e.pressed:
            touch_points[e.index]=e.position; touch_last_positions[e.index]=e.position
            if touch_points.size()==1: primary_touch_id=e.index; dragging=true
            elif touch_points.size()==2:
                dragging=false; pinch_active=true
                var pts:=touch_points.values(); pinch_distance=Vector2(pts[0]).distance_to(Vector2(pts[1])); pinch_center=(Vector2(pts[0])+Vector2(pts[1]))*0.5
        else:
            touch_points.erase(e.index); touch_last_positions.erase(e.index)
            if touch_points.size()<2: pinch_active=false
            if touch_points.size()==1:
                primary_touch_id=int(touch_points.keys()[0]); touch_last_positions[primary_touch_id]=touch_points[primary_touch_id]; dragging=true
            else: dragging=false
    elif e is InputEventScreenDrag:
        touch_points[e.index]=e.position
        var previous:Vector2=Vector2(touch_last_positions.get(e.index,e.position)); touch_last_positions[e.index]=e.position
        if touch_points.size()==1 and not pinch_active: cam -= (e.position-previous)/zoom
        elif touch_points.size()>=2:
            var pts:=touch_points.values(); var c:Vector2=(Vector2(pts[0])+Vector2(pts[1]))*0.5; var dist:float=Vector2(pts[0]).distance_to(Vector2(pts[1]))
            if pinch_distance>1.0: zoom=clamp(zoom*clamp(dist/pinch_distance,0.72,1.38),0.45,2.4)
            cam -= (c-pinch_center)/zoom; pinch_center=c; pinch_distance=dist
    elif e is InputEventMouseButton and e.pressed:
        if e.button_index==MOUSE_BUTTON_WHEEL_UP: zoom=clamp(zoom*1.12,0.45,2.4)
        elif e.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom=clamp(zoom/1.12,0.45,2.4)
        elif e.button_index==MOUSE_BUTTON_LEFT: dragging=true
    elif e is InputEventMouseMotion and dragging and e.button_mask&MOUSE_BUTTON_MASK_LEFT: cam -= e.relative/zoom
    elif e is InputEventMouseButton and not e.pressed and e.button_index==MOUSE_BUTTON_LEFT: dragging=false
    elif e is InputEventKey and e.pressed:
        if e.keycode==KEY_SPACE: paused=not paused
        elif e.keycode==KEY_1: sim_speed=0.5
        elif e.keycode==KEY_2: sim_speed=1.0
        elif e.keycode==KEY_3: sim_speed=2.0
        elif e.keycode==KEY_4: sim_speed=4.0
        elif e.keycode==KEY_TAB: selected_kingdom=(selected_kingdom+1)%max(1,kingdoms.size())

func _on_viewport_size_changed()->void:
    var size:=get_viewport_rect().size
    is_portrait=size.y>size.x*1.08
    queue_redraw()
