shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;

// 고함 Lv5 에 입에서 뻗어 나가는 **호랑이 옆얼굴**.
//
// # 왜 그림 한 장인가
//
// 처음에는 3D 머리를 늘여 썼습니다. 63도로 내려다보는 카메라에서는 정수리만
// 보여서, 굴리고 늘여도 파란 덩어리에 가까웠습니다. 옆얼굴은 **옆에서 봐야**
// 옆얼굴이고, 그 그림은 이미 있습니다(test3 의 tiger_line).
//
// # 목은 흐리고 입은 뚜렷하게
//
// 소리가 아이의 입에서 나가는 것으로 보이려면, 아이 쪽 끝이 **모여 사라져야**
// 합니다. 목 쪽 알파를 떨어뜨리면 호랑이가 아이 머리에서 피어나는 모양이
// 되고, 입 쪽을 그대로 두면 그쪽이 앞으로 뻗어 나가는 끝이 됩니다.
//
// 선화의 알파를 그대로 쓰되 색은 파랑 하나로 덮습니다 - 구르기 잔상·미는
// 선과 같은 파랑이라 "소리가 그린 것" 으로 읽힙니다.

uniform sampler2D tex : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(0.34, 0.66, 1.0, 1.0);
// 목이 있는 쪽. 이 그림은 입이 왼쪽(U=0), 목이 오른쪽(U=1)입니다.
uniform float neck_u = 1.0;
// 어디서부터 흐려지기 시작하나(0 = 입 끝, 1 = 목 끝).
uniform float fade_start : hint_range(0.0, 1.0) = 0.30;

// 그림을 위아래로 뒤집을지. 바닥에 눕힌 판이라, 어느 쪽이 화면 위로
// 가는지가 판을 어느 방향으로 돌렸느냐에 달려 있습니다 - **눈이 화면
// 위쪽**에 와야 얼굴로 읽힙니다.
uniform float flip_v = 0.0;
// 0 이면 가로(U)를 따라, 1 이면 세로(V)를 따라 흐려집니다.
uniform float fade_axis = 0.0;

void fragment() {
	vec2 uv = vec2(UV.x, mix(UV.y, 1.0 - UV.y, flip_v));
	vec4 c = texture(tex, uv);
	// 0 이 입, 1 이 목이 되도록 뒤집습니다.
	// 흐려지는 축. 옆얼굴은 가로(입->목), 정면은 세로(이마->턱)입니다.
	float along = mix(uv.x, uv.y, fade_axis);
	float t = mix(1.0 - along, along, neck_u);
	float keep = 1.0 - smoothstep(fade_start, 1.0, t);
	ALBEDO = tint.rgb;
	ALPHA = c.a * tint.a * keep;
}
