class_name Dungeon
extends Node3D

## 한 층을 만듭니다: 방을 놓고, 복도로 잇고, 바닥/벽 메시와 충돌체를 세우고,
## 적이 쓸 길찾기 격자를 채웁니다.
##
## 격자 한 칸은 1.5m 입니다. 방은 6~12칸(9~18m), 복도는 2칸(3m)이라
## 복도에서는 적 하나와 맞붙고 방에서는 여럿을 상대하게 됩니다. 공간이 전투의
## 난이도를 정하므로 이 두 숫자가 사실상 밸런스 손잡이입니다.

const TILE := 1.5
## 벽 높이. **아이가 작아 보이게 하는 값입니다.**
##
## 1.25m 짜리 캐릭터 옆에 1.6m 벽을 세우면 어른 허리쯤 되는 칸막이로 보여서,
## 아이가 작다는 느낌이 나지 않습니다. 2.8m 는 실제 방 천장 높이에 가깝고,
## 캐릭터의 2.2배라 화면에서 아이가 확실히 올려다보는 크기가 됩니다.
##
## 한동안 낮춰 뒀던 이유는 **가림** 때문이었습니다. 카메라를 두 배로 당긴 뒤로
## 사이에 낀 벽이 화면에서 차지하는 비율이 커져서, 남쪽 벽에 붙어 서면 벽
## 윗면이 화면 아래 절반을 덮었습니다. 지금은 캐릭터를 가리는 픽셀만 걷어내는
## 셰이더가 있어(wall_fade.gdshader) 높이를 되돌릴 수 있습니다.
const WALL_H := 2.8

## 텍스처 타일 크기(칸 단위). 그림 하나가 몇 칸을 덮을지입니다.
##
## 바닥 그림 한 장이 덮는 넓이. 5칸 x 3칸 = 7.5m x 4.5m 입니다.
##
## 처음에는 4칸 x 2칸(6m x 3m)이었는데, 그러면 한 화면에 같은 그림이 서너 장
## 들어가 **되풀이가 그대로 보입니다.** 늘리면 한 화면에 한 장 남짓이 되어
## 되풀이가 눈에 띄지 않고, 덤으로 무늬가 1.7배 커져 캐릭터 옆에서 덜
## 자잘해집니다. 대신 그림 한 픽셀이 덮는 실제 크기가 커져 흐려지는데,
## 수채화라 흐려지는 쪽이 오히려 어울립니다.
##
## 다만 끝까지 키우면(10.5m x 6m 까지 가 봤습니다) 판자 한 장이 어른 키만
## 해져서 아이가 거인의 마루에 선 것처럼 보입니다. 그 직전에서 멈춥니다.
##
## 벽 그림은 1.9 이고 벽 높이가 1.6m 이므로 2칸(3m)입니다.
const FLOOR_TILE_X := 5
const FLOOR_TILE_Y := 3
const WALL_TILE := 2

