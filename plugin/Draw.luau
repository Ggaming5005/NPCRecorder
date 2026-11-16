--!strict
local Draw = {}
Draw.__index = Draw
local function point(value): Vector3
	return Vector3.new(value[1], value[2], value[3])
end
function Draw.new()
	local folder = Instance.new("Folder")
	folder.Name = "NPCRecorderOverlay"
	folder.Parent = game:GetService("CoreGui")
	local lines = Instance.new("WireframeHandleAdornment")
	lines.Adornee = workspace.Terrain
	lines.AlwaysOnTop = true
	lines.Thickness = 2
	lines.ZIndex = 5
	lines.Parent = folder
	local ghost = Instance.new("SphereHandleAdornment")
	ghost.Adornee = workspace.Terrain
	ghost.AlwaysOnTop = true
	ghost.Radius = 0.65
	ghost.Transparency = 0.2
	ghost.Color3 = Color3.fromRGB(103, 188, 155)
	ghost.ZIndex = 6
	ghost.Visible = false
	ghost.Parent = folder
	return setmetatable({ folder = folder, lines = lines, ghost = ghost }, Draw)
end
function Draw:show(event, events)
	self.lines:Clear()
	self.ghost.Visible = event ~= nil
	if not event then return end
	local position = point(event.p)
	self.ghost.CFrame = CFrame.new(position)
	local trail = {}
	for _, sample in events do
		if sample.t > event.t then break end
		if sample.t >= event.t - 8 then table.insert(trail, point(sample.p)) end
		if sample == event then break end
	end
	self.lines.Color3 = Color3.fromRGB(111, 157, 181)
	if #trail > 1 then self.lines:AddPath(trail, false) end
	if event.path and #event.path > 1 then
		local route = {}
		for _, value in event.path do table.insert(route, point(value)) end
		self.lines.Color3 = Color3.fromRGB(230, 191, 111)
		self.lines:AddPath(route, false)
	end
	if event.target then
		self.lines.Color3 = Color3.fromRGB(206, 130, 119)
		self.lines:AddLine(position, point(event.target))
	end
	self.lines.Color3 = Color3.fromRGB(164, 217, 190)
	self.lines:AddText(position + Vector3.yAxis * 2.2, event.id .. " · " .. event.state, 16)
end
function Draw:Destroy()
	self.folder:Destroy()
end
return Draw
