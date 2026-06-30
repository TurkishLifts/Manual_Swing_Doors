# Manual_Swing_Doors
This is an experimental plugin I'm developing to add support for manual swing doors. You can fully customize the swing doors via the Config script located inside the plugin. Please note that Door Key support is currently unavailable but is planned for a future update. Please let me know if there are any bugs.

Important: You must set every door timer to math.huge, as the plugin automatically closes the inner doors only when the swing door is shut and a call is active. Additionally, ensure that invisible Front_Doors are added to every floor with a swing door. If you know a more efficient method for handling this, I’m open to suggestions!

Download invisible Front_Doors and the Sample Swing Door from https://roblox.turkishlifts.com/downloads

# Build
To create a build of Manual_Swing_Doors:
```bash
rojo build plugin.project.json -o Manual_Swing_Doors.rbxm
```

To the Dist folder:
```bash
rojo build plugin.project.json -o Dist/Manual_Swing_Doors.rbxm
```