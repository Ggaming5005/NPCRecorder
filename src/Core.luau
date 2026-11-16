--!strict
local Core = {}
Core.__index = Core
type Ring = { items: { [number]: any }, first: number, count: number }
type Store = { capacity: number, window: number, entities: { [string]: Ring }, count: number, dropped: number, lastTime: number }

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function number(value: any, low: number, high: number, label: string): number
	assert(finite(value) and value >= low and value <= high, label .. " is out of range")
	return value
end

local function text(value: any, limit: number, label: string): string
	assert(type(value) == "string" and #value > 0 and #value <= limit, label .. " must be 1–" .. limit .. " bytes")
	return value
end

local function array(value: any, limit: number, label: string): number
	assert(type(value) == "table", label .. " must be an array")
	local count = #value
	assert(count <= limit, label .. " is too large")
	for key in value do
		assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= count, label .. " must be a dense array")
	end
	for i = 1, count do assert(value[i] ~= nil, label .. " must be a dense array") end
	return count
end

local function vector(value: any): { number }
	assert(array(value, 3, "Position") == 3, "Position needs three coordinates")
	return table.freeze({ number(value[1], -1e7, 1e7, "X"), number(value[2], -1e7, 1e7, "Y"), number(value[3], -1e7, 1e7, "Z") })
end

local function eventCopy(value: any): any
	assert(type(value) == "table", "Event must be a table")
	assert(value.kind == "Decision" or value.kind == "Sample", "Unknown event kind")
	local path = nil
	if value.path then
		array(value.path, 24, "Path")
		path = {}
		for _, point in value.path do table.insert(path, vector(point)) end
		table.freeze(path)
	end
	return table.freeze({
		t = number(value.t, 0, 1e9, "Time"), id = text(value.id, 64, "Entity id"), kind = value.kind,
		state = text(value.state, 48, "State"), reason = text(value.reason, 256, "Reason"),
		p = vector(value.p), target = if value.target then vector(value.target) else nil, path = path,
	})
end

function Core.new(options: any?)
	local config = options or {}
	local capacity = number(config.Capacity or 300, 1, 512, "Capacity")
	assert(capacity % 1 == 0, "Capacity must be an integer")
	local window = number(config.Window or 60, 1, 600, "Window")
	return setmetatable({ capacity = capacity, window = window, entities = {}, count = 0, dropped = 0, lastTime = 0 }, Core)
end

function Core.Record(self: Store, value: any)
	local event = eventCopy(value)
	assert(event.t >= self.lastTime, "Recording time cannot move backward")
	local ring = self.entities[event.id]
	if not ring then
		assert(self.count < 8, "A recorder supports at most eight entity ids; clear it before reusing the budget")
		ring = { items = {}, first = 1, count = 0 }
		self.entities[event.id] = ring
		self.count += 1
	end
	self.lastTime = event.t
	while ring.count > 0 do
		local oldest = ring.items[ring.first]
		if ring.count < self.capacity and event.t - oldest.t <= self.window then break end
		ring.items[ring.first] = nil
		ring.first = ring.first % self.capacity + 1
		ring.count -= 1
		self.dropped += 1
	end
	local index = (ring.first + ring.count - 1) % self.capacity + 1
	ring.items[index] = event
	ring.count += 1
end

function Core.Snapshot(self: Store, now: number?): any
	local cutoff = number(now or self.lastTime, self.lastTime, 1e9, "Snapshot time") - self.window
	local events: { any } = {}
	for _, ring in self.entities do
		for i = 0, ring.count - 1 do
			local event = ring.items[(ring.first + i - 1) % self.capacity + 1]
			if event.t >= cutoff then table.insert(events, event) end
		end
	end
	local order: { [any]: number } = {}
	for index, event in events do order[event] = index end
	table.sort(events, function(a: any, b: any)
		if a.t ~= b.t then return a.t < b.t end
		if a.id == b.id then return order[a] < order[b] end
		return a.id < b.id
	end)
	return table.freeze({ version = 1, events = table.freeze(events), dropped = self.dropped, duration = now or self.lastTime })
end

function Core.Clear(self: Store)
	table.clear(self.entities)
	self.count = 0
	self.dropped = 0
	self.lastTime = 0
end

function Core.validate(value: any): any
	assert(type(value) == "table" and value.version == 1, "Expected an NPCRecorder v1 recording")
	array(value.events, 4096, "Events")
	local events, ids = {}, {}
	local last, count = 0, 0
	for _, raw in value.events do
		local event = eventCopy(raw)
		assert(event.t >= last, "Events must be ordered by time")
		last = event.t
		if not ids[event.id] then ids[event.id] = true; count += 1 end
		assert(count <= 8, "Recording contains more than eight entities")
		table.insert(events, event)
	end
	return table.freeze({ version = 1, events = table.freeze(events), dropped = number(value.dropped or 0, 0, 1e12, "Dropped count"), duration = number(value.duration or last, last, 1e9, "Duration") })
end

function Core.filter(snapshot: any, id: string, state: string?): { any }
	local result = {}
	for _, event in snapshot.events do
		if event.id == id and (not state or event.state == state) then table.insert(result, event) end
	end
	return result
end

function Core.at(events: { any }, time: number): (any?, number)
	local low, high = 1, #events
	local found = 0
	while low <= high do
		local middle = math.floor((low + high) / 2)
		if events[middle].t <= time then found = middle; low = middle + 1 else high = middle - 1 end
	end
	return events[found], found
end

Core.finite = finite
return Core
