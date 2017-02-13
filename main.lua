local iup=require "iuplua"
local prop_dlg=require "prop_manage_dialog"
local cfg_mgr=require "config_manager"
local lfs=require "lfs"
local prg_dlg=require "progress_dialog"
local utils=require "utils"

local list_column_seperator=" -> "

-- Dataset

local templates={}
--[[
{
	dir=directory,
	name=filename,
	tracks={}
}
{
	dir=directory,
	name=new_files[i],
	language=track_languange_text.value}
]]
local files={}

local current_ext_sub_lan={}
local current_ext_sub_title={}
local current_template={}
local current_audio_priority={}
local current_sub_priority={}

local default_template={
	external_sub_language={
		value="none",
		title="language for external subtitle",
		hint="use ',' to seperate multiple languages,support ISO639-2",
		width="medium",
		type="text"
	},
	external_sub_title={
		value="default",
		title="title for external subtitle",
		hint="use ',' to seperate multiple titles",
		width="medium",
		type="text"
	},
	audio_track_select_behavior={
		value="all",
		title="audio track select behavior",
		width="large",
		type="dropdown",
		choice={"all","match","first","none"}
	},
	audio_track_language_priority={
		value="",
		title="audio track select priority",
		hint="use ',' to seperate multiple languages,support ISO639-2",
		width="large",
		type="text"
	},
	sub_track_select_behavior={
		value="all",
		title="subttile track select behavior",
		width="large",
		type="dropdown",
		choice={"all","match","first","none"}
	},
	sub_track_language_priority={
		value="",
		title="subtitle track select priority",
		hint="use ',' to seperate multiple languages,support ISO639-2",
		width="large",
		type="text"
	}
}

local preference={
	mkvmerge_exec_path="",
	output_dir="please select",
	selected_template=1
}

-- UI defination

local main_dialog=nil

local file_list=iup.list{expand="yes",multiple="no"}
local track_list=iup.list{expand="yes",multiple="no"}

local template_list=iup.list{size="100x",dropdown="yes",multiple="no"}
local track_languange_text=iup.text{size="160x",readonly="yes"}
local sub_title_text=iup.text{size="160x",readonly="yes"}

local config_template_button=iup.button{title="config template"}
local select_mkvmerge_path_button=iup.button{title="select mkvmerge"}

local output_dir_text=iup.text{size="200x",readonly="yes"}
local select_output_dir_button=iup.button{title="select output dir"}

local clear_file_button=iup.button{title="clear all"}
local del_file_button=iup.button{title="delete selected file"}
local del_track_button=iup.button{title="delete selected track"}
local add_file_button=iup.button{title="add videos"}
local add_track_button=iup.button{title="add tracks"}
local add_track_to_selected_button=iup.button{title="add tracks to selected video"}
local process_button=iup.button{title="process"}

-- utility func

function assign_external_track_language(tracks)
	local lan_index=1;
	local title_index=1;
	
	for var,track in ipairs(tracks)
	do
		if track.filename ~= nil and track.type == "subtitles"
		then
			track.language=current_ext_sub_lan[lan_index]
			track.title=current_ext_sub_title[title_index]
			if lan_index < #current_ext_sub_lan
			then
				lan_index=lan_index+1
			end
			if title_index < #current_ext_sub_title
			then
				title_index=title_index+1
			end
		end
	end
end

function get_track_list(filepath)
	local cmd=preference.mkvmerge_exec_path.." -i -F json --ui-language en "..utils.path_wrap(filepath)
--	print(cmd)
	local result=io.popen(cmd,"r")
	local json=result:read("*a")
	json=json:gsub("\n","")
	json=json:gsub(" ","")
	return utils.parse_mkvmerge_identify(json)
end

function fill_dropdown(list,data_table)
	for name,props in pairs(data_table)
	do
		list.appenditem=name
	end
	list.value=1
end

function label(text)
	return iup.label{title=text;padding="5x0"}
end

function add_file(directory,filename)
	file_list.appenditem=filename
	table.insert(files,{dir=directory,name=filename,tracks=get_track_list(directory..filename)})
end

function used_languages(type,tracks)
	local language_list={}
	for i,track in ipairs(tracks)
	do
		if track.type == type and track.language ~= nil
		then
			table.insert(language_list,track.language)
		end
	end
	return language_list
end

function get_valid_tracks(tracks)
	local used_audio_languages=used_languages("audio",tracks)
	local used_subtitle_languages=used_languages("subtitles",tracks)
	
	local audio_language=""
	if current_template.audio_track_select_behavior == "first"
	then
		audio_language=utils.get_top_priority(used_audio_languages,current_audio_priority)
	elseif current_template.audio_track_select_behavior == "match"
	then
		audio_language=table.concat(current_audio_priority,",")
	elseif current_template.audio_track_select_behavior == "all"
	then
		audio_language=table.concat(used_audio_languages,",")..",none"
	end
	
	local subtitle_language=""
	if current_template.sub_track_select_behavior == "first"
	then
		subtitle_language=utils.get_top_priority(used_subtitle_languages,current_sub_priority)
	elseif current_template.sub_track_select_behavior == "match"
	then
		subtitle_language=table.concat(current_sub_priority,",")
	elseif current_template.sub_track_select_behavior == "all"
	then
		subtitle_language=table.concat(used_subtitle_languages,",")..",none"
	end
	
	local valid={}
	for i,track in ipairs(tracks)
	do
		if track.type == "audio" and audio_language:match(track.language) == nil 
		then
			
		elseif track.type == "subtitles" and subtitle_language:match(track.language) == nil
		then
			
		else
			table.insert(valid,track)
		end
	end
	
	return valid
