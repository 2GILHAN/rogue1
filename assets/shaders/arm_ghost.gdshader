shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// 몸 전체를 복제해 놓고 **팔 언저리만 남기는** 잔상.
//
// # 왜 이렇게 하는가
//
// 팔만 따로 복제할 수가 없습니다 - 몸은 스킨 메시 하나라 "팔" 이라는 조각이
// 없습니다. 그래서 통째로 복제한 뒤, 남길 자리(두 손의 가운데)에서 멀어질수록
// 지워 버립니다. 결과는 팔만 파랗게 남은 잔상입니다.
//
// 구르기 잔상과 같은 파랑을 씁니다(Fx.RUSH_COLOR). 두 기술이 같은 힘에서
// 나온 것으로 읽히게.

uniform vec4 tint : source_color = vec4(0.34, 0.66, 1.0, 0.7);
// 남길 자리와 그 반경(월드 좌표).
uniform vec3 center = vec3(0.0);
uniform float radius = 0.36;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = distance(world_pos, center);
	// 안쪽은 그대로, 바깥으로 갈수록 옅어지다 사라집니다.
	float keep = 1.0 - smoothstep(radius * 0.55, radius, d);
	if (keep < 0.02) {
		discard;
	}
	ALBEDO = tint.rgb;
	ALPHA = tint.a * keep;
}
