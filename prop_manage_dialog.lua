local iup=require "iup"
local prop_manage_dialog={}

-- data

local default_prop={}
local props={}
local prop_id_name="new"
local hints={}
local is_apply=false

-- ui definition

local text_width={
	small="80x",
	medium="160x",
	large="240x"
}

local ctrl_suffix={
	text="text",
	toggle="toggle",
	dropdown="dropdown"
}

local edit_dialog=nil
local prop_list=nil
local save_button=nil
local add_button=nil
local del_button=nil

local prop_ctrl={}

local apply_button=nil
local cancel_button=nil

-- utils

local pos_in_list=function(list,text)
	for i=1,tonumber(list.count)
	do
		if list[i] == text
		then
			return i
		end
	end
	return nil
end

local select_dropdown_item=function(dropdown,text)
	for i=1,tonumber(dropdown.count)
	do
		if dropdown[i] == text
		then
			dropdown.value=i
		end
	end
end

local current_prop=function()
	return prop_list[prop_list.value]
end

local label=function(text)
	return iup.label{title=text;padding="5x0"}
end

local label_wrap=function(text,ctrl)
	return iup.hbox{label(text),ctrl}
end

local update_prop_ui=function(props)
	for prop_name,prop_value in pairs(props)
	do
		local ctrl_type=default_prop[prop_name].type
		local ctrl=prop_ctrl[prop_name.."_"..ctrl_suffix[ctrl_type]]
		
		if ctrl_type == ctrl_suffix.text
		then
			ctrl.value=prop_value
		elseif ctrl_type == ctrl_suffix.toggle
		then
			if prop_value
			then
				ctrl.value="ON"
			else
				ctrl.value="OFF"
			end
		elseif ctrl_type == ctrl_suffix.dropdown
		then
			select_dropdown_item(ctrl,prop_value)
		end
	end
end

local prop_selected=function(index)
	prop_id_name=prop_list[index]
	update_prop_ui(props[prop_list[index]])
end

local parse_ctrl_name=function(ctrl_name)
	local reversed=ctrl_name:reverse()
	local pivot=ctrl_name:len()-reversed:find("_")+1
	
	return ctrl_name:sub(1,pivot-1),ctrl_name:sub(pivot+1,ctrl_name:len())
end

local read_prop=function()
	local new_prop={}
	local ctrl_type=""
	local name=""
	for ctrl_name,ctrl in pairs(prop_ctrl)
	do
		name,ctrl_type=parse_ctrl_name(ctrl_name)
		if ctrl_type == ctrl_suffix.text
		then
			new_prop[name]=ctrl.value
		elseif ctrl_type == ctrl_suffix.toggle
		then
			if ctrl.value == "ON"
			then
				new_prop[name]=true
			else
				new_prop[name]=false
			end
		elseif ctrl_type == ctrl_suffix.dropdown
		then
			new_prop[name]=ctrl[ctrl.value]
		else
			print("unknown control - name:"..name..",type:"..ctrl_type)
		end
	end
	return new_prop
end

local list_contains=function(name)
	for index=1,tonumber(prop_list.count)
	do
		if prop_list[index]==name
		then
			return true
		end
	end
	return false
end

local get_default_prop_table=function()
	local default_table={}
	for name,setting in pairs(default_prop)
	do
		default_table[name]=setting.value
	end
	return default_table
end

-- callbacks

local on_cancel=function()
	is_apply=false
	edit_dialog:hide()
end

local on_apply=function()
	is_apply=true
	edit_dialog:hide()
end

local on_add=function()
	local accepted=false
	local new_name=""
	
	local name_dlg=nil
	local new_name_text=iup.text{}
	local accept_button=iup.button{title="accept";size="100x"}
	local refuse_button=iup.button{title="cancel";size="100x"}
	
	function accept_button:action()
		accepted=true
		new_name=new_name_text.value
		name_dlg:hide()
	end
	
	function refuse_button:action()
		name_dlg:hide()
	end
	
	name_dlg=iup.dialog{
		iup.vbox{
			label_wrap("new name:",new_name_text),
			iup.hbox{
				accept_button,
				refuse_button;
				margin="5x5"
			}
		};title="Input name",size="QUARTERxQUARTER"
	}
	name_dlg:map()
	new_name_text.value="new"
	name_dlg:popup()
	
	if accepted
	then
		prop_id_name=new_name
		update_prop_ui(get_default_prop_table())
	end
