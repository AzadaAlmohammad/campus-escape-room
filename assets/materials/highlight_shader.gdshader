shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 0.3, 0.5);
uniform float fresnel_power : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
	ALBEDO = highlight_color.rgb;
	ALPHA = fresnel * highlight_color.a;
}
