extends Node2D

const WORLD_W := 140
const WORLD_H := 86
const TILE := 24
const SPECIES := [
	{"name":"البشر","icon":"♟","color":Color("#e9c46a"),"food":1.0,"wood":1.0,"ore":1.0,"water":1.0,"biome":"all"},
	{"name":"الألف","icon":"✦","color":Color("#72d6a5"),"food":1.15,"wood":1.35,"ore":0.75,"water":1.0,"biome":"forest"},
	{"name":"الأقزام","icon":"◆","color":Color("#c8a27a"),"food":0.9,"wood":0.75,"ore":1.5,"water":0.9,"biome":"mountain"},
	{"name":"الأورك","icon":"●","color":Color("#b96a6a"),"food":1.3,"wood":0.8,"ore":1.1,"water":0.9,"biome":"plains"},
	{"name":"الهفلق","icon":"●","color":Color("#f2c879"),"food":1.2,"wood":1.1,"ore":0.8,"water":1.1,"biome":"plains"},
	{"name":"البدو","icon":"⌁","color":Color("#d8a15c"),"food":1.05,"wood":0.55,"ore":0.9,"water":1.4,"biome":"desert"},
	{"name":"أهل البحر","icon":"≈","color":Color("#58b8df"),"food":1.45,"wood":0.7,"ore":0.8,"water":1.5,"biome":"coast"},
	{"name":"التنانين القدماء","icon":"♢","color":Color("#c77dff"),"food":0.7,"wood":0.6,"ore":1.4,"water":0.8,"biome":"mountain"}
]

var rng := RandomNumberGenerator.new()
var terrain := []
var resources := []
var populations := []
var kingdoms := []
var selected_species := 0
var gold := 180
var faith := 70
var world_age := 1
var paused := false
var zoom := 0.82
var cam := Vector2.ZERO
var dragging := false
var drag_start := Vector2.ZERO
var hover_cell := Vector2i(-1,-1)
var event_text := "بدأت الخليقة... اختر سلالة ثم المس الخريطة لتضعها."
var event_timer := 0.0
var last_touch_distance := 0.0
var ui_font: Font
var card_rects := []
var world_rect := Rect2(18,92,900,610)

func _ready():
	rng.randomize()
	ui_font = ThemeDB.fallback_font
	_generate_world()
	queue_redraw()

func _generate_world():
	terrain.clear(); resources.clear(); populations.clear(); kingdoms.clear()
	for y in range(WORLD_H):
		terrain.append([]); resources.append([]); populations.append([])
		for x in range(WORLD_W):
			var n := sin(x*0.11)+cos(y*0.13)+sin((x+y)*0.045)
			var edge := min(min(x,WORLD_W-1-x),min(y,WORLD_H-1-y))
			var t := 0
			if edge < 4 + int((sin(x*0.2)+1)*1.2): t=0
			elif n > 1.15: t=4
			elif n < -1.1: t=1
			elif n > 0.25: t=2
			elif n < -0.35: t=3
			else: t=2
			terrain[y].append(t)
			var r := {"wood":0,"ore":0,"food":0,"gold":0}
			if t==2 or t==3: r.wood = rng.randi_range(1,3)
			if t==4: r.ore = rng.randi_range(2,5)
			if t==2: r.food = rng.randi_range(2,5)
			if t==1: r.food = rng.randi_range(1,3); r.ore=rng.randi_range(0,2)
			if t==0: r.food=rng.randi_range(1,3)
			if rng.randf()<0.035: r.gold=1
			resources[y].append(r)
			populations[y].append(null)
	for i in range(5): _spawn_kingdom(i)
	for i in range(90):
		var p := Vector2i(rng.randi_range(5,WORLD_W-6),rng.randi_range(5,WORLD_H-6))
		if terrain[p.y][p.x] != 0 and populations[p.y][p.x]==null:
			populations[p.y][p.x]={"species":rng.randi_range(0,7),"pop":rng.randi_range(4,18),"age":1,"kingdom":rng.randi_range(0,4)}

