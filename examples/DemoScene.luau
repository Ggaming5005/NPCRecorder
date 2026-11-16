--!strict
-- Original block-built assets; no external models, images, or audio.
local DemoScene = {}
local PALETTE = { Floor = "DDDCCB", Dark = "35484A", Sage = "91A38A", Light = "EDE8D5", Amber = "D4A35F", Rust = "B97857" }

local function part(parent: Instance, name: string, size: Vector3, at: CFrame, color: string): Part
	local obj = Instance.new("Part")
	obj.Name = name
	obj.Size = size
	obj.CFrame = at
	obj.Anchored = true
	obj.Color = Color3.fromHex(color)
	obj.Material = Enum.Material.SmoothPlastic
	obj.TopSurface = Enum.SurfaceType.Smooth
	obj.BottomSurface = Enum.SurfaceType.Smooth
	obj.Parent = parent
	return obj
end

local function sign(parent: BasePart, titleText: string, subtitleText: string, face: Enum.NormalId): (TextLabel, TextLabel)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 48
	gui.LightInfluence = 0
	gui.Parent = parent
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(0.90, 0.48)
	title.Position = UDim2.fromScale(0.05, 0.12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = titleText
	title.TextColor3 = Color3.fromHex(PALETTE.Light)
	title.TextScaled = true
	title.Parent = gui
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 10
	limit.MaxTextSize = 70
	limit.Parent = title
	local subtitle = title:Clone()
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.fromScale(0.90, 0.21)
	subtitle.Position = UDim2.fromScale(0.05, 0.68)
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.Text = subtitleText
	subtitle.TextColor3 = Color3.fromHex(PALETTE.Amber)
	subtitle.Parent = gui
	return title, subtitle
end

local function robot(parent: Instance, name: string, coat: string, badge: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local function block(label: string, size: Vector3, position: Vector3, color: string, turn: CFrame?): Part
		local p = part(model, label, size, CFrame.new(position) * (turn or CFrame.identity), color)
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		return p
	end
	for _, side in { -1, 1 } do
		block("Boot", Vector3.new(0.85, 0.55, 1.25), Vector3.new(side * 0.57, 0.275, -0.15), PALETTE.Dark)
		block("Leg", Vector3.new(0.63, 0.78, 0.65), Vector3.new(side * 0.57, 0.93, 0), coat)
		block("Shoulder", Vector3.new(0.58, 0.65, 0.9), Vector3.new(side * 1.17, 2.5, 0), coat)
		block("Forearm", Vector3.new(0.48, 0.90, 0.66), Vector3.new(side * 1.24, 1.84, -0.08), PALETTE.Dark)
		block("Hand", Vector3.new(0.54, 0.38, 0.72), Vector3.new(side * 1.24, 1.32, -0.08), PALETTE.Light)
	end
	block("Torso", Vector3.new(1.8, 1.6, 1.08), Vector3.new(0, 2.05, 0), coat)
	block("ChestPlate", Vector3.new(1.44, 0.81, 0.11), Vector3.new(0, 2.27, -0.60), PALETTE.Light)
	block("Belt", Vector3.new(1.88, 0.23, 1.14), Vector3.new(0, 1.43, 0), PALETTE.Dark)
	local plate = block("UnitNumber", Vector3.new(0.52, 0.39, 0.05), Vector3.new(-0.30, 2.32, -0.68), PALETTE.Dark)
	sign(plate, badge, "", Enum.NormalId.Front)
	block("StatusLight", Vector3.new(0.18, 0.18, 0.06), Vector3.new(0.46, 2.32, -0.68), PALETTE.Amber).Material = Enum.Material.Neon
	block("Neck", Vector3.new(0.58, 0.25, 0.62), Vector3.new(0, 2.98, 0), PALETTE.Dark)
	block("Head", Vector3.new(1.82, 1.35, 1.43), Vector3.new(0, 3.75, 0), coat)
	block("Crown", Vector3.new(1.96, 0.18, 1.50), Vector3.new(0, 4.37, 0), PALETTE.Dark)
	block("Face", Vector3.new(1.58, 0.68, 0.12), Vector3.new(0, 3.78, -0.76), PALETTE.Dark)
	for _, side in { -1, 1 } do
		block("Eye", Vector3.new(0.42, 0.13, 0.07), Vector3.new(side * 0.42, 3.86, -0.85), PALETTE.Amber).Material = Enum.Material.Neon
	end
	block("Mouth", Vector3.new(0.42, 0.08, 0.06), Vector3.new(0, 3.50, -0.85), PALETTE.Light)
	block("Antenna", Vector3.new(0.11, 0.60, 0.11), Vector3.new(0.65, 4.76, 0.05), PALETTE.Dark)
	block("AntennaLight", Vector3.new(0.23, 0.19, 0.23), Vector3.new(0.65, 5.10, 0.05), PALETTE.Amber)
	block("Pack", Vector3.new(1.22, 1.10, 0.42), Vector3.new(0, 2.14, 0.70), PALETTE.Dark)
	model.WorldPivot = CFrame.identity
	model.Parent = parent
	return model
end

function DemoScene.create(parent: Instance, origin: Vector3)
	local scene = Instance.new("Model")
	scene.Name = "NPCRecorderDemoYard"
	local function block(name: string, size: Vector3, position: Vector3, color: string): Part
		return part(scene, name, size, CFrame.new(origin + position), color)
	end
	block("Foundation", Vector3.new(78, 2, 62), Vector3.new(0, -1.25, 0), PALETTE.Dark)
	block("Courtyard", Vector3.new(76, 0.4, 60), Vector3.new(0, 0, 0), PALETTE.Floor)
	block("PatrolLane", Vector3.new(62, 0.07, 9), Vector3.new(0, 0.245, 11), "AFBCA6")
	for i = -5, 5 do
		block("LaneMark", Vector3.new(2.4, 0.05, 0.14), Vector3.new(i * 5.4, 0.31, 15.1), PALETTE.Light)
	end
	block("LoadingBayWall", Vector3.new(20, 7.1, 2), Vector3.new(0, 3.75, -1), "8F9E8C")
	block("WallCoping", Vector3.new(22, 0.45, 2.5), Vector3.new(0, 7.52, -1), PALETTE.Dark)
	for _, x in { -10.7, 10.7 } do
		block("BayPillar", Vector3.new(0.8, 7.3, 2.6), Vector3.new(x, 3.85, -1), PALETTE.Dark)
	end
	block("BayDoor", Vector3.new(5.7, 5.2, 0.20), Vector3.new(0, 2.85, 0.09), "61756A")
	for i = 1, 6 do
		block("DoorSlat", Vector3.new(5.4, 0.07, 0.10), Vector3.new(0, 0.65 + i * 0.67, 0.24), "9EAD97")
	end
	local bay = block("BayNumber", Vector3.new(5.7, 1.1, 0.15), Vector3.new(0, 6.28, 0.13), PALETTE.Dark)
	sign(bay, "LOADING BAY / 03", "", Enum.NormalId.Back)
	for _, spec in {
		{ "Crate_A", Vector3.new(-26, 2.35, -10), Vector3.new(5, 4.3, 5) },
		{ "Crate_B", Vector3.new(25, 2.65, -14), Vector3.new(6, 4.9, 6) },
		{ "Crate_C", Vector3.new(28, 1.9, -5), Vector3.new(4.5, 3.4, 4.5) },
	} do
		local name, p, s = spec[1] :: string, spec[2] :: Vector3, spec[3] :: Vector3
		block(name, s, p, "B7A783")
		for _, side in { -1, 1 } do
			block(name .. "Band", Vector3.new(0.22, s.Y + 0.05, s.Z + 0.08), p + Vector3.new(side * s.X * 0.3, 0, 0), PALETTE.Dark)
		end
		block(name .. "Lid", Vector3.new(s.X + 0.18, 0.22, s.Z + 0.18), p + Vector3.new(0, s.Y / 2, 0), "C6B896")
	end
	for _, x in { -31, 31 } do
		block("Planter", Vector3.new(4.8, 1, 4.8), Vector3.new(x, 0.8, 22), PALETTE.Dark)
		for i = 1, 4 do
			local leaf = block("Leaf", Vector3.new(0.6, 2.5 + i * 0.25, 1.3), Vector3.new(x + (i % 2) * 1.4 - 0.7, 2.5, 22 + math.floor(i / 2) * 0.65 - 0.7), if i % 2 == 0 then "71896A" else "93A77B")
			leaf.CFrame *= CFrame.Angles(0, i, (i - 2.5) * 0.16)
		end
	end
	local board = block("TitleBoard", Vector3.new(30, 5.2, 0.5), Vector3.new(0, 3.2, -26), PALETTE.Dark)
	local _, status = sign(board, "NPC / RECORDER", "PATROL  ·  GUARD 01", Enum.NormalId.Back)
	local guard = robot(scene, "Guard", PALETTE.Sage, "01")
	local intruder = robot(scene, "Intruder", PALETTE.Rust, "X")
	guard:PivotTo(CFrame.new(origin + Vector3.new(-22, 0.32, 11)))
	intruder:PivotTo(CFrame.new(origin + Vector3.new(18, 0.32, 10)))
	local sight = block("ActualSightRay", Vector3.new(0.06, 0.06, 1), Vector3.new(0, -5, 0), PALETTE.Sage)
	sight.CanCollide = false; sight.CanTouch = false; sight.CanQuery = false
	sight.Material = Enum.Material.Neon; sight.Transparency = 0.3
	scene.Parent = parent
	return { Scene = scene, Guard = guard, Intruder = intruder, Sight = sight, Status = status }
end

return DemoScene