end

function load_track_list(index)
	assign_external_track_language(files[index].tracks)
	
	for i,track in ipairs(get_valid_tracks(files[index].tracks))
	do
		local list_text={}
		local concat=function(name)
			if track[name] ~= nil
			then
				table.insert(list_text,name..": "..track[name])
			end
		end
		concat("filename")
		concat("id")
		concat("type")
		concat("codec")
		concat("language")
		concat("title")
		track_list.appenditem=table.concat(list_text,", ")
	end
end

function reload_track_list()
	track_list.removeitem="all"
	if tonumber(file_list.count) > 0
	then
		if tonumber(file_list.value) > 0
		then
			load_track_list(tonumber(file_list.value))
		end
	end
end

function template_selected(index)
	preference.selected_template=index
	current_template=templates[template_list[index]]
	current_audio_priority=utils.parse_sequence(current_template.audio_track_language_priority,",")
	current_sub_priority=utils.parse_sequence(current_template.sub_track_language_priority,",")
	current_ext_sub_lan=utils.parse_sequence(current_template.external_sub_language,",")
	current_ext_sub_title=utils.parse_sequence(current_template.external_sub_title,",")
	track_languange_text.value=current_template.external_sub_language
	sub_title_text.value=current_template.external_sub_title
	reload_track_list()
end

function set_output_dir(dir)
	preference.output_dir=dir
	output_dir_text.value=dir
end

function remove_file(index)
	file_list.removeitem=index
	table.remove(files,index)
end

function remove_track(file_index,track_index)
	track_list.removeitem=track_index
	table.remove(files[file_index].tracks,track_index)
	reload_track_list()
end

function init_template_dropdown()
	fill_dropdown(template_list,templates)
	template_selected(1)
end

-- callback func

function config_template_button:action()
	local result=prop_dlg.show_dialog(templates,default_template)
	if result ~= nil
	then 
		templates=result
		template_list.removeitem="all"
		init_template_dropdown()
		cfg_mgr.save_props("templates.conf",templates)
	end
end

function select_mkvmerge_path_button:action()
	add_file_dialog=iup.filedlg{multiplefiles="no",dialogtype="open"}
	add_file_dialog:popup()
	status=add_file_dialog.status
	
	if status == "0"
	then
		preference.mkvmerge_exec_path=add_file_dialog.value
	end
end

function select_output_dir_button:action()
	add_dir_dialog=iup.filedlg{multiplefiles="yes",dialogtype="dir"}
	add_dir_dialog:popup()
	status=add_dir_dialog.status
	
	if status == "0"
	then
		preference.output_dir=add_dir_dialog.value.."\\"
		output_dir_text.value=preference.output_dir
	end
end