func _spawn_kingdom(i:int):
	var names=["نوران","أراضي السنديان","ممالك الحديد","رايات الرماد","مدن السراب"]
	var p=Vector2i(rng.randi_range(15,WORLD_W-16),rng.randi_range(12,WORLD_H-13))
	while terrain[p.y][p.x]==0: p=Vector2i(rng.randi_range(15,WORLD_W-16),rng.randi_range(12,WORLD_H-13))
	var sp=i%8
	populations[p.y][p.x]={"species":sp,"pop":28,"age":5,"kingdom":i}
	kingdoms.append({"name":names[i],"species":sp,"capital":p,"territory":12,"power":20+i*4,"gold":80,"food":60,"tech":1,"alive":true})

func _process(delta):
	event_timer += delta
	if not paused and event_timer > 0.8:
		event_timer=0
		_sim_tick()
	queue_redraw()

func _sim_tick():
	world_age += 1
	gold += 3
	faith = clamp(faith + rng.randi_range(-1,2),0,100)
	for k in kingdoms:
		if not k.alive: continue
		k.food += 3
		k.gold += 2
		k.tech += 0.002
		k.power += 0.05
	for y in range(1,WORLD_H-1):
		for x in range(1,WORLD_W-1):
			var p=populations[y][x]
			if p==null: continue
			var env=_env_bonus(terrain[y][x],p.species)
			p.pop = clamp(p.pop + env*0.12,1,80)
			p.age += 1
			if rng.randf()<0.008 and p.pop>10:
				var q=Vector2i(x+rng.randi_range(-2,2),y+rng.randi_range(-2,2))
				if terrain[q.y][q.x]!=0 and populations[q.y][q.x]==null:
					populations[q.y][q.x]={"species":p.species,"pop":2,"age":1,"kingdom":p.kingdom}
					kingdoms[p.kingdom].territory += 1
	if world_age%20==0: _story_event()

func _env_bonus(t:int,s:int)->float:
	var species=SPECIES[s]
	if t==1 and species.biome=="desert": return 2.2
	if t==2 and species.biome=="forest": return 2.0
	if t==4 and species.biome=="mountain": return 2.5
	if t==3 and species.biome=="plains": return 1.7
	if t==0 and species.biome=="coast": return 2.6
	return 0.7

func _story_event():
	var events=["ظهرت قافلة تجارية على الحدود.","اكتشف المنقبون عرقًا غنيًا من الحديد.","اجتاحت عاصفة السهول وأعادت توزيع الموارد.","أقيم مهرجان في إحدى القرى وارتفعت المعنويات.","عثر المستكشفون على أطلال حضارة منسية."]
	event_text=events[rng.randi_range(0,events.size()-1)]

func _input(e):
	if e is InputEventMouseMotion:
		if world_rect.has_point(e.position): hover_cell=_screen_to_cell(e.position)
		if dragging: cam += e.relative/zoom
	if e is InputEventMouseButton:
		if e.button_index==MOUSE_BUTTON_LEFT:
			if e.pressed:
				dragging=true; drag_start=e.position
			else:
				if dragging and drag_start.distance_to(e.position)<10: _world_click(e.position)
				dragging=false
		if e.button_index==MOUSE_BUTTON_WHEEL_UP and e.pressed: _zoom_at(e.position,1.12)
		if e.button_index==MOUSE_BUTTON_WHEEL_DOWN and e.pressed: _zoom_at(e.position,0.89)
	if e is InputEventKey and e.pressed:
		if e.keycode==KEY_SPACE: paused=!paused
		if e.keycode==KEY_R: _generate_world()
	if e is InputEventScreenTouch:
		if e.pressed:
			if e.index==0: dragging=true; drag_start=e.position
			elif e.index==1: last_touch_distance=0
		else:
			if e.index==0:
				if dragging and drag_start.distance_to(e.position)<18: _world_click(e.position)
				dragging=false
	if e is InputEventScreenDrag:
		if e.index==0 and dragging: cam += e.relative/zoom
		elif e.index==1:
			var d=e.position.distance_to(drag_start)
			if last_touch_distance>0: _zoom_at(e.position,clamp(d/last_touch_distance,0.9,1.1))
			last_touch_distance=d

