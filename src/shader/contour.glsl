#pragma language glsl3

/* redundant code, this file can be removed.
   the contour line pass has been integrated into the main vertex.glsl shader */

#ifdef VERTEX

uniform mat4 u_view;
uniform mat4 u_rot;
uniform mat4 u_model;
uniform mat4 u_proj;
uniform mat4 u_normal_model;

uniform float curve_coeff;
uniform bool curve_flag;

attribute vec3 VertexNormal;
attribute vec4 VertexWeight;
attribute vec4 VertexBone;
attribute vec4 VertexTangent;

uniform mat4 u_bone_matrices[48];
uniform int  u_skinning;

mat4 get_deform_matrix() {
	if (u_skinning != 0) {
		return
			u_bone_matrices[int(VertexBone.x*255.0)] * VertexWeight.x +
			u_bone_matrices[int(VertexBone.y*255.0)] * VertexWeight.y +
			u_bone_matrices[int(VertexBone.z*255.0)] * VertexWeight.z +
			u_bone_matrices[int(VertexBone.w*255.0)] * VertexWeight.w;
	}
	return mat4(1.0);
}

mat3 get_normal_matrix(mat4 skin_u) {
	// u_normal_model matrix is calculated outside and passed to shader
	// if skinning is enabled then this needs to be recalculated
	if (u_skinning != 0) {
		return mat3(transpose(inverse(skin_u)));
	}
	return mat3(u_normal_model);
}

mat4 get_model_matrix() {
	return u_model;
}

vec4 position(mat4 transform, vec4 vertex) {
	mat4 skin_u = get_model_matrix() * get_deform_matrix();
	mat4 skinview_u = u_view * skin_u;

	vec4 model_v = skin_u * vertex;
	vec4 view_v = skinview_u * vertex;

	// create a fake curved horizon effect
	if (curve_flag) {
		view_v.y = view_v.y + (view_v.z*view_v.z) / curve_coeff; }

	view_v = u_rot * view_v;

	vec3 frag_normal = mat3(u_rot) * get_normal_matrix(skin_u) * VertexNormal;
	vec4 surface_offset = vec4(frag_normal * 0.25, 0.0);
	view_v += surface_offset;

	return u_proj * view_v;
}
#endif

#ifdef PIXEL

uniform vec4 solid_colour;

vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
	return solid_colour;
}

#endif
