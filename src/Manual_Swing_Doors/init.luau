--[[
	Manual Swing Door support for ModuluxV2 by TurkishLifts
	
	       VERSION: v1.2.2, DATE: 12/06/2026
]]--

local module = {}

function module.init(controller)
	local RunService = game:GetService("RunService")

	local SwingDoors = {

	}
	
	local state = {
		Stopped = false,
		key_debounce = false
	}

	local config = require(script.Config)
	
	local JanitorModule = require(
		(script:FindFirstChild("Dependencies") and script:FindFirstChild("Dependencies"):FindFirstChild("Janitor")) 
			or game:GetService("ReplicatedStorage"):FindFirstChild("Janitor")
	)
	local Janitor = JanitorModule.new()
	
	local ElevatorModel : Model = controller.Source
	local Values : Folder = ElevatorModel:WaitForChild("Values")
	local FloorsFolder : Folder = ElevatorModel:FindFirstChild("Floors")
	local CurrentFloor : NumberValue = Values:WaitForChild("Floor")
	local API : BindableEvent = controller.API
	local Swing_API : BindableEvent = script:FindFirstChild("Swing_API")
	local Platform : BasePart = controller.Platform
	local Destination : NumberValue = Values:WaitForChild("Destination")
	local ElevatorFloors = controller.Floors
	if config.OpenInnerdoorsOnSetup == true then
		API:Fire('door_signal', {
			sides = 'all', 
			request = 'open' 
		})
	end
	if not Swing_API then
		local Swing_API_NEW : BindableEvent = Instance.new("BindableEvent")
		Swing_API_NEW.Name = "Swing_API"
		Swing_API_NEW.Parent = script
		Swing_API = Swing_API_NEW
	end

	local GetCFCValue = function(Key : any, FloorName : string)
		local CFC = config.CustomFloorConfig

		if CFC[FloorName] and CFC[FloorName][Key] ~= nil then
			return CFC[FloorName][Key]
		end

		return nil
	end
	
	local GetConfig = function(key, floor, default)
		local val = GetCFCValue(key,floor)
		if val == nil then
			val = config[key]
		end
		if val == nil then
			val = default
		end
		return val
	end

	local HasCalls = function()
		local hasCarCalls = false
		local hasHallCalls = false

		for _, v in controller.Queue.HallCalls do
			local FloorNumber = v.Call
			if FloorsFolder:FindFirstChild(`Floor_{FloorNumber}`) and CurrentFloor.Value ~= FloorNumber then
				hasHallCalls = true
				break
			end
		end

		for _, v in controller.Queue.CarCalls do
			local FloorNumber = v.Call
			if FloorsFolder:FindFirstChild(`Floor_{FloorNumber}`) and CurrentFloor.Value ~= FloorNumber then
				hasCarCalls = true
				break
			end
		end

		if hasCarCalls or hasHallCalls then
			return true
		else
			return false
		end
	end

	local ToggleDoor = function() end
	local SwingDoorFunctions = {
		ToggleDoor = function(Player : Player, DoorModel : Model, Value: string?)
			local FloorModel = DoorModel.Parent.Parent

			local FloorData : {debounce: boolean, bypass_debounce : boolean, opened: boolean, count: number, bypass: boolean, locked : boolean} = SwingDoors[FloorModel.Name]


			local CloseWhileOpen =  GetConfig("CloseWhileOpen", FloorModel.Name, true)
			local OpenSpeed = GetConfig("OpenSpeed", FloorModel.Name, 1)
			local CloseSpeed = GetConfig("CloseSpeed", FloorModel.Name, 1)
			local OpenSoundId = GetConfig("OpenSound", FloorModel.Name, 0)
			local ClosingSoundId = GetConfig("ClosingSound", FloorModel.Name, 0)
			local ClosedSoundId = GetConfig("ClosedSound", FloorModel.Name, 0)
			local DoorSoundsEnabled = GetConfig("DoorSoundsEnabled", FloorModel.Name, false)
			local DoorVolume = GetConfig("DoorVolume", FloorModel.Name, 1)
			local DoorRollOffMaxDistance = GetConfig("DoorRollOffMaxDistance", FloorModel.Name, 15)
			
			local DoorSound : Sound = Platform:FindFirstChild("Swing_Door_Sound")
			if DoorSoundsEnabled then
				if DoorSound == nil then
					local DoorSound_New = Instance.new("Sound",Platform)
					DoorSound_New.Name = "Swing_Door_Sound"
					DoorSound_New.Volume = DoorVolume
					DoorSound_New.RollOffMaxDistance = DoorRollOffMaxDistance
					DoorSound = DoorSound_New
				end
			end

			if Value == "KEY" then
				if FloorData.bypass == true then
					FloorData.bypass = false
					FloorData.count = math.huge
					--FloorData.debounce = false 
					return
				else
					FloorData.bypass = true
					FloorData.count = 0
					if FloorData.opened then return end
				end
			end

			if FloorData.opened and FloorData.bypass == false then
				if CloseWhileOpen then
					FloorData.count = math.huge
				end 
				return 
			elseif FloorData.opened and FloorData.bypass == true then
				FloorData.bypass = false
				FloorData.count = math.huge 
				return
			end

			if (Values.Floor.Value == tonumber((FloorModel.Name:gsub("Floor_",""))) and Values.Speed.Value == 0 and FloorData.locked == false and FloorData.debounce == false) or (Value == "KEY" and FloorData.debounce == false) then
				script.Swing_API:Fire("Swing_Door_Opening", {
					FloorNumber = (FloorModel.Name:gsub("Floor_","")),
					FloorModel = FloorModel,
					DoorModel = DoorModel
				})

				API:Fire('door_signal', {request = 'open'})
				FloorData.debounce = true

				if DoorSoundsEnabled and OpenSoundId ~= 0  then
					if DoorSound.Playing == true then DoorSound:Stop() end
					DoorSound.SoundId = `rbxassetid://{OpenSoundId}`
					DoorSound:Play()
				end

				local startPivot = DoorModel:GetPivot()
				local targetPivot;

				local DoorRotation = GetConfig("DoorRotation",FloorModel.Name, "Clockwise")
				if DoorRotation == "Anticlockwise" then
					targetPivot = startPivot * CFrame.Angles(0, math.rad(90), 0)
				else
					targetPivot = startPivot * CFrame.Angles(0, math.rad(-90), 0)
				end

				local t = 0
				while t < 1 do
					local dt = RunService.Heartbeat:Wait()
					t = math.min(t + dt / OpenSpeed, 1) 
					DoorModel:PivotTo(startPivot:Lerp(targetPivot, t))
				end

				script.Swing_API:Fire("Swing_Door_Opened", {
					FloorNumber = (FloorModel.Name:gsub("Floor_","")),
					FloorModel = FloorModel,
					DoorModel = DoorModel
				})

				FloorData.opened = true
				FloorData.debounce = false


				local openStartTime = os.clock()

				local targetOpenTime = GetConfig("OpenTime",FloorModel.Name,3)

				if FloorData.bypass == true then targetOpenTime = math.huge end

				while FloorData.opened do
					task.wait(0.1) 
					FloorData.count += 1
					if FloorData.count == math.huge then
						break
					end

					if FloorData.bypass then
						openStartTime = os.clock()
						FloorData.count = 0
						continue
					end

					if(os.clock() - openStartTime) >= targetOpenTime then
						break
					end
				end

				FloorData.count = 0

				if not FloorData.bypass then

					script.Swing_API:Fire("Swing_Door_Closing", {
						FloorNumber = (FloorModel.Name:gsub("Floor_","")),
						FloorModel = FloorModel,
						DoorModel = DoorModel
					})
					FloorData.debounce = true

					if DoorSoundsEnabled and ClosingSoundId ~= 0  then
						if DoorSound.Playing == true then DoorSound:Stop() end
						DoorSound.SoundId = `rbxassetid://{ClosingSoundId}`
						DoorSound:Play()
					end
					
					task.delay(CloseSpeed, function()
						if DoorSoundsEnabled and ClosedSoundId ~= 0 then
							if DoorSound.Playing == true then DoorSound:Stop() end
							DoorSound.SoundId = `rbxassetid://{ClosedSoundId}`
							DoorSound:Play()
						end
					end)
					
					local t = 0
					while t < 1 do
						local dt = RunService.Heartbeat:Wait()
						t = math.min(t + dt / CloseSpeed, 1)
						DoorModel:PivotTo(targetPivot:Lerp(startPivot, t))
					end
					
					DoorModel:PivotTo(startPivot)

					FloorData.opened = false
					FloorData.count = 0

					local LiftHasCalls = HasCalls()
					
					
					script.Swing_API:Fire("Swing_Door_Closed", {
						FloorNumber = (FloorModel.Name:gsub("Floor_","")),
						FloorModel = FloorModel,
						DoorModel = DoorModel
					})

					FloorData.debounce = false
				end
			end
		end,

		OnTouched = function(BasePart: BasePart, DoorModel : Model)
			local Data = SwingDoors[DoorModel.Parent.Parent.Name]
			local FloorName : string = DoorModel.Parent.Parent.Name
			local OpenSpeed = GetConfig("OpenSpeed",FloorName,1)
			
			if config.EnableBypass == false or Data.touch_debounce then return end
			
			if (BasePart.Parent.Name == "Triangle Key" or BasePart.Parent.Name == "Safety Contact") and BasePart.Parent:IsA("Tool") then
				Data.touch_debounce = true
				task.delay(OpenSpeed+0.5, function()
					Data.touch_debounce = false
				end)

				if BasePart.Parent.Name == "Triangle Key" then
					if state.key_debounce then
						--Data.touch_debounce = false
						return 
					end
					
					state.key_debounce = true
					
					state.Stopped = not state.Stopped
					if state.Stopped then
						state.SavedFloor = CurrentFloor.Value
						controller.StatValues.DoorSafetyLock = false
						controller.UpdateStatValues()
						
						API:Fire("Stop",true)
						
						if config.OpenInnerdoorsOnKey then
							for _, doorData in controller.door_data do
								doorData.Open({
									open_time = controller.Config.doors.door_timers.open_no_call,
									bypass_door_zone = true,
									disable_safety_lock = true,
									open_floor_doors = false,
								})
							end
						end
					else
						local NearFloor = controller.GetNearestFloor()
						SwingDoors[FloorName].locked = true
						local LevelPosition = controller.CurrentPosition.Position.Y + (controller.Level.Position.Y - controller.Platform.Position.Y)
						local isInDoorZone = math.abs(NearFloor.Level.Position.Y - LevelPosition) < 0.5
						local FloorNumber = tonumber( (FloorName:gsub("Floor_","")) )
						local LiftDest = controller.StatValues.Destination or FloorNumber

						if controller.CheckAllDoorStates("Closed") and not isInDoorZone then
							if ElevatorFloors[tostring(CurrentFloor.Value + 1)] then
								controller.StatValues.Floor = NearFloor.FloorNumber + 1
							else
								controller.StatValues.Floor = NearFloor.FloorNumber - 1
							end

						end

						local Dest

						if LiftDest == FloorNumber then
							if ElevatorFloors[tostring(CurrentFloor.Value + 1)] then
								Dest = CurrentFloor.Value + 1
							elseif ElevatorFloors[tostring(CurrentFloor.Value - 1)] then
								Dest = CurrentFloor.Value - 1
							else
								Dest = nil
							end
						else
							Dest = LiftDest
						end

						API:Fire("Stop", false)
						task.wait(0.1)
						--API:Fire('door_signal', { sides = 'all', request = 'close' })
						if Dest ~= nil then 
							API:Fire("AddCarCall", { call =  Dest })
						end
					end
					task.delay(1, function()
						state.key_debounce = false
					end)			
				end
				
				task.spawn(function()
					ToggleDoor(nil,DoorModel,"KEY")
				end)

			end
		end,
	}

	ToggleDoor = SwingDoorFunctions.ToggleDoor
	if FloorsFolder then
		local Floors = FloorsFolder:GetChildren()

		for i, floor : Model in pairs(Floors) do
			if floor:IsA("Model") == false then continue end

			local FloorNumber = (floor.Name:gsub("Floor_",""))

			local SwingDoorContainer : Model = floor:FindFirstChild("Swing_Doors")
			local FrontDoors : Model = floor:FindFirstChild("Front_Doors")
			local BackDoors : Model = floor:FindFirstChild("Back_Doors")

			if not FrontDoors and not BackDoors then warn(`Front_Doors and Back_Doors not found. Skipping door setup for floor {FloorNumber}.`) continue end
			if not SwingDoorContainer then warn(`Swing_Doors not found. Skipping door setup for floor {FloorNumber}.`) continue end

			local SwingDoor : Model = SwingDoorContainer:FindFirstChildWhichIsA("Model")

			if not SwingDoor then warn(`SwingDoor not found on floor {floor.Name:gsub("Floor_","")}, skipping floor.`) continue end

			if SwingDoors[floor.Name] == nil then
				SwingDoors[floor.Name] = {
					debounce = false,
					opened = false,
					bypass = false,
					locked = false,
					count = 0,
					touch_debounce = false,
					idle_loop_active = false,
					doormodel = SwingDoor
				}
			end

			for _,v : Instance in pairs(SwingDoor:GetChildren()) do
				local DetectorType = GetConfig("DetectorType", floor.Name, "DragDetector")
				if DetectorType == "DragDetector" then
					local DragDetector = Instance.new("DragDetector")
					DragDetector.DragStyle = Enum.DragDetectorDragStyle.Scriptable
					DragDetector.Parent = v
					DragDetector.MaxActivationDistance = GetConfig("MaxActivationDistance",floor.Name,10)
					
					Janitor:Add(
						DragDetector.DragStart:Connect(function(Player)
							if not SwingDoors[floor.Name].debounce then
								SwingDoorFunctions.ToggleDoor(Player, SwingDoor)
							end
						end)
					)
				elseif DetectorType == "ClickDetector" then
					local ClickDetector = Instance.new("ClickDetector")
					ClickDetector.Parent = v
					ClickDetector.MaxActivationDistance = GetConfig("MaxActivationDistance",floor.Name,10)
					
					Janitor:Add(
						ClickDetector.MouseClick:Connect(function(Player)
							if not SwingDoors[floor.Name].debounce then
								SwingDoorFunctions.ToggleDoor(Player, SwingDoor)
							end
						end)
					)
				end

			end

			for _,v : Instance in pairs(SwingDoor:GetDescendants()) do
				if v:IsA("BasePart") then
					Janitor:Add(
						v.Touched:Connect(function(BasePart : BasePart)
							SwingDoorFunctions.OnTouched(BasePart, SwingDoor)
						end)
					)
				end
			end
		end
		
		Janitor:Add(
			API.Event:Connect(function(protocol, params)
				local floorName = "Floor_"..tostring(CurrentFloor.Value)
				local CloseDoorOnCall = GetConfig("CloseDoorOnCall", floorName, false)
				local CloseIdle = GetConfig("CloseIdle", floorName, 0.5)
				
				local LockType = GetConfig("LockType", floorName, "AfterClose")
				local UnlockType = GetConfig("UnlockType", floorName, "BeforeOpen")
				
				if protocol == "on_door_close" then
					SwingDoors[floorName].idle_loop_active = false
					local InnerdoorsCloseSpeed = controller.Config.doors.close_speed
					
					if LockType == "BeforeClose" then
						SwingDoors[floorName].locked = true
					end
					task.wait(InnerdoorsCloseSpeed-(InnerdoorsCloseSpeed * (10/100)))

					if SwingDoors[floorName].opened == true and not SwingDoors[floorName].bypass then
						API:Fire('door_signal', {
							sides = 'all', 
							request = 'open' 
						})
					end
					if LockType == "AfterClose" then
						SwingDoors[floorName].locked = true
					end
				elseif protocol == "on_stop" then
					if UnlockType == "BeforeOpen" then
						SwingDoors[floorName].locked = false
					end
				elseif protocol == "on_car_call_added" or protocol == "on_hall_call_added" then		
					local LiftHasCalls = HasCalls()
					if LiftHasCalls then			
						if CloseDoorOnCall then
							if SwingDoors[floorName].opened then
								while SwingDoors[floorName].debounce or SwingDoors[floorName].opened do
									task.wait(0.1)
								end
								task.wait(CloseIdle)
								API:Fire('door_signal', {
									sides = 'all', 
									request = 'close' 
								})
							end
						else
							while SwingDoors[floorName].debounce or SwingDoors[floorName].opened do
								task.wait(0.1)
							end
							task.wait(CloseIdle)
							if not SwingDoors[floorName].debounce and not SwingDoors[floorName].opened then
								API:Fire('door_signal', {
									sides = 'all', 
									request = 'close' 
								})
							end
						end
					end
				elseif protocol == "on_door_open" then
					if UnlockType == "BeforeOpen" then
						SwingDoors[floorName].locked = false
					end
					SwingDoors[floorName].idle_loop_active = true

				elseif protocol == "on_door_opened" then


					SwingDoors[floorName].locked = false

					local WaitTime = config.IdleTime or 7

					local LiftHasCalls = false

					local OpenDoorOnArrive = GetConfig("OpenDoorOnArrive", floorName, false)
					if OpenDoorOnArrive then
						local OpenDoorDelay = GetConfig("OpenDoorOnArriveDelay", floorName, 0.5)

						task.delay(OpenDoorDelay, function()
							if not SwingDoors[floorName].debounce and not SwingDoors[floorName].opened then
								SwingDoorFunctions.ToggleDoor(nil, SwingDoors[floorName].doormodel)
							end
						end)
					end

					while SwingDoors[floorName].idle_loop_active do
						task.wait(WaitTime)

						if not SwingDoors[floorName].idle_loop_active then
							break
						end

						LiftHasCalls = HasCalls()
						if LiftHasCalls then
							local CloseDoorOnCall = GetConfig("CloseDoorOnCall", floorName, false)
							if CloseDoorOnCall then
								SwingDoors[floorName].count = math.huge

								while SwingDoors[floorName].opened do
									task.wait(0.1)
								end

								task.wait(CloseIdle)

								API:Fire('door_signal', {
									sides = 'all', 
									request = 'close' 
								})
							else
								task.wait(CloseIdle)
								if not SwingDoors[floorName].debounce and not SwingDoors[floorName].opened then
									API:Fire('door_signal', {
										sides = 'all', 
										request = 'close' 
									})
								end
							end
						end
					end
				end
			end)
		)
		
		Janitor:Add(
			script.Destroying:Connect(function()
				Janitor:Cleanup()
			end)
		)
	else
		warn("Floors folder cannot be found.")
	end
end

return module