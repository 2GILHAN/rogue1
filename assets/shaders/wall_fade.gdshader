shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

// 캐릭터를 가리는 벽만 비치게 합니다.
//
// # 왜 셰이더인가
//
// 층의 벽은 통째로 **메시 하나**입니다. 가리는 벽만 골라 재질을 바꾸는 방법이
// 없어서, 벽 하나를 투명하게 만들려면 층 전체가 투명해집니다. 그래서 물체가
// 아니라 **픽셀 단위**로 정합니다 - 카메라와 캐릭터를 잇는 선 근처를 지나는
// 픽셀만 걷어냅니다.
//
// # 디더링에서 알파로 바꿨습니다
//
// 처음에는 픽셀을 격자로 버렸습니다(discard). 순서 문제가 없다는 장점이
// 있었지만 **화면에서 점무늬로 보입니다** - 벽이 부드럽게 비치는 것이 아니라
// 체처럼 뚫린 것으로 읽히고, 카메라가 움직이면 그 점들이 지글거립니다.
//
// 지금은 알파로 부드럽게 섞습니다. 반투명이 늘 겪는 두 가지를 이렇게 풉니다.
//
//   같은 메시 안에서 앞뒤가 뒤집히는 것
//     -> `depth_draw_opaque`. 깊이를 쓰므로 그리는 순서와 상관없이 앞에 있는
//        면이 이깁니다. 벽은 통째로 메시 하나라 물체끼리의 정렬 문제는
//        애초에 없습니다.
//
//   벽이 캐릭터 위에 덧그려지는 것
//     -> 남기는 비율이 0.18 이라 **덧그려져도 18%** 입니다. 캐릭터가 82%
//        로 비쳐 보이고, 벽이 거기 있다는 것도 같이 읽힙니다. 완전히
//        지우지 않는 것이 처음부터 의도였습니다(fade_keep 주석).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_texture = true;
uniform vec3 tint : source_color = vec3(1.0);
uniform float rough : hint_range(0.0, 1.0) = 0.9;
// 면 밝기 차이를 얼마나 지울지.
uniform float flatten : hint_range(0.0, 1.0) = 0.40;

// 게임 쪽에서 매 프레임 넣어 줍니다(game.gd).
uniform vec3 player_pos = vec3(0.0);
uniform vec3 cam_pos = vec3(0.0);
// 캐릭터 주위로 얼마나 넓게 걷어낼지(m). 키가 1.25m 라 이 정도면 몸 전체가
// 보이면서 벽이 필요 이상으로 뚫리지 않습니다.
uniform float fade_radius = 1.15;
// 가장 많이 걷어낼 때 남기는 비율. 0 으로 두면 벽이 아예 사라져서 어디가
// 벽이었는지 알 수 없습니다.
uniform float fade_keep : hint_range(0.0, 1.0) = 0.18;
// 캐릭터보다 얼마나 앞(카메라 쪽)에 있어야 걷어낼지(m). 바닥에 내려놓고 잽니다.
//
// **등 뒤 벽이 검게 얼룩지던 것**이 이 값이 없어서였습니다. 아래 t 검사는
// 카메라에서 캐릭터로 가는 선 위의 자리만 보는데, 내려다보는 카메라에서는
// 등 뒤 벽의 **위쪽**이 캐릭터보다 카메라에 가깝습니다(높으니까). 그래서
// 가리지도 않는 벽에 구멍이 뚫렸고, 뚫린 자리 뒤에는 아무것도 없어서
// 거뭇한 얼룩으로 보였습니다.
uniform float fade_ahead = 0.05;
// 벽 한 칸의 크기(m). `Dungeon.TILE` 을 그대로 받습니다.
//
// **판정을 픽셀이 아니라 칸으로 합니다.** 픽셀마다 재면 캐릭터 주위에
// 동그란 구멍이 뚫리는데, 그러면 벽에 얼룩이 진 것처럼 보이고 어디까지가
// 벽인지도 안 읽힙니다. 칸으로 재면 **가리는 벽면이 통째로** 비칩니다 -
// 벽 한 장이 유리가 되는 것이라, 방의 모양이 그대로 남습니다.
uniform float cell_size = 1.5;
// 벽을 따라 얼마나 멀리까지 같이 비칠지(m).
//
// **이 값이 없어서 화면이 깨졌습니다.** 축을 따라 자리를 주인공에게 맞추면
// 그 축 위의 벽이 전부 같은 답을 내는데, 그 축은 지도 끝까지 이어집니다 -
// 가리지도 않는 먼 벽까지 통째로 비쳐서 방이 사라지고, 뚫린 자리 뒤에는
// 아무것도 없어 거뭇한 쐐기만 남았습니다.
//
// 벽을 따라 이만큼 떨어지면 도로 불투명해집니다. 앞뒤로 이 거리씩이므로
// 한 번에 비치는 것은 그 두 배 길이의 **벽 한 판**입니다.
/// **물건 하나를 통째로** 볼까(소품), 아니면 벽면 축을 따라 볼까(벽).
///
/// 벽면 축 규칙은 **긴 벽**을 위한 것입니다 - 이 면이 보는 쪽으로 벽이 놓인
/// 축을 알아내고 그 축을 따라 판정합니다. 가구에는 그런 축이 없습니다.
/// 앞판·옆판·뒷판의 법선이 제각각이라 판마다 다른 답이 나오고, 그래서 벽은
/// 비쳤는데 책장만 남아 뒷모습이 그대로 보였습니다.
///
/// 켜면 **물건의 자리 하나**로만 판정합니다. 판이 여럿이어도 답이 하나라
/// 물건이 통째로 비칩니다.
uniform bool whole_object = false;
uniform vec3 object_pos = vec3(0.0);
uniform float run_span = 3.4;
uniform float run_fade = 2.0;

