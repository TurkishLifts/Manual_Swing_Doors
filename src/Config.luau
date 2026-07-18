local config = {
	DetectorType = "DragDetector", -- DragDetector | ClickDetector | None
	NewDragDetector = false, -- Enables the new modulux DragDetector style on the doors.
	OpenTime = 3, -- How long the door stays open - Seconds
	MaxActivationDistance = 10, -- The max distance the elevator door can be opened.
	CloseWhileOpen = true, -- Enables closing the door when it is open, by clicking it again.
	DoorRotation = "Anticlockwise", -- Clockwise | Anticlockwise

	LockType = "AfterClose", -- AfterClose | BeforeClose
	UnlockType = "BeforeOpen", -- BeforeOpen | AfterOpen
	OpenSpeed = 1,  -- How fast the door opens - Seconds
	CloseSpeed = 1, -- How fast the door closes - Seconds
	
	DoorSoundsEnabled = false, -- Enables door sounds.
	OpenSound = 123456789, -- Open sound - Asset ID
	ClosingSound = 123456789, -- Open sound - Asset ID
	ClosedSound = 123456789, -- Plays when the swing door is closed
	LockSound = 123456789, -- Plays when the swing door is locked
	UnlockSound = 123456789, -- Plays when the swing door is unlocked
	DoorVolume = 1, -- Volume of the door sounds
	DoorRollOffMaxDistance = 15, -- Maximum distance where the door sounds could be heard.
	
	IdleTime = 7, -- How long the lift waits until responding to another call.
	CloseIdle = 0.5, -- How long the lift waits after the door closes

	OpenInnerdoorsOnSetup = true, -- Opens the innerdoors when the lift's setup is complete.
	
	OpenInnerdoorsOnKey = true, -- Forces inner doors open when elevator is stopped via Triangle Key
	
	OpenDoorOnArrive = false, -- Opens the door when the innerdoors open.
	CloseDoorOnCall = false, -- Closes the door when there is a call.
	OpenDoorOnArriveDelay = 0.5, -- Delays the OpenDoorOnArrive. Does not affect manual door opening

	EnableBypass = true, -- Gives the ability to unlock swingdoors via Triangle Key or Safety Contact.
	
	CustomFloorConfig = {
		--[[
		["Floor_1"] = {
			DoorRotation = "Anticlockwise",
			OpenSpeed = 1,
		}
		]]--
	}
}

return config
