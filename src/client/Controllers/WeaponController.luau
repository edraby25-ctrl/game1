--!strict
-- Plays a purely cosmetic sword swing by tweening the SwordGrip Motor6D's C0.
-- Each client tweens its own local view of the (replicated) joint, so this
-- never touches anything server-authoritative.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Constants = require(Shared.Constants)

local WeaponController = {}

local SWING_TIME = 0.18
local BLOCK_TWEEN_TIME = 0.12
-- Must match WeaponService's GRIP_C0 (the handle's rest pose in the hand).
local REST_C0 = CFrame.new(0, -0.5, -0.2) * CFrame.Angles(math.rad(90), 0, 0)
local SWING_C0 = REST_C0 * CFrame.Angles(0, math.rad(-110), 0)
local BLOCK_C0 = REST_C0 * CFrame.Angles(math.rad(60), 0, 0)

local attackSwing: RemoteEvent
local blockStateChanged: RemoteEvent

-- Searched by name rather than assumed to live under a part called "Handle":
-- the sword model is whatever's cloned from Workspace.arming_sword, so its
-- internal part names aren't under our control.
local function getGrip(character: Model?): Motor6D?
	if not character then
		return nil
	end
	local sword = character:FindFirstChild("Sword")
	if not sword then
		return nil
	end
	for _, descendant in sword:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Name == "SwordGrip" then
			return descendant
		end
	end
	return nil
end

local function playSwing(character: Model?)
	local grip = getGrip(character)
	if not grip then
		return
	end

	grip.C0 = SWING_C0
	TweenService:Create(
		grip,
		TweenInfo.new(SWING_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ C0 = REST_C0 }
	):Play()
end

local function setBlockPose(character: Model?, isBlocking: boolean)
	local grip = getGrip(character)
	if not grip then
		return
	end

	local target = isBlocking and BLOCK_C0 or REST_C0
	TweenService:Create(
		grip,
		TweenInfo.new(BLOCK_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = target }
	):Play()
end

function WeaponController.PlayLocalSwing()
	playSwing(Players.LocalPlayer.Character)
end

function WeaponController.SetLocalBlockPose(isBlocking: boolean)
	setBlockPose(Players.LocalPlayer.Character, isBlocking)
end

function WeaponController.Init()
	attackSwing = Net.GetEvent(Constants.Remotes.AttackSwing)
	blockStateChanged = Net.GetEvent(Constants.Remotes.BlockStateChanged)
end

function WeaponController.Start()
	attackSwing.OnClientEvent:Connect(function(attacker: Player)
		playSwing(attacker.Character)
	end)

	blockStateChanged.OnClientEvent:Connect(function(blocker: Player, isBlocking: boolean)
		setBlockPose(blocker.Character, isBlocking)
	end)
end

return WeaponController
