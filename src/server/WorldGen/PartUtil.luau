--!strict
-- Small shared helpers for procedural Part-based geometry. Used by every
-- WorldGen builder (houses, trees, NPC rig) so anchoring/material/collision
-- defaults stay consistent instead of being repeated at every call site.

local PartUtil = {}

export type PartSpec = {
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Anchored: boolean?,
	CanCollide: boolean?,
	Shape: Enum.PartType?,
	Name: string?,
}

function PartUtil.NewPart(spec: PartSpec): BasePart
	local part: BasePart
	if spec.Shape and spec.Shape ~= Enum.PartType.Block then
		local p = Instance.new("Part")
		p.Shape = spec.Shape
		part = p
	else
		part = Instance.new("Part")
	end

	part.Name = spec.Name or "Part"
	part.Size = spec.Size
	part.CFrame = spec.CFrame
	part.Color = spec.Color or Color3.fromRGB(255, 255, 255)
	part.Material = spec.Material or Enum.Material.SmoothPlastic
	part.Anchored = if spec.Anchored == nil then true else spec.Anchored
	part.CanCollide = if spec.CanCollide == nil then true else spec.CanCollide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	return part
end

function PartUtil.NewWedge(spec: PartSpec): BasePart
	local part = Instance.new("WedgePart")
	part.Name = spec.Name or "Wedge"
	part.Size = spec.Size
	part.CFrame = spec.CFrame
	part.Color = spec.Color or Color3.fromRGB(255, 255, 255)
	part.Material = spec.Material or Enum.Material.SmoothPlastic
	part.Anchored = if spec.Anchored == nil then true else spec.Anchored
	part.CanCollide = if spec.CanCollide == nil then true else spec.CanCollide
	return part
end

return PartUtil
