#pragma language glsl3

varying vec3 frag_position;
varying vec3 frag_w_position;
varying vec4 dir_frag_light_pos;
varying vec4 dir_static_frag_light_pos;
varying vec3 frag_normal;

uniform bool  u_uses_tileatlas;
uniform Image u_tileatlas;
uniform vec4  u_tileatlas_uv[128];

uniform bool u_wireframe_enabled;

#ifdef VERTEX

flat out vec2 texscale;
flat out vec2 texoffset;
flat out int  tex_uv_index;
varying float highlight_attr;

uniform mat4 u_view;
uniform mat4 u_rot;
uniform mat4 u_model;
uniform mat4 u_proj;
uniform mat4 u_normal_model;

uniform bool u_apply_a_transformation;
uniform mat4 u_transform_a;
uniform bool u_apply_a_mesh_transformation;
uniform mat4 u_mesh_transform_a;

uniform float curve_coeff;
uniform bool curve_flag;

attribute vec3 VertexNormal;
attribute vec4 VertexWeight;
attribute vec4 VertexBone;
attribute vec4 VertexTangent;

uniform bool instance_draw_call;
attribute vec4 InstanceColumn1;
attribute vec4 InstanceColumn2;
attribute vec4 InstanceColumn3;
attribute vec4 InstanceColumn4;

attribute vec2 TextureScale;
attribute vec2 TextureOffset;
attribute float TextureUvIndex;

attribute float HighlightAttribute;

uniform mat4 u_bone_matrices[48];
uniform int  u_skinning;

uniform float u_contour_outline_offset;

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
	return mat3(transpose(inverse(skin_u)));
}

mat4 get_instance_model() {
	return mat4(InstanceColumn1,
				InstanceColumn2,
				InstanceColumn3,
				InstanceColumn4);
}

mat4 get_model_matrix() {
	if (instance_draw_call) {
		return mat4(InstanceColumn1,
		            InstanceColumn2,
		            InstanceColumn3,
		            InstanceColumn4);
	} else {
		return u_model;
	}
}

mat4 apply_a_transformation(mat4 model) {
	return u_transform_a * model;
}
mat4 apply_a_mesh_transformation(mat4 model) {
	return u_mesh_transform_a * model;
}

vec4 position(mat4 transform, vec4 vertex) {
	mat4 skin_u = get_model_matrix() * get_deform_matrix();
	//mat4 skin_u = get_model_matrix();

	if (u_apply_a_transformation) {
		skin_u = apply_a_transformation(skin_u); }
	else if (u_apply_a_mesh_transformation) {
		skin_u = apply_a_mesh_transformation(skin_u); }

	mat4 skinview_u = u_view * skin_u;

	frag_normal = normalize(get_normal_matrix(skin_u) * VertexNormal);

	vec4 model_v = skin_u * vertex;
	vec4 view_v = skinview_u * vertex;

	if (u_contour_outline_offset != 0.0) {
		vec4 surface_offset = vec4(frag_normal * u_contour_outline_offset, 0.0);
		view_v += surface_offset;
	}

	frag_position = (u_rot * view_v).xyz;
	view_v = u_rot * view_v;

	// in wireframe mode, add a small offset to the vertex to stop z-fighting
	if (u_wireframe_enabled) {
		view_v.xyz += frag_normal*0.05;
	}

	// interpolate fragment position in viewspace and worldspace
	frag_w_position = model_v.xyz;

	// apply texture offset/scaling
	if (u_uses_tileatlas) {
		texscale = TextureScale;
		if (texscale.x == 0) { texscale.x = 1; }
		if (texscale.y == 0) { texscale.y = 1; }
		texoffset = TextureOffset;
		tex_uv_index = int(TextureUvIndex);
	}

	highlight_attr = HighlightAttribute;

	return u_proj * view_v;
}
#endif

#ifdef PIXEL

flat in vec2 texscale;
flat in vec2 texoffset;
flat in int  tex_uv_index;
varying float highlight_attr;

