local utils={}

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
	local top_priority_value=nil
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
		if value == true
		then
			return true
		else
			return false
		end
	end
	
	local tracks={}
	
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

return utils