extends Node2D

# Civilization layer v2: autonomous cities, armies, diplomacy, trade, rebellions and empires.
var world
var cities=[]
var armies=[]
var relations={}
var routes=[]
var timer:=0.0
var rng:=RandomNumberGenerator.new()

func _ready():
 rng.randomize();world=get_parent();seed()
func _process(delta):
 if world==null:return
 timer+=delta
 if not world.paused and timer>1.35/max(.5,world.sim_speed):timer=0;tick()
 queue_redraw()
func seed():
 for i in range(world.kingdoms.size()):
  var p=world._capital_pos(i)
  cities.append({"id":1000+i*10,"k":i,"name":["أورين","فالدار","ميراث","كاردين","سيلفا"][i],"p":p,"level":3,"capital":true,"walls":2,"garrison":28,"pros":72.0})
  for j in range(2):
   var q=near(p,6+j*4);cities.append({"id":1001+i*10+j,"k":i,"name":["نيمرا","دارين","إيلورا","مارون","فيرا","أركون"][i*2+j],"p":q,"level":1,"capital":false,"walls":1,"garrison":8,"pros":52.0})
func tick():
 cities_tick();diplomacy_tick();army_tick();rebellion_tick();empire_tick();ruin_tick()
func cities_tick():
 for c in cities:
  if c.k<0 or c.k>=world.kingdoms.size():continue
  var k=world.kingdoms[c.k]
  if not k.alive:c.k=-1;continue
  c.pros=clamp(c.pros+(0.2 if k.food>0 else -0.8),5,100)
  if c.level<5 and c.pros>78 and k.wood>10 and k.ore>6 and rng.randf()<.05:c.level+=1;c.walls+=1;c.garrison+=6;k.wood-=10;k.ore-=6;world.event_text="تطورت مدينة %s إلى المستوى %d."%[c.name,c.level]
func diplomacy_tick():
 for i in range(world.kingdoms.size()):
  if not world.kingdoms[i].alive:continue
  for j in range(i):
   if not world.kingdoms[j].alive:continue
   var key=relkey(i,j);var v=float(relations.get(key,0))+rng.randf_range(-1.5,1.8);relations[key]=clamp(v,-100,100)
   if v>68 and not world.kingdoms[i].allies.has(j):world.kingdoms[i].allies.append(j);world.kingdoms[j].allies.append(i);world.event_text="تحالف بين %s و%s."%[world.kingdoms[i].name,world.kingdoms[j].name]
   if v< -60 and not world.kingdoms[i].wars.has(j) and rng.randf()<.04:world.kingdoms[i].wars.append(j);world.kingdoms[j].wars.append(i);world.event_text="اندلعت الحرب بين %s و%s."%[world.kingdoms[i].name,world.kingdoms[j].name]
   if v>35 and not route(i,j):routes.append({"a":i,"b":j,"v":rng.randi_range(2,7)})
 for r in routes:
  if world.kingdoms[r.a].alive and world.kingdoms[r.b].alive:world.kingdoms[r.a].gold+=r.v;world.kingdoms[r.b].gold+=r.v
func army_tick():
 for a in armies:
  if a.s<=0:continue
  var c=target(a.k,a.target,a.p)
  if c.is_empty():a.s=0;continue
  a.p+=Vector2i(sign(c.p.x-a.p.x),sign(c.p.y-a.p.y))
  if a.p.distance_to(c.p)<=1.2:a.siege+=1;c.garrison=max(0,c.garrison-rng.randi_range(2,5));a.s-=rng.randi_range(0,2);if c.garrison<=0 and a.siege>=3:c.k=a.k;c.garrison=10;a.siege=0;a.target=-1;world.event_text="استولت %s على مدينة %s."%[world.kingdoms[a.k].name,c.name]
 for k in world.kingdoms:
  if k.alive and not k.wars.is_empty() and armies.size()<18 and rng.randf()<.22:armies.append({"k":k.id,"p":world._capital_pos(k.id),"s":rng.randi_range(22,48),"target":k.wars[0],"siege":0})
func rebellion_tick():
 for k in world.kingdoms:
  if not k.alive or k.stability>24 or rng.randf()>.035:continue
  for c in cities:
   if c.k==k.id and not c.capital:
    var id=world.kingdoms.size();c.k=id;c.capital=true;c.garrison=14;world.kingdoms.append({"id":id,"name":"مملكة الفجر الجديد","s":k.s,"r":-1,"capital":c.id,"cities":[],"territory":10,"power":24.0,"gold":35,"food":30,"wood":8,"ore":8,"tech":0.0,"level":1,"faith":40,"alive":true,"empire":false,"stability":60.0,"wars":[k.id],"allies":[]});k.wars.append(id);k.stability=45;k.territory=max(0,k.territory-10);world.event_text="ثورة أسست مملكة جديدة: مملكة الفجر الجديد.";break
func empire_tick():
 for k in world.kingdoms:
  if k.alive and k.cities.size()>=4 and k.territory>=45 and k.level>=4 and not k.empire:k.empire=true;k.power+=30;world.event_text="توّجت %s نفسها إمبراطورية."%k.name
func ruin_tick():
 for r in world.ruins:
  if r.found:continue
  for c in cities:
   if c.k>=0 and c.p.distance_to(r.p)<4 and rng.randf()<.07:r.found=true;world.kingdoms[c.k].gold+=10;world.kingdoms[c.k].tech+=3;world.event_text="اكتشفت %s آثارًا قديمة قرب %s."%[world.kingdoms[c.k].name,c.name];break
func near(o,d):
 for i in range(40):
  var p=o+Vector2i(rng.randi_range(-d,d),rng.randi_range(-d,d))
  if p.x>2 and p.y>2 and p.x<world.WORLD_W-3 and p.y<world.WORLD_H-3 and world.terrain[p.y][p.x]!=0:return p
 return o
func target(k,t,p):
 var best={};var bd=99999.0
 for c in cities:
  if c.k==t:
   var d=p.distance_to(c.p)
   if d<bd:bd=d;best=c
 return best
func relkey(a,b):return "%d:%d"%[min(a,b),max(a,b)]
func route(a,b):
 for r in routes:
  if (r.a==a and r.b==b) or (r.a==b and r.b==a):return true
 return false
func _draw():
 if world==null:return
 for c in cities:
  if c.k<0 or c.k>=world.kingdoms.size():continue
  var p=world.WORLD_RECT.position+(Vector2(c.p)*world.TILE-world.cam)*world.zoom+Vector2(world.TILE,world.TILE)*world.zoom*.5
  draw_circle(p,max(2,(9 if c.capital else 5)*world.zoom),world.S[world.kingdoms[c.k].species].color)
 for a in armies:
  if a.s<=0 or a.k<0 or a.k>=world.kingdoms.size():continue
  var p=world.WORLD_RECT.position+(Vector2(a.p)*world.TILE-world.cam)*world.zoom+Vector2(world.TILE,world.TILE)*world.zoom*.5
  draw_circle(p,max(2,4*world.zoom),Color("#f4f1de"))
  if a.siege>0:draw_arc(p,8*world.zoom,0,TAU,12,Color("#f7d774"),max(1,world.zoom))