func _zoom_at(pos:Vector2,factor:float):
	var before=(pos-world_rect.position)/zoom+cam
	zoom=clamp(zoom*factor,0.45,1.65)
	var after=(pos-world_rect.position)/zoom+cam
	cam += before-after

func _screen_to_cell(pos:Vector2)->Vector2i:
	var w=(pos-world_rect.position)/zoom+cam
	return Vector2i(floor(w.x/TILE),floor(w.y/TILE))

func _world_click(pos:Vector2):
	if not world_rect.has_point(pos): return
	var c=_screen_to_cell(pos)
	if c.x<0 or c.y<0 or c.x>=WORLD_W or c.y>=WORLD_H: return
	if terrain[c.y][c.x]==0:
		event_text="الماء يمنع الاستيطان هنا. اختر أرضًا مناسبة."
		return
	var existing=populations[c.y][c.x]
	if existing:
		event_text="%s: عدد السكان %d — العمر %d جيل" % [SPECIES[existing.species].name,int(existing.pop),int(existing.age)]
		return
	if gold<12:
		event_text="لا يكفي الذهب لإرسال مستوطنين."
		return
	gold-=12
	var k=max(kingdoms.size()-1,0)
	populations[c.y][c.x]={"species":selected_species,"pop":5,"age":1,"kingdom":k}
	event_text="تم تأسيس مستوطنة %s. ستتغير خصائصها مع البيئة عبر الأجيال." % SPECIES[selected_species].name

func _draw():
	draw_rect(Rect2(0,0,1280,720),Color("#090d15"))
	_draw_header(); _draw_world(); _draw_sidebar()

