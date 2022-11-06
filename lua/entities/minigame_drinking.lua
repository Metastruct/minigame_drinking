local Tag = "minigame_drinking"
local DRINKURL="https://metastruct.github.io/minigame_drinking/assets/"

DEFINE_BASECLASS( "base_anim" )

ENT.Category = "Fun + Games"

ENT.Type			= "anim"
ENT.Base			= "base_anim"
ENT.Editable 		= false
ENT.Spawnable 		= false
ENT.AdminOnly 		= false

ENT.PrintName = "Drinking game"
ENT.Information = "Compete with other players on best drinking skills"
ENT.Author = "FailCake"
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.FLAG_DRINK = 1
ENT.FLAG_WATER = 2
ENT.FLAG_BLUFF = 3
ENT.PICK_TIMER = 3
ENT.TOTAL_TIME = 78 -- 78
ENT.DEBUG = false

ENT.REWARD_TABLE = {
	{
		p1 = ENT.FLAG_DRINK,
		p2 = ENT.FLAG_DRINK,
		rewards = {
			p1 = 1,
			p2 = 1
		}
	},
	{
		p1 = ENT.FLAG_DRINK,
		p2 = ENT.FLAG_WATER,
		rewards = {
			p1 = 1,
			p2 = 0
		}
	},
	{
		p1 = ENT.FLAG_WATER,
		p2 = ENT.FLAG_DRINK,
		rewards = {
			p1 = 0,
			p2 = 1
		}
	},
	{
		p1 = ENT.FLAG_DRINK,
		p2 = ENT.FLAG_BLUFF,
		rewards = {
			p1 = 0,
			p2 = 2
		}
	},
	{
		p1 = ENT.FLAG_BLUFF,
		p2 = ENT.FLAG_DRINK,
		rewards = {
			p1 = 2,
			p2 = 0
		}
	},
	{
		p1 = ENT.FLAG_WATER,
		p2 = ENT.FLAG_BLUFF,
		rewards = {
			p1 = 2,
			p2 = 0
		}
	},
	{
		p1 = ENT.FLAG_BLUFF,
		p2 = ENT.FLAG_WATER,
		rewards = {
			p1 = 0,
			p2 = 2
		}
	},
	{
		p1 = ENT.FLAG_BLUFF,
		p2 = ENT.FLAG_BLUFF,
		rewards = {
			p1 = 1,
			p2 = 1
		}
	}
}

if SERVER then
	AddCSLuaFile()
	util.AddNetworkString("__minigame_drinking_snd")
	util.AddNetworkString(Tag)
	util.PrecacheModel("models/props_junk/glassjug01.mdl")
else

	ENT.UrlTex_drink_icon = surface.LazyURLImage(DRINKURL.."drink.png")
	ENT.UrlTex_water_icon = surface.LazyURLImage(DRINKURL.."water.png")
	ENT.UrlTex_belch_icon = surface.LazyURLImage(DRINKURL.."belch.png")
	ENT.UrlTex_tbbg = surface.LazyURLImage(DRINKURL.."table_bg.png")
	ENT.UrlTex_icon = surface.LazyURLImage(DRINKURL.."icon.png")

end
	
function ENT:Initialize()
	self.__players = {} -- Reset
	self.__started = false
	self.__selected_btn = {}

	if SERVER then
		self:SetModel("models/props_farm/wooden_barrel.mdl")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetModelScale(0.6, 0)
		self:SetSolid(SOLID_BBOX)
		self:CPPISetOwner(me)
		self:SetTrigger(true)
		self:SetUseType(SIMPLE_USE)
		self:Activate()
	else
		local mi, ma = self:OBBMins() * 1.5, self:OBBMaxs() * 15
		self:SetRenderBounds(mi, ma)
		self.bottle = ClientsideModel("models/props_junk/glassjug01.mdl", RENDERGROUP_TRANSLUCENT)
		self.bottle:SetColor(Color(255, 255, 255, 254))
		self.bottle:SetPos(self:GetPos() + Vector(0, 0, 25))
		self.bottle:SetParent(self)

		self.icons = {}

		self.icons.drink = {1}

		self.icons.water = {2}

		self.icons.blech = {3}

		self.__cached_sounds = {}
		self.__beatScale = 0.2
	end
end

