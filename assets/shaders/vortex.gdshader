shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, unshaded;

// 고함이 만드는 **소용돌이**. 입에서 시작해 바닥의 부채꼴로 벌어지는 판입니다.
//
// # 왜 원뿔이 아닌가
//
// 처음에는 원뿔을 겹쳐 세웠습니다. 그런데 **둥근 원뿔은 부채꼴을 못 덮습니다** -
// 판정은 각도 30~132도짜리 부채꼴인데 원뿔의 밑면은 언제나 온전한 원이라,
// 옆으로는 판정 밖까지 삐져나오고 앞으로는 모자랍니다.
//
// 그래서 메시를 **부채꼴에서 그대로 뽑습니다**(Fx.shout_cone_mesh). 꼭짓점이
// 입이고 테두리가 바닥의 호라, 위에서 보면 칠해 둔 부채꼴과 정확히 겹칩니다.
//
// # 그러면 어떻게 도는가
//
// 메시를 돌리면 부채꼴 밖으로 나갑니다. 도는 것은 **무늬만** 합니다 - UV 가
// 이미 극좌표(u = 각도, v = 반지름)라 그대로 흘리면 됩니다. 형태는 판정에
// 붙들려 있고 움직임만 도는 셈입니다.

uniform sampler2D noise_tex : repeat_enable;
uniform float scroll_speed : hint_range(0.0, 5.0) = 1.6;
// 나선이 몇 바퀴 감기는지. 크면 촘촘한 소용돌이, 작으면 도는 줄무늬입니다.
uniform float spiral_amount : hint_range(0.0, 10.0) = 3.2;
uniform vec4 vortex_color : source_color = vec4(0.34, 0.62, 1.0, 0.6);
// 지금 쓰는 각도가 **만들어 둔 최대 각도의 몇 배인가**(0~1).
//
// 메시는 최대 각도로 한 번만 만들고, 좁은 고함은 여기서 잘라 씁니다 -
// 모으는 동안 매 프레임 메시를 다시 만들면 그 값이 그대로 듭니다.
uniform float arc_frac : hint_range(0.0, 1.0) = 1.0;
// 전체 투명도. 모으는 동안 진해지고 지른 뒤 스러집니다.
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// u = 부채꼴을 가로지르는 각도(0~1), v = 입에서 테두리까지(0~1).
	float across = UV.x - 0.5;
	// **각도를 잘라 냅니다.** 가장자리는 부드럽게 - 딱 자르면 톱니가 됩니다.
	float inside = 1.0 - smoothstep(arc_frac * 0.5 - 0.03, arc_frac * 0.5,
		abs(across));

	// 극좌표 그대로 흘립니다. 각도로 돌리고 반지름으로 안쪽으로 빨아들입니다.
	vec2 spiral_uv = vec2(UV.x + spiral_amount * UV.y * 0.15,
		UV.y - TIME * scroll_speed);
	float n = texture(noise_tex, spiral_uv).r;

	// 입 쪽과 테두리 쪽을 다 옅게 합니다. 입 쪽이 진하면 얼굴을 덮고,
	// 테두리가 진하면 판이 딱 잘려 보입니다.
	float along = smoothstep(0.0, 0.22, UV.y) * (1.0 - smoothstep(0.72, 1.0, UV.y));

	ALBEDO = vortex_color.rgb;
	ALPHA = n * inside * along * vortex_color.a * fade;
}
