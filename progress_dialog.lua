local iup=require "iuplua"

local progress_dialog={}

function progress_dialog.get_dialog(min_progress,max_progress,text)
	progress=iup.dialog{
		iup.vbox{
			iup.progressbar{min=tostring(min_progress),max=tostring(max_progress)},
			iup.text{value=text,size="300x",readonly="yes"};
			margin="20x20"
		}
		;title="Processing...",size="QUARTERxQUARTER"
	}
	return progress
end

function progress_dialog.update(dialog,progress_value,text)
	
	dialog[1][1].value=tostring(progress_value)
	dialog[1][2].value=text
	iup.Redraw(dialog[1][2],0)
--	print("progress dialog.update:"..dialog[1][2].value..", "..text)
end

return progress_dialog