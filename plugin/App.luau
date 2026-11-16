--!nonstrict
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local Core = require(script.Parent.Runtime.Core)
local Runtime = require(script.Parent.Runtime)
local Demo = require(script.Parent.Demo)
local Draw = require(script.Parent.Draw)
local App = {}
App.__index = App

local function create(class, props, parent)
	local object = Instance.new(class)
	for key, value in props do object[key] = value end
	object.Parent = parent
	return object
end
local function cleaned(reason)
	return tostring(reason):gsub("^.-:%d+: ", "")
end

function App.start(plugin)
	local self = setmetatable({ plugin = plugin, connections = {}, events = {}, ids = {}, states = {}, sessions = {}, time = 0, playing = false, closed = false, overlay = true }, App)
	local ok, err = pcall(function() self:initialize() end)
	if not ok then self:Destroy(); error(err, 0) end
	return self
end

function App:initialize()
	local theme = settings().Studio.Theme
	local colors = {
		background = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		input = theme:GetColor(Enum.StudioStyleGuideColor.InputFieldBackground),
		button = theme:GetColor(Enum.StudioStyleGuideColor.Button),
		text = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
		muted = theme:GetColor(Enum.StudioStyleGuideColor.DimmedText),
		accent = Color3.fromRGB(100, 172, 142),
	}
	self.colors = colors
	self.widget = self.plugin:CreateDockWidgetPluginGuiAsync("NPCRecorder.v1", DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 430, 760, 360, 560))
	self.widget.Title = "NPCRecorder"
	self.toolbar = self.plugin:CreateToolbar("NPCRecorder")
	self.toggle = self.toolbar:CreateButton("NPCRecorder", "Inspect instrumented NPC decisions", "", "NPCRecorder")
	self.toggle.ClickableWhenViewportHidden = true
	self.draw = Draw.new()
	local root = create("ScrollingFrame", { Name = "Inspector", Size = UDim2.fromScale(1, 1), BackgroundColor3 = colors.background, BorderSizePixel = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3 }, self.widget)
	create("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, root)
	create("UIListLayout", { Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder }, root)
	local order = 0
	local function item(class, props, parent)
		if not parent then order += 1; props.LayoutOrder = order end
		return create(class, props, parent or root)
	end
	local function label(text, size, height, muted)
		return item("TextLabel", { Size = UDim2.new(1, 0, 0, height or size + 6), BackgroundTransparency = 1, Text = text, TextSize = size, Font = Enum.Font.SourceSans, TextColor3 = if muted then colors.muted else colors.text, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true })
	end
	local function button(text, callback, accent)
		local b = item("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = if accent then colors.accent else colors.button, BorderSizePixel = 0, Text = text, TextSize = 15, Font = Enum.Font.SourceSansSemibold, TextColor3 = if accent then Color3.fromRGB(15, 32, 25) else colors.text })
		create("UICorner", { CornerRadius = UDim.new(0, 3) }, b)
		b.Activated:Connect(function()
			local ok, err = pcall(callback)
			if not ok then self.status.Text = cleaned(err) end
		end)
		return b
	end
	label("NPC RECORDER", 12, 18, true)
	label("Revisit the decision", 24, 28)
	self.status = label("Add hooks to your NPC, then read its recording in the Server test view.", 14, 40, true)
	self.sessionButton = button("Session    Refresh to find recordings", function() self:refreshSessions(true) end)
	button("Read recording", function() self:capture() end, true)
	self.entityButton = button("Entity    —", function()
		if #self.ids == 0 then return end
		self.entity = self.ids[(table.find(self.ids, self.entity) or 0) % #self.ids + 1]
		self.filterState = nil
		self:filter()
	end)
	self.filterButton = button("State    All", function()
		local index = if self.filterState then table.find(self.states, self.filterState) or 0 else 0
		self.filterState = self.states[index + 1]
		self:filter()
	end)
	self.rangeLabel = label("No recording loaded", 13, 20, true)
	self.timeline = item("TextButton", { Name = "Timeline", Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = colors.input, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ClipsDescendants = true })
	self.cursor = create("Frame", { Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = colors.text, BorderSizePixel = 0, ZIndex = 4 }, self.timeline)
	self.timeline.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then self.dragging = true; self:scrubX(input.Position.X) end
	end)
	self.timeline.InputChanged:Connect(function(input)
		if self.dragging and input.UserInputType == Enum.UserInputType.MouseMovement then self:scrubX(input.Position.X) end
	end)
	table.insert(self.connections, game:GetService("UserInputService").InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then self.dragging = false end
	end))
	local controls = item("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 })
	for i, spec in { { "Previous decision", -1 }, { "Play history", 0 }, { "Next decision", 1 } } do
		local b = create("TextButton", { Position = UDim2.new((i - 1) / 3, 0, 0, 0), Size = UDim2.new(1 / 3, -4, 1, 0), BackgroundColor3 = colors.button, BorderSizePixel = 0, Text = spec[1], TextSize = 13, TextColor3 = colors.text, Font = Enum.Font.SourceSans }, controls)
		if spec[2] == 0 then self.playButton = b end
		b.Activated:Connect(function()
			if spec[2] == 0 then
				if not self.snapshot then return end
				if self.time >= (self.lastTime or 0) then self.time = self.firstTime or 0 end
				self.playing = not self.playing
				self.playButton.Text = if self.playing then "Pause history" else "Play history"
			else self:decision(spec[2]) end
		end)
	end
	self.timeInput = item("TextBox", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = colors.input, BorderSizePixel = 0, Text = "0.000", PlaceholderText = "Time in seconds", ClearTextOnFocus = false, Font = Enum.Font.Code, TextSize = 14, TextColor3 = colors.text })
	self.timeInput.FocusLost:Connect(function()
		local time = tonumber(self.timeInput.Text)
		if time and Core.finite(time) then self:seek(time) else self.timeInput.Text = string.format("%.3f", self.time) end
	end)
	self.stateLabel = label("No decision", 22, 28)
	self.reasonLabel = label("Recorded reasons appear here. NPCRecorder observes your hooks; it does not infer intent.", 15, 58)
	self.reasonLabel.AutomaticSize = Enum.AutomaticSize.Y
	self.reasonLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.positionLabel = label("", 13, 45, true)
	button("Toggle world overlay", function() self.overlay = not self.overlay; self:seek(self.time) end)
	label("Green · recorded position     Blue · recent trail\nAmber · recorded route     Coral · recorded target", 12, 36, true)
	label("EXAMPLE", 12, 18, true)
	self.demoButton = button("Start guard demo", function() self:toggleDemo() end)
	label("TRANSFER", 12, 18, true)
	label("Copy JSON before stopping Play to keep a recording. Paste it below to inspect it later.", 13, 34, true)
	button("Show recording JSON", function()
		assert(self.snapshot, "Read a recording first")
		self.json.Text = HttpService:JSONEncode(self.snapshot)
		self.json.Visible = true
	end)
	self.json = item("TextBox", { Size = UDim2.new(1, 0, 0, 140), Visible = false, BackgroundColor3 = colors.input, BorderSizePixel = 0, Text = "", PlaceholderText = "Paste NPCRecorder JSON", ClearTextOnFocus = false, MultiLine = true, TextWrapped = false, Font = Enum.Font.Code, TextSize = 12, TextColor3 = colors.text, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	button("Paste / import JSON", function()
		if not self.json.Visible then self.json.Visible = true; self.json:CaptureFocus(); return end
		self:loadJSON(self.json.Text)
	end)
	table.insert(self.connections, self.toggle.Click:Connect(function() self.widget.Enabled = not self.widget.Enabled end))
	table.insert(self.connections, self.widget:GetPropertyChangedSignal("Enabled"):Connect(function()
		self.toggle:SetActive(self.widget.Enabled)
		if not self.widget.Enabled then
			self.playing, self.dragging = false, false
			self.playButton.Text = "Play history"
			self.draw:show(nil, {})
			if self.demo then self.demo:Destroy(); self.demo = nil; self.demoButton.Text = "Start guard demo" end
		end
	end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		if self.playing and self.widget.Enabled then
			self:seek(self.time + dt, true)
			if self.time >= self.lastTime then self.playing = false; self.playButton.Text = "Play history" end
		end
	end))
	table.insert(self.connections, self.plugin.Unloading:Connect(function() self:Destroy() end))
	self:refreshSessions(false)
end

function App:refreshSessions(advance)
	self.sessions = {}
	for _, child in ServerStorage:GetChildren() do
		if child:GetAttribute("NPCRecorderVersion") == 1 and child:FindFirstChild("Snapshot") and child.Snapshot:IsA("StringValue") then table.insert(self.sessions, child) end
	end
	table.sort(self.sessions, function(a, b) return a.Name < b.Name end)
	local index = table.find(self.sessions, self.session) or 0
	if advance or index == 0 then index = index % math.max(1, #self.sessions) + 1 end
	self.session = self.sessions[index]
	self.sessionButton.Text = "Session    " .. (if self.session then self.session.Name else "None · click to refresh")
end

function App:loadJSON(json)
	assert(type(json) == "string" and #json <= 2 * 1024 * 1024, "JSON must be at most 2 MB")
	local snapshot = Core.validate(HttpService:JSONDecode(json))
	self.snapshot = snapshot
	self.ids = {}
	local seen = {}
	for _, event in snapshot.events do if not seen[event.id] then seen[event.id] = true; table.insert(self.ids, event.id) end end
	table.sort(self.ids)
	self.entity = if seen[self.entity] then self.entity else self.ids[1]
	self.filterState = nil
	self.playing = false
	self.playButton.Text = "Play history"
	self:filter()
	self.status.Text = string.format("Frozen snapshot · %d events · %d capacity/age evictions. Read again to refresh.", #snapshot.events, snapshot.dropped)
end

function App:capture()
	self:refreshSessions(false)
	assert(self.session, if RunService:IsClient() then "Switch to the Server test view to read server recordings." else "No recording found. Start the example or instrument an NPC.")
	self:loadJSON(self.session.Snapshot.Value)
end

function App:filter()
	self.entityEvents = if self.snapshot and self.entity then Core.filter(self.snapshot, self.entity) else {}
	if not self.snapshot or not self.entity then
		self.events = {}
	else self.events = Core.filter(self.snapshot, self.entity, self.filterState) end
	self.states = {}
	local seen = {}
	if self.snapshot then
		for _, event in self.snapshot.events do
			if event.id == self.entity and not seen[event.state] then seen[event.state] = true; table.insert(self.states, event.state) end
		end
	end
	table.sort(self.states)
	self.entityButton.Text = "Entity    " .. (self.entity or "—")
	self.filterButton.Text = "State    " .. (self.filterState or "All")
	self.firstTime = if self.events[1] then self.events[1].t else 0
	self.lastTime = if self.events[#self.events] then self.events[#self.events].t else 0
	self.rangeLabel.Text = string.format("%.1fs — %.1fs  ·  %d samples and decisions", self.firstTime, self.lastTime, #self.events)
	for _, child in self.timeline:GetChildren() do if child ~= self.cursor then child:Destroy() end end
	local colors = { Color3.fromRGB(105, 175, 145), Color3.fromRGB(224, 178, 102), Color3.fromRGB(113, 157, 194), Color3.fromRGB(194, 130, 117) }
	local markers = 0
	for _, event in self.events do
		if event.kind == "Decision" and markers < 128 then
			markers += 1
			local span = self.lastTime - self.firstTime
			local fraction = if span > 0 then (event.t - self.firstTime) / span else 0
			create("Frame", { Position = UDim2.new(fraction, -4 * fraction, 0.18, 0), Size = UDim2.new(0, 4, 0.64, 0), BorderSizePixel = 0, BackgroundColor3 = colors[((table.find(self.states, event.state) or 1) - 1) % #colors + 1] }, self.timeline)
		end
	end
	self:seek(self.firstTime)
end

function App:seek(time, keepPlaying, exactIndex)
	if not keepPlaying then self.playing = false; self.playButton.Text = "Play history" end
	self.time = math.clamp(time, self.firstTime or 0, self.lastTime or 0)
	local event, index = Core.at(self.entityEvents or {}, self.time)
	if exactIndex then event, index = self.entityEvents[exactIndex], exactIndex end
	self.eventIndex = index
	if event and self.filterState and event.state ~= self.filterState then event = nil end
	self.current = event
	self.timeInput.Text = string.format("%.3f", self.time)
	local span = (self.lastTime or 0) - (self.firstTime or 0)
	local fraction = if span > 0 then (self.time - (self.firstTime or 0)) / span else 0
	self.cursor.Position = UDim2.new(fraction, -2 * fraction, 0, 0)
	self.stateLabel.Text = if event then event.state else "No decision"
	self.reasonLabel.Text = if event then event.reason else "No matching state at this time."
	self.positionLabel.Text = if event then string.format("%s at %.3fs\nPosition %.1f, %.1f, %.1f · %d route points", event.kind, event.t, event.p[1], event.p[2], event.p[3], if event.path then #event.path else 0) else ""
	self.draw:show(if self.overlay and self.widget.Enabled then event else nil, self.entityEvents or {})
end

function App:scrubX(x)
	local fraction = math.clamp((x - self.timeline.AbsolutePosition.X) / math.max(1, self.timeline.AbsoluteSize.X), 0, 1)
	self:seek((self.firstTime or 0) + fraction * ((self.lastTime or 0) - (self.firstTime or 0)))
end

function App:decision(direction)
	local events = self.entityEvents or {}
	local index = (self.eventIndex or 0) + direction
	while index >= 1 and index <= #events do
		local event = events[index]
		if event.kind == "Decision" and (not self.filterState or event.state == self.filterState) then
			self:seek(event.t, false, index)
			return
		end
		index += direction
	end
end

function App:toggleDemo()
	if self.demo then self.demo:Destroy(); self.demo = nil; self.demoButton.Text = "Start guard demo"; return end
	assert(not RunService:IsRunning(), "Stop Play mode to start the editor example")
	self.demo = Demo.start(Runtime, workspace)
	self.demoButton.Text = "Stop guard demo"
	self:refreshSessions(false)
	self.status.Text = "Demo running. Wait for patrol, chase and search, then Read recording."
end

function App:Destroy()
	if self.closed then return end
	self.closed = true
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if self.demo then self.demo:Destroy(); self.demo = nil end
	if self.draw then self.draw:Destroy() end
	if self.widget then self.widget:Destroy() end
	if self.toolbar then self.toolbar:Destroy() end
	self.snapshot, self.current, self.session = nil, nil, nil
	table.clear(self.events)
	if self.entityEvents then table.clear(self.entityEvents) end
end

return App
