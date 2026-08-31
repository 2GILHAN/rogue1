shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, diffuse_burley;

// 풀장의 물.
//
// # 왜 셰이더인가
//
// 예전에는 반투명 원판 하나였습니다. "물이 들었다" 는 됐지만 **가만히 있는
// 파란 판**이라, 화면이 멈춰 있을 때 그냥 색칠한 바닥으로 보였습니다. 물은
// 색이 아니라 **움직임**으로 알아봅니다.
//
// # 왜 정점을 안 흔드나
//
// 63도로 내려다보는 카메라에서는 수면의 높낮이가 실루엣에 거의 안 나타납니다.
// 정점을 흔들려면 원판을 잘게 쪼개야 하는데(24조각 -> 수백), 폰에서 그 값을
// 내고 얻는 것이 없습니다. **무늬만 움직이면** 위에서 보기에는 같습니다.
//
// # 좌표를 UV 가 아니라 월드에서 씁니다
//
// 원판(CylinderMesh)의 윗면 UV 는 가운데로 모여서, 그걸 쓰면 무늬가 가운데
// 한 점으로 빨려 들어갑니다. 월드 XZ 를 쓰면 어디서나 같은 크기의 물결이
// 됩니다.

uniform vec3 shallow : source_color = vec3(0.42, 0.80, 0.92);
uniform vec3 deep : source_color = vec3(0.10, 0.45, 0.68);
uniform float wave_scale = 2.6;
uniform float wave_speed = 0.55;
// 반짝이는 잔물결의 세기. 0 이면 그냥 색만 일렁입니다.
uniform float sparkle : hint_range(0.0, 1.0) = 0.55;
uniform float alpha : hint_range(0.0, 1.0) = 0.72;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float waves(vec2 p, float t) {
	// 방향이 다른 물결 셋을 겹칩니다. 하나면 줄무늬가 흐르는 것으로 보이고,
	// 둘이면 격자가 보입니다 - 셋을 서로 어긋난 각도로 겹쳐야 규칙이 안
	// 읽힙니다.
	float a = sin(dot(p, vec2(1.0, 0.34)) * 3.1 + t * 1.7);
	float b = sin(dot(p, vec2(-0.42, 1.0)) * 2.3 - t * 1.3);
	float c = sin(dot(p, vec2(0.77, -0.63)) * 4.7 + t * 2.4);
	return (a + b + c) / 3.0;
}

void fragment() {
	vec2 p = world_pos.xz * wave_scale;
	float t = TIME * wave_speed;
	float w = waves(p, t);
	// 물결의 골은 짙게, 마루는 옅게. 깊이가 다른 것처럼 보입니다.
	ALBEDO = mix(deep, shallow, w * 0.5 + 0.5);
	// 마루 끝에만 하얗게 얹어 잔물결이 반짝이게 합니다. pow 로 좁혀야
	// 화면 절반이 하얘지지 않습니다.
	float crest = pow(clamp(w, 0.0, 1.0), 7.0);
	EMISSION = vec3(1.0) * crest * sparkle;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	ALPHA = alpha;
}