const FLOOR_TEXTURE := "res://assets/textures/floor_wood.png"
## 벽 색. 흰색에 아주 가까운 아이보리입니다. 순백으로 두면 밝은 곳에서 하얗게
## 타 버려 면이 어디서 꺾이는지 안 보입니다.
const WALL_SIDE_COLOR := Color(0.94, 0.91, 0.84)
## 벽면 UV 한 칸이 덮는 폭(m). 지금은 벽이 단색이라 쓰이지 않지만, 걸레받이의
## 나뭇결 간격이 이 값으로 정해집니다.
const PAPER_SPAN := 1.5
## 걸레받이. 벽 아래를 이만큼 두껍게 내밀고 바닥과 같은 나무로 칠합니다.
const BASE_H := 0.16
const BASE_OUT := 0.05
## 걸레받이. 벽 아래를 이만큼 두껍게 내밀고 바닥과 같은 나무로 칠합니다.
##
## 벽지가 바닥에 곧바로 닿으면 두 면이 맞붙은 자리가 종이처럼 얇아 보입니다.
## 실제 방에도 그 자리에는 걸레받이가 있고, 그 턱 하나가 벽에 두께를 줍니다.
## 윗면은 한 단계 낮춥니다. 내려다보는 카메라라 윗면이 가장 많이 보이는데,
## 옆면과 같은 밝기면 벽이 하나의 흰 덩어리가 되어 두께가 사라집니다.
const WALL_TOP_COLOR := Color(0.80, 0.76, 0.69)
## 아틀라스에 가로로 이어 붙인 벽 그림 수. 벽 칸마다 그중 하나를 고릅니다.
const WALL_SHADER := "res://assets/shaders/wall_fade.gdshader"
## 벽 그림. **아이 방 벽 한 장**입니다(1522 x 892).
##
## 한동안 벽돌(`wall2.png`)을 지도 오른쪽 절반에 같이 깔아 견줬습니다. 벽돌은
## 걷어냈습니다 - 가로줄이 뚜렷한 무늬는 이 그림체(외곽선과 넓은 단색 면)에서
## 벽을 **쌓아 올린 것**으로 읽히고, 벽이 배경이 아니라 주인공만큼 눈에
## 들어옵니다. 파일은 남겨 뒀습니다.
const WALL_TEXTURE := "res://assets/textures/wall3.png"
## **윗면은 무늬 없이 벽지의 종이색만** 칠합니다.
##
## 내려다보는 카메라라 벽의 윗면이 잘 보이는데, 거기에 알아볼 수 있는 그림
## (깃발·무지개·종이학)이 깔리면 **벽지가 벽에 붙어 있는 것이 아니라 위에
## 누워 있는 것**이 됩니다. 옆면은 실제로 벽지가 붙는 면이라 그림 그대로 씁니다.
##
## 다른 그림(회벽)을 깔아 봤더니 이번엔 **색이 달라 다른 재질**로 보였습니다.
## 무늬를 빼고 벽지의 바탕색을 그대로 쓰면 같은 벽의 윗면으로 읽힙니다.
## 값은 `wall3.png` 에서 가장 많이 나오는 색입니다(48%, 240/224/216).
const WALL_TOP_COLOR_TEX := ""
const WALL_TOP_TINT := Color(0.941, 0.878, 0.847)
## 벽 그림에 곱하는 색조. 셰이더가 색조를 그림에 곱하므로 1 에 가깝게 둡니다 -
## 어두운 색을 주면 걸레받이에서 겪은 것처럼 그림이 통째로 가라앉습니다.
const WALL_TEX_TINT := Color(0.98, 0.96, 0.92)
## 벽 그림이 가로로 한 번 도는 거리(m).
##
## 세로는 벽 높이(2.8m)에 **한 번** 들어가므로, 그림 비율(1522 x 892 =
## 1.706)을 지키려면 가로는 2.8 x 1.706 = 4.78m 입니다. 이 값을 줄이면
## 그림이 옆으로 눌리고, 늘리면 늘어납니다.
##
## **이 그림에는 알아볼 수 있는 물건들이 있습니다**(깃발·종이학·무지개).
## 민무늬와 달리 되풀이가 눈에 띄므로, 이 값이 곧 "같은 무지개가 몇 미터마다
## 나오나" 입니다 - 늘리면 덜 자주 나오지만 그림도 같이 커집니다.
const WALL_TEX_RUN := 4.78

var w := 46
var h := 46
var solid := PackedByteArray()
var rooms: Array[Rect2i] = []
var astar: AStarGrid2D

## 벽 재질들. 매 프레임 카메라/캐릭터 위치를 넣어 줘야 해서 들고 있습니다.
var wall_materials: Array[ShaderMaterial] = []

var _rng: RandomNumberGenerator


func _idx(x: int, y: int) -> int:
	return y * w + x


func is_solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return true
	return solid[_idx(x, y)] == 1


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * TILE, 0.0, (c.y + 0.5) * TILE)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE)), int(floor(p.z / TILE)))


