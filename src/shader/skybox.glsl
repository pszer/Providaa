#pragma language glsl3

uniform CubeImage skybox;
varying vec3 cube_coords;

#ifdef VERTEX
	extern mat4 u_proj;
	extern mat4 u_rot;

	vec4 position(mat4 mvp, vec4 v_position)
    {
        cube_coords = normalize(v_position.xyz);
		return u_proj * u_rot * v_position;
	}
#endif

#ifdef PIXEL
    vec4 effect(vec4 pixel_color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
		vec3 pix_color = Texel(skybox, cube_coords).rgb;
        //return Texel(skybox, cube_coords);
		return vec4(pix_color, 1.0);
	}
#endif
