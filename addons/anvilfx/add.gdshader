// One layer of an AnvilFX sheet. Fades by `opacity` and hides everything left of `cut_u` (atlas UV),
// feathered over `feather_u`, so a trail strip can be revealed from its head. The node's `modulate` tints and
// fades it too (a multiply holdout only fades: tinting a shadow would colour the ground).
shader_type canvas_item;
render_mode blend_add;

uniform float opacity = 1.0;
uniform float cut_u = -1.0;
uniform float feather_u = 0.0001;

varying vec4 tint;

void vertex() {
	tint = COLOR;   // modulate times self_modulate
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float k = clamp((UV.x - cut_u) / feather_u, 0.0, 1.0) * opacity * tint.a;
	COLOR = vec4(c.rgb * tint.rgb * k, c.a);
}