# ---------------------------------------------------------------- 생성

func generate_test_room(rng: RandomNumberGenerator, side: int = 22) -> void:
	## **네모난 방 하나**만 파냅니다. 실험용입니다.
	##
	## 던전을 그대로 쓰면 방을 찾아다니는 데 시간이 들고, 무엇을 보려고
	## 들어왔는지가 흐려집니다. 벽 하나로 둘러싸인 빈 방이면 적 하나와
	## 나만 남습니다 - 그것이 실험입니다.
	_rng = rng
	w = side + 6
	h = side + 6
	solid = PackedByteArray()
	solid.resize(w * h)
	solid.fill(1)
	rooms.clear()
	var rect := Rect2i(3, 3, side, side)
	rooms.append(rect)
	_carve_rect(rect)
	_build_astar()
	_build_geometry()


func generate(floor_num: int, rng: RandomNumberGenerator) -> void:
	_rng = rng
	# 층이 깊어질수록 넓어집니다. 무한히 넓히면 이동 시간만 길어지므로 상한을 둡니다.
	# **판을 좁혔습니다**(48~64 → 34~44).
	#
	# 넓은 판에 방을 흩어 놓으면 그 사이가 전부 복도가 됩니다. 재 보니 가장
	# 긴 곧은 복도가 **27~52m** 였습니다 - 초당 3.1m 로 걸으면 한 복도에
	# 9~17초, 그동안 아무 일도 일어나지 않습니다.
	w = clampi(34 + floor_num, 34, 44)
	h = w
	solid = PackedByteArray()
	solid.resize(w * h)
	solid.fill(1)
	rooms.clear()

	# 방을 더, 더 크게 놓습니다. **방이 차지하는 비율**이 오르면 그만큼
	# 복도가 줄어듭니다.
	var want := clampi(7 + floor_num / 2, 7, 11)
	var tries := 0
	while rooms.size() < want and tries < 1400:
		tries += 1
		var rw := _rng.randi_range(8, 13)
		var rh := _rng.randi_range(7, 12)
		var rx := _rng.randi_range(2, w - rw - 3)
		var ry := _rng.randi_range(2, h - rh - 3)
		var rect := Rect2i(rx, ry, rw, rh)
		# 방 사이에 최소 두 칸의 벽을 남깁니다. 붙어 버리면 방 구분이 사라집니다.
		# 벽 한 칸만 남깁니다. 좁은 판에서 두 칸을 요구하면 방이 다 안 들어가
		# 그만큼 다시 흩어집니다. 한 칸이어도 벽은 서므로 구분은 그대로입니다.
		var padded := Rect2i(rx - 1, ry - 1, rw + 2, rh + 2)
		var clash := false
		for other in rooms:
			if padded.intersects(other):
				clash = true
				break
		if clash:
			continue
		rooms.append(rect)
		_carve_rect(rect)

	# **가장 가까운 방으로 이어 갑니다.**
	#
	# 예전에는 시작 방에서 **먼 순서로 정렬**해 그 차례대로 이었습니다.
	# 그러면 길이 판을 갈지자로 가로지르면서, 이어야 할 두 방이 매번 판의
	# 반대편에 있게 됩니다 - 긴 복도가 거기서 나왔습니다.
	#
	# 가까운 것부터 이으면 복도 하나하나가 짧아지고, 그러면서도 차례의 끝에
	# 남는 방은 시작에서 먼 방이라 **출구 자리로 쓰기에도 그대로** 맞습니다
	# (출구는 `rooms` 의 마지막 방에 섭니다).
	if rooms.size() > 2:
		var order: Array[Rect2i] = [rooms[0]]
		var left := rooms.slice(1)
		while left.size() > 0:
			var here: Vector2i = order[order.size() - 1].get_center()
			var best := 0
			var best_d := 1.0e18
			for k in left.size():
				var d := float(here.distance_squared_to((left[k] as Rect2i).get_center()))
				if d < best_d:
					best_d = d
					best = k
			order.append(left[best])
			left.remove_at(best)
		rooms = order

	for i in range(1, rooms.size()):
		_corridor(rooms[i - 1].get_center(), rooms[i].get_center())
	# 고리를 몇 개 더 만듭니다. 한 줄로만 이어지면 되돌아 나오는 길이
	# 지루합니다. **차례상 가까운 짝끼리만** 잇습니다 - 아무 둘이나 이으면
	# 그 하나가 판을 가로지르는 긴 복도가 되어, 방금 없앤 것을 도로 만듭니다.
	for _i in range(3):
		if rooms.size() < 4:
			break
		var a := _rng.randi_range(0, rooms.size() - 3)
		var b := a + _rng.randi_range(2, mini(3, rooms.size() - 1 - a))
		_corridor(rooms[a].get_center(), rooms[b].get_center())

	_build_astar()
	_build_geometry()


