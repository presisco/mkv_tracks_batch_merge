local iup=require "iuplua"
local prop_dlg=require "prop_manage_dialog"
local cfg_mgr=require "config_manager"
local lfs=require "lfs"
local prg_dlg=require "progress_dialog"
local utils=require "utils"

local list_column_seperator=" -> "

local default_template={
	external_sub_language={
		value="chs,eng,und",
		title="language for external subtitle",
		hint="use ',' to seperate multiple languages,support ISO639-2,'und' for undefined language",
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
	external_audio_language={
		value="chs,eng,und",
		title="language for external audio",
		hint="use ',' to seperate multiple languages,support ISO639-2,'und' for undefined language",
		width="medium",
		type="text"
	},
	external_audio_title={
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
		value="jpn,eng,chi,und",
		title="audio track select priority",
		hint="use ',' to seperate multiple languages,support ISO639-2,'und' for undefined language",
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
		hint="use ',' to seperate multiple languages,support ISO639-2,'und' for undefined language",
		width="large",
		type="text"
	},
	default_subtitle={
		value="first external",
		title="default subtitle track behavior",
		width="medium",
		type="dropdown",
		choice={"first external","auto"}
	},
	default_audio={
		value="first external",
		title="default audio track behavior",
		width="medium",
		type="dropdown",
		choice={"first external","auto"}
	}
}

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
	language=ext_sub_lan_text.value}
]]
local files={}

local current_ext_sub_lan={}
local current_ext_sub_title={}
local current_template={}
local current_audio_priority={}
local current_sub_priority={}
local current_attr_list={
	audio={
		ext_lan={},
		ext_title={},
		priority={},
		default=default_template.default_audio,
		behavior=default_template.audio_track_select_behavior
	},
	subtitles={
		ext_lan={},
		ext_title={},
		priority={},
		default=default_template.default_subtitle,
		behavior=default_template.sub_track_select_behavior
	}
}

local preference={
	mkvmerge_exec_path="",
	output_dir="please select",
	selected_template=1
}

local is_processing=false
local is_scanning_dir=false

-- UI defination

local main_dialog=nil

local file_list=iup.list{expand="yes",multiple="no"}
local track_list=iup.list{expand="yes",multiple="no"}

local template_list=iup.list{size="100x",dropdown="yes",multiple="no"}
local ext_sub_lan_text=iup.text{size="160x",readonly="yes"}
local ext_sub_title_text=iup.text{size="160x",readonly="yes"}
local ext_audio_lan_text=iup.text{size="160x",readonly="yes"}
local ext_audio_title_text=iup.text{size="160x",readonly="yes"}
local audio_track_behavior_text=iup.text{size="60x",readonly="yes"}
local audio_track_priority_text=iup.text{size="160x",readonly="yes"}
local subtitle_track_behavior_text=iup.text{size="60x",readonly="yes"}
local subtitle_track_priority_text=iup.text{size="160x",readonly="yes"}

local config_template_button=iup.button{title="config template"}
local select_mkvmerge_path_button=iup.button{title="select mkvmerge"}

local output_dir_text=iup.text{size="200x",readonly="yes"}
local select_output_dir_button=iup.button{title="select output dir"}

local clear_file_button=iup.button{title="clear all"}
local del_file_button=iup.button{title="delete selected file"}
local del_track_button=iup.button{title="delete selected track"}
local add_file_button=iup.button{title="add videos"}
local add_dir_button=iup.button{title="add directory"}
local add_track_button=iup.button{title="add tracks"}
local add_track_to_selected_button=iup.button{title="add tracks to selected video"}
local process_button=iup.button{title="process"}
local about_button=iup.button{title="about"}

-- utility func

function get_selected_track_id()
	local text=track_list[track_list.value]
	return text:match("id: (.-),")
end

