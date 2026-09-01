shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

// **허리 아래를 지웁니다.** 자동차를 탄 동안에만 씁니다.
//
// # 왜 셰이더인가
//
// 몸은 뼈대 하나에 붙은 **메시 하나**라, 다리만 골라 숨기는 방법이 없습니다.
// 뼈를 접어 넣는 방법도 써 봤자 발끝이 어딘가로 삐져나오고, 자세가 바뀌면
// 다시 어긋납니다. 픽셀 단위로 높이를 보고 지우면 자세와 상관이 없습니다.
//
// # 높이를 프래그먼트에서 봅니다
//
// 정점 단계에서 보면 **스키닝이 언제 적용되는지**에 답이 매입니다. 프래그먼트의
// `VERTEX` 는 이미 화면에 찍히는 자리(뷰 좌표)라, 그것을 세계로 되돌리면
// 뼈가 어떻게 움직였든 실제로 그려진 높이가 나옵니다.

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
/// 이 높이(세계 좌표) 아래가 사라집니다. 자동차 지붕 언저리입니다.
uniform float waist_y = 0.0;
/// 완전히 사라지기까지의 높이. 0 이면 칼로 자른 듯 끊깁니다 - 그러면 지운
/// 것이 아니라 잘린 몸으로 보입니다.
uniform float fade_span = 0.30;
/// 맨 아래에 남기는 정도. 0 이면 완전히 사라집니다.
uniform float keep = 0.0;

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo;
	ALBEDO = c.rgb;
	float wy = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	float t = clamp((wy - (waist_y - fade_span)) / max(fade_span, 0.001), 0.0, 1.0);
	ALPHA = c.a * mix(keep, 1.0, t);
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