uniform Image MainTex;

uniform vec4 u_wireframe_colour;
uniform vec4 u_selection_colour;

uniform bool u_solid_colour_enable;
uniform bool u_global_coord_uv_enable;
uniform bool u_highlight_pass;
uniform float u_time;

uniform bool u_draw_as_contour;
uniform vec4 u_contour_colour;

vec3 ambient_lighting( vec4 ambient_col ) {
	return ambient_col.rgb * ambient_col.a;
}

// diffuse lighting with a "clamped effect", there is very little transition between
// points in light and points in shadow so things look flatter
vec3 diffuse_lighting( vec3 normal, vec3 light_dir, vec4 light_col) {
	float diff = max(0.0, dot(normalize(normal), normalize(light_dir))) ;
	if (diff > 0.0) {
		diff = 1.0 - pow( 1.0 - diff , 8 );
		diff = min(1.0, 1.3 * diff);
	}
	//float diff = max(0.0, dot(normal, normalize(light_dir)));
	vec3 diff_col = light_col.rgb * light_col.a * diff;
	return diff_col;
}

vec3 specular_highlight( vec3 normal , vec3 light_dir, vec4 light_col ) {
	return vec3(0,0,0);
}

vec2 calc_tex_coords( vec2 uv_coords ) {
	if (u_uses_tileatlas) {
		vec2 t_off = texoffset;
		vec2 t_scale = texscale;
		vec4 uv_info = u_tileatlas_uv[tex_uv_index];

		uv_coords.x = mod(uv_coords.x/t_scale.x - t_off.x, 1.0);
		uv_coords.y = mod(uv_coords.y/t_scale.y - t_off.y, 1.0);
		
		return vec2(
			uv_info.x + uv_info.z * uv_coords.x,
			uv_info.y + uv_info.w * uv_coords.y
		);
	} else {
		return uv_coords;
	}
}

void effect( ) {
	if (u_draw_as_contour) {
		love_Canvases[0] = u_contour_colour;
		return;
	}

	if (u_highlight_pass) {
		if (highlight_attr < 0.5) {
			love_Canvases[0] = VaryingColor * 2.0*(highlight_attr-0.5);
			discard;
		}
	}
	if (u_solid_colour_enable) {
		love_Canvases[0] = VaryingColor;
	}
	if (u_wireframe_enabled) {
		vec4 col = u_wireframe_colour;
		if (highlight_attr != 0.0) {
			col = u_selection_colour;
		}

		float frag_dist = length(frag_position);
		float wireframe_dist = 600.0;
		float dd = (wireframe_dist - frag_dist) / wireframe_dist;
		float mul = frag_dist > wireframe_dist ? 0.0 : pow(dd, 1.5);
		love_Canvases[0] = vec4(col.xyz, col.a * mul);
		return;
	}

	if (u_uses_tileatlas && tex_uv_index < 0) {
		love_Canvases[0] = vec4(0.0);
		return;
	}

	vec3 light = vec3(1.0,1.0,1.0);
	vec2 coords;
	if (u_global_coord_uv_enable) {
		vec3 n = frag_normal;
		float ny = n.y!=0?1:0;
		float s = dot(frag_normal,vec3(0,0,1));
		if (s==0) {s=1;}
		float S = dot(frag_normal,vec3(1,0,0));
		if (S==0) {s=1;}
		float u = frag_w_position.x*s + frag_w_position.z*(1.0-ny)*S;
		float v = frag_w_position.y + frag_w_position.z*ny;
		coords = vec2((u + 6*u_time)/16.0, (v + 6*u_time)/16.0);
	} else {
		coords = calc_tex_coords(vec2(VaryingTexCoord));
	}

	vec4 texcolor = Texel(MainTex, coords);
	vec4 pix = texcolor * vec4(light,1.0);

	love_Canvases[0] = pix * VaryingColor;
}

#endif
