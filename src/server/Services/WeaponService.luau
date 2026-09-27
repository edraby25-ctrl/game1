--!strict
-- Equips every player with a sword welded to their right hand via a Motor6D,
-- so the client can swing it by tweening that joint's C0. The sword itself
-- is cloned from a template found in the world (Workspace.arming_sword),
-- falling back to a plain blocky sword if that isn't there.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

-- With zero rotation the sword pointed straight down, meaning the model's
-- blade runs along its own local -Y rather than -Z like the old procedural
-- sword -- this 90-degree X rotation remaps -Y to point forward instead.
-- The position offset is a rough starting point, not a fit to this specific
-- mesh's pivot; see the Command Bar tuning workflow if it's not seated right.
local GRIP_C0 = CFrame.new(0, -0.5, -0.2) * CFrame.Angles(math.rad(90), 0, 0)

-- The model came in ~3x smaller than intended; ScaleTo grows every part
-- proportionally around the model's pivot.
local SWORD_SCALE = 1.5

local WeaponService = {}

local swordTemplate: Instance

local function findSwordTemplate(): Instance?
	local instance = Workspace:FindFirstChild("arming_sword")
	if instance and (instance:IsA("Model") or instance:IsA("BasePart")) then
		return instance
	end
	return nil
end

local function buildBlockySword(): Model
	local model = Instance.new("Model")
	model.Name = "SwordTemplate"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 1.2)
	handle.Color = Color3.fromRGB(87, 61, 38)
	handle.Material = Enum.Material.Wood
	handle.Parent = model

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(1.2, 0.25, 0.25)
	guard.Color = Color3.fromRGB(150, 150, 150)
	guard.Material = Enum.Material.Metal
	guard.CFrame = handle.CFrame * CFrame.new(0, 0, -0.7)
	guard.Parent = model

	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(0.2, 0.6, 3)
	blade.Color = Color3.fromRGB(200, 200, 210)
	blade.Material = Enum.Material.Metal
	blade.CFrame = guard.CFrame * CFrame.new(0, 0, -1.6)
	blade.Parent = model

	model.PrimaryPart = handle
	return model
end

local function getPrimaryPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") then
		if instance.PrimaryPart then
			return instance.PrimaryPart
		end
		return instance:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- Clones the template, wraps it in a "Sword" Model if it wasn't one already
-- (so equip() always has a consistent container to parent), and rigidly
-- welds every other part to the primary part so the whole thing moves as
-- one piece when the grip joint swings.
local function buildSword(): (Model, Motor6D)
	local clone = swordTemplate:Clone()
	local primary = getPrimaryPart(clone)
	if not primary then
		error("Sword template has no BasePart to use as a grip point")
	end

	local sword: Model
	if clone:IsA("Model") then
		sword = clone
	else
		sword = Instance.new("Model")
		clone.Parent = sword
	end
	sword.Name = "Sword"
	sword.PrimaryPart = primary
	sword:ScaleTo(SWORD_SCALE)

	for _, descendant in sword:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.Massless = true
			if descendant ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = descendant
				weld.Parent = primary
			end
		end
	end

	local grip = Instance.new("Motor6D")
	grip.Name = "SwordGrip"
	grip.Part1 = primary
	grip.C0 = GRIP_C0
	grip.Parent = primary

	return sword, grip
end

local function findGripPart(character: Model): BasePart?
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	local partName = "RightHand"
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
		partName = "Right Arm"
	end

	local part = character:WaitForChild(partName, 5)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function equip(character: Model)
	local gripPart = findGripPart(character)
	if not gripPart then
		return
	end

	local existing = character:FindFirstChild("Sword")
	if existing then
		existing:Destroy()
	end

	local model, grip = buildSword()
	grip.Part0 = gripPart
	model.Parent = character
end

function WeaponService.Init()
	local found = findSwordTemplate()
	if found then
		swordTemplate = found
		swordTemplate.Parent = ServerStorage
	else
		swordTemplate = buildBlockySword()
		swordTemplate.Parent = ServerStorage
	end
end

function WeaponService.Start()
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(equip)
		if player.Character then
			equip(player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return WeaponService
