--!strict
-- Thin wrapper over RemoteEvents/RemoteFunctions so both client and server
-- can fetch the same remote by name without manually wiring up instances.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreate(name: string, className: string): Instance
	local existing = remotesFolder:FindFirstChild(name)
	if existing then
		return existing
	end

	if RunService:IsServer() then
		local instance = Instance.new(className)
		instance.Name = name
		instance.Parent = remotesFolder
		return instance
	end

	return remotesFolder:WaitForChild(name)
end

function Net.GetEvent(name: string): RemoteEvent
	return getOrCreate(name, "RemoteEvent") :: RemoteEvent
end

function Net.GetFunction(name: string): RemoteFunction
	return getOrCreate(name, "RemoteFunction") :: RemoteFunction
end

return Net
