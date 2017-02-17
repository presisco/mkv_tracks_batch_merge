local lfs=require "lfs"

local utils={}

local supported_content_type_set={
	video=true,
	audio=true,
	subtitles=true,
	buttons=true,
	Chapters=true,
	Tags=true,
	Info=true
}

function utils.get_xml_type(xml_string)
	return xml_string:match("<(%a+)>")
end

function utils.is_valid_xml_file(xml_string)
	local root_element=utils.get_xml_type(xml_string)
	if root_element == "Chapters" 
		or root_element == "Tags" 
		or root_element == "Info"
	then
		return true
	else
		return false
	end
end

function utils.get_content_summary(filepath)
	local cmd=preference.mkvmerge_exec_path.." -i -F json --ui-language en "..utils.path_wrap(filepath)
--	print(cmd)
	local result=io.popen(cmd,"r")
	local json=result:read("*a")
	result:close()
--	print(json)
	if utils.is_valid_file_for_mkv(json)
	then
		return utils.parse_mkvmerge_identify(json)
	else
		local file_stream=io.open(filepath,"r")
		local file_string=file_stream:read("*a")
		if utils.is_valid_file_for_mkv(file_string)
		then
			return utils.get_xml_type(file_string)
		else
			return "unknown"
		end
	end
end

