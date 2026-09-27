--!strict
-- Moves "mover" enemies toward the player, soulslike-approach style:
-- while idle, it only notices a player inside its front-facing sight cone
-- (directional sight); once aggroed, it chases by distance alone until the
-- player breaks line of sight/range. It stops short of the player rather
-- than walking into them, leaving room for EnemyAIService's attack to land.
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)

local EnemyService = require(script.Parent.EnemyService)

local EnemyMovementService = {}

local SIGHT_CONE_COS = math.cos(math.rad(Constants.Enemy.SightConeDegrees / 2))
local handledMovers: { [Model]: boolean } = {}

local function findTarget(root: BasePart, alreadyAggroed: boolean): (Player?, BasePart?)
	local nearestPlayer: Player? = nil
	local nearestRoot: BasePart? = nil
	local nearestDistance = Constants.Enemy.SightRange

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not targetRoot or not humanoid or humanoid.Health <= 0 then
			continue
		end

		local toTarget = targetRoot.Position - root.Position
		local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
		local distance = flat.Magnitude
		if distance > nearestDistance or distance < 0.01 then
			continue
		end

		if not alreadyAggroed then
			local facing = root.CFrame.LookVector
			local flatFacing = Vector3.new(facing.X, 0, facing.Z)
			if flatFacing.Magnitude < 0.01 then
				continue
			end
			if flatFacing.Unit:Dot(flat.Unit) < SIGHT_CONE_COS then
				continue
			end
		end

		nearestDistance = distance
		nearestPlayer = player
		nearestRoot = targetRoot
	end

	return nearestPlayer, nearestRoot
end

-- Humanoid:MoveTo() drives both walking and turning natively (AutoRotate),
-- which is smoother and doesn't fight the physics engine the way manually
-- overwriting CFrame every tick did. Reissuing the standoff target on every
-- tick -- even while already "holding" at that distance -- is what keeps it
-- turning to track the player instead of freezing once it stops advancing.
local function moveLoop(enemy: Model)
	local aggroed = false

	while enemy.Parent do
		task.wait(Constants.Enemy.RepathInterval)

		if not EnemyService.IsAlive(enemy) then
			aggroed = false
			continue
		end

		-- Re-fetched each tick: EnemyService swaps in a fresh Humanoid on
		-- respawn, so a captured reference from before death would be stale.
		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		local root = enemy.PrimaryPart
		if not humanoid or not root then
			continue
		end

		local target, targetRoot = findTarget(root, aggroed)
		if not target or not targetRoot then
			if aggroed then
				humanoid:MoveTo(root.Position)
				aggroed = false
			end
			continue
		end

		aggroed = true

		local toTarget = targetRoot.Position - root.Position
		local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
		if flat.Magnitude < 0.01 then
			continue
		end

		local standoff = targetRoot.Position - flat.Unit * Constants.Enemy.ChaseStopDistance
		humanoid:MoveTo(Vector3.new(standoff.X, root.Position.Y, standoff.Z))
	end
end

function EnemyMovementService.Start()
	task.spawn(function()
		while true do
			for _, enemy in EnemyService.GetMovers() do
				if not handledMovers[enemy] then
					handledMovers[enemy] = true
					task.spawn(moveLoop, enemy)
				end
			end
			task.wait(1)
		end
	end)
end

return EnemyMovementService
