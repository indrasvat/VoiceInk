tell application "Zen Browser"
	activate
	delay 0.1
	tell application "System Events"
		keystroke "l" using command down
		delay 0.1
		keystroke "c" using command down
	end tell
	delay 0.1
	return (the clipboard as text)
end tell 
