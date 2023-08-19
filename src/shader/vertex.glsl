extern mat4 u_proj;
extern mat4 u_view;
extern mat4 u_rot;
//extern mat4 u_model;
//
extern float curve_coeff;
extern bool curve_flag;

vec4 position(mat4 transform, vec4 vertex) {
	vec4 view_v = u_view * vertex;

	if (curve_flag) {
		view_v.y = view_v.y + (view_v.z*view_v.z) / curve_coeff;
	}

	return u_proj * u_rot * view_v;
}
