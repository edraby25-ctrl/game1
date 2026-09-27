--!strict
-- Gives enemies a simple telegraphed melee attack: wait for a player to walk
-- into range, flash a warning color, then check range again and deal damage.
-- The gap between flash and impact is what a dodge-roll's i-frames are for.
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)

local EnemyService = require(script.Parent.EnemyService)
local CombatService = require(script.Parent.CombatService)

local EnemyAIService = {}

local TELEGRAPH_COLOR = Color3.fromRGB(255, 60, 60)
local handledEnemies: { [Model]: boolean } = {}

local function findNearestPlayerInRange(origin: Vector3): Player?
	local nearestPlayer: Player? = nil
	local nearestDistance = Constants.Enemy.AttackRange

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - origin).Magnitude
			if distance <= nearestDistance then
				nearestDistance = distance
				nearestPlayer = player
			end
		end
	end

	return nearestPlayer
end

local function attackLoop(enemy: Model)
	while enemy.Parent do
		task.wait(0.5)

		if not EnemyService.IsAlive(enemy) then
			continue
		end

		local root = enemy.PrimaryPart
		if not root then
			continue
		end

		local target = findNearestPlayerInRange(root.Position)
		if not target then
			continue
		end

		local originalColor = root.Color
		root.Color = TELEGRAPH_COLOR
		task.wait(Constants.Enemy.TelegraphDuration)
		root.Color = originalColor

		if not EnemyService.IsAlive(enemy) then
			continue
		end

		local character = target.Character
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot and (targetRoot.Position - root.Position).Magnitude <= Constants.Enemy.AttackRange then
			CombatService.DamagePlayer(target, Constants.Enemy.AttackDamage, root.Position)
		end

		task.wait(Constants.Enemy.AttackCooldown)
	end
end

function EnemyAIService.Start()
	task.spawn(function()
		while true do
			for _, enemy in EnemyService.GetEnemies() do
				if not handledEnemies[enemy] then
					handledEnemies[enemy] = true
					task.spawn(attackLoop, enemy)
				end
			end
			task.wait(1)
		end
	end)
end

return EnemyAIService