function add_file_button:action()
	add_file_dialog=iup.filedlg{multiplefiles="yes",dialogtype="open"}
	add_file_dialog:popup()
	status=add_file_dialog.status
	
	if status == "0"
	then
		directory,new_files=utils.parse_filedlg_value(add_file_dialog.value)
		
		prg_dlg.show_dialog(0,#new_files,"")
		for i=1,#new_files
		do
			prg_dlg.update(i,new_files[i])
			add_file(directory,new_files[i])
		end
		prg_dlg.hide_dialog()
	end
	
end

function add_track_button:action()
	if #files == 0
	then
		iup.Message("Warning","no video selected,please add video first!")
		return
	end
	
	add_file_dialog=iup.filedlg{multiplefiles="yes",dialogtype="open"}
	add_file_dialog:popup()
	status=add_file_dialog.status
	
	if status == "0"
	then
		directory,new_files=utils.parse_filedlg_value(add_file_dialog.value)
		local track_per_file=math.ceil(#new_files/#files)
		local file_index=1
		for i=1,#new_files
		do
			local tracks_info=get_track_list(directory..new_files[i])
			
			for var,track_info in ipairs(tracks_info)
			do
				track_info.dir=directory
				track_info.filename=new_files[i]
				table.insert(files[file_index].tracks,track_info)
			end
			
			if i%track_per_file == 0
			then
				file_index=file_index+1
			end
		end
	end
	
	reload_track_list()
end

function add_track_to_selected_button:action()
	if #files == 0 or tonumber(file_list.value) == 0
	then
		iup.Message("Warning","no video selected,please add video first!")
		return
	end
	
	add_file_dialog=iup.filedlg{multiplefiles="yes",dialogtype="open"}
	add_file_dialog:popup()
	status=add_file_dialog.status
	
	if status == "0"
	then
		directory,new_files=utils.parse_filedlg_value(add_file_dialog.value)
		local track_per_file=math.ceil(#new_files/#files)
		for i=1,#new_files
		do
			local tracks_info=get_track_list(directory..new_files[i])
			
			for var,track_info in ipairs(tracks_info)
			do
				track_info.dir=directory
				track_info.filename=new_files[i]
				table.insert(files[tonumber(file_list.value)].tracks,track_info)
			end
		end
	end
	
	reload_track_list()
end

function del_file_button:action()
	remove_file(tonumber(file_list.value))
end

function del_track_button:action()
	remove_track(tonumber(file_list.value),tonumber(track_list.value))
end

function clear_file_button:action()
	file_list.removeitem="all"
	utils.clear_table(files)
	track_list.removeitem="all"
end

function process_button:action()
	msg,err=lfs.attributes(preference.mkvmerge_exec_path)
	if msg == nil
	then
		iup.Message("Error","no valid mkvmerge selected!")
		return
	end
	
	if preference.output_dir == "please select"
	then
		iup.Message("Error","don't have output directory!")
		return
	end
	
	prg_dlg.show_dialog(0,#files,"")
	
	local external_sub_languages=utils.parse_sequence(current_template.external_sub_language,",")
	
	for var,file in ipairs(files)
	do
		prg_dlg.update(var,file.name)
		local filepath=file.dir..file.name
		local cmd_list={
			output={preference.mkvmerge_exec_path,
				"-o",
				utils.path_wrap(
					preference.output_dir
					..utils.rename_to_mkv(file.name))},
			input={},
		}
		
		local append=function(filepath,option,value)
			if cmd_list.input[filepath][option] == nil
			then
				cmd_list.input[filepath][option] = { }
			end
			table.insert(cmd_list.input[filepath][option],value)
		end
		
		local concat_to_final=function(filepath,value)
			cmd_list.input[filepath][" "][1]
				=cmd_list.input[filepath][" "][1]
					..value.." "
		end
		
		assign_external_track_language(file.tracks)
		for index,track in ipairs(get_valid_tracks(file.tracks))
		do
			local track_filepath=""
			if track.filename == nil
			then
				track_filepath=filepath
			else
				track_filepath=track.dir..track.filename
			end
			
			if cmd_list.input[track_filepath] == nil
			then
				cmd_list.input[track_filepath] = {[" "]={""}}
			end
			
			if track.language ~= "none"
			then
				concat_to_final(track_filepath,
					"--language "..track.id..":"..track.language)
			end
				
			if track.title ~= nil
			then
				concat_to_final(track_filepath,
					"--track-name "..track.id..":"..track.title)
			end
			
			if track.type == "audio"
			then
				append(track_filepath,"--audio-tracks",track.id)
			elseif track.type == "subtitles"
			then
				append(track_filepath,"--subtitle-tracks",track.id)
			elseif track.type == "video"
			then
				append(track_filepath,"--video-tracks",track.id)
			elseif track.type == "button"
			then
				append(track_filepath,"--button-tracks",track.id)
			end
		end
		
		local final_cmd=table.concat(cmd_list.output," ").." "
		for filepath,options in pairs(cmd_list.input)
		do
			for option,values in pairs(options)
			do
				final_cmd=final_cmd..option.." "..table.concat(values)
			end
			final_cmd=final_cmd.." "..utils.path_wrap(filepath).." "
		end
		
		print(final_cmd)
	end
	prg_dlg.hide_dialog()
end

function template_list:action(text,item,state)
	if state == 1
	then
		template_selected(item)
	end
end

function file_list:action(text,item,state)
	if state == 1
	then
		reload_track_list()
	end
end

-- program life

function prepare_data()
	templates=cfg_mgr.load_props("templates.conf")
	preference=cfg_mgr.load_props("preference.conf",preference)
end

function prepare_ui()
	while cfg_mgr.is_empty_table(templates)
	do
		config_template_button:action()
	end

	main_dialog = iup.dialog{
	iup.vbox{
		iup.hbox{
			label("template:"),
			template_list,
			label("subtitle languages"),
			track_languange_text,
			label("subtitle titles"),
			sub_title_text;
			margin="0x5"
		},
		iup.hbox{
			config_template_button,
			select_mkvmerge_path_button;
			margin="0x5"
		},
		iup.hbox{
			iup.vbox{label("files:"),file_list},
			iup.vbox{label("tracks:"),track_list};
			margin="0x5"
		},
		iup.hbox{
			label("output dir:"),
			output_dir_text,
			select_output_dir_button;
			margin="0x5"
		};
		iup.hbox{
			add_file_button,
			add_track_button,
			add_track_to_selected_button,
			del_file_button,
			clear_file_button,
			del_track_button,
			process_button;
			margin="0x5"
		};margin="10x10"
	}; title="Video Name Formatter",size="HALFxHALF"}
	
	main_dialog:map()

	init_template_dropdown()
	output_dir_text.value=preference.output_dir
	
	main_dialog:show()
	
	function main_dialog:close_cb()
		cfg_mgr.save_props("preference.conf",preference)
	end
end

local function main()
	prepare_data()
	prepare_ui()
	iup.MainLoop()
end

main()
