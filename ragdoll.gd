## Ragdoll (yalnız görüntü, her makinede ayrı): karakter iskeletine kod ile fizik kemikleri kurar.
## Ağ yok: vuruşlar ve patlamalar poke() ile buraya düşer; ölen karakter yakınındaki son darbelerle savrulur.
## Tüm karakter modelleri aynı iskeleti paylaşır (Hips, Torso, Head, UpperArm.L ...).
extends RefCounted

# kemik -> [yarıçap oranı, kütle, eklem salınımı (derece)]
const BONES := {
	"Body_2": [0.16, 6.0, 0.0], "Hips": [0.15, 3.0, 15.0], "Abdomen": [0.15, 4.0, 25.0], "Torso": [0.18, 6.0, 25.0], "Head": [0.17, 3.0, 40.0],
	"UpperArm.L": [0.07, 1.5, 80.0], "LowerArm.L": [0.06, 1.0, 70.0], "UpperArm.R": [0.07, 1.5, 80.0], "LowerArm.R": [0.06, 1.0, 70.0],
	"UpperLeg.L": [0.09, 3.0, 60.0], "LowerLeg.L": [0.075, 2.0, 70.0], "UpperLeg.R": [0.09, 3.0, 60.0], "LowerLeg.R": [0.075, 2.0, 70.0],
}
const WORLD_MASK := 1 # zemin ve duvarlar
const POKE_LIFE := 0.8 # ölüm haberi ağdan gecikmeli gelir

static var pokes: Array = [] # [konum, itme, zaman]
static var live: Array = [] # açık simülatörler (en eskisi önce)


## Kalite ayarına göre aynı anda kaç ragdoll: Düşük = yok (eski ölüm animasyonu).
static func cap() -> int:
	var s: Node = Engine.get_main_loop().root.get_node_or_null("/root/Settings") if Engine.get_main_loop() else null
	var q: int = s.quality if s else 2
	return [0, 6, 16][clampi(q, 0, 2)]