varying vec3 world_pos;
// 이 면이 어느 쪽을 보는지(월드 기준). **벽면을 통째로 판정하는 데** 씁니다.
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = tint * COLOR.rgb;
	if (has_texture) {
		base *= texture(albedo_tex, UV).rgb;
	}
	ALBEDO = base;
	ROUGHNESS = rough;
	SPECULAR = 0.0;
	// 벽을 **납작하게** 만듭니다.
	//
	// 윗면은 해를 정면으로 받고 옆면은 스치듯 받아서, 둘이 만나는 선이
	// 그림자처럼 읽혔습니다(조명을 꺼 봐도 남는 것으로 확인). 이 그림체는
	// 넓은 단색 면이라 면마다 밝기가 다르면 얼룩으로 보입니다.
	//
	// 알베도의 일부를 발광으로 되돌려 어두운 면을 끌어올립니다. 0 이면
	// 예전처럼 면마다 다르고, 1 이면 완전히 평평합니다.
	EMISSION = base * flatten;

	// **이 픽셀이 아니라 이 픽셀이 속한 벽면**으로 판정합니다.
	//
	// 칸으로 자르던 것에서 한 번 더 올렸습니다. 칸으로 하면 가리는 자리
	// 앞뒤로 두세 칸만 뚫려서, 긴 벽 한가운데에 창이 난 것처럼 보였습니다.
	// **같은 축에 놓인 벽은 전부 같이** 비쳐야 방이 방으로 남습니다.
	//
	// 방법: 이 면이 보는 쪽으로 벽이 놓인 축을 알아내고, 그 축을 따라
	// 자리를 **주인공에게 맞춘 점**을 대신 봅니다. Z 를 보는 벽(=X 축을 따라
	// 길게 뻗은 벽)이면 x 만 주인공 것으로 바꿉니다 - 그러면 그 벽의 모든
	// 픽셀이 같은 답을 내므로, 벽면 하나가 통째로 비칩니다.
	//
	// 윗면(수평)은 축이 없습니다. 그때만 예전처럼 칸으로 봅니다 - 윗면은
	// 내려다볼 때 눈에 들어오는 넓은 바닥 같은 면이라, 통째로 비우면
	// 벽이 있었다는 것 자체가 안 보입니다.
	// 두 축의 후보. 하나는 X 축을 따라 뻗은 벽(=Z 를 보는 면)에 맞춘 자리이고,
	// 다른 하나는 그 반대입니다.
	// **소품은 자기 자리 하나로** 봅니다(위 `whole_object`).
	vec3 test_pos = whole_object ? vec3(object_pos.x, world_pos.y, object_pos.z)
		: world_pos;
	vec3 probe_x = vec3(player_pos.x, test_pos.y, test_pos.z);
	vec3 probe_z = vec3(test_pos.x, test_pos.y, player_pos.z);
	vec3 probe;
	if (whole_object) {
		// 축을 안 봅니다. 물건의 자리 그대로가 곧 판정할 점입니다.
		probe = test_pos;
	} else if (abs(world_normal.y) > 0.7) {
		// **윗면에는 축이 없습니다.** 아래 벽이 어느 쪽으로 뻗었는지 알 수
		// 없으므로, 두 후보 중 **더 가까운 쪽**을 씁니다 - 그러면 이 윗면을
		// 이고 있는 벽면과 같은 답이 나와서 둘이 같이 비칩니다. 칸으로
		// 자르면 윗면만 계단 모양으로 남아 벽과 따로 놉니다.
		vec3 seg0 = player_pos - cam_pos;
		float l2 = max(dot(seg0, seg0), 0.0001);
		float tx = clamp(dot(probe_x - cam_pos, seg0) / l2, 0.0, 1.0);
		float tz = clamp(dot(probe_z - cam_pos, seg0) / l2, 0.0, 1.0);
		probe = distance(probe_x, cam_pos + seg0 * tx)
			< distance(probe_z, cam_pos + seg0 * tz) ? probe_x : probe_z;
	} else if (abs(world_normal.z) > abs(world_normal.x)) {
		probe = probe_x;
	} else {
		probe = probe_z;
	}

	// 카메라에서 캐릭터로 가는 선분 위에 이 자리를 내려 봅니다.
	vec3 seg = player_pos - cam_pos;
	float len2 = max(dot(seg, seg), 0.0001);
	float t = dot(probe - cam_pos, seg) / len2;
	float visible = 1.0;
	// t 가 0~1 사이일 때만 = 카메라와 캐릭터 **사이**에 있을 때만 걷어냅니다.
	// 캐릭터 뒤의 벽은 가리지 않으므로 그대로 둡니다.
	// 바닥에 내려놓고 봅니다. 가리는 벽은 캐릭터보다 **카메라 쪽**에 있고,
	// 등 뒤 벽은 반대쪽에 있습니다 - 높이를 빼면 둘이 부호로 갈립니다.
	// 카메라가 바로 위에 있으면 앞뒤가 없습니다. 그때는 이 검사를 건너뜁니다
	// (나누기가 0 이 되어 화면이 통째로 깨집니다).
	float flat_len = length(seg.xz);
	float ahead = fade_ahead + 1.0;
	if (flat_len > 0.001) {
		ahead = dot(player_pos.xz - probe.xz, seg.xz / flat_len);
	}
	// **벽을 따라 얼마나 떨어졌나.** 축을 맞추면서 잃어버린 값입니다 -
	// probe 는 주인공에게 맞춘 자리라 이 거리가 거기서는 언제나 0 입니다.
	float along;
	if (whole_object) {
		// 물건은 벽처럼 길게 뻗지 않습니다. 「따라 멀어지면 닫힌다」 는
		// 긴 벽을 자르려던 규칙이라, 여기서는 늘 0 입니다.
		along = 0.0;
	} else if (abs(world_normal.y) > 0.7) {
		along = min(abs(world_pos.x - player_pos.x), abs(world_pos.z - player_pos.z));
	} else if (abs(world_normal.z) > abs(world_normal.x)) {
		along = abs(world_pos.x - player_pos.x);
	} else {
		along = abs(world_pos.z - player_pos.z);
	}

	if (t > 0.02 && t < 0.98 && ahead > fade_ahead) {
		float d = distance(probe, cam_pos + seg * t);
		// 칸 단위라 가장자리가 계단으로 끊깁니다. `fade_radius` 를 넉넉히
		// 잡아 **바깥 칸이 반쯤 비치게** 하면 그 계단이 층으로 읽힙니다 -
		// 딱 잘리는 것보다 눈이 훨씬 편합니다.
		visible = mix(fade_keep, 1.0,
			smoothstep(fade_radius * 0.35, fade_radius, d));
		// 벽을 따라 멀어지면 도로 닫힙니다. 이 한 줄이 "가리는 벽 한 판" 과
		// "그 축의 벽 전부" 를 가릅니다.
		visible = mix(visible, 1.0,
			smoothstep(run_span, run_span + run_fade, along));
	}
	// 부드럽게 섞습니다. 가장자리는 `smoothstep` 이 이미 완만하게 만들어
	// 두었으므로, 여기서는 그 값을 그대로 알파로 씁니다.
	ALPHA = visible;
}