function adjust_tracks_attributes(tracks)
	local helper={}
	local filtered_tracks={}
	local exist_languages={
		audio={},
		subtitles={}
	}
	local language_filters={
		audio="",
		subtitles=""
	}
	
	for name,attr_set in pairs(current_attr_list)
	do
		helper[name]={}
		helper[name]["cursor"]={}
		for attr_name,var in pairs(attr_set)
		do
			if type(var) == "table"
			then
				helper[name]["cursor"][attr_name]=1
			end
		end
		helper[name].has_default=false
		helper[name].internal_default_index=0
	end
	
	for index,track in ipairs(tracks)
	do
		if track.type == "audio" or track.type == "subtitles"
		then
			if current_attr_list[track.type].default == "first external"
			then
				if track.filename ~= nil
				then
					if not helper[track.type].has_default
					then
						track.default="true"
						if helper[track.type].internal_default_index > 0
						then
							tracks[helper[track.type].internal_default_index].default="false"
						end
						helper[track.type].has_default=true
					else
						track.default="false"
					end
				else
					helper[track.type].internal_default_index=index
				end
			else
			end
			
			track.language=current_attr_list[track.type].ext_lan[helper[track.type].cursor.ext_lan]
			track.title=current_attr_list[track.type].ext_title[helper[track.type].cursor.ext_title]
			
			table.insert(exist_languages[track.type],track.language)
			
			for attr_name,var in pairs(helper[track.type].cursor)
			do
				if var < #current_attr_list[track.type][attr_name]
				then
					helper[track.type]["cursor"][attr_name]=var+1
				end
			end
		end
	end
	
	for content_type,filter_text in pairs(language_filters)
	do
		if current_attr_list[content_type].behavior == "first"
		then
			language_filters[content_type]=utils.get_top_priority(exist_languages[content_type],current_attr_list.audio.priority)
		elseif current_attr_list[content_type].behavior == "match"
		then
			language_filters[content_type]=table.concat(current_attr_list.audio.priority,",")
		else
			language_filters[content_type]=table.concat(exist_languages[content_type],",")..",und"
		end
	end
	
	for i,track in ipairs(tracks)
	do
		if language_filters[track.type] == nil 
		then
			table.insert(filtered_tracks,track)
		elseif language_filters[track.type]:match(track.language)
		then
			table.insert(filtered_tracks,track)
		end
	end
	
	return filtered_tracks
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
	local cmd=preference.mkvmerge_exec_path.." -i -F json --ui-language en "..utils.path_wrap(directory..filename)
--	print(cmd)
	local result=io.popen(cmd,"r")
	local json=result:read("*a")
	result:close()
--	print(json)
	if utils.is_valid_file_for_mkv(json)
	then
		file_list.appenditem=filename
		table.insert(files,{dir=directory,name=filename,tracks=utils.parse_mkvmerge_identify(json)})
	end
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

function load_track_list(index)
	local clone_tracks=utils.duplicate_tracks(files[index].tracks)
	
	for i,track in ipairs(adjust_tracks_attributes(clone_tracks))
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
		concat("default")
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
	
	current_attr_list.audio.priority=utils.parse_sequence(current_template.audio_track_language_priority,",")
	current_attr_list.audio.behavior=current_template.audio_track_select_behavior
	current_attr_list.audio.ext_lan=utils.parse_sequence(current_template.external_audio_language,",")
	current_attr_list.audio.ext_title=utils.parse_sequence(current_template.external_audio_title,",")
	current_attr_list.audio.default=current_template.default_audio
	
	current_attr_list.subtitles.priority=utils.parse_sequence(current_template.sub_track_language_priority,",")
	current_attr_list.subtitles.behavior=current_template.sub_track_select_behavior
	current_attr_list.subtitles.ext_lan=utils.parse_sequence(current_template.external_sub_language,",")
	current_attr_list.subtitles.ext_title=utils.parse_sequence(current_template.external_sub_title,",")
	current_attr_list.subtitles.default=current_template.default_subtitle
	
	ext_sub_lan_text.value=current_template.external_sub_language
	ext_sub_title_text.value=current_template.external_sub_title
	ext_audio_lan_text.value=current_template.external_audio_language
	ext_audio_title_text.value=current_template.external_audio_title
	audio_track_behavior_text.value=current_template.audio_track_select_behavior
	audio_track_priority_text.value=current_template.audio_track_language_priority
	subtitle_track_behavior_text.value=current_template.sub_track_select_behavior
	subtitle_track_priority_text.value=current_template.sub_track_language_priority
	reload_track_list()
end

function set_output_dir(dir)
	preference.output_dir=dir
	output_dir_text.value=dir
end

function remove_file(index)
	file_list.removeitem=index
	track_list.removeitem="all"
	table.remove(files,index)
end

function remove_track(file_index,track_index)
	utils.remove_track_by_id(files[file_index].tracks,get_selected_track_id())
	track_list.removeitem=track_index
	reload_track_list()
end

function init_template_dropdown()
	fill_dropdown(template_list,templates)
	template_selected(1)
end

function scan_dir(root_dir)
	if is_scanning_dir
	then
		iup.Message("Error","now scanning dir! please wait!")
		return
	end

	is_scanning_dir=true
	local progress_dialog=prg_dlg.get_dialog(0,1,"scanning")
	local on_update=function(text)
		prg_dlg.update(progress_dialog,0,text)
	end
	progress_dialog:show()
	
	local new_files=utils.build_file_list(preference.mkvmerge_exec_path,root_dir,on_update)
	for index,file in ipairs(new_files)
	do
		file_list.appenditem=file.name
		table.insert(files,file)
	end
	progress_dialog:hide()
	reload_track_list()
	is_scanning_dir=false
end

