-- WARNING: This script requires AE_Utilities.lua of version 1.12 or later!
-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "AE_MixSmartbones"

-- **************************************************
-- General information about this script
-- **************************************************

AE_MixSmartbones = {}

function AE_MixSmartbones:Name()
	return "Smartbone Correction"
end

function AE_MixSmartbones:Version()
	return "1.3.4"
end

function AE_MixSmartbones:UILabel()
	return "Mix smartbones"
end

function AE_MixSmartbones:Creator()
	return "Alexandra Evseeva"
end

function AE_MixSmartbones:Description()
	return "Edit smartbone driven tracks on main timeline. Select smartbone at frame with keys on driven tracks and with no keys on smartbone's tracks.With one selected smartbone it's behavior will be corrected. With two selected smartbones a correcting bone will be created.On success all keys at this frame will be deleted."
end




-- **************************************************
-- Recurring values
-- **************************************************

--AE_MixSmartbones.replaceKeys = 0

-- **************************************************
-- Is Enabled
-- **************************************************

function AE_MixSmartbones:IsRelevant(moho)
    local layer = moho.layer
    return layer ~= nil and layer:LayerType() == MOHO.LT_BONE and moho.frame == 1
end

function AE_MixSmartbones:IsEnabled(moho)
    return moho.frame == 1
end

-- **************************************************
-- The guts of this script
-- **************************************************

function AE_MixSmartbones:Run(moho)

	moho.document:PrepUndo("mix smartbones", moho.layer)
	moho.document:SetDirty()
	
	--self.replaceKeys = 0
	
	local skel = moho:Skeleton()
	if skel == nil then
    return LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Đã chọn lớp không phải là xương", "Hãy chọn một lớp xương", "", "THOÁT")end
    local selBones = {}
	local selChans = {}
	for b=0, skel:CountBones()-1 do
		local bone = skel:Bone(b)
		local name = bone:Name()
		if bone.fSelected then
			if (moho.layer:HasAction(name) or moho.layer:HasAction(name.." 2")) then
				table.insert(selBones, bone)
				table.insert(selChans, bone.fAnimAngle)
				for a = 0, bone.fAnimAngle:CountActions()-1 do 
					local boneName = bone.fAnimAngle:ActionName(a)
					if string.sub(boneName, -2) == " 2" then boneName = string.sub(1, -3) end
					local driveBone = skel:BoneByName(boneName)
					if driveBone then table.insert(selChans, driveBone.fAnimAngle) end
				end
			else 
				return LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Đã chọn xương", bone:Name(), "không có hành động thông minh", "THOÁT")
			end
		end
	end
	
	self.keysCollection = self:CollectKeyValues(moho, selChans)
	if #self.keysCollection < 1 then
    return LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Không có key tại khung hình hiện tại", "Hãy tạo hoạt ảnh cho khung hình này", "", "THOÁT")
	end

	if #selBones == 1 then
		self:CorrectSmartbone(moho, selBones[1])
	elseif #selBones == 2 then
		self:CreateCorrectingBone(moho, {selBones[1], selBones[2]})
	else
		return LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Số lượng smartbones được chọn sai", "Chọn một hoặc hai smartbones để điều chỉnh", "", "THOÁT")
	end

	moho.document:PrepUndo("cập nhật các chế độ xem", moho.layer)
	moho.document:SetDirty()

	for i, layer in AE_Utilities:IterateAllLayers(moho) do
		if not layer:IsReferencedLayer() then 
			layer:UpdateCurFrame(true)
		end
	end
	
	
	moho.document:Undo()
	moho:UpdateUI()
	
	
end

function AE_MixSmartbones:CreateCorrectingBone(moho, smartbones)
	local skel = moho:Skeleton()
	if skel == nil then return end
	
	local sourceFrame = moho.layerFrame
	local angle1 = smartbones[1].fAngle
	local angle2 = smartbones[2].fAngle
	local corrName = smartbones[1]:Name() ..self:RoundAngle(angle1).." | "..smartbones[2]:Name() ..self:RoundAngle(angle2)
	local corrBone = skel:BoneByName(corrName)
	if corrBone then return self:CorrectSmartbone(moho, corrBone) end
	corrBone = skel:AddBone(0)
	corrBone:SetName(corrName)
  	corrBone.fParent = -1 
  	corrBone.fShy = true
    corrBone.fStrength = 0
  	corrBone.fAnimAngle:SetValue(0,0)
	local startPos = LM.Vector2:new_local()
	startPos:Set(-2,0)
	corrBone.fAnimPos:SetValue(0, startPos)	
	
	--- set angles for corrbone's own action--------
	moho.layer:ActivateAction(corrName)
  	local frame1 = 150
  	local frame2 = 300
  	corrBone.fAnimAngle:SetValue(frame1, math.pi/4)
  	corrBone.fAnimAngle:SetValue(frame2, math.pi/2)
	moho.layer:ActivateAction(nil)

	--- set corrBone animation in corrected smartbones
	for i=1,2 do
		--print("analise parent no ", i, ": ", smartbones[i]:Name())
		local smartboneFrame, actName = self:FindFrameAndAction(moho, smartbones[i], smartbones[i].fAngle)
		if smartboneFrame > 0 then 
			moho.layer:ActivateAction(actName)
			corrBone.fAnimAngle:SetValue(smartboneFrame, math.pi/4)
			local secondZero = AE_Utilities:FindSmartBoneFrame(smartbones[i].fAnimAngle:GetValue(0), smartbones[i].fAnimAngle, true)
			if secondZero > 0 then
				corrBone.fAnimAngle:SetValue(secondZero, 0)
			end
			moho.layer:ActivateAction(nil)
		else
			local alertText = "Không có góc '" .. 180 * smartbones[i].fAngle / math.pi .. "' trong các hành động của '" .. smartbones[i]:Name() .. "'"
			LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Không thể tìm thấy góc", alertText, "", "THOÁT")
			skel:DeleteBone(skel:BoneID(corrBone))
			moho.layer:DeleteAction(corrName)
			return

		end
	end

	skel:UpdateBoneMatrix()
	local keysCollection = self:EvalSmartboneCorrection(moho, frame2, corrBone:Name())
	for k,v in pairs(keysCollection) do
		local actChannel = v.channel:ActionByName(corrBone:Name())
		local actDerivedChannel = AE_Utilities:GetDerivedChannel(moho, actChannel)
		actDerivedChannel:SetValue(frame1, actDerivedChannel:GetValue(0))
		for i=0, actChannel:CountKeys()-1 do
			actChannel:SetKeyInterpByID(i,MOHO.INTERP_LINEAR)
		end
	end

