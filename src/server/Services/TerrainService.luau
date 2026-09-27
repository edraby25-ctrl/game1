--!strict
-- Paints the world's ground into Workspace.Terrain: a raised, gently rolling
-- landmass with a flat village clearing at the center and hills rising
-- toward a forest-edge ring further out. Terrain is voxel data, not an
-- Instance tree, so Rojo can't sync it from files -- it's generated here at
-- server start instead. Pairs with WorldHeightMap, which is the single
-- source of truth for ground height so buildings/trees/NPCs placed by other
-- services line up with what gets painted here.
--
-- Terrain:FillRegion calls are relatively expensive; this uses a coarse grid
-- of column fills (one call per ~8-stud cell) rather than per-voxel calls to
-- keep the call count low enough not to hitch the server on boot.
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local WorldHeightMap = require(Shared.WorldHeightMap)

local TerrainService = {}

local GRID_STEP = 8 -- studs per height-sample cell; coarser = fewer FillRegion calls

function TerrainService.Init()
	local terrain = Workspace.Terrain
	local world = Constants.World
	local half = world.ForestRingOuter
	local baseY = world.GroundLevel - 20 -- solid rock beneath the height map

	local cellsPerAxis = math.floor((half * 2) / GRID_STEP)
	local startCoord = -math.floor(cellsPerAxis / 2) * GRID_STEP

	for ix = 0, cellsPerAxis - 1 do
		local x = startCoord + ix * GRID_STEP
		for iz = 0, cellsPerAxis - 1 do
			local z = startCoord + iz * GRID_STEP
			local centerX = x + GRID_STEP / 2
			local centerZ = z + GRID_STEP / 2

			if centerX * centerX + centerZ * centerZ <= half * half then
				local topY = WorldHeightMap.GetGroundY(centerX, centerZ)
				local heightAboveBase = topY - world.GroundLevel

				local region = Region3.new(
					Vector3.new(x, baseY, z),
					Vector3.new(x + GRID_STEP, topY, z + GRID_STEP)
				):ExpandToGrid(4)

				local material = heightAboveBase > world.MaxHillHeight * 0.55
					and Enum.Material.Rock
					or Enum.Material.Grass

				terrain:FillRegion(region, 4, material)
			end
		end
	end

	print(string.format("[TerrainService] Generated terrain across radius %d studs.", half))
end

return TerrainService