function process_list()
	is_processing=true
	local progress_dialog=prg_dlg.get_dialog(0,#files,"loading")
	progress_dialog:show()
	
	local external_sub_languages=utils.parse_sequence(current_template.external_sub_language,",")
	
	for var,file in ipairs(files)
	do
		prg_dlg.update(progress_dialog,var,file.name)
		local filepath=file.dir.."\\"..file.name
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
		
		local clone_tracks=utils.duplicate_tracks(file.tracks)
		
		for index,track in ipairs(adjust_tracks_attributes(clone_tracks))
		do
			local track_filepath=""
			if track.filename == nil
			then
				track_filepath=filepath
			else
				track_filepath=track.dir.."\\"..track.filename
			end
			
			if cmd_list.input[track_filepath] == nil
			then
				cmd_list.input[track_filepath] = {[" "]={""}}
			end
			
			if track.type == "Chapters"
			then
				concat_to_final(track_filepath,"--chapters")
			elseif track.type == "Info"
			then
				concat_to_final(track_filepath,"--segmentinfo")
			elseif track.type == "Tags"
			then
				concat_to_final(track_filepath,"--global-tags")
			else
				if track.language ~= "und"
				then
					concat_to_final(track_filepath,
					"--language "..track.id..":"..track.language)
				end
					
				if track.title ~= nil and track.title ~= "" 
				then
					concat_to_final(track_filepath,
						"--track-name "..track.id..":"..track.title)
				end
			
				if track.default == "true"
				then
					concat_to_final(track_filepath,
						"--default-track "..track.id)
				end
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
				if option ~= " "
				then
					final_cmd=final_cmd..option.." "..table.concat(values,",").." "
				else
					final_cmd=final_cmd..option.." "..table.concat(values," ").." "
				end
			end
			final_cmd=final_cmd.." "..utils.path_wrap(filepath).." "
		end
		
		print("-------------")
		print(final_cmd)
		print("+++++++++++++")
		local result=io.popen(final_cmd,"r")
		local cmd_output=result:read("*l")
		while cmd_output ~= nil
		do
			print(cmd_output)
			cmd_output=result:read("*l")
		end
		result:close()
	end
	is_processing=false
	progress_dialog:hide()
	clear_file_button:action()
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
		
		local progress_dialog=prg_dlg.get_dialog(0,#new_files,"")
		progress_dialog:show()
		for i=1,#new_files
		do
			prg_dlg.update(progress_dialog,i,new_files[i])
			add_file(directory,new_files[i])
		end
		progress_dialog:hide()
	end
	
end

function add_dir_button:action()
	local add_dir_dialog=iup.filedlg{multiplefiles="yes",dialogtype="dir"}
	add_dir_dialog:popup()
	local status=add_dir_dialog.status
	
	if status == "0"
	then
		scan_task=coroutine.create(scan_dir)
		coroutine.resume(scan_task,add_dir_dialog.value)
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
			
			local cmd=preference.mkvmerge_exec_path.." -i -F json --ui-language en "..utils.path_wrap(directory..filename)
--			print(cmd)
			local result=io.popen(cmd,"r")
			local json=result:read("*a")
			
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
	
	if is_processing
	then
		iup.Message("Error","already processing! please wait!")
		return
	end
	
	process_task=coroutine.create(process_list)
	coroutine.resume(process_task)
end

function about_button:action()
	about_dialog=iup.dialog{
		iup.vbox{
			iup.label{title="Author: presisco"},
			iup.hbox{
				label("Project Site: "),
				iup.text{size="200x",value="https://github.com/presisco/mkv_tracks_batch_merge",readonly="yes"}
			};
			margin="20x20"
		};
		title="about",size="QUARTERxQUARTER",shrink="yes"
	}
	about_dialog:show()
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
			template_list;
			margin="0x5"
		},
		iup.hbox{
			label("external subtitle languages"),
			ext_sub_lan_text,
			label("external subtitle titles"),
			ext_sub_title_text;
			margin="0x5"
		},
		iup.hbox{
			label("external audio languages"),
			ext_audio_lan_text,
			label("external audio titles"),
			ext_audio_title_text;
			margin="0x5"
		},
		iup.hbox{
			label("audio track selection behavior"),
			audio_track_behavior_text,
			label("audio track priority"),
			audio_track_priority_text;
			margin="0x5"
		},
		iup.hbox{
			label("subtitle track selection behavior"),
			subtitle_track_behavior_text,
			label("subtitle track priority"),
			subtitle_track_priority_text;
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
			add_dir_button,
			add_track_button,
			add_track_to_selected_button,
			del_file_button,
			clear_file_button,
			del_track_button,
			process_button,
			about_button;
			margin="0x5"
		};margin="10x10"
	}; title="MKV tracks batch merge",size="HALFxHALF"}
	
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
