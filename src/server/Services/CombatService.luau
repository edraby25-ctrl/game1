--!strict
-- Server-authoritative validation for attack/dodge requests. Damage/hitbox
-- detection and dodge i-frame tracking are left as TODOs for the combat pass.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Constants = require(Shared.Constants)

local PlayerDataService = require(script.Parent.PlayerDataService)
local EnemyService = require(script.Parent.EnemyService)

local CombatService = {}

local requestAttack: RemoteEvent
local requestDodge: RemoteEvent
local requestBlock: RemoteEvent
local attackLanded: RemoteEvent
local attackSwing: RemoteEvent
local blockStateChanged: RemoteEvent

local lastAttackAt: { [Player]: number } = {}
local lastDodgeAt: { [Player]: number } = {}
local blockingPlayers: { [Player]: boolean } = {}

local ATTACK_CONE_COS = math.cos(math.rad(Constants.Combat.AttackConeDegrees / 2))
local BLOCK_CONE_COS = math.cos(math.rad(Constants.Combat.BlockConeDegrees / 2))

local function getEnemiesInCone(origin: Vector3, lookVector: Vector3): { Model }
	local hit = {}
	for _, enemy in EnemyService.GetEnemies() do
		if not EnemyService.IsAlive(enemy) then
			continue
		end

		local root = enemy.PrimaryPart
		if not root then
			continue
		end

		local toEnemy = root.Position - origin
		local distance = toEnemy.Magnitude
		if distance > Constants.Combat.AttackRange or distance <= 0 then
			continue
		end

		local direction = toEnemy.Unit
		if direction:Dot(lookVector) >= ATTACK_CONE_COS then
			table.insert(hit, enemy)
		end
	end
	return hit
end

local function onAttackRequested(player: Player)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	if blockingPlayers[player] then
		return
	end

	local now = os.clock()
	local last = lastAttackAt[player]
	if last and now - last < Constants.Combat.AttackCooldown then
		return
	end
	if profile.Stamina < Constants.Combat.AttackStaminaCost then
		return
	end

	lastAttackAt[player] = now
	PlayerDataService.Update(player, { Stamina = profile.Stamina - Constants.Combat.AttackStaminaCost })

	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			attackSwing:FireClient(otherPlayer, player)
		end
	end

	local hitEnemies = getEnemiesInCone(root.Position, root.CFrame.LookVector)
	for _, enemy in hitEnemies do
		EnemyService.Damage(enemy, Constants.Combat.AttackDamage)
	end

	attackLanded:FireClient(player, #hitEnemies)
end

local function performDodgeDash(character: Model, root: BasePart, humanoid: Humanoid)
	local moveDirection = humanoid.MoveDirection
	local flatDirection = Vector3.new(moveDirection.X, 0, moveDirection.Z)
	if flatDirection.Magnitude < 0.1 then
		local look = root.CFrame.LookVector
		flatDirection = Vector3.new(look.X, 0, look.Z)
	end
	if flatDirection.Magnitude < 0.01 then
		return
	end
	flatDirection = flatDirection.Unit

	local dash = Instance.new("BodyVelocity")
	dash.Name = "DodgeDash"
	dash.MaxForce = Vector3.new(1, 0, 1) * 1e5
	dash.P = 1250
	dash.Velocity = flatDirection * Constants.Combat.DodgeSpeed
	dash.Parent = root
	Debris:AddItem(dash, Constants.Combat.DodgeDashDuration)

	character:SetAttribute("Invulnerable", true)
	task.delay(Constants.Combat.DodgeIFrameDuration, function()
		if character.Parent then
			character:SetAttribute("Invulnerable", false)
		end
	end)

	local attachmentA = Instance.new("Attachment")
	attachmentA.Position = Vector3.new(0, 1, 0)
	attachmentA.Parent = root

	local attachmentB = Instance.new("Attachment")
	attachmentB.Position = Vector3.new(0, -1, 0)
	attachmentB.Parent = root

	local trail = Instance.new("Trail")
	trail.Attachment0 = attachmentA
	trail.Attachment1 = attachmentB
	trail.Lifetime = 0.25
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = root

	local cleanupDelay = Constants.Combat.DodgeDashDuration + trail.Lifetime
	Debris:AddItem(attachmentA, cleanupDelay)
	Debris:AddItem(attachmentB, cleanupDelay)
	Debris:AddItem(trail, cleanupDelay)
end

local function onDodgeRequested(player: Player)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid then
		return
	end

	local now = os.clock()
	local last = lastDodgeAt[player]
	if last and now - last < Constants.Combat.DodgeCooldown then
		return
	end
	if profile.Stamina < Constants.Combat.DodgeStaminaCost then
		return
	end

	lastDodgeAt[player] = now
	PlayerDataService.Update(player, { Stamina = profile.Stamina - Constants.Combat.DodgeStaminaCost })

	performDodgeDash(character, root, humanoid)
end

local function onBlockRequested(player: Player, isBlocking: boolean)
	blockingPlayers[player] = isBlocking or nil

	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			blockStateChanged:FireClient(otherPlayer, player, isBlocking)
		end
	end
end

-- attackerPosition, when given, lets a directional block reduce damage that
-- arrives from within the player's front-facing block cone.
function CombatService.DamagePlayer(player: Player, amount: number, attackerPosition: Vector3?)
	local character = player.Character
	if not character or character:GetAttribute("Invulnerable") then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local finalDamage = amount
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local profile = PlayerDataService.Get(player)

	if blockingPlayers[player] and attackerPosition and root and profile and profile.Stamina > 0 then
		local toAttacker = Vector3.new(attackerPosition.X - root.Position.X, 0, attackerPosition.Z - root.Position.Z)
		if toAttacker.Magnitude > 0.01 then
			local facing = root.CFrame.LookVector
			local flatFacing = Vector3.new(facing.X, 0, facing.Z).Unit
			if flatFacing:Dot(toAttacker.Unit) >= BLOCK_CONE_COS then
				finalDamage = amount * (1 - Constants.Combat.BlockDamageReduction)
				PlayerDataService.Update(player, {
					Stamina = math.max(0, profile.Stamina - Constants.Combat.BlockStaminaCost),
				})
			end
		end
	end

	humanoid:TakeDamage(finalDamage)
end

function CombatService.Init()
	requestAttack = Net.GetEvent(Constants.Remotes.RequestAttack)
	requestDodge = Net.GetEvent(Constants.Remotes.RequestDodge)
	requestBlock = Net.GetEvent(Constants.Remotes.RequestBlock)
	attackLanded = Net.GetEvent(Constants.Remotes.AttackLanded)
	attackSwing = Net.GetEvent(Constants.Remotes.AttackSwing)
	blockStateChanged = Net.GetEvent(Constants.Remotes.BlockStateChanged)
end

function CombatService.Start()
	requestAttack.OnServerEvent:Connect(onAttackRequested)
	requestDodge.OnServerEvent:Connect(onDodgeRequested)
	requestBlock.OnServerEvent:Connect(onBlockRequested)

	Players.PlayerRemoving:Connect(function(player)
		lastAttackAt[player] = nil
		lastDodgeAt[player] = nil
		blockingPlayers[player] = nil
	end)
end

return CombatService
