// keyboard_check_direct() reads the physical keyboard even when the game is in the background.
// The co-op build keeps running unfocused, so every call in the game goes through here.
if variable_global_exists("coop_focus") {if global.coop_focus=0 return 0}
return keyboard_check_direct(argument0)
