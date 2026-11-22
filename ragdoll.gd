## Ragdoll (yalnız görüntü, her makinede ayrı): karakter iskeletine gerçekçi ağırlık, doğru kütle merkezi
## (body_offset / joint_offset), anatomik 6DOF eklem sınırları ve otomatik yerleşme (settler) ile fizik kurar.
## Ağ yok: vuruşlar ve patlamalar poke() ile buraya düşer; ölen karakter yakınındaki son darbelerle savrulur.
extends RefCounted

# kemik -> [yarıçap, kütle, [x_min, x_max], [y_min, y_max], [z_min, z_max]] (derece cinsinden anatomik sınırlar)
const BONES := {
	"Body_2":     [0.15, 7.0, [0.0, 0.0],     [0.0, 0.0],     [0.0, 0.0]],
	"Hips":       [0.14, 4.0, [-10.0, 10.0],  [-8.0, 8.0],    [-10.0, 10.0]],
	"Abdomen":    [0.15, 5.0, [-18.0, 22.0],  [-12.0, 12.0],  [-14.0, 14.0]],
	"Torso":      [0.18, 7.0, [-18.0, 24.0],  [-14.0, 14.0],  [-16.0, 16.0]],
	"Head":       [0.17, 3.2, [-26.0, 32.0],  [-32.0, 32.0],  [-20.0, 20.0]],
	"UpperArm.L": [0.068, 1.8, [-60.0, 80.0], [-25.0, 25.0],  [-40.0, 65.0]],
	"LowerArm.L": [0.056, 1.2, [-8.0, 105.0], [-10.0, 10.0],  [-10.0, 10.0]],
	"UpperArm.R": [0.068, 1.8, [-60.0, 80.0], [-25.0, 25.0],  [-65.0, 40.0]],
	"LowerArm.R": [0.056, 1.2, [-8.0, 105.0], [-10.0, 10.0],  [-10.0, 10.0]],
	"UpperLeg.L": [0.09, 3.4, [-68.0, 32.0],  [-16.0, 16.0],  [-20.0, 32.0]],
	"LowerLeg.L": [0.072, 2.2, [-108.0, 6.0], [-8.0, 8.0],    [-8.0, 8.0]],
	"UpperLeg.R": [0.09, 3.4, [-68.0, 32.0],  [-16.0, 16.0],  [-32.0, 20.0]],
	"LowerLeg.R": [0.072, 2.2, [-108.0, 6.0], [-8.0, 8.0],    [-8.0, 8.0]],
}
const WORLD_MASK := 1 # zemin ve duvarlar
const POKE_LIFE := 0.8 # ölüm haberi ağdan gecikmeli gelir

static var pokes: Array = [] # [konum, itme, zaman, yarıçap]
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
			_wake(s)
			_push(s, [[at, push, now, r]])


static func _wake(sim: PhysicalBoneSimulator3D) -> void:
	for c in sim.get_children():
		if c is PhysicalBone3D:
			c.gravity_scale = 1.0
	var sk := sim.get_parent()
	if sk:
		for c in sk.get_children():
			if c is Settler and c.sim == sim:
				c.wake()


## Kemik uzunluğu: doğrudan çocuğa mesafe (Neck / Fist dahil); yoksa güvenli anatomik varsayılan.
static func _bone_len(sk: Skeleton3D, i: int, bn: String) -> float:
	if bn == "Head":
		return 0.34
	if bn == "Body_2":
		return 0.18
	if bn == "Torso":
		var nk := sk.find_bone("Neck")
		if nk >= 0:
			return maxf(sk.get_bone_rest(nk).origin.length(), 0.36)
		return 0.44
	var kids := sk.get_bone_children(i)
	for c in kids:
		var cname := sk.get_bone_name(c)
		if cname in BONES or cname.begins_with("Fist") or cname.begins_with("Neck"):
			var l := sk.get_bone_rest(c).origin.length()
			if l > 0.08:
				return l
	if bn.begins_with("LowerLeg"):
		return 0.42
	if bn.begins_with("LowerArm"):
		return 0.38
	return 0.28


