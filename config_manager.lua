local config_manager={}

local log_type_wrap={
  ["unknown"]={"?","?"},
  ["string"]={"\"","\""},
  ["number"]={"(",")"},
  ["boolean"]={"[","]"},
  ["table"]={"{","}"}
}
local log_depth_blank="\t"
local log_kv_seperator="="

function config_manager.is_empty_table(data_table)
	local pair_count=0
	for k,v in pairs(data_table)
	do
		pair_count=pair_count+1
	end
	if pair_count > 0
	then
		return false
	else
		return true
	end
end

local text2bool=function(text)
  if text == "true"
  then
    return true
  else
    return false
  end
end

local bool2text=function(bool)
  if bool
  then
    return "true"
  else
    return "false"
  end
end

function config_manager.print_table_itr(file,depth,table)
  kv_sp=log_kv_seperator
  t_wrap=log_type_wrap
  get_blanks=function(depth)
    return log_depth_blank:rep(depth)
  end
  for k,v in pairs(table)
  do
    local value_type=type(v)
    local key_type=type(k)
    local key=nil

    if key_type=="boolean"
    then
      key=bool2text(k)
    else
      key=k
    end

    if value_type == "table"
    then
      file:write(get_blanks(depth)..t_wrap[key_type][1]..key..t_wrap[key_type][2]
        ..kv_sp..t_wrap[value_type][1].."\n")
      config_manager.print_table_itr(file,depth+1,v)
      file:write(get_blanks(depth)..t_wrap[value_type][2].."\n")
    else
      local value=nil
      if value_type == "boolean"
      then
        value=bool2text(v)
      elseif value_type == "string"
      then
        value=v:gsub("\n"," ")
        value=value:gsub("\r"," ")
      else
        value=v
      end

      file:write(get_blanks(depth)..t_wrap[key_type][1]..key..t_wrap[key_type][2]
        ..kv_sp..t_wrap[value_type][1]..value..t_wrap[value_type][2].."\n")
    end
  end
end

function config_manager.read_table_itr(lines,index)
	local i=index
  kv_sp=log_kv_seperator
  t_wrap=log_type_wrap
  local pref_table={}
  local force_break=false
  while i < #lines and not force_break
  do
    line=lines[i]:gsub(log_depth_blank,"")
    if line == t_wrap["table"][2]
    then
--	  print("picked table end!@"..i)
      force_break=true
    else
      local midground=line:find(kv_sp)
      local key=line:sub(2,midground-2)
      local value=line:sub(midground+2,line:len()-1)
      local k_header=line:sub(1,1)
      local v_header=line:sub(midground+1,midground+1)

      if k_header == t_wrap["number"][1]
      then
        key=tonumber(key)
      elseif k_header == t_wrap["boolean"][1]
      then
        key=text2bool(key)
      end

      if v_header == t_wrap["string"][1]
      then
      elseif v_header == t_wrap["number"][1]
      then
        value=tonumber(value)
      elseif v_header == t_wrap["boolean"][1]
      then
        value=text2bool(value)
      else
        value,i=config_manager.read_table_itr(lines,i+1)
      end
	  
      pref_table[key]=value
      i=i+1
    end
  end
  return pref_table,i
end

function config_manager.fill_empty(dst,src)
	if dst == nil 
		or src == nil 
		or type(dst) ~= "table" 
		or type(src) ~= "table"
	then
		return
	end
	
	for key,value in pairs(src)
	do
		if dst[key] == nil
		then
			dst[key]=value
		end
	end
end

function config_manager.load_props(filename,defaults)
  
  pref_file,err_msg=io.open(filename,"r")
  if pref_file == nil
  then
    if err_msg:find("No such file or directory") ~= nil
    then
      createfile=io.open(filename,"w")
      createfile:close()
      pref_file,err_msg=io.open(filename,"r")
    end
    if pref_file == nil
    then
      print("open failed:"..err_msg)
      return nil,err_msg
    end
  end

  local lines={}

  for line in pref_file:lines()
  do
    table.insert(lines,line)
  end

  pref_file:close()
  
  local pref_table=config_manager.read_table_itr(lines,1)
	
  if config_manager.is_empty_table(pref_table)
  then
    pref_table={}
  end
  
  config_manager.fill_empty(pref_table,defaults)
  
  return pref_table
end

function config_manager.save_props(filename,props)
  pref_file,err_msg=io.open(filename,"w")
  
  config_manager.print_table_itr(pref_file,0,props)
	
  pref_file:write("end of file!\n")
  pref_file:flush()
  pref_file:close()
end

return config_manager