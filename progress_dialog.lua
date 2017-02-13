local iup=require "iuplua"

local progress_dialog={}

local progressbar=nil
local progresstext=nil
local progress=nil

function progress_dialog.show_dialog(min_progress,max_progress,text)
	progressbar=iup.progressbar{min=tostring(min_progress),max=tostring(max_progress)}
	progresstext=iup.text{size="300x",readonly="yes"}
	progress=iup.dialog{
		iup.vbox{
			progressbar,
			progresstext;
			margin="20x20"
		}
		;title="Processing...",size="QUARTERxQUARTER"
	}
	progress:show()
	progresstext.value=text
end

function progress_dialog.update(progress_value,text)
	progressbar.value=tostring(progress_value)
	progresstext.value=text
end

function progress_dialog.hide_dialog()
	progress:hide()
end

return progress_dialog