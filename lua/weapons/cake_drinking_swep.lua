AddCSLuaFile()


AddCSLuaFile()
SWEP.Author = "FailCake :D"
SWEP.ViewModel = ""
SWEP.WorldModel = Model("models/MaxOfS2D/camera.mdl")
SWEP.PrintName = "Drinking Minigame"
SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = true
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.ShowViewModel = false
SWEP.ShowWorldModel = false

if CLIENT then
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
	SWEP.ViewModelFlip = false
	SWEP.CSMuzzleFlashes = false
	SWEP.Slot = 0
	SWEP.SlotPos = 5
end

SWEP.WElements = {
	["foam"] = {
		type = "Model",
		model = "models/dav0r/hoverball.mdl",
		bone = "ValveBiped.Bip01_L_Hand",
		rel = "cup",
		pos = Vector(0, 0.879, 3),
		angle = Angle(0, 0, 0),
		size = Vector(0.36, 0.36, 0.1),
		color = Color(255, 255, 255, 255),
		surpresslightning = false,
		material = "models/xqm/rails/gumball_1",
		skin = 0,
		bodygroup = {}
	},
	["beer"] = {
		type = "Model",
		model = "models/XQM/cylinderx1.mdl",
		bone = "ValveBiped.Bip01_L_Hand",
		rel = "cup",
		pos = Vector(0, 0.899, -0.529),
		angle = Angle(90, 90, 0),
		size = Vector(0.56, 0.356, 0.356),
		color = Color(255, 0, 190, 251),
		surpresslightning = false,
		material = "models/Effects/splodecard1_sheet",
		skin = 0,
		bodygroup = {}
	},
	["water"] = {
		type = "Model",
		model = "models/XQM/cylinderx1.mdl",
		bone = "ValveBiped.Bip01_L_Hand",
		rel = "cup",
		pos = Vector(0, 0.899, -0.529),
		angle = Angle(90, 90, 0),
		size = Vector(0.56, 0.356, 0.356),
		color = Color(0, 192, 255, 220),
		surpresslightning = false,
		material = "models/debug/debugwhite",
		skin = 0,
		bodygroup = {}
	},
	["beer_2"] = {
		type = "Model",
		model = "models/XQM/cylinderx1.mdl",
		bone = "ValveBiped.Bip01_L_Hand",
		rel = "cup",
		pos = Vector(0, 0.899, -0.529),
		angle = Angle(90, 90, 0),
		size = Vector(0.56, 0.356, 0.356),
		color = Color(255, 0, 190, 252),
		surpresslightning = false,
		material = "models/effects/muzzleflash/blurmuzzle",
		skin = 0,
		bodygroup = {}
	},
	["beer_3"] = {
		type = "Model",
		model = "models/XQM/cylinderx1.mdl",
		bone = "ValveBiped.Bip01_L_Hand",
		rel = "cup",
		pos = Vector(0, 0.899, -0.529),
		angle = Angle(90, 90, 0),
		size = Vector(0.56, 0.346, 0.346),
		color = Color(255, 0, 190, 128),
		surpresslightning = false,
		material = "models/props_combine/portalball001_sheet",
		skin = 0,
		bodygroup = {}
	},
	["cup"] = {
		type = "Model",
		model = "models/props_junk/garbage_coffeemug001a.mdl",
		bone = "ValveBiped.Bip01_L_Hand",
		rel = "",
		pos = Vector(7.791, 1.557, 0.518),
		angle = Angle(-26.883, 87.662, -8.183),
		size = Vector(1, 1, 1.5),
		color = Color(255, 255, 255, 254),
		surpresslightning = false,
		material = "models/props_combine/health_charger_glass",
		skin = 0,
		bodygroup = {}
	}
}

function SWEP:Initialize()
	self:SetHoldType("normal")

	if CLIENT then
		self.WElements = self:TableCopy(self.WElements)
		self.__drinkingWater = false
		self:CreateModels(self.WElements) -- create worldmodels
	end
end

function SWEP:Holster(wep)
	return true
end

function SWEP:ShouldDropOnDie()
	return false
end

-- Turn on / off
function SWEP:PrimaryAttack()
end

function SWEP:Reload()
end

function SWEP:SecondaryAttack()
end

function SWEP:SetWater(water)
	if SERVER then return end
	self.__drinkingWater = water
end

