--!strict
-- Mirrors the server-authoritative profile locally so UI/other controllers
-- can read current health/stamina without round-tripping to the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Constants = require(Shared.Constants)
local Signal = require(Shared.Signal)

local PlayerDataController = {}

PlayerDataController.DataChanged = Signal.new()

local data: { [string]: any } = {}

function PlayerDataController.Get()
	return data
end

function PlayerDataController.Init()
	local remote = Net.GetEvent(Constants.Remotes.PlayerDataChanged)
	remote.OnClientEvent:Connect(function(profile)
		data = profile
		PlayerDataController.DataChanged:Fire(profile)
	end)
end

return PlayerDataController