## Modeli ragdoll'a çevirir; dönen simülatörü stop() ile geri alırsın. cap dolmuşsa en eskisi donar.
static func start(model: Node3D, extra := Vector3.ZERO) -> PhysicalBoneSimulator3D:
	if cap() <= 0:
		return null
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return null
	var sk: Skeleton3D = skels[0]
	# Önceden kalma Flinch değiştiricisini temizle: ragdoll kemikleriyle çakışıp titreme yapmasın
	for ch in sk.get_children():
		if ch is Flinch:
			ch.amt.clear()
	var sim := PhysicalBoneSimulator3D.new()
	sk.add_child(sim)
	for bn in BONES:
		var i := sk.find_bone(bn)
		if i < 0:
			continue
		var cfg: Array = BONES[bn]
		var len_ := _bone_len(sk, i, bn)
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bn
		pb.bone_name = bn
		pb.mass = cfg[1]
		pb.collision_layer = 0
		pb.collision_mask = WORLD_MASK
		pb.linear_damp = 0.45
		pb.angular_damp = 2.2
		pb.friction = 0.95
		pb.bounce = 0.02

		# Doğru kütle merkezi: gövde kemiğin ortasında, eklem kemiğin kökünde (spagetti ve dönme hatasını önler)
		var mid := Vector3(0.0, len_ * 0.5, 0.0)
		pb.body_offset = Transform3D(Basis.IDENTITY, mid)
		pb.joint_offset = Transform3D(Basis.IDENTITY, -mid)

		var x_lim: Array = cfg[2]
		var y_lim: Array = cfg[3]
		var z_lim: Array = cfg[4]
		if x_lim[0] != x_lim[1] or y_lim[0] != y_lim[1] or z_lim[0] != z_lim[1]:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
			var lims := {"x": x_lim, "y": y_lim, "z": z_lim}
			for ax in ["x", "y", "z"]:
				var r: Array = lims[ax]
				pb.set("joint_constraints/%s/angular_limit_enabled" % ax, true)
				pb.set("joint_constraints/%s/angular_limit_lower" % ax, r[0])
				pb.set("joint_constraints/%s/angular_limit_upper" % ax, r[1])
				pb.set("joint_constraints/%s/angular_limit_softness" % ax, 0.85)
				pb.set("joint_constraints/%s/angular_restitution" % ax, 0.0)
				pb.set("joint_constraints/%s/angular_damping" % ax, 2.2)

		var cs := CollisionShape3D.new()
		var cap_ := CapsuleShape3D.new()
		cap_.radius = cfg[0]
		cap_.height = maxf(len_, cap_.radius * 2.0 + 0.02)
		cs.shape = cap_
		cs.position = Vector3.ZERO
		pb.add_child(cs)

		var xf := sk.get_bone_global_pose(i)
		pb.transform = Transform3D(xf.basis.orthonormalized(), xf.origin) * pb.body_offset
		sim.add_child(pb)

	# Ayaklar kökten sarkıyor (IK kemikleri): simülatörden sonra çalışıp baldırı izlesin
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
	var settler := Settler.new()
	settler.sim = sim
	sk.add_child(settler)

	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.extra_cull_margin = 4.0 # kemikler gövdeden uzaklaşınca model kırpılmasın
	_push(sim, pokes, extra)
	live.append(sim)
	var n := cap()
	while live.size() > n:
		var old: Node = live.pop_front()
		if is_instance_valid(old):
			_freeze(old)
	return sim


static func _freeze(sim: Node) -> void:
	for b in sim.get_children():
		if b is PhysicalBone3D:
			b.linear_velocity = Vector3.ZERO
			b.angular_velocity = Vector3.ZERO
			b.gravity_scale = 0.0


## Geri al (oyuncu yeniden doğunca): animasyon kaldığı yerden sürer.
static func stop(sim: PhysicalBoneSimulator3D) -> void:
	if sim == null or not is_instance_valid(sim):
		return
	live.erase(sim)
	var sk := sim.get_parent()
	sim.physical_bones_stop_simulation()
	for n in sk.get_children():
		if n is Feet or (n is Settler and n.sim == sim):
			n.queue_free()
	sim.queue_free()
	for a in sk.owner.find_children("*", "AnimationPlayer", true, false) if sk.owner else []:
		a.play()


