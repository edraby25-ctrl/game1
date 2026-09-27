--!strict
-- Reads combat input and forwards intent to the server. The server remains
-- authoritative over whether the attack/dodge actually happens.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Constants = require(Shared.Constants)

local WeaponController = require(script.Parent.WeaponController)

local CombatController = {}

local requestAttack: RemoteEvent
local requestDodge: RemoteEvent
local requestBlock: RemoteEvent
local attackLanded: RemoteEvent

local hitFlash: Frame
local isBlocking = false

local function buildHitFlash()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CombatFeedback"
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "HitFlash"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ZIndex = 10
	frame.Parent = screenGui

	return frame
end

local function flashHit()
	hitFlash.BackgroundTransparency = 0.7
	TweenService:Create(hitFlash, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
end

local function setBlocking(active: boolean)
	if isBlocking == active then
		return
	end
	isBlocking = active
	requestBlock:FireServer(active)
	WeaponController.SetLocalBlockPose(active)
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isBlocking then
			return
		end
		WeaponController.PlayLocalSwing()
		requestAttack:FireServer()
	elseif input.KeyCode == Enum.KeyCode.Q then
		requestDodge:FireServer()
	elseif input.KeyCode == Enum.KeyCode.F then
		setBlocking(true)
	end
end

local function onInputEnded(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.KeyCode == Enum.KeyCode.F then
		setBlocking(false)
	end
end

function CombatController.Init()
	requestAttack = Net.GetEvent(Constants.Remotes.RequestAttack)
	requestDodge = Net.GetEvent(Constants.Remotes.RequestDodge)
	requestBlock = Net.GetEvent(Constants.Remotes.RequestBlock)
	attackLanded = Net.GetEvent(Constants.Remotes.AttackLanded)
	hitFlash = buildHitFlash()
end

function CombatController.Start()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)

	attackLanded.OnClientEvent:Connect(function(hitCount: number)
		if hitCount > 0 then
			flashHit()
		end
	end)
end

return CombatController
