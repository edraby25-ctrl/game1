--!strict
-- Drives townsfolk wandering: each NPC occasionally strolls to a random
-- point near its home (the doorway VillageService spawned it at) and
-- otherwise idles. Mirrors EnemyMovementService's polling pattern (discover
-- newly-tagged models on a loop, hand each one its own coroutine) but with
-- none of the aggro/combat logic -- townsfolk never target players.
local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared.Constants)
local WorldHeightMap = require(Shared.WorldHeightMap)

local NPC_TAG = "Townsfolk"

local NPCWanderService = {}

local handled: { [Model]: boolean } = {}

-- Humanoid:MoveTo() drives both walking and turning natively; see
-- HANDOFF.md's gotcha about not fighting it by setting .CFrame directly.
local function wanderLoop(npc: Model)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local homePosition = npc:GetAttribute("HomePosition") :: Vector3?
	if not humanoid or not homePosition then
		return
	end

	while npc.Parent do
		local waitTime = Constants.NPC.WanderIntervalMin
			+ math.random() * (Constants.NPC.WanderIntervalMax - Constants.NPC.WanderIntervalMin)
		task.wait(waitTime)

		if not npc.Parent then
			break
		end

		if math.random() < Constants.NPC.IdleChance then
			continue
		end

		local angle = math.random() * math.pi * 2
		local radius = math.random() * Constants.NPC.WanderRadius
		local targetX = homePosition.X + math.cos(angle) * radius
		local targetZ = homePosition.Z + math.sin(angle) * radius
		local targetY = WorldHeightMap.GetGroundY(targetX, targetZ)

		humanoid:MoveTo(Vector3.new(targetX, targetY + 3, targetZ))
	end
end

function NPCWanderService.Start()
	task.spawn(function()
		while true do
			for _, npc in CollectionService:GetTagged(NPC_TAG) do
				if npc:IsA("Model") and not handled[npc] then
					handled[npc] = true
					task.spawn(wanderLoop, npc)
				end
			end
			task.wait(1)
		end
	end)
end

return NPCWanderService
