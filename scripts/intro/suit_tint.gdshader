shader_type canvas_item;
// Recolorea el traje azul del astronauta (assets/characters/astronaut.png) con el color del rol.
// Solo afecta a píxeles claramente azules; visor, piel, mochila y contorno quedan igual.
// Cuando haya sprites propios por rol, basta con quitar este material.

uniform vec4 suit_color : source_color = vec4(1.0, 0.7, 0.28, 1.0);

void fragment() {
	vec4 c = COLOR;
	if (c.a > 0.0 && c.b > 0.35 && c.b - max(c.r, c.g) > 0.2) {
		float t = min(c.b * 1.1, 1.0);
		float hi = t > 0.8 ? 0.25 * (t - 0.8) : 0.0;
		c.rgb = min(suit_color.rgb * t + vec3(hi), vec3(1.0));
	}
	COLOR = c;
}