function ENT:Think()
	if SERVER then return end
	
	if not IsValid(self.bottle) then return end
	self.bottle:SetAngles(Angle(math.cos(CurTime() * 2) * 20, 0, 0))

	self:SetNextClientThink(CurTime())
	return true
end

function ENT:OnRemove()
	if CLIENT then
		if self.bottle ~= nil and IsValid(self.bottle) then
			self.bottle:Remove()
		end
	end

	self:StopAll()
end

function ENT:IsPlyPlaying(ply)
	return table.HasValue(self:GetPlaying(), ply)
end

function ENT:AddHooks()
	local EntTag = Tag..'_' .. self:EntIndex()
	if SERVER then
		hook.Add("PlayerDisconnected", EntTag, function(ply)
			if not IsValid(self) then return end
			if not self.__started then return end
			if not self:IsPlyPlaying(ply) or #self:GetPlaying() > 2 then return end
			self:EndMinigame(ply)
		end)
		
		
		hook.Add("PlayerReserved",EntTag,function(ply,tag,prev)
			--TODO: you can't really leave this game except only end it altogether
			--TODO: test 2 and 2+ players
			
			if prev~=Tag then return end -- only interested when someone leaves
			if not IsValid(self) then return end
			if not self.__started then return end
			if not self:IsPlyPlaying(ply) or #self:GetPlaying() > 2 then return end
			
			self:EndMinigame(ply)
		end)
		
		hook.Add("PlayerDeath", EntTag, function( ply, inflictor, attacker) 
			if not IsValid(self) then return end
			if not self.__started then return end
			if not self:IsPlyPlaying(ply) or #self:GetPlaying() > 2 then return end
			if ply==attacker then
				self:EndMinigame(ply) -- UNDONE: winner could force instant victory
			else
				timer.Simple(0.5,function()
					ply:Revive()
				end)
			end
			
		end)
	else
		local view = {}
		hook.Add("CalcView", EntTag, function(ply, pos, angles, fov)
			if not IsValid(ply) or not IsValid(self) then return end
			view.origin = self:GetPos() + Vector(0, -60, 80)
			view.angles = Angle(45, 90, 0)
			view.fov = fov

			return view
		end)

		hook.Add("ShouldDrawLocalPlayer", EntTag, function(ply)
			if not IsValid(ply) or not IsValid(self) then return end

			return true
		end)

		hook.Add("PrePlayerDraw", EntTag, function(ply)
			if not IsValid(ply) or not IsValid(self) then return end

			return not self:IsPlyPlaying(ply)
		end)
	end

	hook.Add("PlayerButtonUp", EntTag, function(ply, btn)
		if not IsValid(ply) or not IsValid(self) then return end
		if not self:GetNWBool("__can_select") or not self:IsPlyPlaying(ply) then return end
		if btn ~= KEY_1 and btn ~= KEY_2 and btn ~= KEY_3 then return end
		self.__selected_btn[ply:EntIndex()] = self:ButtonToPick(btn)
	end)
end

function ENT:RemoveHooks()	
	local EntTag = Tag..'_' .. self:EntIndex()

	if CLIENT then
		hook.Remove("CalcView", EntTag)
		hook.Remove("ShouldDrawLocalPlayer", EntTag)
		hook.Remove("PrePlayerDraw", EntTag)
	else
		hook.Remove("PlayerDeath", EntTag)
		hook.Remove("PlayerReserved", EntTag)
		hook.Remove("PlayerDisconnected", EntTag)
	end

	hook.Remove("PlayerButtonUp", EntTag)
end

function ENT:SolvePicks()
	if CLIENT then return end
	if not IsValid(self) then return end
	local plys = self:GetPlaying()
	if #plys < 2 then return end
	local PICK_1 = self.__selected_btn[plys[1]:EntIndex()] or 1
	local PICK_2 = self.__selected_btn[plys[2]:EntIndex()] or 1
	local P1_DRINK = plys[1]:GetNWInt("__drink_ammount", 0)
	local P2_DRINK = plys[2]:GetNWInt("__drink_ammount", 0)
	self:PlaySoundEffect(plys[1], PICK_1)
	self:PlaySoundEffect(plys[2], PICK_2)

	if math.random(1, 8) == 2 then
		local rndPly = table.Random(plys)
		local rnd = math.random(1, 3)
		rndPly:Puke(0.3) -- Random puke
		self:PlaySound("hey_" .. rnd, DRINKURL.."hey_" .. rnd .. ".ogg")
	end

	for k, v in pairs(self.REWARD_TABLE) do
		if PICK_1 == v.p1 and PICK_2 == v.p2 then
			plys[1]:SetNWInt("__drink_ammount", P1_DRINK + v.rewards.p1)
			plys[2]:SetNWInt("__drink_ammount", P2_DRINK + v.rewards.p2)
			break
		end
	end
