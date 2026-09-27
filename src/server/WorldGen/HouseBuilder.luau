--!strict
-- Procedural medieval-style house: four walls, a pitched wedge roof, a door,
-- and a chimney. Deliberately simple/low-poly Part geometry since no mesh
-- pipeline is available in this environment (see HANDOFF.md).

local PartUtil = require(script.Parent.PartUtil)

local HouseBuilder = {}

export type HouseOptions = {
	Position: Vector3, -- ground-level position (base of the walls sits here)
	FacingAngle: number, -- radians, which way the door faces
	Width: number?,
	Depth: number?,
	WallHeight: number?,
	WallColor: Color3?,
	RoofColor: Color3?,
}

function HouseBuilder.Build(options: HouseOptions): Model
	local width = options.Width or 16
	local depth = options.Depth or 14
	local wallHeight = options.WallHeight or 10
	local wallColor = options.WallColor or Color3.fromRGB(198, 173, 133)
	local roofColor = options.RoofColor or Color3.fromRGB(120, 58, 47)

	local model = Instance.new("Model")
	model.Name = "House"

	local baseCFrame = CFrame.new(options.Position) * CFrame.Angles(0, options.FacingAngle, 0)

	local function place(localCFrame: CFrame): CFrame
		return baseCFrame * localCFrame
	end

	-- Floor
	local floor = PartUtil.NewPart({
		Name = "Floor",
		Size = Vector3.new(width, 1, depth),
		CFrame = place(CFrame.new(0, 0.5, 0)),
		Color = Color3.fromRGB(90, 70, 55),
		Material = Enum.Material.WoodPlanks,
	})
	floor.Parent = model

	local wallThickness = 1
	local doorWidth = 4
	local doorHeight = 7

	-- Back wall (opposite the door, full wall)
	local backWall = PartUtil.NewPart({
		Name = "BackWall",
		Size = Vector3.new(width, wallHeight, wallThickness),
		CFrame = place(CFrame.new(0, wallHeight / 2 + 1, -depth / 2)),
		Color = wallColor,
		Material = Enum.Material.Brick,
	})
	backWall.Parent = model

	-- Side walls
	local leftWall = PartUtil.NewPart({
		Name = "LeftWall",
		Size = Vector3.new(wallThickness, wallHeight, depth),
		CFrame = place(CFrame.new(-width / 2, wallHeight / 2 + 1, 0)),
		Color = wallColor,
		Material = Enum.Material.Brick,
	})
	leftWall.Parent = model

	local rightWall = PartUtil.NewPart({
		Name = "RightWall",
		Size = Vector3.new(wallThickness, wallHeight, depth),
		CFrame = place(CFrame.new(width / 2, wallHeight / 2 + 1, 0)),
		Color = wallColor,
		Material = Enum.Material.Brick,
	})
	rightWall.Parent = model

	-- Front wall split around the doorway: two side segments + a lintel above the door
	local frontSegmentWidth = (width - doorWidth) / 2
	local frontLeft = PartUtil.NewPart({
		Name = "FrontWallLeft",
		Size = Vector3.new(frontSegmentWidth, wallHeight, wallThickness),
		CFrame = place(CFrame.new(-(doorWidth / 2 + frontSegmentWidth / 2), wallHeight / 2 + 1, depth / 2)),
		Color = wallColor,
		Material = Enum.Material.Brick,
	})
	frontLeft.Parent = model

	local frontRight = PartUtil.NewPart({
		Name = "FrontWallRight",
		Size = Vector3.new(frontSegmentWidth, wallHeight, wallThickness),
		CFrame = place(CFrame.new(doorWidth / 2 + frontSegmentWidth / 2, wallHeight / 2 + 1, depth / 2)),
		Color = wallColor,
		Material = Enum.Material.Brick,
	})
	frontRight.Parent = model

	local lintelHeight = wallHeight - doorHeight
	if lintelHeight > 0 then
		local lintel = PartUtil.NewPart({
			Name = "Lintel",
			Size = Vector3.new(doorWidth, lintelHeight, wallThickness),
			CFrame = place(CFrame.new(0, doorHeight + lintelHeight / 2 + 1, depth / 2)),
			Color = wallColor,
			Material = Enum.Material.Brick,
		})
		lintel.Parent = model
	end

	-- Door (non-functional, just dressing)
	local door = PartUtil.NewPart({
		Name = "Door",
		Size = Vector3.new(doorWidth - 0.4, doorHeight - 0.4, 0.4),
		CFrame = place(CFrame.new(0, doorHeight / 2 + 1, depth / 2 - 0.2)),
		Color = Color3.fromRGB(76, 46, 30),
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
	})
	door.Parent = model

	-- Pitched roof made of two wedges meeting at a ridge
	local roofOverhang = 1.5
	local roofWidth = width + roofOverhang * 2
	local roofSlopeDepth = depth / 2 + roofOverhang
	local roofBaseY = wallHeight + 1
	local roofRise = 6

	local roofLeft = PartUtil.NewWedge({
		Name = "RoofLeft",
		Size = Vector3.new(roofRise, roofSlopeDepth, roofWidth),
		CFrame = place(CFrame.new(0, roofBaseY + roofRise / 2, -roofSlopeDepth / 2 + depth / 2)
			* CFrame.Angles(0, 0, math.rad(90))
			* CFrame.Angles(math.rad(90), 0, 0)),
		Color = roofColor,
		Material = Enum.Material.Slate,
	})
	roofLeft.Parent = model

	local roofRight = PartUtil.NewWedge({
		Name = "RoofRight",
		Size = Vector3.new(roofRise, roofSlopeDepth, roofWidth),
		CFrame = place(CFrame.new(0, roofBaseY + roofRise / 2, roofSlopeDepth / 2 - depth / 2)
			* CFrame.Angles(0, math.rad(180), 0)
			* CFrame.Angles(0, 0, math.rad(90))
			* CFrame.Angles(math.rad(90), 0, 0)),
		Color = roofColor,
		Material = Enum.Material.Slate,
	})
	roofRight.Parent = model

	-- Ridge cap to hide the seam between the two wedges
	local ridge = PartUtil.NewPart({
		Name = "RoofRidge",
		Size = Vector3.new(roofWidth, 1, 1.4),
		CFrame = place(CFrame.new(0, roofBaseY + roofRise, 0)),
		Color = roofColor,
		Material = Enum.Material.Slate,
	})
	ridge.Parent = model

	-- Chimney
	local chimney = PartUtil.NewPart({
		Name = "Chimney",
		Size = Vector3.new(2, 6, 2),
		CFrame = place(CFrame.new(width / 4, roofBaseY + roofRise / 2 + 3, -depth / 4)),
		Color = Color3.fromRGB(120, 110, 105),
		Material = Enum.Material.Concrete,
	})
	chimney.Parent = model

	model.PrimaryPart = floor
	return model
end

return HouseBuilder
