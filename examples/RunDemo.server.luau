--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Recorder = require(ReplicatedStorage.NPCRecorder)
local Demo = require(ReplicatedStorage.NPCRecorderExamples.Demo)
local handle = Demo.start(Recorder, workspace)

-- Disable/re-enable through the owner only after calling handle:Destroy().
-- The demo also disconnects itself when its Scene is destroyed.
game:BindToClose(function() handle:Destroy() end)