end

function ENT:PlaySoundEffect(ply, id)
	if id == self.FLAG_DRINK then
		self:PlaySound("gulp", DRINKURL.."gulp.ogg", 0.7, false, ply)
			self:DoAnimation(ply, "gesture_salute")
		self:SetWeaponStatus(ply, false)
	elseif id == self.FLAG_WATER then
		self:PlaySound("water", DRINKURL.."water.ogg", 0.9, false, ply)
		self:DoAnimation(ply, "gesture_salute")
		self:SetWeaponStatus(ply, true)
	elseif id == self.FLAG_BLUFF then
		self:PlaySound("burps", DRINKURL.."burps.ogg", 0.9, false, ply)
		self:DoAnimation(ply, "taunt_zombie")
		self:SetWeaponStatus(ply, false)
	end
end

function ENT:PreparePlayer(id, restrict)
	local ply = self:GetPlaying(id)
	if not IsValid(ply) then return end
	ply:ExitVehicle()
	local _ = not ply:Alive() and ply:Spawn()
	ply:SetAllowNoclip(not restrict, Tag)
	ply:SetAllowBuild(not restrict, Tag)
	ply:RestrictFly(restrict, Tag)
	ply:SetNWInt("__drink_ammount", 0)
	ply:SetNWBool("HideNames", restrict)
	ply:SetNWBool("HideTyping", restrict)
	local _ = ply.SetFlying and ply:SetFlying(false)
	ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	ply:PreventMoving(restrict)
	ply:StripWeapons()

	if restrict then
		ply:RestrictGuns({"cake_drinking_swep"}, Tag, true)

		ply:Give("cake_drinking_swep")

		timer.Simple(0.35, function()
			if id == 1 then
				ply:SetPos(self:GetPos() + Vector(-35, 0, 0))
				ply:SetEyeAngles(Angle(0, 0, 0))
			else
				ply:SetPos(self:GetPos() + Vector(35, 0, 0))
				ply:SetEyeAngles(Angle(0, -180, 0))
			end
		end)
	else
		ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
		ply:RestrictGuns(false, Tag)
		hook.Run("PlayerLoadout", ply)
	end
end

function ENT:GetPlaying(id)
	if id == nil then return self.__players end

	return self.__players[id]
end

function ENT:SetPlaying(id, ply)
	if id == nil then return false end
	if ply and not ply:Reserve(Tag) then return false end
	self.__players[id] = ply -- Sync with CL?
	return true
end

function ENT:PrintMessage(msg)
	if CLIENT then return end

	for _, v in pairs(self:GetPlaying()) do
		v:ChatPrint("[<color=232,83,174>Drinking Minigame<color=255,255,255>] " .. msg)
	end
end

function ENT:SetWeaponStatus(ply, isWater)
	if CLIENT then return end
	if not IsValid(ply) then return end
	net.Start(Tag)
		net.WriteEntity(self)
		net.WriteString("SET_WEAPON_STATUS")
		net.WriteEntity(ply)
		net.WriteBool(isWater)
	net.Broadcast()
end

function ENT:DoAnimation(ply, anim)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	if SERVER then
		net.Start(Tag)
		net.WriteEntity(self)
		net.WriteString("PLY_ANIMATION")
		net.WriteEntity(ply)
		net.WriteString(anim)
		net.Broadcast()

		return
	end

	local act = ply:GetSequenceActivity(ply:LookupSequence(anim))
	ply:AnimResetGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD)

	if act ~= 1 then
		ply:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, act, true)
	end

	ply:AnimSetGestureWeight(GESTURE_SLOT_ATTACK_AND_RELOAD, 10)
end

