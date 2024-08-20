--[[
DAE to MAT converter by Dice

This converter only supports triangle meshes!
Lua 5.4 must be installed to run this tool.
]]

---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--
-- xml.lua - XML parser for use with the Corona SDK.
--
-- version: 1.2
--
-- CHANGELOG:
--
-- 1.2 - Created new structure for returned table
-- 1.1 - Fixed base directory issue with the loadFile() function.
--
-- NOTE: This is a modified version of Alexander Makeev's Lua-only XML parser
-- found here: http://lua-users.org/wiki/LuaXml
--
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

function newParser()

    XmlParser = {};

    function XmlParser:ToXmlString(value)
        value = string.gsub(value, "&", "&amp;"); -- '&' -> "&amp;"
        value = string.gsub(value, "<", "&lt;"); -- '<' -> "&lt;"
        value = string.gsub(value, ">", "&gt;"); -- '>' -> "&gt;"
        value = string.gsub(value, "\"", "&quot;"); -- '"' -> "&quot;"
        value = string.gsub(value, "([^%w%&%;%p%\t% ])",
            function(c)
                return string.format("&#x%X;", string.byte(c))
            end);
        return value;
    end

    function XmlParser:FromXmlString(value)
        value = string.gsub(value, "&#x([%x]+)%;",
            function(h)
                return string.char(tonumber(h, 16))
            end);
        value = string.gsub(value, "&#([0-9]+)%;",
            function(h)
                return string.char(tonumber(h, 10))
            end);
        value = string.gsub(value, "&quot;", "\"");
        value = string.gsub(value, "&apos;", "'");
        value = string.gsub(value, "&gt;", ">");
        value = string.gsub(value, "&lt;", "<");
        value = string.gsub(value, "&amp;", "&");
        return value;
    end

    function XmlParser:ParseArgs(node, s)
        string.gsub(s, "(%w+)=([\"'])(.-)%2", function(w, _, a)
            node:addProperty(w, self:FromXmlString(a))
        end)
    end

    function XmlParser:ParseXmlText(xmlText)
        local stack = {}
        local top = newNode()
        table.insert(stack, top)
        local ni, c, label, xarg, empty
        local i, j = 1, 1
        while true do
            ni, j, c, label, xarg, empty = string.find(xmlText, "<(%/?)([%w_:]+)(.-)(%/?)>", i)
            if not ni then break end
            local text = string.sub(xmlText, i, ni - 1);
            if not string.find(text, "^%s*$") then
                local lVal = (top:value() or "") .. self:FromXmlString(text)
                stack[#stack]:setValue(lVal)
            end
            if empty == "/" then -- empty element tag
                local lNode = newNode(label)
                self:ParseArgs(lNode, xarg)
                top:addChild(lNode)
            elseif c == "" then -- start tag
                local lNode = newNode(label)
                self:ParseArgs(lNode, xarg)
                table.insert(stack, lNode)
		top = lNode
            else -- end tag
                local toclose = table.remove(stack) -- remove top

                top = stack[#stack]
                if #stack < 1 then
                    error("XmlParser: nothing to close with " .. label)
                end
                if toclose:name() ~= label then
                    error("XmlParser: trying to close " .. toclose.name .. " with " .. label)
                end
                top:addChild(toclose)
            end
            i = j + 1
        end
        local text = string.sub(xmlText, i);
        if #stack > 1 then
            error("XmlParser: unclosed " .. stack[#stack]:name())
        end
        return top
    end

    function XmlParser:loadFile(xmlFilename, base)
        if not base then
            base = system.ResourceDirectory
        end

        local path = system.pathForFile(xmlFilename, base)
        local hFile, err = io.open(path, "r");

        if hFile and not err then
            local xmlText = hFile:read("*a"); -- read file content
            io.close(hFile);
            return self:ParseXmlText(xmlText), nil;
        else
            print(err)
            return nil
        end
    end

    return XmlParser
end

function newNode(name)
    local node = {}
    node.___value = nil
    node.___name = name
    node.___children = {}
    node.___props = {}

    function node:value() return self.___value end
    function node:setValue(val) self.___value = val end
    function node:name() return self.___name end
    function node:setName(name) self.___name = name end
    function node:children() return self.___children end
    function node:numChildren() return #self.___children end
    function node:addChild(child)
        if self[child:name()] ~= nil then
            if type(self[child:name()].name) == "function" then
                local tempTable = {}
                table.insert(tempTable, self[child:name()])
                self[child:name()] = tempTable
            end
            table.insert(self[child:name()], child)
        else
            self[child:name()] = child
        end
        table.insert(self.___children, child)
    end

    function node:properties() return self.___props end
    function node:numProperties() return #self.___props end
    function node:addProperty(name, value)
        local lName = "@" .. name
        if self[lName] ~= nil then
            if type(self[lName]) == "string" then
                local tempTable = {}
                table.insert(tempTable, self[lName])
                self[lName] = tempTable
            end
            table.insert(self[lName], value)
        else
            self[lName] = value
        end
        table.insert(self.___props, { name = name, value = self[name] })
    end

    return node
end

local xmlsimple = newParser()

local attributes={
	META = string.char(0x00),
	MESH = string.char(0x10),
	VERT = string.char(0x22),
	NORM = string.char(0x32),
	TEXT = string.char(0x41),
	FACE = string.char(0x58),
	SKIN = string.char(0x60),
	ANIM = string.char(0x70),
	POSE = string.char(0x8F),
	SLOT = string.char(0x90),
	TIME = string.char(0xA0)
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

local function get_precision(list)
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

local function mat4_mul(a,b)
	local a11,a12,a13,a14=a[1],a[2],a[3],a[4]
	local a21,a22,a23,a24=a[5],a[6],a[7],a[8]
	local a31,a32,a33,a34=a[9],a[10],a[11],a[12]
	local a41,a42,a43,a44=a[13],a[14],a[15],a[16]

	local b11,b12,b13,b14=b[1],b[2],b[3],b[4]
	local b21,b22,b23,b24=b[5],b[6],b[7],b[8]
	local b31,b32,b33,b34=b[9],b[10],b[11],b[12]
	local b41,b42,b43,b44=b[13],b[14],b[15],b[16]

	return {
		a11*b11+a12*b21+a13*b31+a14*b41,
		a11*b12+a12*b22+a13*b32+a14*b42,
		a11*b13+a12*b23+a13*b33+a14*b43,
		a11*b14+a12*b24+a13*b34+a14*b44,
		a21*b11+a22*b21+a23*b31+a24*b41,
		a21*b12+a22*b22+a23*b32+a24*b42,
		a21*b13+a22*b23+a23*b33+a24*b43,
		a21*b14+a22*b24+a23*b34+a24*b44,
		a31*b11+a32*b21+a33*b31+a34*b41,
		a31*b12+a32*b22+a33*b32+a34*b42,
		a31*b13+a32*b23+a33*b33+a34*b43,
		a31*b14+a32*b24+a33*b34+a34*b44,
		a41*b11+a42*b21+a43*b31+a44*b41,
		a41*b12+a42*b22+a43*b32+a44*b42,
		a41*b13+a42*b23+a43*b33+a44*b43,
		a41*b14+a42*b24+a43*b34+a44*b44
	}
end

local function mat4_inv(a)
	local a11,a12,a13,a14=a[1],a[2],a[3],a[4]
	local a21,a22,a23,a24=a[5],a[6],a[7],a[8]
	local a31,a32,a33,a34=a[9],a[10],a[11],a[12]
	local a41,a42,a43,a44=a[13],a[14],a[15],a[16]

	local c11 =  a22*a33*a44-a22*a34*a43-a32*a23*a44+a32*a24*a43+a42*a23*a34-a42*a24*a33
	local c12 = -a12*a33*a44+a12*a34*a43+a32*a13*a44-a32*a14*a43-a42*a13*a34+a42*a14*a33
	local c13 =  a12*a23*a44-a12*a24*a43-a22*a13*a44+a22*a14*a43+a42*a13*a24-a42*a14*a23
	local c14 = -a12*a23*a34+a12*a24*a33+a22*a13*a34-a22*a14*a33-a32*a13*a24+a32*a14*a23
	local c21 = -a21*a33*a44+a21*a34*a43+a31*a23*a44-a31*a24*a43-a41*a23*a34+a41*a24*a33
	local c22 =  a11*a33*a44-a11*a34*a43-a31*a13*a44+a31*a14*a43+a41*a13*a34-a41*a14*a33
	local c23 = -a11*a23*a44+a11*a24*a43+a21*a13*a44-a21*a14*a43-a41*a13*a24+a41*a14*a23
	local c24 =  a11*a23*a34-a11*a24*a33-a21*a13*a34+a21*a14*a33+a31*a13*a24-a31*a14*a23
	local c31 =  a21*a32*a44-a21*a34*a42-a31*a22*a44+a31*a24*a42+a41*a22*a34-a41*a24*a32
	local c32 = -a11*a32*a44+a11*a34*a42+a31*a12*a44-a31*a14*a42-a41*a12*a34+a41*a14*a32
	local c33 =  a11*a22*a44-a11*a24*a42-a21*a12*a44+a21*a14*a42+a41*a12*a24-a41*a14*a22
	local c34 = -a11*a22*a34+a11*a24*a32+a21*a12*a34-a21*a14*a32-a31*a12*a24+a31*a14*a22
	local c41 = -a21*a32*a43+a21*a33*a42+a31*a22*a43-a31*a23*a42-a41*a22*a33+a41*a23*a32
	local c42 =  a11*a32*a43-a11*a33*a42-a31*a12*a43+a31*a13*a42+a41*a12*a33-a41*a13*a32
	local c43 = -a11*a22*a43+a11*a23*a42+a21*a12*a43-a21*a13*a42-a41*a12*a23+a41*a13*a22
	local c44 =  a11*a22*a33-a11*a23*a32-a21*a12*a33+a21*a13*a32+a31*a12*a23-a31*a13*a22

	local det = a11*c11+a12*c21+a13*c31+a14*c41

	if det==0 then
		return a
	end

	return {
		c11/det,c12/det,c13/det,c14/det,
		c21/det,c22/det,c23/det,c24/det,
		c31/det,c32/det,c33/det,c34/det,
		c41/det,c42/det,c43/det,c44/det
	}
end

local function mat4_transpose(a)
	return {
		a[1],a[5],a[9],a[13],
		a[2],a[6],a[10],a[14],
		a[3],a[7],a[11],a[15],
		a[4],a[8],a[12],a[16]
	}
end

local function mat4_euler(x,y,z)
	local cx,sx=math.cos(x),math.sin(x)
	local cy,sy=math.cos(y),math.sin(y)
	local cz,sz=math.cos(z),math.sin(z)
	
	return {
		cy*cz,
		-cy*sz,
		sy,
		0,
		cz*sx*sy+cx*sz,
		cx*cz-sx*sy*sz,
		-cy*sx,
		0,
		sx*sz-cx*cz*sy,
		cz*sx+cx*sy*sz,
		cx*cy,
		0,
		0,0,0,1
	}
end

local function get_bone_hierarchy(parent,animation)
	local bone = {
		joint    = parent["@sid"] or parent["@name"],
		matrix   = {},
		children = {}
	}

	for value in parent.matrix:value():gmatch("%S+") do
		bone.matrix[#bone.matrix+1] = tonumber(value)
	end

	if parent.node then
		if #parent.node>0 then
			for _,child in pairs(parent.node) do
				bone.children[#bone.children+1] = get_bone_hierarchy(child)
			end
		else
			bone.children[#bone.children+1] = get_bone_hierarchy(parent.node)
		end
	end

	return bone
end

local function get_bone_global_transform(
	bone,
	transforms,
	parent_transform
)
	for _,child in ipairs(bone.children) do
		transforms[child.joint]=mat4_mul(
			transforms[bone.joint] or bone.matrix,
			child.matrix
		)
		get_bone_global_transform(
			child,
			transforms
		)
	end
end

local function get_bone_animated_transform(
	bone,
	animation,
	transforms,
	time_
)
	local next_frame_available = false

	for _,child in ipairs(bone.children) do
		local animated_offset = child.matrix

		for _,segment in ipairs(animation) do
			if segment.joint==child.joint then
				for i=1,#segment.frame_time do
					if segment.frame_time[i]>time_ then
						next_frame_available = true

						break
					end

					for j=1,16 do
						animated_offset[j] = segment.frame_pose[(i-1)*16+j]
					end
				end

				break
			end
		end

		transforms[child.joint] = mat4_mul(
			transforms[bone.joint] or bone.matrix,
			animated_offset
		)

		next_frame_available = get_bone_animated_transform(
			child,
			animation,
			transforms,
			time_
		) or next_frame_available
	end

	return next_frame_available
end

local function import_dae(data)
	local xml = xmlsimple:ParseXmlText(data)

	local vertices = {}
	local normals  = {}
	local textures = {}
	local groups   = {}
	local skin     = {}

	for _,source in pairs(xml.COLLADA.library_geometries.geometry.mesh.source) do
		if source["@id"]:find("positions") then
			for value in source.float_array:value():gmatch("%S+") do
				vertices[#vertices+1] = tonumber(value)
			end
		elseif source["@id"]:find("normals") then
			for value in source.float_array:value():gmatch("%S+") do
				normals[#normals+1] = tonumber(value)
			end
		elseif source["@id"]:find("map") then
			for value in source.float_array:value():gmatch("%S+") do
				textures[#textures+1] = tonumber(value)
			end
		end
	end

	for _,triangles in pairs(xml.COLLADA.library_geometries.geometry.mesh.triangles) do
		local faces = {name=triangles["@material"]}

		for value in triangles.p:value():gmatch("%S+") do
			faces[#faces+1] = tonumber(value)
		end

		groups[#groups+1] = faces
	end

	local animation       = {}
	local inv_bind_matrix = {}
	local weights         = {}

	for _,source in pairs(xml.COLLADA.library_controllers.controller.skin.source) do
		if source["@id"]:find("joints") then
			for value in source.Name_array:value():gmatch("%S+") do
				animation[#animation+1] = {
					joint               = value,
					frame_time          = {},
					frame_pose          = {},
					inverse_bind_matrix = {}
				}
			end
		elseif source["@id"]:find("bind_poses") then
			for value in source.float_array:value():gmatch("%S+") do
				inv_bind_matrix[#inv_bind_matrix+1] = tonumber(value)
			end
		elseif source["@id"]:find("weights") then
			for value in source.float_array:value():gmatch("%S+") do
				weights[#weights+1] = tonumber(value)
			end
		end
	end
	
	for i,segment in ipairs(animation) do
		for j=1,16 do
			segment.inverse_bind_matrix[j] = inv_bind_matrix[(i-1)*16+j]
		end
	end

	local vcount = {}
	local vbinds = {}

	for value in xml.COLLADA.library_controllers.controller.skin.vertex_weights.vcount:value():gmatch("%S+") do
		vcount[#vcount+1] = tonumber(value)
	end
	for value in xml.COLLADA.library_controllers.controller.skin.vertex_weights.v:value():gmatch("%S+") do
		vbinds[#vbinds+1] = tonumber(value)
	end

	local vertex_weights = {}
	local v = 0

	for _,count in ipairs(vcount) do
		local vertex_group = {}

		for i=1,count do
			vertex_group[#vertex_group+1] = vbinds[v+1]
			vertex_group[#vertex_group+1] = weights[vbinds[v+2]+1]

			v = v+2
		end

		vertex_weights[#vertex_weights+1] = vertex_group
	end

	for v,animation_a in pairs(xml.COLLADA.library_animations.animation) do
		if animation_a.animation then
			anim = animation_a.animation["@id"]
			for _,animation_b in pairs(animation_a.animation) do
				for _,source in pairs(animation_b.source) do
					if source["@id"]:find("input") then
						for _,segment in pairs(animation) do
							if source["@id"] == animation_b["@name"].."_motion_bone_"..segment.joint.."_pose_matrix-input" then
								missed = false
								for value in source.float_array:value():gmatch("%S+") do
									segment.frame_time[#segment.frame_time+1] = tonumber(value)
								end
							end
						end
					elseif source["@id"]:find("output") then
						for _,segment in pairs(animation) do
							if source["@id"] == animation_b["@name"].."_motion_bone_"..segment.joint.."_pose_matrix-output" then
								for value in source.float_array:value():gmatch("%S+") do
									segment.frame_pose[#segment.frame_pose+1] = tonumber(value)
								end
							end
						end
					end
				end
			end
		end
	end

	for _,vertex_group in ipairs(vertex_weights) do
		local joint_id = vertex_group[1]
		local weight   = 0

		for i=1,#vertex_group,2 do
			if vertex_group[i+1]>weight then
				joint_id = vertex_group[i]
				weight   = vertex_group[i+1]
			end
		end

		skin[#skin+1] = joint_id
	end

	local skeleton = get_bone_hierarchy(xml.COLLADA.library_visual_scenes.visual_scene.node)

	return {
		vertices = vertices,
		normals  = normals,
		textures = textures,
		groups   = groups,
		skin     = skin
	},{
		skeleton  = skeleton,
		animation = animation
	}
end

local function export_mat(model,animation,precision,framerate)
	local mesh_data = {}
	local vert_data = {}
	local norm_data = {}
	local text_data = {}
	local face_data = {}
	local skin_data = {}
	local anim_data = {}
	local pose_data = {}
	local slot_data = {}
	local time_data = {}

	for _,faces in ipairs(model.groups) do
		local vertices = {}
		local normals  = {}
		local textures = {}
		local skin     = {}

		if faces.name then
			mesh_data[#mesh_data+1] = attributes.MESH
			mesh_data[#mesh_data+1] = string.char(0x00)
			mesh_data[#mesh_data+1] = encode_uint(#faces.name,4)
			mesh_data[#mesh_data+1] = faces.name
		end

		local fi,ff = get_precision(faces)

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
				1-model.textures[faces[i+2]*2+2]
			)

			skin[v+1] = model.skin[faces[i]+1]

			face_data[#face_data+1] = encode_fixed(v,fi,0)
			face_data[#face_data+1] = encode_fixed(n,fi,0)
			face_data[#face_data+1] = encode_fixed(t,fi,0)
		end

		local vi,vf = get_precision(vertices)
		local ni,nf = get_precision(normals)
		local ti,tf = get_precision(textures)
		local si,sf = get_precision(skin)

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

		if #skin>0 then
			skin_data[#skin_data+1] = attributes.SKIN
			skin_data[#skin_data+1] = string.char((si<<4)|sf)
			skin_data[#skin_data+1] = encode_uint(#skin,4)

			for _,value in ipairs(skin) do
				skin_data[#skin_data+1]=encode_fixed(value,si,sf)
			end
		end
	end

	if animation then
		local global_transforms   = {}
		local animated_transforms = {}
		local inverse_transforms  = {}
		local poses               = {}
		local slots               = {}
		local times               = {}

		get_bone_global_transform(
			animation.skeleton,
			global_transforms
		)

		local time_ = 0

		while get_bone_animated_transform(
			animation.skeleton,
			animation.animation,
			animated_transforms,
			time_
		) do
			for joint,transform in pairs(global_transforms) do
				if animated_transforms[joint] then
					inverse_transforms[joint] = mat4_mul(
						animated_transforms[joint],
						mat4_inv(transform)
					)
				else
					inverse_transforms[joint] = {
						1,0,0,0,
						0,1,0,0,
						0,0,1,0,
						0,0,0,1
					}
				end
			end

			slots[#slots+1] = #poses/16
			times[#times+1] = time_

			for _,segment in ipairs(animation.animation) do
				for i=1,16 do
					poses[#poses+1] = inverse_transforms[segment.joint][i]
				end
			end

			time_ = time_+1/framerate
		end

		local pi,pf = get_precision(poses)
		local si,sf = get_precision(slots)
		local ti,tf = get_precision(times)

		pose_data[#pose_data+1] = attributes.POSE
		pose_data[#pose_data+1] = string.char((pi<<4)|pf)
		pose_data[#pose_data+1] = encode_uint(#poses,4)

		slot_data[#slot_data+1] = attributes.SLOT
		slot_data[#slot_data+1] = string.char((si<<4)|sf)
		slot_data[#slot_data+1] = encode_uint(#slots,4)

		time_data[#time_data+1] = attributes.TIME
		time_data[#time_data+1] = string.char((ti<<4)|tf)
		time_data[#time_data+1] = encode_uint(#times,4)

		for _,value in ipairs(poses) do
			pose_data[#pose_data+1]=encode_fixed(value,pi,pf)
		end
		for _,value in ipairs(slots) do
			slot_data[#slot_data+1]=encode_fixed(value,si,sf)
		end
		for _,value in ipairs(times) do
			time_data[#time_data+1]=encode_fixed(value,ti,tf)
		end
	end

	return
		table.concat(mesh_data)..
		table.concat(vert_data)..
		table.concat(norm_data)..
		table.concat(text_data)..
		table.concat(face_data)..
		table.concat(skin_data)..
		table.concat(anim_data)..
		table.concat(pose_data)..
		table.concat(slot_data)..
		table.concat(time_data)
end

if #arg==0 then
	print(
		"DAE2MAT Copyright (C) 2024 Dice\n"..
		"Usage: lua dae2mat.lua <options> -i <file> -e <file>\n\n"..
		"-i\tImport source\n"..
		"-e\tExport binary\n"..
		"-p\tChange precision (default 2)"..
		"-f\tChange framerate (default 15)"
	)

	return
end

local model
local animation
local option
local precision = 2
local framerate = 15

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

		model,animation=import_dae(file:read("*a"))

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
				animation,
				precision,
				framerate
			)
		)

		file:close()
	elseif option=="-p" then
		precision=tonumber(argument) or 2
	elseif option=="-f" then
		framerate=tonumber(argument) or 15
	else
		print("Invalid option")

		return
	end
end
