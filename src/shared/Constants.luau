--!strict
local Constants = {}

Constants.Combat = {
	BaseStamina = 100,
	StaminaRegenPerSecond = 15,

	AttackStaminaCost = 15,
	AttackCooldown = 0.5,
	AttackDamage = 20,
	AttackRange = 8,
	AttackConeDegrees = 80,

	DodgeStaminaCost = 25,
	DodgeCooldown = 0.6,
	DodgeIFrameDuration = 0.3,
	DodgeSpeed = 50,
	DodgeDashDuration = 0.2,

	BlockConeDegrees = 120,
	BlockDamageReduction = 0.75,
	BlockStaminaCost = 10,
}

Constants.Enemy = {
	MaxHealth = 50,
	RespawnDelay = 5,

	AttackRange = 6,
	AttackDamage = 10,
	AttackCooldown = 2,
	TelegraphDuration = 0.5,

	SightRange = 40,
	SightConeDegrees = 100,
	MoveSpeed = 14,
	ChaseStopDistance = 5,
	RepathInterval = 0.1,
}

Constants.Remotes = {
	PlayerDataChanged = "PlayerDataChanged",
	RequestAttack = "RequestAttack",
	RequestDodge = "RequestDodge",
	AttackLanded = "AttackLanded",
	AttackSwing = "AttackSwing",
	RequestBlock = "RequestBlock",
	BlockStateChanged = "BlockStateChanged",
}

return Constants