end

function AE_MixSmartbones:CorrectSmartbone(moho, smartbone)
	local corrFrame, actName = self:FindFrameAndAction(moho, smartbone, smartbone.fAngle)
	if corrFrame > 0 then 
		self:EvalSmartboneCorrection(moho, corrFrame, actName)
	else LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Góc không sử dụng", "Smartbone được chọn không có hành động cho góc của khung hình này (" .. (180 * smartbone.fAngle / math.pi) .. ")", "", "THOÁT")end
end

function AE_MixSmartbones:CollectKeyValues(moho, excludeList)
	local function has_value(tab, val)
		for k,v in pairs(tab) do 
			if v == val then return true end
		end
		return false
	end
	local keysCollection = {}
	for i, layer in AE_Utilities:IterateAllLayers(moho) do
		-------------------------------------
		--if not layer:IsReferencedLayer() then
		-------------------------------------
			if layer == moho.layer or layer:IsAncestorSelected() then
				local layerFrame = moho.frame + layer:TotalTimingOffset()
				for subId, channel in AE_Utilities:IterateLayerSubChannels(moho, layer) do
					if (not has_value(excludeList, channel)) and channel:HasKey(layerFrame) then
						local derivedChannel = AE_Utilities:GetDerivedChannel(moho,channel, true)
						if derivedChannel then
							local newValue = derivedChannel:GetValue(layerFrame)
							local v = {["channel"] = derivedChannel, ["keyVal"] = newValue, ["frame"] = layerFrame, ["layer"] = layer}	
							table.insert(keysCollection, v)
						end
					end
				end
			end
		-------------------------------------
		--end
		-------------------------------------
	end
	return keysCollection
end

function AE_MixSmartbones:EvalSmartboneCorrection(moho, corrFrame, actName)

	local keysCollection = self.keysCollection
	print("Số lượng phần tử trong keysCollection đã chỉnh sửa: " .. #self.keysCollection)
 --Dòng thông báo khi hoàn thành
	
	moho.layer:ActivateAction(actName)
	for k,v in pairs(keysCollection) do
		local oldValue = v.channel:GetValue(corrFrame) - v.channel:GetValue(0)
		v.channel:SetValue(corrFrame, v.keyVal + oldValue)
		v.channel:SetKeyInterp(corrFrame,MOHO.INTERP_LINEAR)
	end
	moho.layer:ActivateAction(nil)
	for k,v in pairs(keysCollection) do
		if not v.layer:IsReferencedLayer() then
			v.channel:DeleteKey(v.frame)
			--[[
			if self.replaceKeys > -1 and v.channel:GetValue(v.frame) ~= v.channel:GetValue(0) then
				if self.replaceKeys == 0 then
					self.replaceKeys = LM.GUI.Alert(
							LM.GUI.ALERT_INFO,
							"Animation found!",
							"Some channels would not display default values after key removing.",
							"Would You like to set default value keys instead?",
							"No, thanks",
							nil,
							"Yes, please"
						) - 1
				end
				if self.replaceKeys == 1 then
					v.channel:SetValue(v.frame, v.channel:GetValue(0))
				end
			end
			--]]
		end
	end
	
	return keysCollection
	
end

function AE_MixSmartbones:FindFrameAndAction(moho, smartbone, angle)
	local actName = smartbone:Name()
	local smartboneTrack = moho:ChannelAsAnimVal(smartbone.fAnimAngle:ActionByName(actName))
	local smartboneFrame, subFrame = AE_Utilities:FindSmartBoneFrame(angle, smartboneTrack)
	if smartboneFrame < 0 then
		actName = actName.." 2"
		if(smartbone.fAnimAngle:ActionByName(actName))then
			smartboneTrack = moho:ChannelAsAnimVal(smartbone.fAnimAngle:ActionByName(actName))
			smartboneFrame, subFrame = AE_Utilities:FindSmartBoneFrame(angle, smartboneTrack)
		end
	end
	if (subFrame-smartboneFrame) > 0.5 then smartboneFrame = smartboneFrame + 1 end
	return smartboneFrame, actName, smartboneTrack
end

function AE_MixSmartbones:RoundAngle(angle)
	local degrees = 180*angle/math.pi
	if math.abs(degrees-math.ceil(degrees)) <  math.abs(degrees-math.floor(degrees))then
		return math.ceil(degrees)
	else 
		return math.floor(degrees)
	end
end



