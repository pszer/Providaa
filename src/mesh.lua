-- custom mesh class for love2d meshes
--

local cpml = require 'cpml'

Mesh = {

	atypes = {
	  {"VertexPosition", "float", 3},
	  {"VertexTexCoord", "float", 2},
	  {"VertexNormal"  , "float", 3}
	},

	vertex_attribute = 1,
	texcoord_attribute = 2,
	normal_attribute = 3

}
Mesh.__index = Mesh

function Mesh:new(tex, ...)
	local arg = {...}
	local this = {
		mesh = love.graphics.newMesh(Mesh.atypes, unpack(arg)),
		texture = tex,
	}

	this.mesh:setDrawRange(1,3000)

	setmetatable(this,Mesh)

	if this.texture then
		t = this.texture:getImage()
		if t then
			this.mesh:setTexture(t)
		end
	end

	return this
end

function Mesh:setTriangle(index, v1, v2, v3)
	self.mesh:setVertex(index,   v1)
	self.mesh:setVertex(index+1, v2)
	self.mesh:setVertex(index+2, v3)
end

function Mesh:setRectangle(index, v1, v2, v3, v4)
	--local vmap = {1,2,3, 3,4,1}
	self:setTriangle(index, v1, v2, v3)
	self:setTriangle(index+3, v3, v4, v1)
end

function Mesh.mergeMeshes(texture, list)
	local length = #list

	local count = 0
	for i = 1, length do
		count = count + list[i].mesh:getVertexCount()
	end

	print(length,"meshes",count,"verts")

	local mesh = Mesh:new(texture, count, "triangles", "dynamic")
	mesh.mesh:setDrawRange(1, count*2)

	local V = 1
	for i = 1, length do
		local m = list[i]
		local vcount = m.mesh:getVertexCount()
		
		for j=1,vcount do
			local vertex = {m.mesh:getVertex(j)}
			mesh.mesh:setVertex(V, vertex)
			V = V + 1
		end
	end

	return mesh
end

function Mesh:updateTexture()
	if self.texture then
		if self.texture:animationChangesThisTick() and UPDATE_ANIMATION then
			local t = self.texture:getImage()
			if t then
				self.mesh:setTexture(t)
			end
		end
	end
end

function Mesh:draw()
	if self.mesh then
		love.graphics.draw(self.mesh)
	end
end

function Mesh:scaleTexture(scalex, scaley)
	scaley = scaley or scalex

	-- prevent division by 0
	if scalex == 0 then scalex = 0.01 end
	if scaley == 0 then scaley = 0.01 end

	local mesh = self.mesh
	for i = 1,mesh:getVertexCount() do
		local u,v = mesh:getVertexAttribute(i, 2)
		mesh:setVertexAttribute(i, 2, u/scalex,v/scaley)
	end
end

function Mesh:translateTexture(x,y)
	local mesh = self.mesh
	for i = 1,mesh:getVertexCount() do
		local u,v = mesh:getVertexAttribute(i, 2)
		mesh:setVertexAttribute(i, 2, u - x,v - y)
	end
end

function Mesh:fitTexture(xunit,yunit)
	local w,h = self.texture.props.texture_width, self.texture.props.texture_height
	self:scaleTexture(w/xunit, h/yunit)
end

function Mesh:scaleFittedTexture(xunit,yunit,x,y)
	local w,h = self.texture.props.texture_width, self.texture.props.texture_height
	self:translateTexture(x/xunit, y/yunit)
end

function Mesh:calculateNormal()
	local vmap = self.mesh:getVertexMap()

	for i=1,self.mesh:getVertexCount(), 3 do 

		local x1,y1,z1 = self.mesh:getVertexAttribute(i  , Mesh.vertex_attribute)
		local x2,y2,z2 = self.mesh:getVertexAttribute(i+1, Mesh.vertex_attribute)
		local x3,y3,z3 = self.mesh:getVertexAttribute(i+2, Mesh.vertex_attribute)

		x2 = x2 - x1
		y2 = y2 - y1
		z2 = z2 - z1

		x3 = x3 - x1
		y3 = y3 - y1
		z3 = z3 - z1

		local a,b = cpml.vec3(x2,y2,z2), cpml.vec3(x3,y3,z3)
		local norm = cpml.vec3.cross(a,b)
		norm = cpml.vec3.normalize(norm)

		self.mesh:setVertexAttribute(i  , Mesh.vertex_attribute, norm.x, norm.y, norm.z)
		self.mesh:setVertexAttribute(i+1, Mesh.vertex_attribute, norm.x, norm.y, norm.z)
		self.mesh:setVertexAttribute(i+2, Mesh.vertex_attribute, norm.x, norm.y, norm.z)

	end
end

function Mesh:normal()
	return self.normal
end

function Mesh:testAgainstDirection(x,y,z, threshold)
	local normal = self.normal
	local dot = cpml.vec3.dot(normal,cpml.vec3.new(x,y,z))
	return dot > threshold
end