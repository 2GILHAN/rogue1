shader_type canvas_item;

// 화면 전체에 거는 색감 필터. 지브리 톤.
//
// # 왜 화면 필터인가
//
// 처음에는 캐릭터 텍스처를 직접 칠했습니다(tools/tint_models.py). 두 가지가
// 나빴습니다 - 되돌리려면 다시 구워야 하고, **바닥과 벽은 그대로**라 사람만
// 톤이 다른 화면이 됐습니다. 색감은 그림 하나의 성질이 아니라 화면 전체의
// 성질이라, 마지막에 한 번 거는 편이 맞습니다.
//
// 옵션으로 끌 수 있는 것도 이 방식이라야 됩니다. 텍스처에 구워 넣으면 끄는
// 길이 없습니다.
//
// # 무엇을 하는가
//
// 버튼 그림에 쓴 것과 **같은 세 가지**입니다(tools/tint_buttons.py).
//
//   1. 채도를 낮춥니다 - 원색을 없앱니다.
//   2. 명도를 [floor, ceil] 로 눌러 넣습니다 - 순수한 검정과 흰색이
//      사라지고, 가장 어두운 곳도 짙은 색으로 남습니다.
//   3. 채도가 낮은 곳을 따뜻하게 밉니다 - 회색이 나무색 쪽으로 갑니다.
//      고르게 밀면 파란 것까지 갈색이 되므로 채도로 가중치를 줍니다.

uniform sampler2D screen : hint_screen_texture, filter_linear;
// 0 이면 원본, 1 이면 온전히 걸립니다. 옵션을 켜고 끌 때 이 값이 옮겨 갑니다 -
// 한 프레임에 바뀌면 화면이 깜빡인 것으로 보입니다.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float sat = 0.72;
uniform float floor_v = 0.10;
uniform float ceil_v = 0.94;
uniform float warm = 0.06;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 src = texture(screen, SCREEN_UV).rgb;
	vec3 hsv = rgb2hsv(src);
	hsv.y *= sat;
	hsv.z = floor_v + hsv.z * (ceil_v - floor_v);
	vec3 col = hsv2rgb(hsv);
	// 채도가 낮은 곳에서 더 세게. 회색·흰색·그림자가 먼저 따뜻해집니다.
	col += warm * (1.0 - hsv.y) * vec3(1.0, 0.45, -0.75);
	COLOR = vec4(mix(src, clamp(col, 0.0, 1.0), amount), 1.0);
}
