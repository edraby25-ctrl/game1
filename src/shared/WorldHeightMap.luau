--!strict
-- Single source of truth for "how tall is the ground at (x, z)". Used by
-- TerrainService (paints voxel terrain to match) and anything that places an
-- Instance on the ground (buildings, trees, NPC spawn points), so nothing
-- floats or clips. Deterministic: same input, same output, every call.
local Constants = require(script.Parent.Constants)

local WorldHeightMap = {}

local function noise(x: number, z: number): number
	return (math.noise(x * 0.015, z * 0.015, 7) + 1) * 0.5
end

-- Ground's Y coordinate (not height-above-zero) at (x, z): flat near the
-- village center, easing up into hills toward the outer forest ring.
function WorldHeightMap.GetGroundY(x: number, z: number): number
	local distance = math.sqrt(x * x + z * z)
	local world = Constants.World

	if distance <= world.VillageRadius then
		return world.GroundLevel + noise(x, z) * 1.5
	end

	local t = math.clamp(
		(distance - world.VillageRadius) / (world.ForestRingOuter - world.VillageRadius),
		0,
		1
	)
	local eased = t * t
	return world.GroundLevel + eased * world.MaxHillHeight * (0.4 + 0.6 * noise(x, z))
end

return WorldHeightMap