function utils.build_file_list(root_dir,on_update)
	local raw_file_list={}
	local ext_file_list={
		audio={},
		subtitles={},
		Chatpers={},
		Tags={},
		Info={}
	}
	
	local file_contains_video=function(tracks)
		for i=1,#tracks
		do
			if tracks[i].type == "video"
			then
				return true
			end
		end
		return false
	end
	
	local file_scanner=function(dir)
		for file in lfs.dir(root_dir)
		do
			if file ~= "." and file ~= ".."
			then
				local filepath=root_dir.."\\"..file
				if lfs.attributes(filepath) ~= "directory"
				then
					if on_update ~= nil
					then
						on_update(filepath)
					end
					local props=utils.get_content_summary(filepath)
					if type(props) == "table"
					then
						if file_contains_video(props)
						then
							table.insert(raw_file_list,{dir=root_dir,name=file,tracks=props})
						else
							table.insert(ext_file_list[props[1].type],{dir=root_dir,filename=file,tracks=props})
						end
					elseif props ~= "unknown"
					then
						table.insert(ext_file_list[props[1].type],{dir=root_dir,filename=file,tracks={{type=props}}})
					end
				else
					file_scanner(filepath)
				end
			end
		end
	end
	
	local file_cursor={}
	local file_per_video={}
	for type,var in pairs(ext_file_list)
	do
		file_per_video[type]=math.ceil(#ext_file_list[type]/#raw_file_list)
		file_cursor[type]=1
	end
	
	for index,video_file in ipairs(raw_file_list)
	do
		for type,list in pairs{ext_file_list}
		do
			for i=1,file_per_video[type]
			do
				local ext_file=list[file_cursor[type]]
				for j,track in ext_file.tracks
				do	
					track.dir=ext_file.dir
					track.filename=ext_file.filename
					table.insert(video_file.tracks,track)
				end
				file_cursor[type]=file_cursor[type]+1
			end
		end
	end
	
	return raw_file_list
end

function utils.remove_track_by_id(tracks,target_id)
	for index,props in ipairs(tracks)
	do
		if props.id == target_id
		then
			table.remove(tracks,index)
			return
		end
	end
end

function utils.duplicate_tracks(tracks)
	local clone={}
	
	for index,props in ipairs(tracks)
	do
		local clone_props={}
		for name,value in pairs(props)
		do
			clone_props[name]=value
		end
		table.insert(clone,clone_props)
	end
	
	return clone
end

function utils.get_file_extension(filename)
	local reversed=filename:reverse()
	local ext_index=reversed:find(".",1,true)
	if ext_index == nil
	then
		return ""
	else
		return filename:sub(filename:len()+2-ext_index,filename:len())
	end
end

function utils.rename_to_mkv(filepath)
	local reversed=filepath:reverse()
	local ext_index=reversed:find(".",1,true)
	return filepath:sub(1,filepath:len()-ext_index)..".mkv"
end

function utils.print_tracks(tracks)
	print("----------")
	local p=function(index,name)
		if tracks[index][name] ~= nil
		then
			print(name..": "..tracks[index][name])
		end
	end
	
	for i=1,#tracks
	do
		p(i,"dir")
		p(i,"filename")
		p(i,"id")
		p(i,"codec")
		p(i,"type")
		p(i,"language")
		p(i,"title")
	end
end

function utils.get_top_priority(dataset,priority)
	local top_priority=#priority+1
	local top_priority_value=""
	for i=1,#dataset
	do
		local current_priority=#priority+1
		for j=1,#priority
		do
			if dataset[i] == priority[j]
			then
				current_priority=j
				break
			end
		end
		if current_priority < top_priority
		then
			top_priority = current_priority
			top_priority_value=dataset[i]
		end
	end
	return top_priority_value
end

function utils.path_wrap(path)
	return "\""..path.."\""
end

function utils.is_valid_file_for_mkv(json_string)
	if json_string:match("\"recognized\": true") ~= nil
		and json_string:match("\"recognized\": true") ~= nil
	then
		return true
	else
		return false
	end
end

function utils.parse_mkvmerge_identify(json_string)
	local get_string_value=function(json_string,name)
		local value=json_string:match("\""..name.."\":\"(.-)\"")
		if value == nil
		then
			value="none"
		end	
		--print("name:"..name..",value:"..value)
		return value
	end
	
	local get_string_value_nil=function(json_string,name)
		local value=json_string:match("\""..name.."\":\"(.-)\"")
		return value
	end
	
	local get_dec_value=function(json_string,name)
		local value=json_string:match("\""..name.."\":(.-),")
		--print("name:"..name..",value:"..value)
		return value
	end
	
	local get_bool_value=function(json_string,name)
		local value=json_string:match("\""..name.."\":(.-),")
		if value == nil
		then
			return "true"
		else
			return value
		end
	end
	
	local tracks={}
	
	json_string=json_string:gsub("\n","")
	json_string=json_string:gsub(" ","")
	
	json_string=json_string:match("\"tracks\":%[(.*)%]")
	json_string="@"..json_string:gsub("%],\"warnings\":%[","").."/"
	json_string=json_string:gsub("},{","}/@{")
--	print(json_string)
	for track_json in json_string:gmatch("@{(.-)}/")
	do
--		print(track_json)
		local track={}
		local properties_json=track_json:match("{(.*)}")
--		print(properties_json)
		track.codec=get_string_value(track_json,"codec")
		track.id=get_dec_value(track_json,"id")
		track.type=get_string_value(track_json,"type")
		track.language=get_string_value(properties_json,"language")
		track.title=get_string_value_nil(properties_json,"track_name")
		track.default=get_bool_value(properties_json,"default_track")
		table.insert(tracks,track)
	end
	return tracks
end

function utils.parse_sequence(text,seperator)
	if text == nil
	then
		return {}
	end
	
	local result={}
	
	local pivot=text:find(seperator)
	while pivot ~= nil
	do
		table.insert(result,text:sub(1,pivot-1))
		if pivot < text:len()
		then
			text=text:sub(pivot+1,text:len())
		else
			text=""
		end
		pivot=text:find(seperator)
	end
	table.insert(result,text)
	return result;
end

function utils.get_filename_from_path(filepath)
	local filename=filepath:gsub("(.*)\\","")
	return filename
end

function utils.parse_filedlg_value(value)
	local filenames={}
	local dir=""
	local index=value:find("|")
	local next=0
	local length=value:len()
	if index == nil
	then
		table.insert(filenames,utils.get_filename_from_path(value))
		dir=value:match("(.*)\\").."\\"
	else
		index=index+1
		while index < length-1
		do
			next=value:find("|",index)
			table.insert(filenames,value:sub(index,next-1))
			index=next+1
		end
		dir=value:match("(.-)|").."\\"
	end
	return dir,filenames
end

function utils.clear_table(data_table)
	for key,value in pairs(data_table)
	do
		data_table[key]=nil
	end
end

function utils.parse_list_value(value)
	local selected_index={}
	local selected_sign="+"
	
	local sign_dex=selected_sign:byte(1)
	for i=1,value:len()
	do
		if value:byte(i) == sign_dex
		then
			table.insert(selected_index,i)
		end
	end
	
	return selected_index
end

function utils.set_insert(set,value)
	if type(value) == "table"
	then
		for element,var in pairs(value)
		do
			set[element]=true
		end
	else
		set[value]=true
	end
end

function utils.set_contains(set,value)
	if set[value] ~= nil
	then
		return true
	else
		return false
	end
end

function utils.set_remove(set,value)
	set[value]=nil
end

return utils