function ENT:Use(ply, caller)
	if CLIENT then return end
	if not IsValid(ply) then return end
	if self.__started then return end -- Minigame already started
	if self.DEBUG and ply ~= me then return ply:ChatPrint("[<color=232,83,174>Drinking Minigame<color=255,255,255>] Debug mode active, only owner") end
	local ply_1 = self:GetPlaying(1)
	local ply_2 = self:GetPlaying(2)

	if not self.DEBUG then
		if ply == ply_1 or ply == ply_2 then
			-- Stop timer
			self:CancelMinigameStart()
			self:EmitSound("buttons/combine_button3.wav")
			ply:ChatPrint("[<color=232,83,174>Drinking Minigame<color=255,255,255>] No longer queued")
			ply:UnReserve(Tag)
			if ply == ply_1 then
				return self:SetPlaying(1, nil)
			elseif ply == ply_2 then
				return self:SetPlaying(2, nil)
			end
		end
	end
	local plyres = ply:IsReserved()
	if plyres then 
		ply:ChatPrint("Cannot enter, already playing game: "..tostring(plyres))
		return
	end
	
	if not IsValid(ply_1) then
		local ret = self:SetPlaying(1, ply)
		if not ret then return end
		
		return self:CheckMinigameStart()
	elseif not IsValid(ply_2) then
		local ret = self:SetPlaying(2, ply)
		if not ret then return end
		
		return self:CheckMinigameStart()
	else
		ply:ChatPrint("[<color=232,83,174>Drinking Minigame<color=255,255,255>] Queue for minigame full, try again later")
	end
end

function ENT:CancelMinigameStart()
	if CLIENT then return end
	local timerId = "__minigame_start_" .. self:EntIndex()

	if timer.Exists(timerId) then
		self:PrintMessage("Canceled start")
		self:EmitSound("buttons/combine_button2.wav")
	end

	timer.Destroy(timerId)
end

function ENT:CheckMinigameStart()
	if CLIENT then return end

	if #self:GetPlaying() >= 2 then
		self:EmitSound("buttons/combine_button1.wav")
		self:PrintMessage("Starting minigame in 3 seconds")

		timer.Create("__minigame_start_" .. self:EntIndex(), 3, 1, function()
			self:PrintMessage("Press 1, 2 or 3 to make your selection")
			self:StartMinigame()
		end)
	else
		self:EmitSound("buttons/combine_button1.wav")
		self:PrintMessage("Waiting for 1 more player")
	end
end

function ENT:PlaySound(id, url, vol, loop, ent)
	if CLIENT then return end
	vol = vol or 0.8
	loop = loop or false
	ent = ent or self
	net.Start("__minigame_drinking_snd",true)
	net.WriteEntity(self)

	net.WriteTable({id, url, loop, ent, vol})

	net.Broadcast()
end

function ENT:StartMinigame()
	if CLIENT then return end
	if self.__started then return end
	net.Start(Tag)
	net.WriteEntity(self)
	net.WriteString("MINIGAME_STARTED")
	net.WriteTable(self:GetPlaying()) -- Send players
	net.Broadcast()
	self:PreparePlayer(1, true)
	self:PreparePlayer(2, true)
	self.__started = true
	self.__selected_btn = {}
	self:SetNWInt("__minigame_time", self.TOTAL_TIME)
	self:SetNWInt("__pick_remain", 0)
	self:SetNWBool("__can_select", false)
	self:PlaySound("ambient", DRINKURL.."minigame-theme.ogg")
	self:AddHooks()

	-- Start minigame
	timer.Simple(1, function()
		self:EnablePick()
	end)

	timer.Create("__minigame_timer_" .. self:EntIndex(), 1, self.TOTAL_TIME, function()
		local time = self:GetNWInt("__minigame_time")
		self:SetNWInt("__minigame_time", time - 1)
		if time - 1 <= 0 then return self:EndMinigame() end
	end)
end

function ENT:BroadcastWinner(name)
	for _, v in pairs(player.GetAll()) do
		if not IsValid(v) then continue end
		v:ChatPrint("[<color=232,83,174>Drinking Minigame<color=255,255,255>] <color=219,186,5>" .. name .. "<color=255,255,255> won the drinking minigame!")
	end
end

function ENT:EndMinigame(no_winner)
	local winner = self:CheckWinners()
	if no_winner then
		winner = nil
	end

	if not IsValid(winner) then
		if self.__started then
			self:PrintMessage("No one won!")
		end
	else
		self:DoAnimation(winner, "taunt_cheer")
		local nick_1 = (winner:GetNick())
		self:BroadcastWinner(nick_1)
		self:EmitSound("metachievements/lightning_1.wav")
	end

	-- Set players drunk
	for _, v in pairs(self:GetPlaying()) do
		if not IsValid(v) then continue end
		v:SetDrunkFactor(20)
		v:UnReserve(Tag)
		timer.Simple(6, function()
			v:SetDrunkFactor(0)
		end)
	end

	self:StopAll() -- Server side only
	net.Start(Tag)
	net.WriteEntity(self)
	net.WriteString("MINIGAME_END")
	net.Broadcast()
