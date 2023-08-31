#ifdef VERTEX

extern mat4 u_model;
extern mat4 u_lightspace;
//extern mat4 u_view;
//extern mat4 u_rot;
//extern mat4 u_proj;

attribute vec4 VertexWeight;
attribute vec4 VertexBone;

uniform mat4 u_bone_matrices[64];
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

vec4 position(mat4 transform, vec4 vertex) {
	mat4 skin_u = u_model * get_deform_matrix();
	vec4 pos_v = u_lightspace * skin_u * vertex;
	//vec4 pos_v = u_proj * u_rot * u_view * skin_u * vertex;
	return pos_v;
}

#endif

#ifdef PIXEL
	vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords ) {
		gl_FragDepth = gl_FragCoord.z;
		//return vec4(1) * -gl_FragCoord.z;
		//return vec4(1) * gl_FragCoord.z;
		//return vec4(1) * gl_FragCoord.z;
		return vec4(vec3(1) * gl_FragCoord.z,1);
	}
#endif
