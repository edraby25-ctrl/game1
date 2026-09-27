--!strict
-- Builds the village: a ring of houses with doors facing the center, a well
-- at dead center, a forest scattered across the ring outside the clearing,
-- and one townsfolk NPC standing near each house. Pure Part geometry (see
-- WorldGen/HouseBuilder, WorldGen/TreeBuilder, WorldGen/TownsfolkFactory) --
-- no mesh pipeline is available in this environment (see HANDOFF.md).
--
-- Townsfolk are plain decorative NPCs (no Humanoid health/respawn
-- machinery -- see HANDOFF.md's note that pure decoration doesn't need it),
-- tagged NPC_TAG so NPCWanderService can drive their wandering without this
-- service needing to know anything about movement. This mirrors
-- EnemyService/EnemyMovementService's split, but townsfolk are intentionally
-- a separate tag/service from Enemy/EnemyMover -- they are not combat actors.
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local WorldHeightMap = require(Shared.WorldHeightMap)

local ServerScriptService = game:GetService("ServerScriptService")
local WorldGen = ServerScriptService:WaitForChild("Server"):WaitForChild("WorldGen")
local HouseBuilder = require(WorldGen.HouseBuilder)
local TreeBuilder = require(WorldGen.TreeBuilder)
local TownsfolkFactory = require(WorldGen.TownsfolkFactory)

local NPC_TAG = "Townsfolk"
local SEED = 90210 -- fixed seed: village layout is deterministic across server restarts

local FIRST_NAMES = {
	"Alaric", "Beatrix", "Cedric", "Dorna", "Edwin", "Fenna",
	"Gareth", "Hilde", "Ivo", "Jorah", "Katla", "Leofric",
}

local SHIRT_COLORS = {
	Color3.fromRGB(150, 90, 60),
	Color3.fromRGB(90, 110, 70),
	Color3.fromRGB(120, 70, 100),
	Color3.fromRGB(180, 150, 70),
}

local VillageService = {}

local function getOrCreateFolder(name: string): Folder
	local existing = Workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace
	return folder
end

local function buildWell(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Well"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(3, 6, 6)
	base.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	base.Color = Color3.fromRGB(120, 116, 110)
	base.Material = Enum.Material.Concrete
	base.Anchored = true
	base.Parent = model

	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2
		local post = Instance.new("Part")
		post.Name = "Post" .. i
		post.Size = Vector3.new(0.6, 7, 0.6)
		post.CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 2.6, 3.5 + 3, math.sin(angle) * 2.6))
		post.Color = Color3.fromRGB(90, 65, 45)
		post.Material = Enum.Material.Wood
		post.Anchored = true
		post.Parent = model
	end

	local cap = Instance.new("Part")
	cap.Name = "RoofCap"
	cap.Size = Vector3.new(7, 2.5, 7)
	cap.CFrame = CFrame.new(position + Vector3.new(0, 10.5, 0))
	cap.Color = Color3.fromRGB(120, 58, 47)
	cap.Material = Enum.Material.Slate
	cap.Anchored = true
	cap.CanCollide = false
	cap.Parent = model

	model.PrimaryPart = base
	return model
end

local function spawnTownsfolkAt(house: Model, index: number, folder: Folder)
	local floor = house:FindFirstChild("Floor") :: BasePart?
	if not floor then
		return
	end

	local doorPart = house:FindFirstChild("Door") :: BasePart?
	local spawnPosition: Vector3
	if doorPart then
		spawnPosition = doorPart.Position + doorPart.CFrame.LookVector * 6
	else
		spawnPosition = floor.Position
	end

	local groundY = WorldHeightMap.GetGroundY(spawnPosition.X, spawnPosition.Z)
	local finalPosition = Vector3.new(spawnPosition.X, groundY, spawnPosition.Z)

	local npc = TownsfolkFactory.Build({
		Position = finalPosition,
		DisplayName = FIRST_NAMES[((index - 1) % #FIRST_NAMES) + 1],
		ShirtColor = SHIRT_COLORS[((index - 1) % #SHIRT_COLORS) + 1],
	})
	npc.Parent = folder
	CollectionService:AddTag(npc, NPC_TAG)
	npc:SetAttribute("HomePosition", finalPosition)
end

function VillageService.Init()
	local rng = Random.new(SEED)
	local world = Constants.World
	local villageFolder = getOrCreateFolder("Village")
	local forestFolder = getOrCreateFolder("Forest")
	local townsfolkFolder = getOrCreateFolder("Townsfolk")

	-- Houses in a ring around the clearing's center, doors facing inward.
	local houseCount = 9
	local ringRadius = world.VillageRadius * 0.62
	for i = 1, houseCount do
		local angle = (i / houseCount) * math.pi * 2 + rng:NextNumber() * 0.15
		local x = math.cos(angle) * ringRadius
		local z = math.sin(angle) * ringRadius
		local groundY = WorldHeightMap.GetGroundY(x, z)
		local facingAngle = angle + math.pi -- face towards the center

		local house = HouseBuilder.Build({
			Position = Vector3.new(x, groundY, z),
			FacingAngle = facingAngle,
			Width = 14 + rng:NextInteger(0, 4),
			Depth = 12 + rng:NextInteger(0, 4),
			WallHeight = 9 + rng:NextInteger(0, 2),
		})
		house.Name = "House" .. i
		house.Parent = villageFolder

		spawnTownsfolkAt(house, i, townsfolkFolder)
	end

	local well = buildWell(Vector3.new(0, WorldHeightMap.GetGroundY(0, 0), 0))
	well.Parent = villageFolder

	-- Forest: rejection-sampled over a square, kept only inside the annulus
	-- between the clearing edge and the outer terrain radius. Density biases
	-- up with distance so the treeline reads as a forest edge, not a wall.
	local innerRadius = world.VillageRadius * 0.95
	local outerRadius = world.ForestRingOuter * 0.97
	local treeCount = 140

	local placed = 0
	local attempts = 0
	while placed < treeCount and attempts < treeCount * 8 do
		attempts += 1
		local x = (rng:NextNumber() * 2 - 1) * outerRadius
		local z = (rng:NextNumber() * 2 - 1) * outerRadius
		local distance = math.sqrt(x * x + z * z)
		if distance >= innerRadius and distance <= outerRadius then
			local densityBias = (distance - innerRadius) / (outerRadius - innerRadius)
			if rng:NextNumber() < (0.35 + densityBias * 0.65) then
				local groundY = WorldHeightMap.GetGroundY(x, z)
				local tree = TreeBuilder.Build({
					Position = Vector3.new(x, groundY, z),
					Random = rng,
				})
				tree.Name = "Tree" .. placed
				tree.Parent = forestFolder
				placed += 1
			end
		end
	end

	print(string.format(
		"[VillageService] Placed %d houses, 1 well, %d trees, %d townsfolk.",
		houseCount,
		placed,
		houseCount
	))
end

return VillageService
