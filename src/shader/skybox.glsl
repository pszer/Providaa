#pragma language glsl3

uniform CubeImage skybox;
uniform float skybox_brightness;

varying vec3 cube_coords;

#ifdef VERTEX
	extern mat4 u_proj;
	extern mat4 u_rot;

	vec4 position(mat4 mvp, vec4 v_position)
    {
        cube_coords = normalize(v_position.xyz);
		cube_coords.y = -cube_coords.y;
		return u_proj * u_rot * v_position;
	}
#endif

#ifdef PIXEL
	void effect()
    {
		vec3 pix_color = Texel(skybox, cube_coords).rgb;
		vec4 result = vec4(pix_color * skybox_brightness,1.0);

		float brightness = dot(result.rgb, vec3(0.2126, 0.7152, 0.0722));

		love_Canvases[0] = result;
	}
#endif