end

local on_save=function()
	local new_prop=read_prop()
	props[prop_id_name]=new_prop
	if not list_contains(prop_id_name)
	then
		prop_list.appenditem=prop_id_name
	end
	if tonumber(prop_list.count) == 1
	then
		prop_list.value=1
	end
end

local on_del=function()
	if tonumber(prop_list.count) < 2
	then
		iup.Message("Warning!","Only one left,can't delete!")
	else
		props[current_prop()]=nil
		prop_list.removeitem=prop_list.value
		prop_selected(prop_list.value)
	end
end

local action_prop_list=function(text,item,state)
	if state == 1
	then
		prop_id_name=text
		prop_selected(item)
	end
end

-- program life

local fill_ui=function()
	
	local is_empty=true
	for name,props in pairs(props)
	do
		is_empty=false
		prop_list.appenditem=name
	end
	
	if not is_empty
	then
		prop_list.value=1
		prop_selected(1)
	end
	
	for name,setting in pairs(default_prop)
	do
		if setting.type == ctrl_suffix.dropdown
		then
			local dropdown=prop_ctrl[name.."_"..ctrl_suffix.dropdown]
			for i=1,#setting.choice
			do
				dropdown.appenditem=setting.choice[i]
			end
			dropdown.value=1
		end
	end
end

local start_ui=function()
	prop_list=iup.list{size="100x",dropdown="yes",multiple="no"}
	function prop_list:action(text,item,state)
		action_prop_list(text,item,state)
	end
	
	save_button=iup.button{title="save change"}
	function save_button:action()
		on_save()
	end
	add_button=iup.button{title="new"}
	function add_button:action()
		on_add()
	end
	del_button=iup.button{title="delete"}
	function del_button:action()
		on_del()
	end
	
	local prop_field=iup.vbox{}
	for name,settings in pairs(default_prop)
	do
		local new_ctrl=nil
		local suffix=""
		
		if settings.type == "text"
		then
			new_ctrl=iup.text{text_width[settings.width]}
		elseif settings.type == "toggle"
		then
			new_ctrl=iup.toggle{"settings.title";}
		elseif settings.type == "dropdown"
		then
			new_ctrl=iup.list{size=settings.width,dropdown="yes",multiple="no"}
		end
		prop_ctrl[name.."_"..ctrl_suffix[settings.type]]=new_ctrl
		
		if settings.hint ~= nil
		then
			prop_field:append(label(settings.hint))
		end
		
		if settings.type == "boolean"
		then
			prop_field:append(new_ctrl)
		else
			prop_field:append(label_wrap(settings.title,new_ctrl))
		end
	end
	
	apply_button=iup.button{title="apply"}
	function apply_button:action()
		on_apply()
	end
	cancel_button=iup.button{title="cancel"}
	function cancel_button:action()
		on_cancel()
	end

	edit_dialog=iup.dialog{
	iup.vbox{
		iup.hbox{
			label("property:"),
			prop_list,
			save_button,
			add_button,
			del_button;
			margin="0x10"
		},
		iup.frame{
			prop_field;
			title="properties"
		},
		iup.hbox{
			apply_button,
			cancel_button;
			margin="0x5"
		};margin="10x5"
	}; title="Config",size="QUARTERxHALF"}
	edit_dialog:map()
	fill_ui()
	edit_dialog:popup()
end

function prop_manage_dialog.show_dialog(prop_table,default_prop_table,hint_table)
	
	if prop_table == nil
	then
		props={}
	else
		props=prop_table
	end
	
	default_prop=default_prop_table
	hints=hint_table
	start_ui()
	
	if is_apply
	then
		return props
	else
		return nil
	end
end

return prop_manage_dialog