end

function ENT:CheckWinners()
	local plys = self:GetPlaying()
	if #plys <= 0 then return nil end

	if #plys <= 1 then
		return plys[1]
	else
		local drink_1 = plys[1]:GetNWInt("__drink_ammount", 0)
		local drink_2 = plys[2]:GetNWInt("__drink_ammount", 0)

		if drink_1 < drink_2 then
			return plys[1]
		elseif drink_1 > drink_2 then
			return plys[2]
		elseif drink_1 == drink_2 then
			return nil
		end
	end
end

function ENT:ButtonToPick(btn)
	if btn == KEY_1 then
		return self.FLAG_DRINK
	elseif btn == KEY_2 then
		return self.FLAG_WATER
	elseif btn == KEY_3 then
		return self.FLAG_BLUFF
	end
end

function ENT:EnablePick()
	if self:GetNWBool("__can_select") then return end
	self:SetNWBool("__can_select", true)
	self:SetNWInt("__pick_remain", self.PICK_TIMER) -- Set timer

	timer.Create("__minigame_pick_" .. self:EntIndex(), 1, self.PICK_TIMER, function()
		local currentPick = self:GetNWInt("__pick_remain")
		self:SetNWInt("__pick_remain", currentPick - 1)

		if currentPick - 1 <= 0 then
			self:SetNWBool("__can_select", false)
			self:SolvePicks()
			-- STOP LOOP
			self:EnablePick() -- Start loop again
		end
	end)
end

function ENT:StopAll()
	if CLIENT then
		self:StopAllSounds()
		self:RemoveHooks()
		timer.Destroy("__minigame_beat_" .. self:EntIndex())
	else
		timer.Destroy("__minigame_pick_" .. self:EntIndex())
		timer.Destroy("__minigame_timer_" .. self:EntIndex())
		timer.Destroy("__minigame_start_" .. self:EntIndex())
		self:PreparePlayer(1, false)
		self:PreparePlayer(2, false)
		self:RemoveHooks()
	end

	self.__players = {} -- Reset
	self.__started = false
	self.__selected_btn = {}
end

