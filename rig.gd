extends RefCounted
## Tek parça (iskeletsiz) karakter modeline kodla basit bir insan iskeleti takar.
## Model: önü +X, yukarı +Y, sağ taraf +Z, ortalanmış (yapay zekâ modelleri böyle geliyor).
## Eklem yerleri characters.gd'deki "rig" sözlüğünden gelir: Vector2(yana uzaklık, yükseklik), model biriminde.
## Köşe ağırlıkları en yakın iki kemiğe, kemik çizgisine uzaklığa göre paylaştırılır.

const BONES := ["hips", "spine", "head", "arm_r", "fore_r", "arm_l", "fore_l", "leg_r", "shin_r", "leg_l", "shin_l"]
const PARENT := [-1, 0, 1, 1, 3, 1, 5, 0, 7, 0, 9]
# Kemiğin kabaca kalınlığı: uzaklık buna bölünür ki gövde köşeleri ince kol kemiğine kaçmasın.
const RADIUS := [0.13, 0.13, 0.16, 0.045, 0.04, 0.045, 0.04, 0.08, 0.07, 0.08, 0.07]
enum {HIPS, SPINE, HEAD, ARM_R, FORE_R, ARM_L, FORE_L, LEG_R, SHIN_R, LEG_L, SHIN_L}

static var _cache := {} # model yolu -> [ağırlıklı mesh, skin]


static func _p(v: Vector2, side: float) -> Vector3:
	return Vector3(0, v.y, v.x * side)


## Her kemiğin [başlangıç, bitiş] noktası (model uzayında).
static func segments(j: Dictionary) -> Array:
	var s := [
		[Vector3(0, j.hip.y, 0), Vector3(0, j.belt, 0)],
		[Vector3(0, j.belt, 0), Vector3(0, j.neck, 0)],
		[Vector3(0, j.neck, 0), Vector3(0, 0.5, 0)],
	]
	for side in [1.0, -1.0]:
		s.append([_p(j.shoulder, side), _p(j.elbow, side)])
		s.append([_p(j.elbow, side), _p(j.hand, side)])
	for side in [1.0, -1.0]:
		s.append([_p(j.hip, side), _p(j.knee, side)])
		s.append([_p(j.knee, side), _p(Vector2(j.ankle.x, -0.5), side)])
	return s


## mi'nin yanına Skeleton3D ekler ve mesh'i ona bağlar.
static func build(mi: MeshInstance3D, j: Dictionary, key: String) -> Skeleton3D:
	var segs := segments(j)
	var sk := Skeleton3D.new()
	for i in BONES.size():
		sk.add_bone(BONES[i])
		sk.set_bone_parent(i, PARENT[i])
		var local: Vector3 = segs[i][0] - (segs[PARENT[i]][0] if PARENT[i] >= 0 else Vector3.ZERO)
		sk.set_bone_rest(i, Transform3D(Basis(), local))
		sk.set_bone_pose_position(i, local)
	mi.get_parent().add_child(sk)
	if not _cache.has(key):
		_cache[key] = [_skinned_mesh(mi.mesh, segs), sk.create_skin_from_rest_transforms()]
	mi.mesh = _cache[key][0]
	mi.skin = _cache[key][1]
	mi.skeleton = mi.get_path_to(sk)
	return sk


static func _skinned_mesh(src: ArrayMesh, segs: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr := src.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		bones.resize(verts.size() * 4)
		weights.resize(verts.size() * 4)
		for vi in verts.size():
			var v := verts[vi]
			var b1 := 0; var d1 := INF # en yakın
			var b2 := 0; var d2 := INF # ikinci en yakın
			for b in segs.size():
				var d: float = Geometry3D.get_closest_point_to_segment(v, segs[b][0], segs[b][1]).distance_to(v) / RADIUS[b]
				if d < d1:
					b2 = b1; d2 = d1
					b1 = b; d1 = d
				elif d < d2:
					b2 = b; d2 = d
			var w1 := 1.0 / (pow(d1, 4) + 1e-6)
			var w2 := 1.0 / (pow(d2, 4) + 1e-6)
			bones[vi * 4] = b1
			bones[vi * 4 + 1] = b2
			weights[vi * 4] = w1 / (w1 + w2)
			weights[vi * 4 + 1] = w2 / (w1 + w2)
		arr[Mesh.ARRAY_BONES] = bones
		arr[Mesh.ARRAY_WEIGHTS] = weights
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(si, src.surface_get_material(si))
	return out
