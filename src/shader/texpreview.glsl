#pragma language glsl3

#ifdef PIXEL
	uniform vec2 texture_scale;
	uniform vec2 texture_offset;
	uniform Image tex;

	vec2 calc_tex_coords( vec2 uv_coords ) {
		vec2 t_off = texture_offset;
		vec2 t_scale = texture_scale;

		uv_coords.x = mod(uv_coords.x/t_scale.x - t_off.x, 1.0);
		uv_coords.y = mod(uv_coords.y/t_scale.y - t_off.y, 1.0);
	
		return uv_coords;
	}

	vec4 effect( vec4 color, Image _t, vec2 texture_coords, vec2 screen_coords ) {
			vec4 texcolor = Texel(tex, calc_tex_coords(texture_coords));
			return texcolor * color;
	}
#endif

#ifdef VERTEX
	vec4 position( mat4 transform_projection, vec4 vertex_position )
	{
			return transform_projection * vertex_position;
	}
#endif
