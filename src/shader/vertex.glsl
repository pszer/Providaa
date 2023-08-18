extern mat4 u_proj;
extern mat4 u_view;

vec4 position(mat4 transform, vec4 vertex) {
	vec4 view_v = u_view * vertex;

	view_v.y = view_v.y + (view_v.z*view_v.z) / 1280;

	return u_proj * view_v;
}
