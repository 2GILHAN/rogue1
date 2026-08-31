shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// 캐릭터를 가리는 벽만 비치게 합니다.
//
// # 왜 셰이더인가
//
// 층의 벽은 통째로 **메시 하나**입니다. 가리는 벽만 골라 재질을 바꾸는 방법이
// 없어서, 벽 하나를 투명하게 만들려면 층 전체가 투명해집니다. 그래서 물체가
// 아니라 **픽셀 단위**로 정합니다 - 카메라와 캐릭터를 잇는 선 근처를 지나는
// 픽셀만 걷어냅니다.
//
// # 왜 알파가 아니라 디더링인가
//
// 반투명 표면은 불투명한 것들보다 나중에 그려집니다. 벽을 반투명으로 만들면
// 벽이 캐릭터 위에 덧그려져서, 가리는 것을 없애려다 더 가리게 됩니다.
// 픽셀을 격자로 버리면(discard) 불투명 패스에 그대로 남아 순서 문제가 없고,
// 화면에서는 성기게 비치는 것으로 보입니다.

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

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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

	// 카메라에서 캐릭터로 가는 선분 위에 이 픽셀을 내려 봅니다.
	vec3 seg = player_pos - cam_pos;
	float len2 = max(dot(seg, seg), 0.0001);
	float t = dot(world_pos - cam_pos, seg) / len2;
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
		ahead = dot(player_pos.xz - world_pos.xz, seg.xz / flat_len);
	}
	if (t > 0.02 && t < 0.98 && ahead > fade_ahead) {
		float d = distance(world_pos, cam_pos + seg * t);
		visible = mix(fade_keep, 1.0,
			smoothstep(fade_radius * 0.5, fade_radius, d));
	}
	if (visible < 0.995) {
		// R2 저불일치 수열로 만든 격자. 무작위 잡음보다 고르게 흩어져서
		// 성기게 비치는 유리처럼 보입니다.
		float dither = fract(dot(FRAGCOORD.xy, vec2(0.7548776662, 0.5698402909)));
		if (visible < dither) {
			discard;
		}
	}
}
