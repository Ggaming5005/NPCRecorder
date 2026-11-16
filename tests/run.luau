--!strict
local Core = require("../src/Core")
local passed = 0
local function test(name: string, callback: () -> ())
	local ok, err = pcall(callback)
	assert(ok, name .. ": " .. tostring(err))
	passed += 1
end
local function rejects(callback: () -> ())
	assert(not pcall(callback), "Expected rejection")
end
local function event(t: number, id: string?): any
	return { t = t, id = id or "guard", kind = "Decision", state = "Patrol", reason = "Waypoint reached", p = { t, 2, 3 }, path = { { 0, 0, 0 }, { 10, 0, 2 } } }
end

test("capacity preserves chronological newest events", function()
	local core = Core.new({ Capacity = 3 })
	for i = 1, 10 do core:Record(event(i)) end
	local snapshot = core:Snapshot()
	assert(#snapshot.events == 3 and snapshot.events[1].t == 8 and snapshot.events[3].t == 10)
	assert(snapshot.dropped == 7)
end)
test("capacity is per entity", function()
	local core = Core.new({ Capacity = 2 })
	core:Record(event(1, "a"))
	for i = 2, 6 do core:Record(event(i, "b")) end
	local snapshot = core:Snapshot()
	assert(#Core.filter(snapshot, "a") == 1 and #Core.filter(snapshot, "b") == 2)
end)
test("equal timestamps preserve per-entity insertion order", function()
	local core = Core.new()
	for i = 1, 4 do
		for _, id in { "a", "b" } do
			local e = event(1, id); e.state = tostring(i); core:Record(e)
		end
	end
	for _, id in { "a", "b" } do assert(Core.at(Core.filter(core:Snapshot(), id), 1).state == "4") end
end)
test("time window expires idle entities too", function()
	local core = Core.new({ Window = 2 })
	core:Record(event(0, "a")); core:Record(event(1, "b")); core:Record(event(4, "b"))
	local snapshot = core:Snapshot(5)
	assert(#snapshot.events == 1 and snapshot.events[1].t == 4)
	assert(#core:Snapshot(7).events == 0)
end)
test("source mutation cannot change history", function()
	local core = Core.new()
	local source = event(1)
	core:Record(source)
	source.p[1] = 999
	source.path[1][1] = 999
	local saved = core:Snapshot().events[1]
	assert(saved.p[1] == 1 and saved.path[1][1] == 0)
	rejects(function() saved.p[1] = 9 end)
	rejects(function() saved.path[1][1] = 9 end)
	rejects(function() core:Snapshot().events[1] = nil end)
end)
test("backward timestamps do not mutate record", function()
	local core = Core.new()
	core:Record(event(4))
	rejects(function() core:Record(event(3)) end)
	assert(#core:Snapshot().events == 1)
end)
test("at returns last event at or before requested time", function()
	local core = Core.new()
	for i = 1, 5 do core:Record(event(i)) end
	local events = core:Snapshot().events
	assert(Core.at(events, 0) == nil)
	assert(Core.at(events, 3.9).t == 3)
	assert(Core.at(events, 5).t == 5 and Core.at(events, 99).t == 5)
end)
test("state filter is exact", function()
	local core = Core.new()
	core:Record(event(1))
	local second = event(2); second.state = "Search"; core:Record(second)
	assert(#Core.filter(core:Snapshot(), "guard", "Search") == 1)
end)
test("clear releases ids and resets time", function()
	local core = Core.new()
	for i = 1, 8 do core:Record(event(i, tostring(i))) end
	rejects(function() core:Record(event(9, "ninth")) end)
	core:Clear()
	core:Record(event(0, "ninth"))
	assert(#core:Snapshot().events == 1 and core:Snapshot().dropped == 0)
end)
test("invalid finite inputs are rejected", function()
	for _, value in { 0/0, math.huge, -math.huge, -1 } do
		rejects(function() Core.new({ Capacity = value }) end)
		rejects(function() local e=event(value); Core.new():Record(e) end)
	end
	rejects(function() Core.new({ Capacity = 1.2 }) end)
	rejects(function() local e=event(1); e.p[2]=0/0; Core.new():Record(e) end)
end)
test("malformed and excessive arrays are rejected", function()
	rejects(function() local e=event(1); e.p.extra=1; Core.new():Record(e) end)
	rejects(function() local e=event(1); e.path=table.create(25,{0,0,0}); Core.new():Record(e) end)
	rejects(function() local e=event(1); e.path={[1]={0,0,0},[3]={0,0,0}}; Core.new():Record(e) end)
end)
test("import validates schema and chronology", function()
	local saved=Core.validate({version=1,events={event(0),event(1)},duration=2,dropped=4})
	assert(#saved.events == 2 and saved.duration == 2)
	rejects(function() Core.validate({version=2,events={}}) end)
	rejects(function() Core.validate({version=1,events={event(2),event(1)}}) end)
	rejects(function() Core.validate({version=1,events={event(2)},duration=1}) end)
	rejects(function() Core.validate({version=1,events={event(2)},dropped=-1}) end)
end)
test("invalid state does not consume capacity", function()
	local core=Core.new({Capacity=1})
	core:Record(event(1))
	local e=event(2); e.reason=string.rep("x",257)
	rejects(function() core:Record(e) end)
	assert(core:Snapshot().events[1].t==1)
end)
print(string.format("NPCRecorder: %d tests passed", passed))