func _carve_rect(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			solid[_idx(x, y)] = 0


func _corridor(a: Vector2i, b: Vector2i) -> void:
	# L 자. 가로 먼저인지 세로 먼저인지는 반반으로 섞습니다.
	if _rng.randi() % 2 == 0:
		_carve_line(a.x, b.x, a.y, true)
		_carve_line(a.y, b.y, b.x, false)
	else:
		_carve_line(a.y, b.y, a.x, false)
		_carve_line(a.x, b.x, b.y, true)


func _carve_line(from: int, to: int, fixed: int, horizontal: bool) -> void:
	var lo := mini(from, to)
	var hi := maxi(from, to)
	for v in range(lo, hi + 1):
		for t in range(0, 2):  # 복도 폭 2칸
			var x := v if horizontal else fixed + t
			var y := fixed + t if horizontal else v
			if x > 0 and y > 0 and x < w - 1 and y < h - 1:
				solid[_idx(x, y)] = 0


# ---------------------------------------------------------------- 길찾기

func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in h:
		for x in w:
			if solid[_idx(x, y)] == 1:
				astar.set_point_solid(Vector2i(x, y), true)


func path_between(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if astar == null:
		return out
	var a := _nearest_open(world_to_cell(from))
	var b := _nearest_open(world_to_cell(to))
	if a.x < 0 or b.x < 0:
		return out
	for c in astar.get_id_path(a, b):
		out.append(cell_to_world(c))
	return out


func _nearest_open(c: Vector2i) -> Vector2i:
	if not is_solid(c.x, c.y):
		return c
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if not is_solid(n.x, n.y):
					return n
	return Vector2i(-1, -1)


func has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	# 격자 위 브레젠험. 물리 레이캐스트보다 싸고, 벽이 격자에 딱 맞아 정확합니다.
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var guard := 0
	while guard < 4096:
		guard += 1
		if is_solid(a.x, a.y):
			return false
		if a == b:
			return true
		var e2 := err * 2
		if e2 >= dy:
			err += dy
			a.x += sx
		if e2 <= dx:
			err += dx
			a.y += sy
	return false


# ---------------------------------------------------------------- 배치용

func room_center(i: int) -> Vector3:
	return cell_to_world(rooms[i].get_center())


func random_point_in_room(i: int, rng: RandomNumberGenerator) -> Vector3:
	var r := rooms[i]
	for _t in range(24):
		var c := Vector2i(rng.randi_range(r.position.x + 1, r.end.x - 2),
			rng.randi_range(r.position.y + 1, r.end.y - 2))
		if not is_solid(c.x, c.y):
			return cell_to_world(c)
	return room_center(i)


# ---------------------------------------------------------------- 지오메트리

func _build_geometry() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	# 그림이 들어가면 albedo 는 흰색에 가깝게 둡니다. 색을 곱하면 그림이
	# 탁해집니다. 칸마다 흔드는 밝기(정점 색)는 그대로 살립니다.
	var floor_mat := _textured(FLOOR_TEXTURE, Color(0.38, 0.33, 0.30), 0.95)
	# 벽만 셰이더를 씁니다. 캐릭터를 가릴 때 그 부분만 걷어내야 하는데,
	# 층의 벽이 메시 하나라 재질 교체로는 안 됩니다(wall_fade.gdshader 주석).
	wall_materials.clear()
	# **윗면과 옆면을 같은 색으로** 둡니다.
	#
	# 예전에는 윗면을 따로 어둡게 칠했는데(0.80 대 0.94), 내려다보는 각도에서
	# 두 면이 함께 보이므로 벽 하나가 위아래로 **투톤**이 됐습니다. 색을 맞춰
	# 두면 해가 만드는 명암만 남습니다 - 위를 보는 면이 밝고 옆면이 어두운
	# 것은 눈이 자연스럽게 받아들이는 차이입니다.
	# **벽은 어디나 같은 그림입니다.** 아이 방 벽지 한 장입니다.
	#
	# 이 게임의 그림체는 외곽선과 넓은 단색 면이라, 벽에 눈에 띄는 무늬가
	# 들어가면 그림체가 어긋납니다 - 액자 아틀라스, 세로줄 벽지, 벽돌을
	# 차례로 넣었다 셋 다 걷어냈습니다. 남은 회벽은 무늬라기보다 **면의
	# 얼룩**이라 벽을 배경으로 둡니다.
	#
	# 밋밋함은 **걸레받이**가 대신 풉니다 - 무늬 없이 벽에 두께와 경계를
	# 주는 방법입니다.
	var wall_top_mat := _wall_material(WALL_TOP_COLOR_TEX, WALL_TOP_TINT)
	var wall_side_mat := _wall_material(WALL_TEXTURE, WALL_TEX_TINT)
	# 걸레받이는 바닥과 같은 나무입니다. **벽 셰이더**를 씁니다 - 바닥 재질을
	# 그대로 쓰면 벽이 걷힐 때 걸레받이만 남아 공중에 뜹니다.
	var base_mat := _wall_material(FLOOR_TEXTURE, Color(0.88, 0.82, 0.72))

	var fst := SurfaceTool.new()
	fst.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 벽은 윗면과 옆면을 나눕니다. 위에서 내려다보는 카메라라 윗면이 가장 많이
	# 보이는데, 거기에 액자 그림이 깔리면 벽이 바닥처럼 보입니다.
	var wst := SurfaceTool.new()
	wst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sst := SurfaceTool.new()
	sst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bst := SurfaceTool.new()
	bst.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 칸마다 밝기를 조금씩 흔듭니다. 같은 색 평면은 3D 에서 유난히 가짜로
	# 보입니다. 다만 그림이 깔린 뒤로는 세게 흔들 이유가 없습니다 - 무늬가
	# 이미 변화를 주고 있는데 밝기까지 흔들면 바닥이 얼룩덜룩해집니다.
	var noise := RandomNumberGenerator.new()
	noise.seed = 20260828

	for y in h:
		for x in w:
			if solid[_idx(x, y)] == 0:
				_add_floor_quad(fst, x, y, 1.0 - noise.randf() * 0.10)
			elif _touches_open(x, y):
				# **벽은 밝기를 흔들지 않습니다(1.0 고정).**
				#
				# 칸마다 최대 12% 씩 흔들었는데, 벽은 여러 칸이 한 면으로
				# 이어져 보이기 때문에 그 차이가 큰 얼룩으로 나타났습니다 -
				# 조명이 없는데 벽에 그림자가 진 것처럼 보였습니다. 바닥은
				# 칸이 무늬에 묻혀 괜찮지만 벽은 아닙니다.
				#
				# 밋밋함은 벽지가 맡습니다. 흔들 이유가 사라졌습니다.
				_add_wall_cell(wst, sst, bst, x, y, 1.0)

	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Floor"
	fst.generate_normals()
	floor_mi.mesh = fst.commit()
	floor_mi.material_override = floor_mat
	add_child(floor_mi)

	var wall_mi := MeshInstance3D.new()
	wall_mi.name = "WallTops"
	wst.generate_normals()
	wall_mi.mesh = wst.commit()
	wall_mi.material_override = wall_top_mat
	add_child(wall_mi)

	var side_mi := MeshInstance3D.new()
	side_mi.name = "WallSides"
	sst.generate_normals()
	side_mi.mesh = sst.commit()
	side_mi.material_override = wall_side_mat
	add_child(side_mi)

	var base_mi := MeshInstance3D.new()
	base_mi.name = "Baseboards"
	bst.generate_normals()
	base_mi.mesh = bst.commit()
	base_mi.material_override = base_mat
	add_child(base_mi)

	_build_collision()
	_build_lights()


func _wall_material(path: String, tint: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(WALL_SHADER)
	var has_tex := path != "" and ResourceLoader.exists(path)
	mat.set_shader_parameter("has_texture", has_tex)
	if has_tex:
		mat.set_shader_parameter("albedo_tex", load(path))
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("rough", 0.9)
	wall_materials.append(mat)
	return mat


func set_fade_focus(camera_position: Vector3, player_position: Vector3,
		radius: float = 1.15) -> void:
	## 가릴지 말지를 정하는 두 점. 매 프레임 넣어 줍니다.
	##
	## 반경도 같이 받습니다. 내려다볼 때는 카메라가 6m 밖이라 1.15m 로
	## 충분하지만, 어깨 너머에서는 3m 뒤라 같은 반경이 화면의 절반을
	## 지웁니다 - 벽 하나가 통째로 사라져 어디가 방인지 안 보입니다.
	for mat in wall_materials:
		mat.set_shader_parameter("cam_pos", camera_position)
		mat.set_shader_parameter("player_pos", player_position)
		mat.set_shader_parameter("fade_radius", radius)


func _textured(path: String, tint: Color, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = rough
	mat.vertex_color_use_as_albedo = true
	if path != "" and ResourceLoader.exists(path):
		mat.albedo_texture = load(path)
		# 그림이 있으면 색을 거의 곱하지 않습니다. 어둡게 곱하면 수채화가
		# 진흙색이 됩니다.
		# 어둡게 내리는 일은 그림 쪽에서 합니다(make_textures.py 의
		# stylize). 여기서 또 곱하면 두 번 어두워져 진흙색이 됩니다.
		# 여기서는 살짝만 눌러 벽·소품과 밝기를 맞춥니다.
		mat.albedo_color = Color(0.88, 0.82, 0.72)
	else:
		mat.albedo_color = tint
	return mat


func _mirror_uv(index: int, span: int) -> Vector2:
	## 한 칸의 U 범위를 돌려줍니다. 타일이 홀수 번째면 뒤집습니다.
	##
	## 이렇게 하면 이웃한 타일의 맞닿는 가장자리가 **언제나 같은 픽셀**이라
	## 이음매가 아예 없습니다. 그림을 이어지게 가공할 필요도 없고 붓질도
	## 그대로 남습니다. 대가는 한 칸 걸러 좌우가 뒤집히는 것인데, 판자나
	## 액자 벽에서는 눈에 띄지 않습니다.
	var within := float(index % span) / float(span)
	var next := within + 1.0 / float(span)
	if int(floor(float(index) / float(span))) % 2 == 1:
		return Vector2(1.0 - within, 1.0 - next)
	return Vector2(within, next)


func _touches_open(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not is_solid(x + dx, y + dy):
				return true
	return false


func _add_floor_quad(st: SurfaceTool, x: int, y: int, shade: float) -> void:
	var x0 := x * TILE
	var z0 := y * TILE
	var x1 := x0 + TILE
	var z1 := z0 + TILE
	st.set_color(Color(shade, shade, shade))
	var u := _mirror_uv(x, FLOOR_TILE_X)
	var v := _mirror_uv(y, FLOOR_TILE_Y)
	# Godot 은 시계 방향이 앞면입니다. 위에서 내려다볼 때 시계 방향이 되도록
	# 놓아야 바닥이 컬링되지 않습니다.
	_quad_uv(st, Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1),
		Vector2(u.x, v.x), Vector2(u.y, v.x), Vector2(u.y, v.y), Vector2(u.x, v.y))


func _add_wall_cell(top_st: SurfaceTool, side_st: SurfaceTool,
		base_st: SurfaceTool, x: int, y: int, shade: float) -> void:
	## 벽 한 칸. **윗면 하나와 옆면 하나**입니다.
	##
	## 예전에는 아래에 걸레받이(0.16m 높이로 0.05m 튀어나온 턱)를 덧대어
	## **두 층으로 쌓았습니다.** 단색 벽이 밋밋한 것을 두께와 경계로 풀려던
	## 것인데, 벽에 그림이 깔리면서 그 이유가 사라졌고 쌓은 자리에 이음매와
	## 그림 끊김이 남았습니다. 한 장으로 두고 그 높이까지 벽면이 덮습니다.
	var x0 := x * TILE
	var z0 := y * TILE
	var x1 := x0 + TILE
	var z1 := z0 + TILE
	var top := WALL_H

	# 윗면은 항상. 위에서 내려다보는 카메라라 이 면이 벽의 인상을 만듭니다.
	top_st.set_color(Color(shade, shade, shade))
	_quad(top_st, Vector3(x0, top, z0), Vector3(x1, top, z0),
		Vector3(x1, top, z1), Vector3(x0, top, z1))

	# 옆면은 열린 칸을 향한 쪽만. 보이지 않는 면을 만들 이유가 없습니다.
	#
	# UV 는 **세계 좌표**에서 뽑습니다. 칸마다 0~1 로 끊으면 무늬가 칸 경계
	# 에서 잘리는데, 세계 좌표로 흘리면 벽을 따라 그대로 이어집니다.
	side_st.set_color(Color(shade, shade, shade))
	# **그림은 세로로 한 번만 들어갑니다.**
	#
	# 예전에는 세로도 1.5m 마다 되풀이했습니다(PAPER_SPAN). 벽 높이가 2.8m
	# 라 그림이 **1.87번** 반복되는데, 벽돌처럼 가로줄이 뚜렷한 그림에서는
	# 그것이 "벽을 두 층 쌓은 것" 으로 보입니다 - 두 번째 줄이 중간에서
	# 잘리기까지 하니 이음매가 그대로 드러납니다.
	#
	# 가로는 계속 흘려야 합니다(칸마다 끊으면 무늬가 칸 경계에서 잘립니다).
	# 대신 도는 거리를 **그림 비율에 맞춰** 잡아야 벽돌이 늘어나지 않습니다 -
	# 2760 x 1504 이니 세로 2.8m 한 번에 맞추면 가로는 5.14m 입니다.
	var v0 := 0.0
	var v1 := 1.0
	var ux0 := x0 / WALL_TEX_RUN
	var ux1 := x1 / WALL_TEX_RUN
	var uz0 := z0 / WALL_TEX_RUN
	var uz1 := z1 / WALL_TEX_RUN

	if not is_solid(x, y - 1):
		_quad_uv(side_st, Vector3(x0, 0, z0), Vector3(x1, 0, z0),
			Vector3(x1, top, z0), Vector3(x0, top, z0),
			Vector2(ux0, v1), Vector2(ux1, v1), Vector2(ux1, v0), Vector2(ux0, v0))
		_add_baseboard(base_st, Vector3(x0, 0, z0), Vector3(x1, 0, z0),
			Vector3(0, 0, -1), shade)
	if not is_solid(x, y + 1):
		_quad_uv(side_st, Vector3(x1, 0, z1), Vector3(x0, 0, z1),
			Vector3(x0, top, z1), Vector3(x1, top, z1),
			Vector2(ux1, v1), Vector2(ux0, v1), Vector2(ux0, v0), Vector2(ux1, v0))
		_add_baseboard(base_st, Vector3(x1, 0, z1), Vector3(x0, 0, z1),
			Vector3(0, 0, 1), shade)
	if not is_solid(x - 1, y):
		_quad_uv(side_st, Vector3(x0, 0, z1), Vector3(x0, 0, z0),
			Vector3(x0, top, z0), Vector3(x0, top, z1),
			Vector2(uz1, v1), Vector2(uz0, v1), Vector2(uz0, v0), Vector2(uz1, v0))
		_add_baseboard(base_st, Vector3(x0, 0, z1), Vector3(x0, 0, z0),
			Vector3(-1, 0, 0), shade)
	if not is_solid(x + 1, y):
		_quad_uv(side_st, Vector3(x1, 0, z0), Vector3(x1, 0, z1),
			Vector3(x1, top, z1), Vector3(x1, top, z0),
			Vector2(uz0, v1), Vector2(uz1, v1), Vector2(uz1, v0), Vector2(uz0, v0))
		_add_baseboard(base_st, Vector3(x1, 0, z0), Vector3(x1, 0, z1),
			Vector3(1, 0, 0), shade)


func _add_baseboard(st: SurfaceTool, a: Vector3, b: Vector3, out_dir: Vector3,
		shade: float) -> void:
	## 벽 아래를 두껍게 만드는 턱. `a`->`b` 가 벽면을 따라가는 변이고
	## `out_dir` 은 방 쪽입니다.
	st.set_color(Color(shade, shade, shade))
	# 양 끝을 **두께만큼 늘립니다.** 안 늘리면 모서리에서 두 띠가 만나지
	# 못하고 5cm 짜리 홈이 남습니다.
	var along := (b - a)
	if along.length_squared() > 0.0001:
		var ext: Vector3 = along.normalized() * BASE_OUT
		a -= ext
		b += ext
	var out := out_dir * BASE_OUT
	var up := Vector3(0, BASE_H, 0)
	var run := a.distance_to(b) / PAPER_SPAN
	var tall := BASE_H / PAPER_SPAN
	_quad_uv(st, a + out, b + out, b + out + up, a + out + up,
		Vector2(0, tall), Vector2(run, tall), Vector2(run, 0), Vector2(0, 0))
	_quad_uv(st, a + out + up, b + out + up, b + up, a + up,
		Vector2(0, 0), Vector2(run, 0), Vector2(run, tall), Vector2(0, tall))


func _quad_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_uv(ud)
	st.add_vertex(d)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(b)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(d)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)

	# 바닥은 한 덩어리로 충분합니다. 벽이 갈 수 있는 곳을 이미 가두고 있습니다.
	var ground := CollisionShape3D.new()
	var gs := BoxShape3D.new()
	gs.size = Vector3(w * TILE, 1.0, h * TILE)
	ground.shape = gs
	ground.position = Vector3(w * TILE * 0.5, -0.5, h * TILE * 0.5)
	body.add_child(ground)

	# 벽은 가로로 이어붙여 개수를 줄입니다. 칸마다 만들면 수천 개가 됩니다.
	for y in h:
		var run := -1
		for x in range(w + 1):
			var is_wall := x < w and is_solid(x, y) and _touches_open(x, y)
			if is_wall and run < 0:
				run = x
			elif not is_wall and run >= 0:
				var length := x - run
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(length * TILE, WALL_H, TILE)
				cs.shape = bs
				cs.position = Vector3((run + length * 0.5) * TILE, WALL_H * 0.5, (y + 0.5) * TILE)
				body.add_child(cs)
				run = -1


func _build_lights() -> void:
	for i in rooms.size():
		var lamp := OmniLight3D.new()
		lamp.position = room_center(i) + Vector3(0, 3.4, 0)
		lamp.omni_range = maxf(rooms[i].size.x, rooms[i].size.y) * TILE * 0.9
		lamp.light_energy = 2.0
		lamp.light_color = Color(1.0, 0.90, 0.76)
		lamp.shadow_enabled = false
		add_child(lamp)
