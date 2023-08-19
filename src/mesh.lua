-- custom mesh class for love2d meshes
--

Mesh = {}
Mesh.__index = Mesh

function Mesh:new(tex, ...)
	local arg = {...}
	local this = {
		mesh = love.graphics.newMesh(unpack(arg)),
		texture = tex
	}

	setmetatable(this,Mesh)

	if this.texture then
		t = this.texture:getImage()
		if t then
			this.mesh:setTexture(t)
		end
	end

	return this
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
	local x1,y1,z1 = self.mesh.getVertexAttribute(1, 1)
	local x2,y2,z2 = self.mesh.getVertexAttribute(2, 1)
	local x3,y3,z3 = self.mesh.getVertexAttribute(3, 1)

	x2 = x2 - x1
	y2 = y2 - y1
	z2 = z2 - z1

	x3 = x3 - x1
	y3 = y3 - y1
	z3 = z3 - z1

	local a,b = cpml.vec3(x2,y2,z2), cpml.vec3(x3,y3,z3)
end
