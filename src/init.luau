--!strict
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local Core = require(script.Core)
local Recorder = {}
Recorder.__index = Recorder

local function vector(value: Vector3?): { number }?
	if value == nil then return nil end
	assert(typeof(value) == "Vector3", "Expected Vector3")
	return { value.X, value.Y, value.Z }
end

function Recorder.new(options: any?)
	local config = options or {}
	local sampleInterval = config.SampleInterval or 0.15
	local publishInterval = config.PublishInterval or 1
	assert(Core.finite(sampleInterval) and sampleInterval >= 0.05 and sampleInterval <= 5, "SampleInterval must be 0.05–5 seconds")
	assert(Core.finite(publishInterval) and publishInterval >= 0.5 and publishInterval <= 30, "PublishInterval must be 0.5–30 seconds")
	local enabled = RunService:IsStudio() and (not RunService:IsRunning() or RunService:IsServer())
	local self = setmetatable({
		_core = Core.new(config), _tracked = {}, _clock = os.clock(), _sampleClock = 0, _publishClock = 0,
		_enabled = enabled, _destroyed = false, _sampleInterval = sampleInterval, _publishInterval = publishInterval,
		_connection = nil, _session = nil, LastError = nil,
	}, Recorder)
	if enabled then
		local session = Instance.new("Folder")
		session.Name = config.Name or "NPC recording"
		session:SetAttribute("NPCRecorderVersion", 1)
		session.Archivable = false
		local data = Instance.new("StringValue")
		data.Name = "Snapshot"
		data.Value = HttpService:JSONEncode(self._core:Snapshot())
		data.Parent = session
		session.Parent = ServerStorage
		self._session = session
	end
	return self
end

function Recorder:_sample(id: string, kind: string)
	local entry = self._tracked[id]
	if not entry or entry.model.Parent == nil then return end
	self._core:Record({ t = os.clock() - self._clock, id = id, kind = kind, state = entry.state, reason = entry.reason,
		p = vector(entry.model:GetPivot().Position), target = entry.target, path = entry.path })
end

function Recorder:Track(id: string, model: Model | BasePart)
	if not self._enabled then return end
	assert(not self._destroyed, "Recorder has been destroyed")
	assert(type(id) == "string" and #id > 0 and #id <= 64, "Entity id must be 1–64 bytes")
	assert(typeof(model) == "Instance" and (model:IsA("Model") or model:IsA("BasePart")), "Track expects a Model or BasePart")
	assert(model.Parent ~= nil, "Parent the model before tracking it")
	assert(not self._tracked[id], "Entity id already tracked")
	local entry = { model = model, state = "Unspecified", reason = "No decision hook recorded", target = nil, path = nil, connection = nil }
	self._tracked[id] = entry
	local ok, err = pcall(function() self:_sample(id, "Decision") end)
	if not ok then self._tracked[id] = nil; error(err, 2) end
	entry.connection = model.Destroying:Connect(function() self:Untrack(id) end)
end

function Recorder:Record(id: string, state: string, reason: string, details: any?)
	if not self._enabled then return end
	assert(not self._destroyed, "Recorder has been destroyed")
	local entry = self._tracked[id]
	assert(entry, "Track the entity before recording its decisions")
	local info = details or {}
	local path = nil
	if info.Path then
		assert(type(info.Path) == "table" and #info.Path <= 24, "Path must contain at most 24 Vector3 positions")
		local count = #info.Path
		for key in info.Path do
			assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= count, "Path must be a dense array")
		end
		path = {}
		for i = 1, count do
			assert(typeof(info.Path[i]) == "Vector3", "Path must be a dense array of Vector3 positions")
			table.insert(path, vector(info.Path[i]))
		end
	end
	local target = vector(info.Target)
	local event = { t = os.clock() - self._clock, id = id, kind = "Decision", state = state, reason = reason,
		p = vector(entry.model:GetPivot().Position), target = target, path = path }
	self._core:Record(event)
	entry.state, entry.reason, entry.target, entry.path = state, reason, target, path
end

function Recorder:Untrack(id: string)
	local entry = self._tracked[id]
	if entry then
		if entry.connection then entry.connection:Disconnect() end
		self._tracked[id] = nil
	end
end

function Recorder:Snapshot()
	return self._core:Snapshot(os.clock() - self._clock)
end

function Recorder:Capture()
	if not self._enabled or self._destroyed then return nil end
	local snapshot = self:Snapshot()
	local json = HttpService:JSONEncode(snapshot)
	assert(#json <= 2 * 1024 * 1024, "Recording exceeds 2 MB; lower Capacity or shorten recorded paths")
	if self._session and self._session.Parent then self._session.Snapshot.Value = json end
	return snapshot
end

function Recorder:Start()
	if not self._enabled then return end
	assert(not self._destroyed, "Recorder has been destroyed")
	if self._connection then return end
	self._connection = RunService.Heartbeat:Connect(function(dt)
		self._sampleClock += dt
		self._publishClock += dt
		local ok, err = pcall(function()
			if self._sampleClock >= self._sampleInterval then
				self._sampleClock = 0
				for id, entry in self._tracked do
					if entry.model.Parent then self:_sample(id, "Sample") else self:Untrack(id) end
				end
			end
			if self._publishClock >= self._publishInterval then self._publishClock = 0; self:Capture() end
		end)
		if not ok then
			self.LastError = tostring(err)
			self:Stop()
			warn("NPCRecorder stopped: " .. self.LastError)
		end
	end)
end

function Recorder:Stop()
	if self._connection then self._connection:Disconnect(); self._connection = nil end
end

function Recorder:Clear()
	assert(not self._destroyed, "Recorder has been destroyed")
	self._core:Clear()
	self._clock = os.clock()
	self._sampleClock, self._publishClock = 0, 0
	for id in self._tracked do self:_sample(id, "Decision") end
	self:Capture()
end

function Recorder:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	self:Stop()
	for id in self._tracked do self:Untrack(id) end
	if self._session then self._session:Destroy(); self._session = nil end
	self._core:Clear()
end

Recorder.Core = Core
return Recorder
