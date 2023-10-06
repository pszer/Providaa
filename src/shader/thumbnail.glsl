#pragma language glsl3

#ifdef VERTEX

uniform mat4 u_view;
uniform mat4 u_model;
uniform mat4 u_proj;

vec4 position(mat4 transform, vec4 vertex) {
	return u_proj * u_view * u_model * vertex;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec4 texturecolor = Texel(tex, texture_coords);
    return texturecolor * color;
}
#endif