func _draw_header():
	draw_rect(Rect2(0,0,1280,76),Color("#111827"))
	draw_string(ui_font,Vector2(26,35),"عالم الآلهة",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("#f7d774"))
	draw_string(ui_font,Vector2(26,59),"اصنع الحضارات... ثم شاهد التاريخ يكتبه الأحياء",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#94a3b8"))
	var stats=["العمر %d"%world_age,"الذهب %d"%gold,"الإيمان %d"%faith,"السكان %d"%_population_total()]
	var x=520
	for s in stats:
		draw_rect(Rect2(x,18,130,40),Color("#1b2535"),true)
		draw_string(ui_font,Vector2(x+12,43),s,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#e5e7eb")); x+=142
	draw_rect(Rect2(1090,16,78,42),Color("#263247"),true)
	draw_string(ui_font,Vector2(1105,43),"▶" if paused else "Ⅱ",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#f7d774"))

func _draw_world():
	draw_rect(world_rect,Color("#0c111a"),true)
	for y in range(WORLD_H):
		for x in range(WORLD_W):
			var sp=Vector2(x*TILE,y*TILE)-cam
			var r=Rect2(world_rect.position+sp*zoom,Vector2(TILE,TILE)*zoom+Vector2.ONE)
			if not world_rect.intersects(r): continue
			draw_rect(r,_terrain_color(terrain[y][x]),true)
			if terrain[y][x]==3 and zoom>0.55:
				draw_circle(r.position+r.size*0.5,r.size.x*0.18,Color("#2f6b4f"))
				draw_line(r.position+Vector2(r.size.x*.5,r.size.y*.35),r.position+Vector2(r.size.x*.5,r.size.y*.8),Color("#6b4f36"),max(1,zoom))
			if terrain[y][x]==4 and zoom>0.55:
				draw_colored_polygon(PackedVector2Array([r.position+Vector2(r.size.x*.5,r.size.y*.15),r.position+Vector2(r.size.x*.85,r.size.y*.82),r.position+Vector2(r.size.x*.2,r.size.y*.82)]),Color("#7b8794"))
			var res=resources[y][x]
			if res.gold>0: draw_circle(r.position+Vector2(r.size.x*.78,r.size.y*.25),max(2,3*zoom),Color("#f7d774"))
			if res.ore>2 and zoom>0.7: draw_circle(r.position+Vector2(r.size.x*.25,r.size.y*.72),max(2,2.5*zoom),Color("#9aa6b2"))
			var p=populations[y][x]
			if p:
				var col=SPECIES[p.species].color
				draw_circle(r.position+r.size*.5,max(3,7*zoom),Color("#10141d"))
				draw_circle(r.position+r.size*.5,max(2.5,5*zoom),col)
				if zoom>0.8: draw_string(ui_font,r.position+Vector2(4,5+10*zoom),SPECIES[p.species].icon,HORIZONTAL_ALIGNMENT_LEFT,-1,int(12*zoom),Color("#ffffff"))
	if hover_cell.x>=0 and hover_cell.y>=0 and hover_cell.x<WORLD_W and hover_cell.y<WORLD_H:
		var q=Rect2(world_rect.position+(Vector2(hover_cell)*TILE-cam)*zoom,Vector2(TILE,TILE)*zoom)
		draw_rect(q,Color("#f7d774"),false,2)
	draw_rect(world_rect,Color("#35445a"),false,2)

func _draw_sidebar():
	var panel=Rect2(936,92,326,610)
	draw_rect(panel,Color("#101722"),true)
	draw_string(ui_font,Vector2(960,124),"بطاقات الخلق",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("#f1f5f9"))
	draw_string(ui_font,Vector2(960,146),"اختر سلالة ثم المس الخريطة",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#8ea0b8"))
	card_rects.clear()
	for i in range(SPECIES.size()):
		var col=i%2; var row=int(i/2)
		var r=Rect2(952+col*150,160+row*86,140,76)
		card_rects.append(r)
		draw_rect(r,Color("#182231") if i!=selected_species else Color("#293a45"),true)
		draw_rect(r,Color("#f7d774") if i==selected_species else Color("#2c3b4d"),false,2)
		draw_circle(r.position+Vector2(30,38),20,SPECIES[i].color)
		draw_string(ui_font,r.position+Vector2(58,32),SPECIES[i].name,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#f8fafc"))
		draw_string(ui_font,r.position+Vector2(58,54),"تكيف تلقائي",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#8ea0b8"))
	var y=520
	draw_string(ui_font,Vector2(960,y),"آخر حدث",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#f7d774"))
	draw_rect(Rect2(952,y+14,294,62),Color("#182231"),true)
	draw_string(ui_font,Vector2(964,y+38),event_text,HORIZONTAL_ALIGNMENT_LEFT,270,13,Color("#dbe4ef"))
	draw_string(ui_font,Vector2(960,615),"التحكم",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#f7d774"))
	draw_string(ui_font,Vector2(960,640),"سحب: تحريك الخريطة • عجلة: زوم",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#8ea0b8"))
	draw_string(ui_font,Vector2(960,663),"مسافة: إيقاف/تشغيل • R: عالم جديد",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#8ea0b8"))

func _unhandled_input(e):
	if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed:
		for i in range(card_rects.size()):
			if card_rects[i].has_point(e.position): selected_species=i; event_text="اخترت %s — ضعها في أي أرض مناسبة."%SPECIES[i].name; return
	if e is InputEventScreenTouch and e.pressed:
		for i in range(card_rects.size()):
			if card_rects[i].has_point(e.position): selected_species=i; event_text="اخترت %s — ضعها في أي أرض مناسبة."%SPECIES[i].name; return

func _terrain_color(t:int)->Color:
	return [Color("#182b36"),Color("#a67c52"),Color("#5d8a58"),Color("#3f6f4e"),Color("#596572")][t]

func _population_total()->int:
	var total=0
	for row in populations:
		for p in row:
			if p: total+=int(p.pop)
	return total
