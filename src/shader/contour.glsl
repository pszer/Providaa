#pragma language glsl3

#ifdef PIXEL

uniform vec4 solid_colour;

void effect( ) {
	if (draw_as_solid_colour) {
		love_Canvases[0] = solid_colour;
		love_Canvases[1] = vec4(0,0,0,0);
	}
}

#endif
