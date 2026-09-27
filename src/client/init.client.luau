--!strict
-- Loads every Controller module, running Init() on all of them before
-- Start() on any of them, so controllers can safely depend on each other.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local Client = playerScripts:WaitForChild("Client")
local Controllers = Client:WaitForChild("Controllers")

local loaded = {}

for _, moduleScript in Controllers:GetChildren() do
	if moduleScript:IsA("ModuleScript") then
		loaded[moduleScript.Name] = require(moduleScript)
	end
end

for _, controller in loaded do
	if controller.Init then
		controller.Init()
	end
end

for _, controller in loaded do
	if controller.Start then
		controller.Start()
	end
end
