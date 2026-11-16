--!nonstrict
return function(Runtime, app)
	local HttpService = game:GetService("HttpService")
	local saved = app.snapshot and HttpService:JSONEncode(app.snapshot)
	local recorder = Runtime.new({ Name = "Integration test", Capacity = 3 })
	local part = Instance.new("Part")
	part.Anchored = true
	local ok, err = pcall(function()
		assert(not pcall(function() recorder:Track("unparented", part) end))
		part.Parent = workspace
		recorder:Track("guard", part)
		assert(not pcall(function() recorder:Record("guard", "Chase", "bad path", { Path = { one = Vector3.zero } }) end))
		assert(#recorder:Snapshot().events == 1)
		recorder:Record("guard", "Patrol", "Route ready", { Path = { Vector3.zero, Vector3.xAxis } })
		local snapshot = recorder:Capture()
		assert(snapshot.events[2].reason == "Route ready" and recorder._session.Snapshot.Value ~= "")
		part:Destroy()
		task.wait()
		assert(recorder._tracked.guard == nil, "Destroyed entity reference retained")
		assert(#recorder:Snapshot().events == 2, "Value history unexpectedly discarded")
		recorder:Destroy()
		assert(not pcall(function() recorder:Start() end), "Destroyed recorder restarted")
		local function event(t, state, x)
			return { t=t,id="guard",kind="Decision",state=state,reason=state.." reason",p={x,0,0} }
		end
		app:loadJSON(HttpService:JSONEncode({version=1,events={event(1,"Chase",1),event(2,"Search",2),event(3,"Chase",3)}}))
		app.filterState="Chase"
		app:filter()
		app:seek(2.5)
		assert(app.current == nil, "State filter held an expired state through a gap")
		app:loadJSON(HttpService:JSONEncode({version=1,events={event(1,"A",1),event(1,"B",2),event(1.00005,"C",3)}}))
		app:seek(1)
		assert(app.current.state=="B")
		app:decision(-1)
		assert(app.current.state=="A", "Equal-time decision unreachable")
		app:decision(1)
		assert(app.current.state=="B")
		app:decision(1)
		assert(app.current.state=="C", "Sub-100us decision skipped")
		assert(app.cursor.Position.X.Scale==1 and app.cursor.Position.X.Offset==-2)
		local retained=app.snapshot
		assert(not pcall(function() app:loadJSON('{"version":2}') end))
		assert(app.snapshot==retained, "Failed import replaced the prior snapshot")
	end)
	recorder:Destroy()
	part:Destroy()
	if saved then app:loadJSON(saved) end
	assert(ok,err)
	return "Native recorder publication, cleanup, invalid paths, state gaps, exact decision navigation, endpoint cursor and failed-import preservation passed"
end
