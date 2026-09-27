--!strict
-- Owns authoritative per-player stamina for the session. Health lives on the
-- character's real Humanoid instead of a parallel counter, so Roblox's own
-- damage/death/respawn handling (Humanoid.Health, Died, auto-respawn) applies.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Constants = require(Shared.Constants)
local Signal = require(Shared.Signal)

export type Profile = {
	Stamina: number,
	MaxStamina: number,
}

local PlayerDataService = {}

PlayerDataService.ProfileAdded = Signal.new()
PlayerDataService.ProfileRemoving = Signal.new()

local profiles: { [Player]: Profile } = {}
local playerDataChanged: RemoteEvent

local function resetProfile(player: Player)
	local profile: Profile = {
		Stamina = Constants.Combat.BaseStamina,
		MaxStamina = Constants.Combat.BaseStamina,
	}
	profiles[player] = profile
	playerDataChanged:FireClient(player, profile)
	PlayerDataService.ProfileAdded:Fire(player, profile)
end

function PlayerDataService.Get(player: Player): Profile?
	return profiles[player]
end

function PlayerDataService.Update(player: Player, patch: { [string]: any })
	local profile = profiles[player]
	if not profile then
		return
	end
	for key, value in patch do
		(profile :: any)[key] = value
	end
	playerDataChanged:FireClient(player, profile)
end

function PlayerDataService.Init()
	playerDataChanged = Net.GetEvent(Constants.Remotes.PlayerDataChanged)
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(function(player)
		resetProfile(player)
		player.CharacterAdded:Connect(function()
			resetProfile(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		profiles[player] = nil
		if profile then
			PlayerDataService.ProfileRemoving:Fire(player, profile)
		end
	end)

	for _, player in Players:GetPlayers() do
		resetProfile(player)
	end

	task.spawn(function()
		while true do
			task.wait(1)
			for player, profile in profiles do
				if profile.Stamina < profile.MaxStamina then
					PlayerDataService.Update(player, {
						Stamina = math.min(profile.MaxStamina, profile.Stamina + Constants.Combat.StaminaRegenPerSecond),
					})
				end
			end
		end
	end)
end

return PlayerDataService
