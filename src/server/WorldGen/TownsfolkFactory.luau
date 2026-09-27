--!strict
-- Builds a minimal R6-style humanoid rig for a non-hostile townsfolk NPC.
-- Hand-built from Parts + Motor6D joints (no mesh pipeline available; see
-- HANDOFF.md). This is deliberately the same joint layout Roblox's own R6
-- characters use, so Humanoid walking/physics behave normally and standard
-- animation ids can be loaded onto it if desired later.
--
-- UNVERIFIED WITHOUT STUDIO: the walk/idle animation ids below are the
-- well-known public Roblox default R6 animations. They *should* just work
-- once loaded through Animator, but this has not been visually confirmed in
-- this session. If townsfolk appear T-posed or don't animate, check these
-- ids first.

local PartUtil = require(script.Parent.PartUtil)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local TownsfolkFactory = {}

local IDLE_ANIM_ID = "rbxassetid://180435571"
local WALK_ANIM_ID = "rbxassetid://180426354"

export type TownsfolkOptions = {
	Position: Vector3,
	DisplayName: string,
	ShirtColor: Color3?,
	PantsColor: Color3?,
	SkinColor: Color3?,
}

local function weld(part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame, parent: Instance, name: string)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = parent
end

function TownsfolkFactory.Build(options: TownsfolkOptions): Model
	local skin = options.SkinColor or Color3.fromRGB(222, 178, 141)
	local shirt = options.ShirtColor or Color3.fromRGB(150, 90, 60)
	local pants = options.PantsColor or Color3.fromRGB(70, 65, 90)

	local model = Instance.new("Model")
	model.Name = options.DisplayName

	local rootPart = PartUtil.NewPart({
		Name = "HumanoidRootPart",
		Size = Vector3.new(2, 2, 1),
		CFrame = CFrame.new(options.Position + Vector3.new(0, 3, 0)),
		Color = Color3.fromRGB(255, 255, 255),
		CanCollide = false,
		Anchored = false,
	})
	rootPart.Transparency = 1
	rootPart.Parent = model

	local torso = PartUtil.NewPart({
		Name = "Torso",
		Size = Vector3.new(2, 2, 1),
		CFrame = rootPart.CFrame,
		Color = shirt,
		Anchored = false,
	})
	torso.Parent = model

	local head = PartUtil.NewPart({
		Name = "Head",
		Size = Vector3.new(1.4, 1.4, 1.4),
		CFrame = rootPart.CFrame * CFrame.new(0, 1.7, 0),
		Color = skin,
		Anchored = false,
	})
	head.Parent = model

	local leftArm = PartUtil.NewPart({
		Name = "Left Arm",
		Size = Vector3.new(1, 2, 1),
		CFrame = rootPart.CFrame * CFrame.new(-1.5, 0, 0),
		Color = skin,
		Anchored = false,
	})
	leftArm.Parent = model

	local rightArm = PartUtil.NewPart({
		Name = "Right Arm",
		Size = Vector3.new(1, 2, 1),
		CFrame = rootPart.CFrame * CFrame.new(1.5, 0, 0),
		Color = skin,
		Anchored = false,
	})
	rightArm.Parent = model

	local leftLeg = PartUtil.NewPart({
		Name = "Left Leg",
		Size = Vector3.new(1, 2, 1),
		CFrame = rootPart.CFrame * CFrame.new(-0.5, -2, 0),
		Color = pants,
		Anchored = false,
	})
	leftLeg.Parent = model

	local rightLeg = PartUtil.NewPart({
		Name = "Right Leg",
		Size = Vector3.new(1, 2, 1),
		CFrame = rootPart.CFrame * CFrame.new(0.5, -2, 0),
		Color = pants,
		Anchored = false,
	})
	rightLeg.Parent = model

	weld(rootPart, torso, CFrame.new(), CFrame.new(), rootPart, "RootJoint")
	weld(torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.7, 0), torso, "Neck")
	weld(torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0, 1, 0), torso, "Left Shoulder")
	weld(torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(0, 1, 0), torso, "Right Shoulder")
	weld(torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0), torso, "Left Hip")
	weld(torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0), torso, "Right Hip")

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.WalkSpeed = Constants.NPC.WalkSpeed
	humanoid.DisplayName = options.DisplayName
	humanoid.Parent = model

	local animator = Instance.new("Animator")
	animator.Parent = humanoid

	local nameTag = Instance.new("BillboardGui")
	nameTag.Name = "NameTag"
	nameTag.Size = UDim2.fromOffset(160, 40)
	nameTag.StudsOffset = Vector3.new(0, 2.4, 0)
	nameTag.AlwaysOnTop = true
	nameTag.Adornee = head
	nameTag.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = options.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 240, 200)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.Parent = nameTag

	model.PrimaryPart = rootPart

	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = IDLE_ANIM_ID
	idleAnim.Name = "Idle"
	idleAnim.Parent = model

	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = WALK_ANIM_ID
	walkAnim.Name = "Walk"
	walkAnim.Parent = model

	return model
end

return TownsfolkFactory