if CLIENT then
	net.Receive(Tag, function()
		local entity = net.ReadEntity()
		if not IsValid(entity) then return end
		local cmd = net.ReadString()

		if cmd == "MINIGAME_STARTED" then
			entity.__players = net.ReadTable()
			entity.__started = true
			entity.__selected_btn = {}

			if entity:IsPlyPlaying(LocalPlayer()) then
				entity:AddHooks()
			end
		elseif cmd == "PLY_ANIMATION" then
			local ply = net.ReadEntity()
			local anim = net.ReadString()
			entity:DoAnimation(ply, anim)
		elseif cmd == "SET_WEAPON_STATUS" then
			local ply = net.ReadEntity()
			local isWater = net.ReadBool()
			local wep = ply:GetActiveWeapon()
			if wep:GetClass() ~= "cake_drinking_swep" then return end
			wep:SetWater(isWater)
		elseif cmd == "MINIGAME_END" then
			-- Manual call
			entity:StopAll()
		end
	end)

	net.Receive("__minigame_drinking_snd", function()
		local owner = net.ReadEntity()
		local tblData = net.ReadTable()
		local id = tblData[1]
		local url = tblData[2]
		local loop = tblData[3]
		local ent = tblData[4]
		local volume = tblData[5]
		if not owner:IsValid() then return end
		if not ent:IsValid() then return end
		if owner.__cached_sounds == nil then return end

		if owner.__cached_sounds[id] ~= nil then
			local station = owner.__cached_sounds[id].Station

			if IsValid(station) then
				if id == "ambient" then
					owner:StartHeartbeat()
				end

				station:SetTime(0)
				station:SetPos(ent:GetPos())
				station:SetVolume(volume)
				station:EnableLooping(loop)
				station:Play()

				return
			end
		end

		sound.PlayURL(url, "noblock noplay 3d", function(station)
			if not IsValid(station) then return end
			owner.__cached_sounds[id] = {}
			owner.__cached_sounds[id].Station = station

			if id == "ambient" then
				owner:StartHeartbeat()
			end

			station:SetPos(ent:GetPos())
			station:SetVolume(volume)
			station:EnableLooping(loop)
			station:Play()
		end)
	end)

	function ENT:StopAllSounds()
		for _, v in pairs(self.__cached_sounds) do
			if not IsValid(v.Station) then continue end
			v.Station:Pause()
		end
	end

	function ENT:StartHeartbeat()
		timer.Create("__minigame_beat_" .. self:EntIndex(), 0.73, 0, function()
			self.__beatScale = 0.25
		end)
	end

	function ENT:Draw()
		if not IsValid(LocalPlayer()) then return end
		if self.UrlTex_icon == nil or self.UrlTex_tbbg == nil or self.UrlTex_drink_icon == nil or self.UrlTex_water_icon == nil or self.UrlTex_belch_icon == nil then return end
		self:DrawModel()

		if not self.__started then
			-- INSTRUCTIONS
			local pos = self:GetPos() + Vector(0, 0, 80)
			local ang = (LocalPlayer():GetPos() - pos):Angle() + Angle(0, 90, 90)
			cam.Start3D2D(pos, Angle(0, ang.yaw, 90), 0.2)
			local wdrink, hdrink = nil
			draw.DrawText("Drinking Game", "Trebuchet18", -94, 1, Color(1, 1, 1, 255), TEXT_ALIGN_LEFT)
			draw.DrawText("Drinking Game", "Trebuchet18", -95, 0, Color(153, 120, 191, 255), TEXT_ALIGN_LEFT)
			wdrink, hdrink = self.UrlTex_icon()

			if wdrink then
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(62, -2, 32, 32)
			end

			wdrink, hdrink = self.UrlTex_tbbg()

			if wdrink then
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(-100, 20, 200, 174)
				surface.SetDrawColor(1, 1, 1, 255)
				surface.DrawOutlinedRect(-100, 20, 200, 174)
			end

			draw.DrawText("Be the one with the least points", "Trebuchet18", -1, 21, Color(1, 1, 1, 255), TEXT_ALIGN_CENTER)
			draw.DrawText("Be the one with the least points", "Trebuchet18", 0, 20, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
			surface.SetDrawColor(1, 1, 1, 255)
			surface.DrawRect(-100, 37, 200, 1)
			-- ICONS
			-- DRINK
			wdrink, hdrink = self.UrlTex_drink_icon()

			if wdrink then
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(-95, 44, 42, 42)
				draw.DrawText("Drink: Gain 1 point. If op-\nponent uses burp, he gains \n2 points", "Default", -49, 46, Color(1, 1, 1, 255), TEXT_ALIGN_LEFT)
			end

			-- WATER
			wdrink, hdrink = self.UrlTex_water_icon()

			if wdrink then
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(53, 94, 42, 42)
				draw.DrawText("Water: Do not gain points. If \nopponent uses burp, you gain \n2 points ", "Default", 50, 95, Color(1, 1, 1, 255), TEXT_ALIGN_RIGHT)
			end

			-- BURP
			wdrink, hdrink = self.UrlTex_belch_icon()

			if wdrink then
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(-95, 146, 42, 42)
				draw.DrawText("Burp: If opponent drinks\nwater, he gains 2 points, else\nyou gain 2 points", "Default", -49, 147, Color(1, 1, 1, 255), TEXT_ALIGN_LEFT)
			end

			cam.End3D2D()

			return
		end

		-- Game stuff
		local pos = self:GetPos() + Vector(0, -20, 10)
		local ang = Angle(0, 0, 45)
		local players = self:GetPlaying()
		if #players < 2 then return end
		local canSelect = self:GetNWBool("__can_select")
		local ply = LocalPlayer()
		cam.Start3D2D(pos, ang, 0.2)

		if self.icons ~= nil and self:IsPlyPlaying(LocalPlayer()) and canSelect then
			for i, v in pairs(self.icons) do
				local wdrink, hdrink = nil

				if i == "drink" then
					wdrink, hdrink = self.UrlTex_drink_icon()
				elseif i == "water" then
					wdrink, hdrink = self.UrlTex_water_icon()
				elseif i == "blech" then
					wdrink, hdrink = self.UrlTex_belch_icon()
				end

				if wdrink then
					surface.SetDrawColor(255, 255, 255, 255)
					surface.DrawTexturedRect(v[1] * 62 - 150, 0, 60, 60)
					draw.DrawText(v[1], "GModNotify", v[1] * 62 - 143, -1, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER)
					draw.DrawText(v[1], "GModNotify", v[1] * 62 - 144, 0, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
					local selected = self.__selected_btn[LocalPlayer():EntIndex()] or 1

					if selected == v[1] then
						surface.SetDrawColor(255, 1, 255, 100)
						surface.DrawOutlinedRect(v[1] * 62 - 150, 0, 60, 60)
						surface.SetDrawColor(255, 1, 100, 20)
						surface.DrawRect(v[1] * 62 - 150, 0, 60, 60)
					end
				end
			end

			if canSelect then
				local leftPick = tostring(self:GetNWInt("__pick_remain"))
				draw.DrawText(leftPick, "GModNotify", -1, -57, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER)
				draw.DrawText(leftPick, "GModNotify", 0, -56, Color(255, 0, 0, 255), TEXT_ALIGN_CENTER)
			end
		end

		local ply1 = players[1]
		local drink1 = ply1:GetNWInt("__drink_ammount", 0)
		local ply2 = players[2]
		local drink2 = ply2:GetNWInt("__drink_ammount", 0)
		local bwidth = 200
		local total = drink1 + drink2
		local perc_1, perc_2 = drink1 / total, drink2 / total
		local w1, w2 = perc_1 * bwidth, perc_2 * bwidth
		local minnick_1 = (ply1:GetNick())
		local minnick_2 = (ply2:GetNick())

		-- HUD -- Ply 1
		if drink1 > 0 then
			surface.SetDrawColor(26, 188, 156, 250)
			surface.DrawRect(-100, -30, bwidth - w1, 15)
		end

		draw.DrawText(minnick_1, "Trebuchet18", -81, -45, Color(0, 0, 0, 255), TEXT_ALIGN_RIGHT)
		draw.DrawText(minnick_1, "Trebuchet18", -80, -46, Color(26, 188, 156, 255), TEXT_ALIGN_RIGHT)
		draw.DrawText(tostring(drink1), "Trebuchet18", -97, -31, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT)

		-- HUD -- Ply 2
		if drink2 > 0 then
			surface.SetDrawColor(155, 89, 182, 250)
			surface.DrawRect(-100 + bwidth - w1, -30, bwidth - w2, 15)
		end

		draw.DrawText(minnick_2, "Trebuchet18", 81, -18, Color(0, 0, 0, 255), TEXT_ALIGN_LEFT)
		draw.DrawText(minnick_2, "Trebuchet18", 80, -19, Color(155, 89, 182, 255), TEXT_ALIGN_LEFT)
		draw.DrawText(tostring(drink2), "Trebuchet18", 97, -31, Color(0, 0, 0, 255), TEXT_ALIGN_RIGHT)
		surface.SetDrawColor(1, 1, 1, 250)
		surface.DrawOutlinedRect(-100, -30, 200, 15)
		cam.End3D2D()

		if self.__beatScale == nil then
			self.__beatScale = 0.2
		end

		cam.Start3D2D(self:GetPos() + Vector(0, 13, 18), Angle(0, 0, 0), self.__beatScale)
		local time = self:GetNWInt("__minigame_time")

		if self.__beatScale > 0.2 then
			self.__beatScale = math.Clamp(self.__beatScale - 0.001, 0.2, 0.5)
		end

		draw.DrawText(string.ToMinutesSeconds(time), "Trebuchet18", -1, 51, Color(1, 1, 1, 255), TEXT_ALIGN_CENTER)
		draw.DrawText(string.ToMinutesSeconds(time), "Trebuchet18", 0, 50, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
		cam.End3D2D()
	end

	function ENT:DrawTranslucent()
		self:Draw()
	end
end

--easylua.EndEntity()




if SERVER and false then
	-- DEBUG STUFF
	if CAW_DRINK_game ~= nil and IsValid(CAW_DRINK_game) then
		CAW_DRINK_game:Remove()
	end

	CAW_DRINK_game = create(Tag)
	CAW_DRINK_game:SetPos(me:GetPos() + Vector(0, 0, 18))
	CAW_DRINK_game:Spawn()
end