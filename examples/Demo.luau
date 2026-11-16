--!strict
local RunService = game:GetService("RunService")
local DemoScene = require(script.Parent.DemoScene)
local Demo = {}

local TARGET_ROUTE = {
	{ Point = Vector3.new(18, 0.32, 10), Seconds = 4 },
	{ Point = Vector3.new(14, 0.32, 10), Seconds = 4 },
	{ Point = Vector3.new(14, 0.32, -11), Seconds = 5 },
	{ Point = Vector3.new(-18, 0.32, -11), Seconds = 4 },
	{ Point = Vector3.new(-18, 0.32, 10), Seconds = 5 },
}
local PATROL_ROUTE = { Vector3.new(-22, 0.32, 11), Vector3.new(21, 0.32, 11), Vector3.new(21, 0.32, 8), Vector3.new(-22, 0.32, 8) }

local function targetAt(time: number, origin: Vector3): (Vector3, Vector3)
	local t = time % 22
	for i, entry in TARGET_ROUTE do
		if t < entry.Seconds then
			local destination = TARGET_ROUTE[i % #TARGET_ROUTE + 1].Point
			return origin + entry.Point:Lerp(destination, t / entry.Seconds), (destination - entry.Point).Unit
		end
		t -= entry.Seconds
	end
	return origin + TARGET_ROUTE[1].Point, Vector3.xAxis
end

function Demo.start(Recorder: any, parent: Instance, origin: Vector3?)
	assert(not RunService:IsRunning() or RunService:IsServer(), "NPCRecorder demo runs in Edit Studio or on the server")
	assert(parent == workspace or parent:IsDescendantOf(workspace), "Demo parent must be in Workspace so its sight rays test the real scene")
	local base = origin or Vector3.new(150, 0, 0)
	local assets = DemoScene.create(parent, base)
	local guard, intruder = assets.Guard, assets.Intruder
	local r = Recorder.new({ Name = "Guard demo", Capacity = 300, Window = 60, SampleInterval = 0.15, PublishInterval = 1 })
	r:Track("guard", guard)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { guard, intruder, assets.Sight }
	local alive = true
	local connection: RBXScriptConnection? = nil
	local destroying: RBXScriptConnection? = nil
	local time = 0
	local state = "Patrol"
	local stateSince = 0
	local patrolIndex = 2
	local lastSeen: Vector3? = nil
	local lastChaseRecord = -10
	local lastRecordedTarget: Vector3? = nil
	local guardPosition = base + PATROL_ROUTE[1]
	local guardDirection = Vector3.xAxis
	local function frontLane(point: Vector3): Vector3
		return Vector3.new(math.clamp(point.X, base.X - 24, base.X + 24), base.Y + 0.32, math.clamp(point.Z, base.Z + 8, base.Z + 13))
	end
	local function record(reason: string, destination: Vector3, target: Vector3?)
		r:Record("guard", state, reason, { Target = target, Path = { guardPosition, destination } })
	end
	local function transition(nextState: string, reason: string, destination: Vector3, target: Vector3?)
		state = nextState
		stateSince = time
		assets.Status.Text = string.upper(state) .. "  ·  GUARD 01"
		assets.Status.TextColor3 = Color3.fromHex(if state == "Chase" then "D4A35F" elseif state == "Search" then "D9BB83" else "C2D3AD")
		record(reason, destination, target)
		assets.Scene:SetAttribute("GuardState", state)
	end
	transition("Patrol", "Starting the marked front-lane patrol route.", base + PATROL_ROUTE[patrolIndex], nil)
	r:Start()
	r:Capture()
	local handle = { Recorder = r, Scene = assets.Scene, Guard = guard, Intruder = intruder }
	function handle:Destroy()
		if not alive then return end
		alive = false
		if connection then connection:Disconnect(); connection = nil end
		if destroying then destroying:Disconnect(); destroying = nil end
		r:Destroy()
		assets.Scene:Destroy()
	end
	destroying = assets.Scene.Destroying:Connect(function() handle:Destroy() end)
	connection = RunService.Heartbeat:Connect(function(dt: number)
		if not alive then return end
		if guard.Parent == nil or intruder.Parent == nil then handle:Destroy(); return end
		time += math.min(dt, 0.15)
		local targetPosition, targetDirection = targetAt(time, base)
		intruder:PivotTo(CFrame.lookAt(targetPosition, targetPosition + targetDirection))
		local eye = guardPosition + Vector3.new(0, 3.8, 0)
		local targetEye = targetPosition + Vector3.new(0, 3.8, 0)
		local ray = targetEye - eye
		local hit = workspace:Raycast(eye, ray, rayParams)
		local inRange = ray.Magnitude <= 43
		local visible = inRange and hit == nil
		local sightEnd = if hit then hit.Position else targetEye
		local sightDelta = sightEnd - eye
		assets.Sight.Size = Vector3.new(0.06, 0.06, math.max(0.02, sightDelta.Magnitude))
		if sightDelta.Magnitude > 0.001 then assets.Sight.CFrame = CFrame.lookAt((eye + sightEnd) / 2, sightEnd) end
		assets.Sight.Color = Color3.fromHex(if visible then "91A38A" else "D4A35F")
		assets.Sight.Transparency = if inRange then 0.3 else 1
		if visible then
			lastSeen = targetPosition
			if state ~= "Chase" then
				transition("Chase", "Intruder visible: the eye-to-target ray is clear and within 43 studs.", frontLane(targetPosition), targetPosition)
				lastChaseRecord = time
				lastRecordedTarget = targetPosition
			elseif time - lastChaseRecord >= 1.25 and (not lastRecordedTarget or (targetPosition - lastRecordedTarget).Magnitude > 5) then
				record("Visible intruder moved; updating the front-corridor destination.", frontLane(targetPosition), targetPosition)
				lastChaseRecord = time
				lastRecordedTarget = targetPosition
			end
		elseif state == "Chase" then
			local why = if hit then "Line of sight blocked by " .. hit.Instance.Name .. "; checking the last seen position." else "Intruder moved outside the 43-stud detection range; checking the last seen position."
			transition("Search", why, frontLane(lastSeen or guardPosition), lastSeen)
		elseif state == "Search" and time - stateSince >= 3 then
			local distance = math.huge
			for i, point in PATROL_ROUTE do
				local candidate = (base + point - guardPosition).Magnitude
				if candidate < distance then distance = candidate; patrolIndex = i end
			end
			transition("Patrol", "No clear sighting for 3 seconds; returning to the nearest patrol waypoint.", base + PATROL_ROUTE[patrolIndex], nil)
		end
		local destination: Vector3
		local speed: number
		if state == "Chase" then
			destination = frontLane(targetPosition)
			speed = if (targetPosition - guardPosition).Magnitude < 4 then 0 else 5.2
		elseif state == "Search" then
			destination = frontLane(lastSeen or guardPosition)
			speed = 2.8
		else
			destination = base + PATROL_ROUTE[patrolIndex]
			speed = 3.1
			if (destination - guardPosition).Magnitude < 0.3 then
				patrolIndex = patrolIndex % #PATROL_ROUTE + 1
				destination = base + PATROL_ROUTE[patrolIndex]
				record("Patrol waypoint reached; continuing along the marked lane.", destination, nil)
			end
		end
		local difference = destination - guardPosition
		if difference.Magnitude > 0.03 and speed > 0 then
			guardDirection = difference.Unit
			guardPosition += guardDirection * math.min(difference.Magnitude, speed * dt)
		elseif state == "Search" then
			local turn = math.sin((time - stateSince) * 2) * 0.65
			guardDirection = Vector3.new(math.sin(turn), 0, -math.cos(turn))
		end
		local desired = CFrame.lookAt(guardPosition, guardPosition + guardDirection)
		local rotation = guard:GetPivot().Rotation:Lerp(desired.Rotation, 1 - math.exp(-9 * dt))
		guard:PivotTo(CFrame.new(guardPosition) * rotation)
	end)
	return handle
end

return Demo