## Yere batır: zemin çarpışması kapanır, yerçekimi gövdeyi aşağı çeker (kor dağılmasıyla birlikte).
static func sink(sim: PhysicalBoneSimulator3D) -> void:
	if sim == null or not is_instance_valid(sim):
		return
	live.erase(sim)
	var sk := sim.get_parent()
	if sk:
		for c in sk.get_children():
			if c is Settler and c.sim == sim:
				c.queue_free()
	for b in sim.get_children():
		if b is PhysicalBone3D:
			b.collision_mask = 0
			b.linear_velocity = Vector3.ZERO
			b.angular_velocity *= 0.15
			b.gravity_scale = 0.65
			b.linear_damp = 2.2 # yavaşça toprağa gömülür


static func _push(sim: PhysicalBoneSimulator3D, list: Array, extra := Vector3.ZERO) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var bones := sim.get_children().filter(func(b): return b is PhysicalBone3D)
	if bones.is_empty():
		return
	var core: PhysicalBone3D = bones[0]
	if extra != Vector3.ZERO:
		var clamped := extra.limit_length(12.0)
		for b in bones:
			b.apply_central_impulse(clamped * b.mass)
	for p in list:
		if now - p[2] > POKE_LIFE:
			continue
		var at: Vector3 = p[0]
		var r: float = p[3]
		if r > 0.0: # patlama: tutarlı savrulma (her kemiği rastgele ters yöne çevirip bükmez)
			var d := core.global_position - at
			if d.length() > r * 1.6:
				continue
			var f: float = minf(p[1].length() * (1.0 - clampf(d.length() / (r * 1.6), 0.0, 1.0)), 14.0)
			var dir := (d.normalized() + Vector3.UP * 0.95).normalized()
			var v := dir * f
			var spin_axis := Vector3.UP.cross(Vector3(dir.x, 0.0, dir.z))
			spin_axis = spin_axis.normalized() if spin_axis.length_squared() > 0.001 else Vector3.RIGHT
			for b in bones:
				b.apply_central_impulse(v * b.mass)
			core.angular_velocity += spin_axis * minf(f * 0.25, 3.0)
			continue
		# mermi / kılıç: en yakın kemiğe doğal darbe + gövdeye yumuşak geriye düşme
		var best: PhysicalBone3D = null
		var bd := 1.6
		for b in bones:
			var dd: float = b.global_position.distance_to(at)
			if dd < bd:
				bd = dd
				best = b
		if best:
			var imp: Vector3 = p[1].limit_length(9.0)
			best.apply_impulse(imp * best.mass * 1.25, (at - best.global_position).limit_length(0.25))
			for b in bones:
				b.apply_central_impulse(imp * b.mass * 0.30)


## Yerde sakinleşen ragdoll'ları otomatik dondurur: mikro titreme ve gereksiz fizik yükünü keser.
class Settler extends Node:
	var sim: PhysicalBoneSimulator3D
	var still_t := 0.0
	var age := 0.0
	var frozen := false

	func wake() -> void:
		still_t = 0.0
		frozen = false

	func _physics_process(dt: float) -> void:
		if frozen:
			return
		if sim == null or not is_instance_valid(sim):
			queue_free()
			return
		age += dt
		if age < 1.2:
			return
		var max_v := 0.0
		for b in sim.get_children():
			if b is PhysicalBone3D:
				max_v = maxf(max_v, b.linear_velocity.length() + b.angular_velocity.length() * 0.2)
		if max_v < 0.22 or age > 5.0:
			still_t += dt
			if still_t >= 0.75 or age > 5.5:
				frozen = true
				for b in sim.get_children():
					if b is PhysicalBone3D:
						b.linear_velocity = Vector3.ZERO
						b.angular_velocity = Vector3.ZERO
						b.gravity_scale = 0.0
		else:
			still_t = 0.0


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
