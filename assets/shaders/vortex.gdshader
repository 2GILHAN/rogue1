shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, unshaded;

// 고함이 만드는 **소용돌이**. 원뿔 여러 겹에 이 셰이더를 씌웁니다.
//
// # 형태만으로는 정적입니다
//
// 원뿔을 겹치면 소용돌이의 *모양*은 잡히지만 그냥 겹친 고깔로 보입니다.
// 빨려드는 느낌의 대부분은 **표면 무늬가 도는 것**에서 나옵니다 - UV 를
// 극좌표로 바꿔 각도로 돌리고 반지름으로 안쪽으로 흘리면, 같은 노이즈가
// 나선으로 감기며 빨려 들어갑니다.
//
// # 왜 blend_add 인가
//
// 소리에서 나오는 기운이라 물이 아니라 빛에 가깝습니다. 더하기로 섞으면
// 겹친 원뿔이 겹칠수록 밝아져서 가운데가 저절로 코어처럼 뭉칩니다.
// 반대로 blend_mix 는 불투명한 물기둥에 어울립니다.

uniform sampler2D noise_tex : repeat_enable;
uniform float scroll_speed : hint_range(0.0, 5.0) = 1.6;
// 나선이 몇 바퀴 감기는지. 크면 촘촘한 소용돌이, 작으면 도는 줄무늬입니다.
uniform float spiral_amount : hint_range(0.0, 10.0) = 3.2;
uniform vec4 vortex_color : source_color = vec4(0.34, 0.62, 1.0, 0.6);
// 정점을 흔드는 폭(m)과 빠르기. 테두리가 울렁여야 딱딱한 고깔로 안 보입니다.
uniform float wobble = 0.045;
uniform float wobble_speed = 7.0;

void vertex() {
	// 높이에 따라 위상을 어긋나게 해서 위아래가 같이 안 움직이게 합니다.
	float w = sin(TIME * wobble_speed + VERTEX.y * 9.0 + VERTEX.x * 4.0);
	VERTEX.xz += normalize(VERTEX.xz + vec2(0.0001)) * w * wobble;
}

void fragment() {
	// UV 를 극좌표처럼 다뤄 회전 + 안쪽으로 빨려드는 스크롤.
	vec2 centered = UV - vec2(0.5);
	float angle = atan(centered.y, centered.x);
	float radius = length(centered);

	vec2 spiral_uv = vec2(angle / (2.0 * PI) + spiral_amount * radius,
		radius - TIME * scroll_speed);
	float n = texture(noise_tex, spiral_uv).r;

	// 가장자리로 갈수록 옅어집니다. 안 그러면 원뿔의 밑동이 딱 잘려 보입니다.
	float edge = clamp(1.0 - radius * 1.6, 0.0, 1.0);
	ALBEDO = vortex_color.rgb;
	ALPHA = n * edge * vortex_color.a;
}
