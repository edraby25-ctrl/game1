--!strict
-- Spawns training-dummy enemies by cloning an R6 rig placed in Workspace
-- (falls back to a plain blocky dummy if none is found), and owns their
-- health/respawn state. A Humanoid gives us Health/Died for free.
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local Signal = require(Shared.Signal)

local ENEMY_TAG = "Enemy"
local MOVER_TAG = "EnemyMover"

local EnemyService = {}

EnemyService.EnemyDamaged = Signal.new()
EnemyService.EnemyDied = Signal.new()

local enemiesFolder: Folder
local dummyTemplate: Model

local function createHealthBar(part: BasePart): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromOffset(80, 10)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.new(0, 0, 0)
	background.BackgroundTransparency = 0.4
	background.BorderSizePixel = 0
	background.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	fill.BorderSizePixel = 0
	fill.Parent = background

	return fill
end

local function getHealthBarGui(model: Model): BillboardGui?
	local root = model.PrimaryPart
	local gui = root and root:FindFirstChild("HealthBar")
	if gui and gui:IsA("BillboardGui") then
		return gui
	end
	return nil
end

local function setHealthBar(model: Model, ratio: number)
	local gui = getHealthBarGui(model)
	if not gui then
		return
	end
	local background = gui:FindFirstChild("Background") :: Frame?
	local fill = background and background:FindFirstChild("Fill") :: Frame?
	if not fill then
		return
	end
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
end

local function setHealthBarVisible(model: Model, visible: boolean)
	local gui = getHealthBarGui(model)
	if gui then
		gui.Enabled = visible
	end
end

-- Hides every visible bit of the dummy, including face decals/textures
-- (which aren't BaseParts, so a Transparency loop over parts alone misses
-- them) and the floating health bar.
local function setModelVisible(model: Model, root: BasePart, visible: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = visible and 0 or 1
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = visible and 0 or 1
		end
	end
	root.CanCollide = visible
	setHealthBarVisible(model, visible)
end

-- Roblox Humanoids latch into a permanent Dead state once Health hits 0;
-- just setting Health back up doesn't undo that, so respawn swaps in a
-- brand new Humanoid rather than trying to revive the old one.
local function respawnEnemy(model: Model, humanoid: Humanoid, root: BasePart, spawnPosition: Vector3)
	task.wait(Constants.Enemy.RespawnDelay)

	model:PivotTo(CFrame.new(spawnPosition))
	setModelVisible(model, root, true)
	setHealthBar(model, 1)

	local freshHumanoid = Instance.new("Humanoid")
	freshHumanoid.MaxHealth = Constants.Enemy.MaxHealth
	freshHumanoid.Health = Constants.Enemy.MaxHealth
	freshHumanoid.BreakJointsOnDeath = false
	if CollectionService:HasTag(model, MOVER_TAG) then
		freshHumanoid.WalkSpeed = Constants.Enemy.MoveSpeed
	end
	freshHumanoid.Parent = model
	humanoid:Destroy()

	EnemyService.EnemyDied:Fire(model, false) -- respawned
end

local function onDied(model: Model, humanoid: Humanoid, root: BasePart, spawnPosition: Vector3)
	setModelVisible(model, root, false)
	setHealthBar(model, 0)
	EnemyService.EnemyDied:Fire(model, true) -- died

	task.spawn(respawnEnemy, model, humanoid, root, spawnPosition)
end

function EnemyService.Damage(model: Model, amount: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid.Health = math.max(0, humanoid.Health - amount)
	setHealthBar(model, humanoid.Health / humanoid.MaxHealth)
	EnemyService.EnemyDamaged:Fire(model, amount, humanoid.Health)

	if humanoid.Health <= 0 then
		local root = model.PrimaryPart :: BasePart
		onDied(model, humanoid, root, root.Position)
	end
end

function EnemyService.GetEnemies(): { Model }
	return CollectionService:GetTagged(ENEMY_TAG) :: { Model }
end

function EnemyService.IsAlive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Looks for a Model directly in Workspace with an R6 Humanoid that isn't a
-- player's character, to use as the dummy's visual template.
local function findRigTemplate(): Model?
	for _, instance in Workspace:GetChildren() do
		if instance:IsA("Model") and Players:GetPlayerFromCharacter(instance) == nil then
			local humanoid = instance:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
				return instance
			end
		end
	end
	return nil
end

local function buildBlockyDummy(): Model
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 4, 1)
	root.Anchored = true
	root.CanCollide = true
	root.Material = Enum.Material.Wood
	root.Color = Color3.fromRGB(120, 80, 45)
	root.Parent = model

	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model

	return model
end

-- Shared setup for any enemy cloned from the template: health, tagging,
-- positioning. `anchored` controls whether it's a fixed training dummy or a
-- physically-simulated enemy that a movement service can walk around.
local function cloneEnemy(position: Vector3, name: string, anchored: boolean): Model
	local model = dummyTemplate:Clone()
	model.Name = name

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = Constants.Enemy.MaxHealth
	humanoid.Health = Constants.Enemy.MaxHealth
	humanoid.BreakJointsOnDeath = false

	local root = (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart) :: BasePart
	model.PrimaryPart = root

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end

	model:PivotTo(CFrame.new(position))

	createHealthBar(root)

	model.Parent = enemiesFolder
	CollectionService:AddTag(model, ENEMY_TAG)

	return model
end

local function spawnDummy(position: Vector3): Model
	return cloneEnemy(position, "TrainingDummy", true)
end

function EnemyService.SpawnMover(position: Vector3): Model
	local model = cloneEnemy(position, "Enemy", false)

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Constants.Enemy.MoveSpeed

	CollectionService:AddTag(model, MOVER_TAG)
	return model
end

function EnemyService.GetMovers(): { Model }
	return CollectionService:GetTagged(MOVER_TAG) :: { Model }
end

function EnemyService.Init()
	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = Workspace

	local foundTemplate = findRigTemplate()
	if foundTemplate then
		dummyTemplate = foundTemplate
		dummyTemplate.Parent = ServerStorage
	else
		dummyTemplate = buildBlockyDummy()
		dummyTemplate.Parent = ServerStorage
	end
end

function EnemyService.Start()
	spawnDummy(Vector3.new(10, 4, 10))
	spawnDummy(Vector3.new(-10, 4, 10))
	EnemyService.SpawnMover(Vector3.new(0, 4, -15))
end

return EnemyService
