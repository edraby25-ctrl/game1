--!strict
-- Loads every Service module, running Init() on all of them before Start()
-- on any of them, so services can safely depend on each other during Start.
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")

local loaded = {}

for _, moduleScript in Services:GetChildren() do
	if moduleScript:IsA("ModuleScript") then
		loaded[moduleScript.Name] = require(moduleScript)
	end
end

for _, service in loaded do
	if service.Init then
		service.Init()
	end
end

for _, service in loaded do
	if service.Start then
		service.Start()
	end
end

print("[Server] loaded services:", table.concat((function()
	local names = {}
	for name in loaded do
		table.insert(names, name)
	end
	return names
end)(), ", "))