if CLIENT then
	SWEP.wRenderOrder = nil

	function SWEP:DrawWorldModel()
		if (self.ShowWorldModel == nil or self.ShowWorldModel) then
			self:DrawModel()
		end

		if (not self.WElements) then return end

		if (not self.wRenderOrder) then
			self.wRenderOrder = {}

			for k, v in pairs(self.WElements) do
				if (v.type == "Model") then
					table.insert(self.wRenderOrder, 1, k)
				elseif (v.type == "Sprite" or v.type == "Quad") then
					table.insert(self.wRenderOrder, k)
				end
			end
		end

		if (IsValid(self.Owner)) then
			bone_ent = self.Owner
		else
			-- when the weapon is dropped
			bone_ent = self
		end

		for k, name in pairs(self.wRenderOrder) do
			local v = self.WElements[name]

			if (not v) then
				self.wRenderOrder = nil
				break
			end

			if (v.hide) then continue end

			if self.__drinkingWater then
				if name ~= "water" and name ~= "cup" then continue end
			else
				if name == "water" then continue end
			end

			local pos, ang

			if (v.bone) then
				pos, ang = self:GetBoneOrientation(self.WElements, v, bone_ent)
			else
				pos, ang = self:GetBoneOrientation(self.WElements, v, bone_ent, "ValveBiped.Bip01_R_Hand")
			end

			if (not pos) then continue end
			local model = v.modelEnt
			local sprite = v.spriteMaterial

			if (v.type == "Model" and IsValid(model)) then
				model:SetPos(pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z)
				ang:RotateAroundAxis(ang:Up(), v.angle.y)
				ang:RotateAroundAxis(ang:Right(), v.angle.p)
				ang:RotateAroundAxis(ang:Forward(), v.angle.r)
				model:SetAngles(ang)
				local matrix = Matrix()
				matrix:Scale(v.size)
				model:EnableMatrix("RenderMultiply", matrix)

				if (v.material == "") then
					model:SetMaterial("")
				elseif (model:GetMaterial() ~= v.material) then
					model:SetMaterial(v.material)
				end

				if (v.skin and v.skin ~= model:GetSkin()) then
					model:SetSkin(v.skin)
				end

				if (v.bodygroup) then
					for k, v in pairs(v.bodygroup) do
						if (model:GetBodygroup(k) ~= v) then
							model:SetBodygroup(k, v)
						end
					end
				end

				if (v.surpresslightning) then
					render.SuppressEngineLighting(true)
				end

				local color = v.color
				render.SetColorModulation(color.r / 255, color.g / 255, color.b / 255)
				render.SetBlend(color.a / 255)
				model:DrawModel()
				render.SetBlend(1)
				render.SetColorModulation(1, 1, 1)

				if (v.surpresslightning) then
					render.SuppressEngineLighting(false)
				end
			end
		end
	end

	function SWEP:GetBoneOrientation(basetab, tab, ent, bone_override)
		local bone, pos, ang

		if (tab.rel and tab.rel ~= "") then
			local v = basetab[tab.rel]
			if (not v) then return end
			-- Technically, if there exists an element with the same name as a bone
			-- you can get in an infinite loop. Let's just hope nobody's that stupid.
			pos, ang = self:GetBoneOrientation(basetab, v, ent)
			if (not pos) then return end
			pos = pos + ang:Forward() * v.pos.x + ang:Right() * v.pos.y + ang:Up() * v.pos.z
			ang:RotateAroundAxis(ang:Up(), v.angle.y)
			ang:RotateAroundAxis(ang:Right(), v.angle.p)
			ang:RotateAroundAxis(ang:Forward(), v.angle.r)
		else
			bone = ent:LookupBone(bone_override or tab.bone)
			if (not bone) then return end
			pos, ang = Vector(0, 0, 0), Angle(0, 0, 0)
			local m = ent:GetBoneMatrix(bone)

			if (m) then
				pos, ang = m:GetTranslation(), m:GetAngles()
			end

			if (IsValid(self.Owner) and self.Owner:IsPlayer() and ent == self.Owner:GetViewModel() and self.ViewModelFlip) then
				ang.r = -ang.r -- Fixes mirrored models
			end
		end

		return pos, ang
	end

	function SWEP:CreateModels(tab)
		if (not tab) then return end

		-- Create the clientside models here because Garry says we can't do it in the render hook
		for k, v in pairs(tab) do
			if (v.type == "Model" and v.model and v.model ~= "" and (not IsValid(v.modelEnt) or v.createdModel ~= v.model) and string.find(v.model, ".mdl") and file.Exists(v.model, "GAME")) then
				v.modelEnt = ClientsideModel(v.model, RENDER_GROUP_VIEW_MODEL_OPAQUE)

				if (IsValid(v.modelEnt)) then
					v.modelEnt:SetPos(self:GetPos())
					v.modelEnt:SetAngles(self:GetAngles())
					v.modelEnt:SetParent(self)
					v.modelEnt:SetNoDraw(true)
					v.createdModel = v.model
				else
					v.modelEnt = nil
				end
			end
		end
	end

	--[[*************************
		Global utility code
	*************************]]
	-- Fully copies the table, meaning all tables inside this table are copied too and so on (normal table.Copy copies only their reference).
	-- Does not copy entities of course, only copies their reference.
	-- WARNING: do not use on tables that contain themselves somewhere down the line or you'll get an infinite loop
	function SWEP:TableCopy(tab)
		if (not tab) then return nil end
		local res = {}

		for k, v in pairs(tab) do
			if (type(v) == "table") then
				res[k] = self:TableCopy(v) -- recursion ho!
			elseif (type(v) == "Vector") then
				res[k] = Vector(v.x, v.y, v.z)
			elseif (type(v) == "Angle") then
				res[k] = Angle(v.p, v.y, v.r)
			else
				res[k] = v
			end
		end

		return res
	end
end