## Darbe kaydı: mermi, kılıç, patlama. r > 0: patlama yarıçapı (uzaklıkla azalır, yukarı fırlatır).
static func poke(at: Vector3, push: Vector3, r := 0.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	while not pokes.is_empty() and now - pokes[0][2] > POKE_LIFE:
		pokes.pop_front()
	pokes.append([at, push, now, r])
	for s in live: # zaten yerde yatanlar da patlamayla savrulsun
		if is_instance_valid(s):
			_push(s, [[at, push, now, r]])


## Modeli ragdoll'a çevirir; dönen simülatörü stop() ile geri alırsın. cap dolmuşsa en eskisi donar.
static func start(model: Node3D, extra := Vector3.ZERO) -> PhysicalBoneSimulator3D:
	if cap() <= 0:
		return null
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return null
	var sk: Skeleton3D = skels[0]
	for a in model.find_children("*", "AnimationPlayer", true, false):
		pass # durdurma: iskelet kirli kalmazsa değiştiriciler (ragdoll) çalışmıyor
	var sim := PhysicalBoneSimulator3D.new()
	sk.add_child(sim)
	for bn in BONES:
		var i := sk.find_bone(bn)
		if i < 0:
			continue
		var cfg: Array = BONES[bn]
		var kids := sk.get_bone_children(i)
		var len_ := 0.25
		for c in kids:
			if sk.get_bone_name(c) in BONES or bn.begins_with("Lower"):
				len_ = sk.get_bone_rest(c).origin.length()
				break
		if bn.begins_with("Lower") and kids.is_empty():
			len_ = 0.4
		if bn == "Head":
			len_ = 0.35
		elif bn == "Body_2": # leğen: bacaklar ve Hips buna bağlı (kök kemik, eklemsiz)
			len_ = 0.2
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bn
		pb.bone_name = bn
		pb.mass = cfg[1]
		pb.collision_layer = 0
		pb.collision_mask = WORLD_MASK
		pb.linear_damp = 0.4
		pb.angular_damp = 2.0
		pb.friction = 0.9
		if cfg[2] > 0.0:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF # koni eklemi Godot fiziğinde patlıyor
			for ax in ["x", "y", "z"]:
				var lim: float = cfg[2] * (0.5 if ax == "y" else 1.0) # y: kemik boyu ekseni (burulma)
				pb.set("joint_constraints/%s/angular_limit_enabled" % ax, true)
				pb.set("joint_constraints/%s/angular_limit_upper" % ax, lim)
				pb.set("joint_constraints/%s/angular_limit_lower" % ax, -lim)
		var cs := CollisionShape3D.new()
		var cap_ := CapsuleShape3D.new()
		cap_.radius = cfg[0]
		cap_.height = maxf(len_, cap_.radius * 2.0 + 0.01)
		cs.shape = cap_
		cs.position = Vector3(0, len_ * 0.5, 0) # kemiğin +Y'si uzunluk yönü
		pb.add_child(cs)
		# Ağaca girmeden önce: eklem ağaca girerken o anki konumlarla kurulur; yanlış konum = patlayan ragdoll.
		# İskelet ölçeği gövdeye miras kalır, şekiller iskelet biriminde.
		var xf := sk.get_bone_global_pose(i)
		pb.transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
		sim.add_child(pb)
	# Ayaklar kökten sarkıyor (IK kemikleri): baldırı izlesin, yoksa yerde kalır.
	var feet := Feet.new()
	sk.add_child(feet)
	feet.setup(sk)
	var body := model.get_parent()
	while body and not body is PhysicsBody3D:
		body = body.get_parent()
	if body: # kendi kapsülümüzün içinde doğuyoruz: ona çarpıp fırlamasın
		for b in sim.get_children():
			if b is PhysicalBone3D:
				b.add_collision_exception_with(body)
	sim.physical_bones_start_simulation()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.extra_cull_margin = 4.0 # kemikler gövdeden uzaklaşınca model kırpılmasın
	_push(sim, pokes, extra)
	live.append(sim)
	var n := cap()
	while live.size() > n:
		var old: Node = live.pop_front()
		if is_instance_valid(old):
			for b in old.get_children():
				if b is PhysicalBone3D:
					b.linear_velocity = Vector3.ZERO
					b.angular_velocity = Vector3.ZERO
					b.gravity_scale = 0.0 # dondur: işlem yükü bitsin
	return sim


## Geri al (oyuncu yeniden doğunca): animasyon kaldığı yerden sürer.
static func stop(sim: PhysicalBoneSimulator3D) -> void:
	if sim == null or not is_instance_valid(sim):
		return
	live.erase(sim)
	var sk := sim.get_parent()
	sim.physical_bones_stop_simulation()
	for n in sk.get_children():
		if n is Feet:
			n.queue_free()
	sim.queue_free()
	for a in sk.owner.find_children("*", "AnimationPlayer", true, false) if sk.owner else []:
		a.play()


## Yere batır: zemin çarpışması kapanır, yerçekimi gövdeyi aşağı çeker (kor dağılmasıyla birlikte).
static func sink(sim: PhysicalBoneSimulator3D) -> void:
	if sim == null or not is_instance_valid(sim):
		return
	live.erase(sim)
	for b in sim.get_children():
		if b is PhysicalBone3D:
			b.collision_mask = 0
			b.linear_velocity = Vector3.ZERO
			b.angular_velocity *= 0.2
			b.gravity_scale = 0.6
			b.linear_damp = 2.0 # yavaşça toprağa gömülür


static func _push(sim: PhysicalBoneSimulator3D, list: Array, extra := Vector3.ZERO) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var bones := sim.get_children().filter(func(b): return b is PhysicalBone3D)
	if bones.is_empty():
		return
	var core: PhysicalBone3D = bones[0]
	if extra != Vector3.ZERO:
		for b in bones:
			b.apply_central_impulse(extra * b.mass)
	for p in list:
		if now - p[2] > POKE_LIFE:
			continue
		var at: Vector3 = p[0]
		var r: float = p[3]
		if r > 0.0: # patlama: merkezden dışarı ve yukarı, uzaklıkla azalır
			var d := core.global_position - at
			if d.length() > r * 1.6:
				continue
			var f: float = p[1].length() * (1.0 - clampf(d.length() / (r * 1.6), 0.0, 1.0))
			var v := (d.normalized() + Vector3.UP * 1.2).normalized() * f
			for b in bones:
				b.apply_central_impulse(v * b.mass)
				b.angular_velocity += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * f * 0.3
			continue
		# mermi / kılıç: en yakın kemiğe vurur, gövde biraz sürüklenir
		var best: PhysicalBone3D = null
		var bd := 1.5
		for b in bones:
			var dd: float = b.global_position.distance_to(at)
			if dd < bd:
				bd = dd
				best = b
		if best:
			best.apply_impulse(p[1] * best.mass * 2.0, at - best.global_position)
			for b in bones:
				b.apply_central_impulse(p[1] * b.mass * 0.35)


## Ayak kemikleri kökten sarkar: her karede baldırın ucuna yapıştır.
class Feet extends SkeletonModifier3D:
	var pairs := [] # [ayak, baldır, baldıra göre duruş]

	func setup(sk: Skeleton3D) -> void:
		for s in ["L", "R"]:
			var f := sk.find_bone("Foot." + s)
			var l := sk.find_bone("LowerLeg." + s)
			if f >= 0 and l >= 0:
				pairs.append([f, l, sk.get_bone_global_pose(l).affine_inverse() * sk.get_bone_global_pose(f)])

	func _process_modification() -> void:
		var sk := get_skeleton()
		for p in pairs:
			sk.set_bone_global_pose(p[0], sk.get_bone_global_pose(p[1]) * p[2])


## Ölmeden vurulunca: isabet noktasına en yakın uzuv (kafa, gövde, kol) darbe yönünde sarsılıp geri gelir.
static func flinch(model: Node3D, at: Vector3, push: Vector3) -> void:
	if model == null or cap() <= 0:
		return
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var sk: Skeleton3D = skels[0]
	var f: Flinch = null
	for c in sk.get_children():
		if c is Flinch:
			f = c
	if f == null:
		f = Flinch.new()
		sk.add_child(f)
	f.hit(at, push)


class Flinch extends SkeletonModifier3D:
	const PARTS := ["Head", "Torso", "UpperArm.L", "UpperArm.R", "Abdomen"]
	var amt := {} # kemik -> [eksen (iskelet uzayı), açı]

	func hit(at: Vector3, push: Vector3) -> void:
		var sk := get_skeleton()
		var local_at := sk.global_transform.affine_inverse() * at
		var best := -1
		var bd := INF
		for bn in PARTS:
			var i := sk.find_bone(bn)
			if i >= 0:
				var dd := sk.get_bone_global_pose(i).origin.distance_to(local_at)
				if dd < bd:
					bd = dd
					best = i
		if best < 0:
			return
		var p := sk.global_basis.inverse() * push
		var axis := Vector3.UP.cross(p).normalized()
		if axis == Vector3.ZERO:
			return
		var a := clampf(push.length() * 0.12, 0.15, 0.6)
		amt[best] = [axis, a]
		var t := sk.find_bone("Torso") # gövde de az sarsılsın
		if t >= 0 and t != best:
			amt[t] = [axis, a * 0.35]

	func _process_modification() -> void:
		var sk := get_skeleton()
		var dt := get_process_delta_time()
		for i in amt.keys():
			var v: Array = amt[i]
			v[1] = lerpf(v[1], 0.0, minf(1.0, dt * 9.0))
			if v[1] < 0.005:
				amt.erase(i)
				continue
			var g := sk.get_bone_global_pose(i)
			g.basis = Basis(v[0], v[1]) * g.basis
			sk.set_bone_global_pose(i, g)
