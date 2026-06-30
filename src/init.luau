--[[
	Manual Swing Door support for ModuluxV2 by TurkishLifts
	
	       VERSION: v1.3.3, DATE: 01/07/2026
]]--

--!nocheck

local module = {}

-- Types
type FloorDataInstance = {
	debounce: boolean,
	bypass_debounce : boolean,
	opened: boolean,
	count: number,
	bypass: boolean,
	locked : boolean,
	touch_debounce: boolean,
	idle_loop_active: boolean,
	doormodel : Model,
	startPivot : CFrame,
	targetPivot : CFrame,
	StateChanged : any
}

function module.init(controller)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	
	local function GetDependency(name : string)
		local embedded = script:FindFirstChild("Dependencies")
		if embedded and embedded:FindFirstChild(name) then
			return require(embedded[name])
		end

		local msdDeps = ReplicatedStorage:FindFirstChild("MSD_Dependencies")
		if msdDeps and msdDeps:FindFirstChild(name) then
			return require(msdDeps[name])
		end

		local legacy = ReplicatedStorage:FindFirstChild(name)

		if legacy then
			warn(`[Manual_Swing_Doors] DEPRECATED: Loading '{name}' directly from ReplicatedStorage is deprecated and will be removed in the future. Put dependencies on ReplicatedStorage.MSD_Dependencies instead.`)
			return require(legacy)
		end

		error(`[Manual_Swing_Doors] Dependency '{name}' not found in script.Dependencies, ReplicatedStorage.MSD_Dependencies, or ReplicatedStorage.`)
	end

	local RunService = game:GetService("RunService")

	local SwingDoors : {FloorDataInstance} = {

	}
	
	local state = {
		Stopped = false,
		key_debounce = false
	}

	if not script:FindFirstChild("Config") then error("Fatal error: Config not found in the plugin Manual_Swing_Doors"); return end
	
	local config = require(script.Config)
	
	local JanitorModule = GetDependency("Janitor")
	local Janitor = JanitorModule.new()
	
	local GoodSignal = GetDependency("goodsignal")

	local ElevatorModel : Model = controller.Source
	local Values : Folder = ElevatorModel:WaitForChild("Values")
	local FloorsFolder : Folder = ElevatorModel:FindFirstChild("Floors")
	local CurrentFloor : NumberValue = Values:WaitForChild("Floor")
	local API : BindableEvent = controller.API
	local Platform : BasePart = controller.Platform

	local ElevatorFloors = controller.Floors
	if config.OpenInnerdoorsOnSetup == true then
		API:Fire('door_signal', {
			sides = 'all', 
			request = 'open' 
		})
	end

	local Swing_API : BindableEvent = script:FindFirstChild("Swing_API")

	if not Swing_API then
		local Swing_API_NEW : BindableEvent = Instance.new("BindableEvent")
		Swing_API_NEW.Name = "Swing_API"
		Swing_API_NEW.Parent = script
		Swing_API = Swing_API_NEW
	end

	local Control_API : BindableEvent = script:FindFirstChild("Control_API")

	if not Control_API then
		local Control_API_NEW : BindableEvent = Instance.new("BindableEvent")
		Control_API_NEW.Name = "Control_API"
		Control_API_NEW.Parent = script
		Control_API = Control_API_NEW
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

	local IsOnFloor = function(FloorName)
		local FloorModel = FloorsFolder[FloorName]
		local FloorData = SwingDoors[FloorName]

		if (Values.Floor.Value == tonumber((FloorModel.Name:gsub("Floor_","")))
			and Values.Speed.Value == 0
			and FloorData.locked == false
			and FloorData.debounce == false)
		then
			return true
		else
			return false
		end
	end

	local FloorExists = function(FloorNumber)
		local FloorModel = FloorsFolder:FindFirstChild(`Floor_{FloorNumber}`)
		if FloorModel then
			return true
		end
		return false
	end
	local ToggleDoor = function() end

	local SwingDoorFunctions = {
		OpenDoor = function(Player : Player, DoorModel : Model, startPivot, targetPivot)
			local FloorModel = DoorModel.Parent.Parent

			local FloorData : FloorDataInstance = SwingDoors[FloorModel.Name]


			local OpenSpeed = GetConfig("OpenSpeed", FloorModel.Name, 1)
			local OpenSoundId = GetConfig("OpenSound", FloorModel.Name, 0)
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
				FloorData.StateChanged:Fire("Opened")
		end,

		CloseDoor = function(Player : Player, DoorModel : Model, startPivot, targetPivot)
				local FloorModel = DoorModel.Parent.Parent

				local FloorData : FloorDataInstance = SwingDoors[FloorModel.Name]


				local CloseSpeed = GetConfig("CloseSpeed", FloorModel.Name, 1)
				local ClosingSoundId = GetConfig("ClosingSound", FloorModel.Name, 0)
				local ClosedSoundId = GetConfig("ClosedSound", FloorModel.Name, 0)
				local DoorSoundsEnabled = GetConfig("DoorSoundsEnabled", FloorModel.Name, false)
				
				local DoorSound : Sound = Platform:FindFirstChild("Swing_Door_Sound")
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

					script.Swing_API:Fire("Swing_Door_Closed", {
						FloorNumber = (FloorModel.Name:gsub("Floor_","")),
						FloorModel = FloorModel,
						DoorModel = DoorModel
					})

					FloorData.debounce = false
					FloorData.StateChanged:Fire("Closed")
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
							task.defer(function()							
								for _, doorData in controller.door_data do
									doorData.Disable(false)
									doorData.Open({
										open_time = controller.Config.doors.door_timers.open_no_call,
										disable_safety_lock = true,
										bypass_door_zone = true,
										bypass_disabled_elevator = true,
									})
								end
							end)
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

	ToggleDoor = function(Player : Player, DoorModel : Model, Value: string?)
		local FloorModel = DoorModel.Parent.Parent
		local CloseWhileOpen =  GetConfig("CloseWhileOpen", FloorModel.Name, true)
		local FloorData = SwingDoors[FloorModel.Name]

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

		if IsOnFloor(FloorModel.Name) or (Value == "KEY" and FloorData.debounce == false) then

		SwingDoorFunctions.OpenDoor(Player, DoorModel, FloorData.startPivot, FloorData.targetPivot)

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

		SwingDoorFunctions.CloseDoor(Player, DoorModel, FloorData.startPivot, FloorData.targetPivot)

	end

	end

	if FloorsFolder then
		local Floors = FloorsFolder:GetChildren()

		for i, floor : Model in ipairs(Floors) do
			if floor:IsA("Model") == false then continue end

			local FloorNumber = (floor.Name:gsub("Floor_",""))

			local SwingDoorContainer : Model = floor:FindFirstChild("Swing_Doors")
			local FrontDoors : Model = floor:FindFirstChild("Front_Doors")
			local BackDoors : Model = floor:FindFirstChild("Back_Doors")

			if not FrontDoors and not BackDoors then warn(`Front_Doors and Back_Doors not found. Skipping door setup for floor {FloorNumber}.`); continue end
			if not SwingDoorContainer then warn(`Swing_Doors not found. Skipping door setup for floor {FloorNumber}.`); continue end

			local SwingDoor : Model = SwingDoorContainer:FindFirstChildWhichIsA("Model")

			if not SwingDoor then warn(`SwingDoor not found on floor {floor.Name:gsub("Floor_","")}, skipping floor.`); continue end

			if SwingDoors[floor.Name] == nil then
				local startPivot = SwingDoor:GetPivot()
				local targetPivot;

				local DoorRotation = GetConfig("DoorRotation",floor.Name, "Clockwise")
				if DoorRotation == "Anticlockwise" then
					targetPivot = startPivot * CFrame.Angles(0, math.rad(90), 0)
				else
					targetPivot = startPivot * CFrame.Angles(0, math.rad(-90), 0)
				end

				SwingDoors[floor.Name] = {
					debounce = false,
					opened = false,
					bypass = false,
					locked = false,
					count = 0,
					touch_debounce = false,
					idle_loop_active = false,
					doormodel = SwingDoor,
					startPivot = startPivot,
					targetPivot = targetPivot,
					StateChanged = GoodSignal.new()
				}
			end

			for _,v : Instance in ipairs(SwingDoor:GetChildren()) do
				local DetectorType = GetConfig("DetectorType", floor.Name, "DragDetector")
				if DetectorType == "DragDetector" then
					local DragDetector = Instance.new("DragDetector")
					DragDetector.DragStyle = Enum.DragDetectorDragStyle.Scriptable
					DragDetector.Parent = v
					DragDetector.MaxActivationDistance = GetConfig("MaxActivationDistance",floor.Name,10)
					if config.NewDragDetector then
						DragDetector.ActivatedCursorIcon = "rbxassetid://135040650935313"
						DragDetector.CursorIcon = "rbxassetid://84133861939386"
					end
					Janitor:Add(
						DragDetector.DragStart:Connect(function(Player)
							if not SwingDoors[floor.Name].debounce then
								ToggleDoor(Player, SwingDoor)
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
								ToggleDoor(Player, SwingDoor)
							end
						end)
					)
				end

			end

			for _,v : Instance in ipairs(SwingDoor:GetDescendants()) do
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
									SwingDoors[floorName].StateChanged:Wait()
								end
								task.wait(CloseIdle)
								API:Fire('door_signal', {
									sides = 'all', 
									request = 'close' 
								})
							end
						else
							while SwingDoors[floorName].debounce or SwingDoors[floorName].opened do
								SwingDoors[floorName].StateChanged:Wait()
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
								ToggleDoor(nil, SwingDoors[floorName].doormodel)
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
							if CloseDoorOnCall then
								SwingDoors[floorName].count = math.huge

								while SwingDoors[floorName].opened do
									SwingDoors[floorName].StateChanged:Wait()
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
			Control_API.Event:Connect(function(protocol : 'swing_door_signal' | 'test' , params : {
				request : 'open' | 'close' | 'toggle',
				OverrideSafety : boolean,
				FloorNumber : number,
				IfOnFloor : boolean,
				OpenTime : number
			})
				if protocol == 'swing_door_signal' then
					if not (params.request and params.FloorNumber) then return end
					if params.OverrideSafety == nil then params.OverrideSafety = false end
					if params.IfOnFloor == nil then params.IfOnFloor = true end
					if FloorExists(params.FloorNumber) == false then warn("This floor does not exist!"); return end

					local FloorData = SwingDoors[`Floor_{params.FloorNumber}`]
					local DoorModel = FloorData.doormodel

					if params.request == 'open' then
						if FloorData.opened or FloorData.debounce then return end
						if params.IfOnFloor then if not IsOnFloor(`Floor_{params.FloorNumber}`) then return end end
						SwingDoorFunctions.OpenDoor(nil, DoorModel, FloorData.startPivot, FloorData.targetPivot)

						if params.OpenTime then
							task.delay(
								params.OpenTime,
								function()
									if FloorData.opened ~= true or FloorData.debounce then return end
									SwingDoorFunctions.CloseDoor(nil, DoorModel, FloorData.startPivot, FloorData.targetPivot)
								end
							)
						end
						if not params.OverrideSafety then API:Fire("Stop",true); state.Stopped = true end
					elseif params.request == 'close' then
						if (not FloorData.opened) or FloorData.debounce then return end
						SwingDoorFunctions.CloseDoor(nil, DoorModel, FloorData.startPivot, FloorData.targetPivot)
						if state.Stopped == true then API:Fire("Stop",false); state.Stopped = false end
					elseif params.request == 'toggle' then
						ToggleDoor(nil, DoorModel, params.OverrideSafety and "KEY" or nil)
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