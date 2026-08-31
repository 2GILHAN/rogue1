shader_type canvas_item;

// 책을 읽는 동안 **바깥부터** 어두워집니다.
//
// # 왜 필요한가
//
// 읽는 2초 동안 조작이 잠기고 적도 멈춥니다. 화면이 그대로면 그냥 멈춘 것으로
// 보여서, 멈춘 것이 아니라 **잠깐 다른 시간에 들어갔다**로 읽히게 만듭니다.
//
// # 왜 가운데가 아니라 바깥인가
//
// 가운데를 밝히는 것이 아니라 가장자리를 지웁니다. 아이와 책만 남기고 방이
// 물러나는 그림이라, 시선이 저절로 손에 든 것으로 갑니다.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
// 화면이 가로로 길어서 그대로 재면 타원이 아니라 납작한 원이 됩니다.
uniform float aspect = 1.78;
// 남길 자리. 아이가 화면 한가운데 있지 않을 때도 있어서 매 프레임 받습니다.
uniform vec2 center = vec2(0.5, 0.5);
// 아이만 남기는 반경과, 완전히 검어지는 반경(화면 짧은 변 기준).
//
// 좁습니다. 방을 조금 어둡게 하는 것이 아니라 **아이와 책만 남기고 나머지는
// 없애는** 것이라, 남는 자리가 아이 키 두어 배면 충분합니다.
uniform float inner = 0.07;
uniform float outer = 0.20;
uniform float max_dark : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 d = UV - center;
	d.x *= aspect;
	float r = length(d);
	float dark = smoothstep(inner, outer, r) * amount * max_dark;
	COLOR = vec4(0.0, 0.0, 0.0, dark);
}
