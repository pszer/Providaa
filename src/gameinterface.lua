-- entities want information such as: what other entities are there, what tile am i standing on etc.
-- this game state information is all held by Prov in providaa.lua, but it can be somewhat scattered
-- and requires knowledge of how this gamestate is managed,
-- making it difficult to write entity behaviour and would require a messy 'require "providaa"'
-- 
-- entities get given a game state interface through which they can query the game state with functions.
-- the wont have direct access to Prov and these functions have predictable side-effects.
--

require "table"
require 'tile'
require 'boundingbox'
require 'quadtree'

GameData = {}
GameData.__index = {}

function GameData:setUpFromProv( Prov )

	function GameData:getTileAtWorldCoord(x,y,z)

	end

	function GameData:getTileAtTileCoord(x,z)

	end

	GameData.tileCoordToWorld = Tile.tileCoordToWorld
	GameData.worldCoordToTile = Tile.worldCoordToTile

	function GameData:queryEntity(name)
		return Prov.ents[name]
	end

	-- for now these spacial query functions are shit and don't utilize any space
	-- partitioning
	function GameData:queryEntitiesAtPoint( point_vec )
		local ents_tested = {}
		for i,ent in ipairs(Prov.ents) do
			local x,y,z, dx,dy,dz = ent:getWorldHitbox()
				
			local test = testPointInBoundingBox(point_vec, {x,y,z}, {dx,dy,dz})

			if test then
				table.insert(ents_tested, ent)
			end
		end
	end -- queryEntitiesAtPoint

	function GameData:queryEntitiesInRegion( rect_pos , rect_size )

	end -- queryEntitiesInRegion

	function GameData:queryLight()

	end

	function GameData:createEntity(prototype, props)

	end

end

