
#pragma language glsl3

varying vec4 frag_position;

#ifdef VERTEX
extern mat4 u_model;
extern mat4 u_lightspace;

attribute vec4 VertexWeight;
attribute vec4 VertexBone;

uniform bool instance_draw_call;
attribute vec4 InstanceColumn1;
attribute vec4 InstanceColumn2;
attribute vec4 InstanceColumn3;
attribute vec4 InstanceColumn4;

uniform mat4 u_bone_matrices[64];
uniform int  u_skinning;

mat4 get_instance_model() {
	return mat4(InstanceColumn1,
				InstanceColumn2,
				InstanceColumn3,
				InstanceColumn4);
}

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

mat4 get_model_matrix() {
	if (instance_draw_call) {
		return mat4(InstanceColumn1,
		            InstanceColumn2,
		            InstanceColumn3,
		            InstanceColumn4);
	}
	return u_model;
}

vec4 position(mat4 transform, vec4 vertex) {
	mat4 skin_u = get_model_matrix() * get_deform_matrix();
	vec4 pos_v = u_lightspace * skin_u * vertex;
	frag_position = pos_v;
	return pos_v;
}

#endif

#ifdef PIXEL
	uniform vec3 light_pos;
	uniform float far_plane;

	void effect() {
		gl_FragDepth = gl_FragCoord.z;
		// get distance between fragment and light source
    	float light_distance = length(frag_position.xyz - light_pos);

		// map to [0;1] range by dividing by far_plane
		light_distance = light_distance / far_plane;

		// write this as modified depth
		gl_FragDepth = light_distance;
	}
#endif
