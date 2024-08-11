--[[
OBJ to MAT converter by Dice

This converter only supports triangle meshes!
Lua 5.4 must be installed to run this tool.
]]

local attributes={
	META = string.char(0x00),
	NAME = string.char(0x10),
	VERT = string.char(0x22),
	NORM = string.char(0x32),
	TEXT = string.char(0x41),
	FACE = string.char(0x58),
	BIND = string.char(0x60),
	POSE = string.char(0x7F)
}

local function encode_uint(value,wordsize)
	local binary=""

	for i=1,wordsize do
		binary=string.char(value&0xFF)..binary
		value=value>>8
	end

	return binary
end

local function encode_fixed(value,integer,fraction)
	value = value+(1<<(integer*8))/2
	value = value*(1<<(fraction*8))

	return encode_uint(
		math.floor(value),
		integer+fraction
	)
end

local function append_vector3(list,x,y,z)
	x = x or 0
	y = y or 0
	z = z or 0

	for i=1,#list,3 do
		if list[i]==x and list[i+1]==y and list[i+2]==z then
			return (i-1)/3
		end
	end

	list[#list+1] = x
	list[#list+1] = y
	list[#list+1] = z

	return (#list-3)/3
end

local function append_vector2(list,x,y)
	x = x or 0
	y = y or 0

	for i=1,#list,2 do
		if list[i]==x and list[i+1]==y then
			return (i-1)/2
		end
	end

	list[#list+1] = x
	list[#list+1] = y

	return (#list-2)/2
end

local function fixed_type(list)
	local max_integer = 0
	local integer     = 0
	local fraction    = 0

	for _,v in ipairs(list) do
		local i=math.floor(math.abs(v))

		max_integer=math.max(i,max_integer)

		if math.abs(v)-i>0 then
			fraction = 2
		end
	end

	repeat
		integer=integer+1
	until 2^(integer*8)>max_integer<<1

	return integer,fraction
end

local function import_obj(obj_data)
	local vertices = {}
	local normals  = {}
	local textures = {}
	local groups   = {}

	for line in (obj_data.."\n"):gmatch("(.-)\n") do
		local tokens={}

		for word in line:gmatch("%S+") do
			tokens[#tokens+1]=tonumber(word:lower()) or word
		end

		if tokens[1]=="o" then

		elseif tokens[1]=="v" then
			for i=2,#tokens do
				vertices[#vertices+1]=tokens[i]
			end
		elseif tokens[1]=="vn" then
			for i=2,#tokens do
				normals[#normals+1]=tokens[i]
			end
		elseif tokens[1]=="vt" then
			textures[#textures+1]=tokens[2]
			textures[#textures+1]=1-tokens[3]
		elseif tokens[1]=="f" then
			if #groups==0 then
				groups[#groups+1]={name=tostring(#groups)}
			end

			local faces=groups[#groups]

			for i=2,#tokens do
				local v,vn,vt
				
				for n in tokens[i]:gmatch("([^/]+)") do
					if not v then
						v=tonumber(n)
					elseif not vt then
						vt=tonumber(n)
					elseif not vn then
						vn=tonumber(n)
					end
				end

				faces[#faces+1] = (v or 1)-1
				faces[#faces+1] = (vn or 1)-1
				faces[#faces+1] = (vt or 1)-1
			end
		elseif tokens[1]=="usemtl" then
			groups[#groups+1]={name=tokens[2]}
		end
	end

	return {
		vertices  = vertices,
		normals   = normals,
		textures  = textures,
		groups    = groups
	}
end

local function export_mat(model,precision,export_name)
	local name_data = {}
	local vert_data = {}
	local norm_data = {}
	local text_data = {}
	local face_data = {}

	for _,faces in ipairs(model.groups) do
		local vertices = {}
		local normals  = {}
		local textures = {}

		if export_name then
			name_data[#name_data+1] = attributes.NAME
			name_data[#name_data+1] = string.char(0x00)
			name_data[#name_data+1] = encode_uint(#faces.name,4)
			name_data[#name_data+1] = faces.name
		end

		local fi,ff = fixed_type(faces)

		face_data[#face_data+1] = attributes.FACE
		face_data[#face_data+1] = string.char(fi<<4)
		face_data[#face_data+1] = encode_uint(#faces,4)

		for i=1,#faces,3 do
			local v = append_vector3(
				vertices,
				model.vertices[faces[i]*3+1],
				model.vertices[faces[i]*3+2],
				model.vertices[faces[i]*3+3]
			)
			local n = append_vector3(
				normals,
				model.normals[faces[i+1]*3+1],
				model.normals[faces[i+1]*3+2],
				model.normals[faces[i+1]*3+3]
			)
			local t = append_vector2(
				textures,
				model.textures[faces[i+2]*2+1],
				model.textures[faces[i+2]*2+2]
			)

			face_data[#face_data+1] = encode_fixed(v,fi,0)
			face_data[#face_data+1] = encode_fixed(n,fi,0)
			face_data[#face_data+1] = encode_fixed(t,fi,0)
		end

		local vi,vf = fixed_type(vertices)
		local ni,nf = fixed_type(normals)
		local ti,tf = fixed_type(textures)

		vf = math.min(vf,precision)
		nf = math.min(nf,precision)
		tf = math.min(tf,precision)

		vert_data[#vert_data+1] = attributes.VERT
		vert_data[#vert_data+1] = string.char((vi<<4)|vf)
		vert_data[#vert_data+1] = encode_uint(#vertices,4)

		norm_data[#norm_data+1] = attributes.NORM
		norm_data[#norm_data+1] = string.char((ni<<4)|nf)
		norm_data[#norm_data+1] = encode_uint(#normals,4)

		text_data[#text_data+1] = attributes.TEXT
		text_data[#text_data+1] = string.char((ti<<4)|tf)
		text_data[#text_data+1] = encode_uint(#textures,4)

		for _,value in ipairs(vertices) do
			vert_data[#vert_data+1]=encode_fixed(value,vi,vf)
		end
		for _,value in ipairs(normals) do
			norm_data[#norm_data+1]=encode_fixed(value,ni,nf)
		end
		for _,value in ipairs(textures) do
			text_data[#text_data+1]=encode_fixed(value,ti,tf)
		end
	end

	return
		table.concat(name_data)..
		table.concat(vert_data)..
		table.concat(norm_data)..
		table.concat(text_data)..
		table.concat(face_data)
end

if #arg==0 then
	print(
		"OBJ2MAT Copyright (C) 2024 Dice\n"..
		"Usage: lua obj2mat.lua <options> -i <file> -e <file>\n\n"..
		"-i\tImport source\n"..
		"-e\tExport binary\n"..
		"-d\tDiscard names\n"..
		"-p\tChange precision (default 2)"
	)

	return
end

local model
local option
local precision     = 2
local discard_names = false

for _,argument in ipairs(arg) do
	if argument:sub(1,1)=="-" then
		option=argument
	elseif not option then
		print("Missing argument")

		return
	elseif option=="-i" then
		local file=io.open(argument,"rb")

		if not file then
			print("Cannot open: "..argument)

			return
		end

		model=import_obj(file:read("*a"))

		file:close()
	elseif option=="-e" then
		if not model then
			print("No model to export")

			return
		end

		local file=io.open(argument,"wb")

		if not file then
			print("Cannot open: "..argument)

			return
		end

		file:write(
			export_mat(
				model,
				precision,
				not discard_names
			)
		)

		file:close()
	elseif option=="-d" then
		discard_names=true
	elseif option=="-p" then
		precision=math.max(tonumber(argument) or 2,0)
	else
		print("Invalid option")

		return
	end
end
