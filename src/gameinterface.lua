-- entities want information such as: what other entities are there, what tile am i standing on etc.
-- this game state information is all held by Prov in providaa.lua, but it can be somewhat scattered
-- and requires knowledge of how this gamestate is managed,
-- making it difficult to write entity behaviour and would require a messy 'require "providaa"'
-- 
-- entities get given a game state interface through which they can query the game state with functions.
-- they wont have direct access to Prov and these functions have predictable side-effects.
--

require "table"
require 'tile'
require 'boundingbox'

GameData = {}
GameData.__index = {}

function GameData:setupFromProv( Prov )

	function GameData:getTileAtWorldCoord(x,y,z)

	end

	function GameData:getTileAtTileCoord(x,z)

	end

	function GameData:tileCoordToWorld(x,y,z)
		return Tile.tileCoordToWorld(x,y,z)
	end
	function GameData:worldCoordToTile(x,y,z)
		return Tile.worldCoordToTile(x,y,z)
	end

	-- queries an entity by a given name
	function GameData:queryEntity(name)
		return Prov.ents[name]
	end

	function GameData:queryEntitiesAtPoint( point_vec )
		return Prov:queryEntitiesAtPoint( point_vec )
	end 

	-- finds all entities with hitboxes intersecting a given rectangle given by pos,size
	function GameData:queryEntitiesInRegion( rect_pos , rect_size )
		return Prov:queryEntitiesInRegion( rect_pos, rect_size )
	end 

	-- finds all entities with hitboxes intersecting a given rectangle given by min,max
	function GameData:queryEntitiesInRegionMinMax( min , max )
		local size = { max[1] - min[1] , max[2] - min[2] , max[3] - min[3] }
		return self:queryEntitiesInRegion( min , size )
	end

	-- gets the current directional light in the scene
	function GameData:queryLight()

	end

	-- creates and adds an entity to the world, returns said entity for further manipulation
	function GameData:createEntity(prototype, props)

	end

	-- raises an internal Prov event
	function GameData:raiseEvent(event, ...)

	end

	function GameData:getDt()
		return Prov.__dt
	end

end

