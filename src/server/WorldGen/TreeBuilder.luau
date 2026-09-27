--!strict
-- Procedural tree: a tapered trunk plus a cluster of foliage spheres.
-- Cheap to instantiate in bulk since a forest edge may need dozens of these.

local PartUtil = require(script.Parent.PartUtil)

local TreeBuilder = {}

export type TreeOptions = {
	Position: Vector3, -- ground-level position (base of the trunk)
	Height: number?,
	TrunkRadius: number?,
	Random: Random?,
}

function TreeBuilder.Build(options: TreeOptions): Model
	local rng = options.Random or Random.new()
	local height = options.Height or (14 + rng:NextNumber() * 8)
	local trunkRadius = options.TrunkRadius or (1 + rng:NextNumber() * 0.6)

	local model = Instance.new("Model")
	model.Name = "Tree"

	local trunk = PartUtil.NewPart({
		Name = "Trunk",
		Size = Vector3.new(trunkRadius * 2, height, trunkRadius * 2),
		CFrame = CFrame.new(options.Position + Vector3.new(0, height / 2, 0)),
		Color = Color3.fromRGB(82, 55, 35),
		Material = Enum.Material.Wood,
		Shape = Enum.PartType.Cylinder,
	})
	-- Roblox cylinders point along local X by default; rotate to stand upright.
	trunk.CFrame = trunk.CFrame * CFrame.Angles(0, 0, math.rad(90))
	trunk.Parent = model

	local foliageColor = Color3.fromRGB(
		40 + rng:NextInteger(0, 25),
		90 + rng:NextInteger(0, 30),
		40 + rng:NextInteger(0, 20)
	)

	local canopyBaseY = options.Position.Y + height * 0.75
	local clusterCount = 3 + rng:NextInteger(0, 2)
	for i = 1, clusterCount do
		local angle = (i / clusterCount) * math.pi * 2
		local offsetRadius = trunkRadius * 1.5
		local offset = Vector3.new(math.cos(angle) * offsetRadius, rng:NextNumber() * 3, math.sin(angle) * offsetRadius)
		local blobSize = 6 + rng:NextNumber() * 3

		local foliage = PartUtil.NewPart({
			Name = "Foliage",
			Size = Vector3.new(blobSize, blobSize, blobSize),
			CFrame = CFrame.new(options.Position + offset + Vector3.new(0, canopyBaseY - options.Position.Y, 0)),
			Color = foliageColor,
			Material = Enum.Material.Grass,
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		})
		foliage.Parent = model
	end

	-- One larger central mass so the canopy reads as a single tree, not a ring of balls.
	local core = PartUtil.NewPart({
		Name = "FoliageCore",
		Size = Vector3.new(9, 9, 9),
		CFrame = CFrame.new(options.Position + Vector3.new(0, canopyBaseY - options.Position.Y, 0)),
		Color = foliageColor,
		Material = Enum.Material.Grass,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
	})
	core.Parent = model

	model.PrimaryPart = trunk
	return model
end

return TreeBuilder
