tell application "Zen Browser"
	activate
	delay 0.05
	tell application "System Events"
		keystroke "l" using command down
		delay 0.05
		keystroke "c" using command down
		delay 0.05
		keystroke tab
	end tell
	delay 0.05
	return (the clipboard as text)
end tell 
