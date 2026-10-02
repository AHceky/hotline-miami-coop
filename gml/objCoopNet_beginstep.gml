// The game keeps running unfocused (so the partner still sees you); drop input meant for other apps.
global.coop_focus=external_call(global.__net_focused)
if global.coop_focus=0 io_clear()
