-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "RL_LostLayerTool"

-- **************************************************
-- General information about this script
-- **************************************************

RL_LostLayerTool = {}

RL_LostLayerTool.BASE_STR = 2370 --BASE_STR is a number to be used into the position value of "MOHO.Localize(position, default)", a function that returns a string located "in AnimeStudioProX.X.strings" file at the value given by "position" that returns the "default" string if it's not found.

function RL_LostLayerTool:Name()
	return "Layer Tool"
end

function RL_LostLayerTool:Version()
	return "20100708_1931_rc2"
end

function RL_LostLayerTool:Description()
	return "Kiểm soát các hiệu ứng/cài đặt lớp và di chuyển toàn bộ lớp (giữ <shift> để hạn chế, <alt> để di chuyển trục Z, <ctrl/cmd> để chỉnh sửa đường dẫn chuyển động"
end

function RL_LostLayerTool:Creator()
	return "(C) 2010 Ramon Lopez Verdu"
end

function RL_LostLayerTool:UILabel()
	return "Layer Tool"
end

-- **************************************************
-- Tool Preferences
-- **************************************************

function RL_LostLayerTool:LoadPrefs(prefs)
	self.angleTolerance = prefs:GetInt("RL_LostLayerTool.angleTolerance", 10)
end

function RL_LostLayerTool:SavePrefs(prefs)
	prefs:SetInt("RL_LostLayerTool.angleTolerance", self.angleTolerance)
end

function RL_LostLayerTool:ResetPrefs()
	self.angleTolerance = 10
end

-- **************************************************
-- Recurring values
-- **************************************************

RL_LostLayerTool.selCount = 1
RL_LostLayerTool.startVal = LM.Vector3:new_local()
RL_LostLayerTool.when = -10000
RL_LostLayerTool.TOLERANCE = 10

RL_LostLayerTool.dragCapture = false

RL_LostLayerTool.startClock = nil
RL_LostLayerTool.osDiffClockFrames = nil
RL_LostLayerTool.onMouseDownClock = nil
RL_LostLayerTool.onMouseDownFrame = nil
RL_LostLayerTool.mouseCapStatus = nil

RL_LostLayerTool.aboutWnd = nil

RL_LostLayerTool.dlogState = false

RL_LostLayerTool.dlog1State = false
RL_LostLayerTool.dlog1Paths = false

RL_LostLayerTool.dlog2State = false

RL_LostLayerTool.dlog3State = false
RL_LostLayerTool.dlog3RandomThanks = nil
RL_LostLayerTool.dlog3SpecialThanksLabels = {} --unnecessary??

-- **************************************************
-- Temp...
-- **************************************************

--moho.layer:SetVisible(false) --(to manage layers vivibility!)

-- **************************************************
-- The guts of this script
-- **************************************************

function RL_LostLayerTool:OnMouseDown(moho, mouseEvent)
	moho.document:PrepMultiUndo()
	moho.document:SetDirty()

	if (RL_LostLayerTool.dlog1State == true) or (RL_LostLayerTool.dlog2State == true) then
		return
	end

	self.selCount = moho.document:CountSelectedLayers()
	self.when = -10000
	if (mouseEvent.ctrlKey) then -- Not sure if this should require a modifier key or not...
		self.when = -20000
		local g = mouseEvent.view:Graphics()
		local m = LM.Matrix:new_local()
		local vec = LM.Vector2:new_local()
		local origin = moho.layer:Origin()
		local pt = LM.Point:new_local()
		local totalTimingOffset = moho.layer:TotalTimingOffset()
		-- First see if any keyframes were picked
		for i = 0, moho.layer.fTranslation:CountKeys() - 1 do
			local frame = moho.layer.fTranslation:GetKeyWhen(i)
			moho.layer:GetFullTransform(frame - totalTimingOffset, m, moho.document)
			vec:Set(origin.x, origin.y)
			m:Transform(vec)
			if (moho.layer.fTranslation:HasKey(frame)) then
				g:WorldToScreen(vec, pt)
				if (math.abs(pt.x - mouseEvent.startPt.x) < self.TOLERANCE and math.abs(pt.y - mouseEvent.startPt.y) < self.TOLERANCE) then
					self.when = frame
					break
				end
			end
		end
		-- If no keyframes were picked, try picking a random point along the curve.
		if (self.when <= -10000) then
			local startFrame = moho.layer.fTranslation:GetKeyWhen(0)
			local endFrame = moho.layer.fTranslation:Duration()
			if (endFrame > startFrame) then
				local vec3 = LM.Vector3:new_local()
				local oldVec3 = LM.Vector3:new_local()
				g:Clear(0, 0, 0, 0)
				g:SetColor(255, 255, 255)
				g:BeginPicking(mouseEvent.startPt, 4)
				for frame = startFrame, endFrame do
					moho.layer:GetFullTransform(frame - totalTimingOffset, m, moho.document)
					vec3:Set(origin.x, origin.y, 0)
					m:Transform(vec3)
					if (frame > startFrame) then
						g:DrawLine(oldVec3.x, oldVec3.y, vec3.x, vec3.y)
					end
					if (g:Pick()) then
						self.when = frame
						break
					end
					oldVec3:Set(vec3)
				end
				if (self.when > -10000) then -- We picked a point on the curve.
					if (self.selCount > 1) then
						return
					end
					moho.layer.fTranslation:AddKey(self.when)
				end
			end
		end
	end

	if (self.when == -20000) then
		return
	end

	self.startVal = {}
	if (self.when > -10000) then
		local startVal = LM.Vector3:new_local()
		startVal:Set(moho.layer.fTranslation:GetValue(self.when))
		table.insert(self.startVal, startVal)
	else
		self.startVal = {}
		for i = 0, self.selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			local startVal = LM.Vector3:new_local()
			startVal:Set(layer.fTranslation.value)
			table.insert(self.startVal, startVal)
			layer.fTranslation:AddKey(moho.frame + layer:TotalTimingOffset())
		end
	end

	mouseEvent.view:DrawMe()

	if (moho.frame > 0) and (self.dragCapture) and (not mouseEvent.ctrlKey)  then
		self.onMouseDownClock = os.clock() --print("onMouseDownClock: " .. self.onMouseDownClock)
		self.onMouseDownFrame = moho.frame

		self.mouseCapStatus = true

		if not (moho.layer.fTranslation:HasKey(moho.frame - 1)) then
			moho.layer.fTranslation:AddKey(moho.frame - 1)
		end
	end
end

function RL_LostLayerTool:OnMouseMoved(moho, mouseEvent)
	if (self.when == -20000) then
		return
	end
	local frame = self.when
	if (frame > -10000 and self.selCount > 1) then
		return
	end
	if (frame <= -10000) then
		frame = moho.frame
	end

	if (RL_LostLayerTool.dlog1State == true) or (RL_LostLayerTool.dlog2State == true) then
		return
	end

	--[[
	if (moho.frame >= 0) and (self.dragCapture) and (moho.frame >= moho.document:StartFrame()) and (moho.frame <= moho.document:EndFrame() -1) then
		local closestKey = moho.layer.fTranslation:GetClosestKeyID(moho.frame) --print("ClosestKey: " .. closestKey) --La key ID anterior m s cercana.
		local getKeyWhen = moho.layer.fTranslation:GetKeyWhen(closestKey) --print("getKeyWhen: " .. getKeyWhen) --El frame donde est  la key anterior m s cercana.

		for i = getKeyWhen, moho.frame - 1 do
			if not (moho.layer.fTranslation:HasKey(i)) then
				moho.layer.fTranslation:AddKey(i) --Aqu  est ba el fallooo!
			end
		end
	end--]]

	if (moho.document:IsOutsideViewEnabled()) then
		local v1 = LM.Vector3:new_local()
		local v2 = LM.Vector3:new_local()
		local vec = LM.Vector3:new_local()
		local m = LM.Matrix:new_local()

		for i = 0, self.selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)

			if (layer:Parent()) then
				layer:Parent():GetFullTransform(moho.frame, m, moho.document)
			else
				moho.document:GetOutsideViewMatrix(m)
			end
			if (layer:LayerParentBone() ~= -1 and layer:Parent() and layer:Parent():IsBoneType()) then
				local parentM = LM.Matrix:new_local()
				layer:GetParentBoneTransform(moho.frame, parentM, moho.document)
				m:Multiply(parentM)
			end
			m:Invert()
			mouseEvent.view:Graphics():ScreenToWorld(mouseEvent.startPt, v1)
			mouseEvent.view:Graphics():ScreenToWorld(mouseEvent.pt, v2)

			vec.x = v2.x - v1.x
			vec.y = v2.y - v1.y

			if (mouseEvent.shiftKey) then
				if (math.abs(vec.x) > math.abs(vec.y)) then
					v2.y = v1.y
				else
					v2.x = v1.x
				end
			end

			v1.z = -0.95
			v2.z = -0.95
			m:Transform(v1)
			m:Transform(v2)

			vec = self.startVal[i + 1] + v2 - v1
			layer.fTranslation:SetValue(frame + layer:TotalTimingOffset(), vec)
		end -- for i
	else
		for i = 0, self.selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer.fTranslation:SetValue(frame + layer:TotalTimingOffset(), self.startVal[i + 1])

			local layerM = LM.Matrix:new_local()
			local tempLayer = MOHO.MohoLayer:new_local()
			tempLayer.fTranslation:SetValue(0, layer.fTranslation.value)

			if (layer:Parent()) then
				local parentM = LM.Matrix:new_local()
				tempLayer:GetFullTransform(moho.frame, layerM, nil)
				layer:Parent():GetFullTransform(moho.frame, parentM, moho.document)
				layerM:Multiply(parentM)
				if (layer:LayerParentBone() ~= -1 and layer:Parent():IsBoneType()) then
					layer:GetParentBoneTransform(moho.frame, parentM, moho.document)
					layerM:Multiply(parentM)
				end
			else
				tempLayer:GetFullTransform(moho.frame, layerM, moho.document)
			end
			self.startVec = mouseEvent.view:Point2Vec(mouseEvent.startPt, layerM)
			self.nextVec = mouseEvent.view:Point2Vec(mouseEvent.pt, layerM)

			local vec = LM.Vector3:new_local()

			if (mouseEvent.altKey) then
				mouseEvent.view:Graphics():ScreenToWorld(mouseEvent.startPt, self.startVec)
				mouseEvent.view:Graphics():ScreenToWorld(mouseEvent.pt, self.nextVec)
				vec:Set(self.startVal[i + 1])
				vec.z = self.startVal[i + 1].z - (self.nextVec.y - self.startVec.y)
				layer.fTranslation:SetValue(frame + layer:TotalTimingOffset(), vec)

				if (layer:Parent()) then
					layer:Parent():DepthSort(moho.document)
				end
			else
				vec.x = self.nextVec.x - self.startVec.x
				vec.y = self.nextVec.y - self.startVec.y

				if (mouseEvent.shiftKey) then
					if (math.abs(vec.x) > math.abs(vec.y)) then
						vec.y = 0
					else
						vec.x = 0
					end
				end

				vec = vec + self.startVal[i + 1]
				layer.fTranslation:SetValue(frame + layer:TotalTimingOffset(), vec)
			end
		end -- for i
	end

	if (frame ~= moho.frame) then
		moho:SetCurFrame(moho.frame) -- force a refresh when editing a key at a different frame
	end

	moho.document:DepthSort()
	mouseEvent.view:DrawMe()

	if (moho.frame >= 0) and (self.dragCapture) and (not mouseEvent.ctrlKey) then
		local frameRate = moho.document:Fps()
		local exposureTime = 1/frameRate --print(exposureTime *1000)

		self.startClock = os.clock() --tonumber(string.format("%.2f\n", os.clock()))
		local osDiffClock = (self.startClock - self.onMouseDownClock)
		self.osDiffClockFrames = osDiffClock * frameRate

		local n = moho.layer.fTranslation:CountKeys()

		local closestKey = moho.layer.fTranslation:GetClosestKeyID(moho.frame) --Closest previous key ID
		local getKeyWhen = moho.layer.fTranslation:GetKeyWhen(closestKey) --Closest previous key frame

		local v1 = LM.Vector3:new_local()

		--LM.Snooze(exposureTime * 1000) --40

		if (osDiffClock - exposureTime) <= tonumber(string.format("%.3f\n", os.clock())) then
			if (self.mouseCapStatus) and (self.onMouseDownFrame == moho.document:StartFrame()) and (self.onMouseDownFrame + self.osDiffClockFrames) <= moho.document:EndFrame() then
				if (n > closestKey + 2) then --print(osDiffClockFrames - moho.frame)
					for i = moho.frame + 1, ((self.onMouseDownFrame + self.osDiffClockFrames) + 3) do --(frameRate / 5)
						if (moho.layer.fTranslation:HasKey(i)) then
							moho.layer.fTranslation:DeleteKey(i)
						end
					end
				end

				moho:SetCurFrame(self.onMouseDownFrame + self.osDiffClockFrames)

				local lastValue = moho.layer.fTranslation:GetValue(getKeyWhen)
				for i = getKeyWhen, (self.onMouseDownFrame + self.osDiffClockFrames) - 1 do
					if not (moho.layer.fTranslation:HasKey(i)) then
						moho.layer.fTranslation:SetValue(i, lastValue)
					end
				end

				if (self.onMouseDownFrame + self.osDiffClockFrames) >= (moho.document:EndFrame() - 1) then
					self.mouseCapStatus = false
					moho:Click()
				end

			elseif (self.mouseCapStatus) and (self.onMouseDownFrame ~= moho.document:StartFrame()) then
				if (n > closestKey + 2) then
					for i = moho.frame + 1, ((self.onMouseDownFrame + self.osDiffClockFrames) + 3) do
						if (moho.layer.fTranslation:HasKey(i)) then
							moho.layer.fTranslation:DeleteKey(i)
						end
					end
				end

				moho:SetCurFrame(self.onMouseDownFrame + self.osDiffClockFrames)

				local lastValue = moho.layer.fTranslation:GetValue(getKeyWhen)
				for i = getKeyWhen, (self.onMouseDownFrame + self.osDiffClockFrames) - 1 do
					if not (moho.layer.fTranslation:HasKey(i)) then
						moho.layer.fTranslation:SetValue(i, lastValue)
					end
				end
			end
		end

		moho:UpdateSelectedChannels()
	end
end

function RL_LostLayerTool:OnMouseUp(moho, mouseEvent)
	if (self.when == -2) then
		return
	end

	if (self.when < 0) then
		moho:NewKeyframe(CHANNEL_LAYER_T)
	end

	if (moho.frame >= 0) and (self.dragCapture) and (not mouseEvent.ctrlKey)  then
		self.startClock = os.clock()
		local osDiffClock = (self.startClock - self.onMouseDownClock)
		self.osDiffClockFrames = osDiffClock * moho.document:Fps()

		--[[
		for i = moho.layer.fTranslation:GetKeyWhen(self.onMouseDownFrame), (moho.frame) do
			if ((i ~= 0) and (i % 2 ~= 1)) then
				if (self.selPoint.fAnimPos:HasKey(i - 1)) then
					self.selPoint.fAnimPos:DeleteKey(i)
				end
			end
		end--]]

		if (self.angleTolerance > 0 and (moho.frame > self.onMouseDownFrame + 2)) then
			-- adaptive freehand capture, remove keys on "straight" sections of the motion curve
			local adaptiveLimit = math.cos(math.rad(self.angleTolerance))

			local layerPosYX1_1 = LM.Vector2:new_local()
			layerPosYX1_1:Set(moho.layer.fTranslation:GetValue(self.onMouseDownFrame + 1).x, moho.layer.fTranslation:GetValue(self.onMouseDownFrame + 1).y) --print(layerPosYX.x .. " / " .. layerPosYX.y)
			local layerPosYX1_2 = LM.Vector2:new_local()
			layerPosYX1_2:Set(moho.layer.fTranslation:GetValue(self.onMouseDownFrame).x, moho.layer.fTranslation:GetValue(self.onMouseDownFrame).y) --print(layerPosYX.x .. " / " .. layerPosYX.y)
			local runningVec = layerPosYX1_1 - layerPosYX1_2

			--local runningVec = moho.layer.fTranslation:GetValue(self.onMouseDownFrame + 1) - moho.layer.fTranslation:GetValue(self.onMouseDownFrame)
			runningVec:NormMe()

			local i = self.onMouseDownFrame + 2

			for i = self.onMouseDownFrame + 2,  moho.frame do
				local layerPosYX2_1 = LM.Vector2:new_local()
				layerPosYX2_1:Set(moho.layer.fTranslation:GetValue(i).x, moho.layer.fTranslation:GetValue(i).y) --print(layerPosYX.x .. " / " .. layerPosYX.y)
				local layerPosYX2_2 = LM.Vector2:new_local()
				layerPosYX2_2:Set(moho.layer.fTranslation:GetValue(i - 1).x, moho.layer.fTranslation:GetValue(i - 1).y) --print(layerPosYX.x .. " / " .. layerPosYX.y)
				local testVec = layerPosYX2_1 - layerPosYX2_2

				testVec:NormMe()
				if (runningVec:Dot(testVec) > adaptiveLimit) then
					moho.layer.fTranslation:DeleteKey(i - 1)
				else
					runningVec = testVec
				end
			end
		end--]]

		if (self.onMouseDownFrame == moho.document:StartFrame()) and ((self.onMouseDownFrame + self.osDiffClockFrames) >= moho.document:EndFrame() - 1) then
			moho:SetCurFrame(self.onMouseDownFrame)
		end
	end
	MOHO.Redraw()
	moho:UpdateUI()
end

function RL_LostLayerTool:OnKeyDown(moho, keyEvent)
	if (keyEvent.ctrlKey) then
		local inc = 1
		if (keyEvent.shiftKey) then
			inc = 10
		end

		local m = LM.Matrix:new_local()
		moho.layer:GetFullTransform(moho.frame, m, moho.document)

		local fakeME = {}
		fakeME.view = keyEvent.view
		fakeME.pt = LM.Point:new_local()
		fakeME.pt:Set(keyEvent.view:Graphics():Width() / 2, keyEvent.view:Graphics():Height() / 2)
		fakeME.startPt = LM.Point:new_local()
		fakeME.startPt:Set(fakeME.pt)
		fakeME.vec = keyEvent.view:Point2Vec(fakeME.pt, m)
		fakeME.startVec = keyEvent.view:Point2Vec(fakeME.pt, m)
		fakeME.shiftKey = false
		fakeME.ctrlKey = false
		fakeME.altKey = keyEvent.altKey
		fakeME.penPressure = 0

		if (keyEvent.keyCode == LM.GUI.KEY_UP) then
			self:OnMouseDown(moho, fakeME)
			fakeME.pt.y = fakeME.pt.y - inc
			fakeME.vec = keyEvent.view:Point2Vec(fakeME.pt, m)
			self:OnMouseMoved(moho, fakeME)
			self:OnMouseUp(moho, fakeME)
		elseif (keyEvent.keyCode == LM.GUI.KEY_DOWN) then
			self:OnMouseDown(moho, fakeME)
			fakeME.pt.y = fakeME.pt.y + inc
			fakeME.vec = keyEvent.view:Point2Vec(fakeME.pt, m)
			self:OnMouseMoved(moho, fakeME)
			self:OnMouseUp(moho, fakeME)
		elseif (keyEvent.keyCode == LM.GUI.KEY_LEFT) then
			self:OnMouseDown(moho, fakeME)
			fakeME.pt.x = fakeME.pt.x - inc
			fakeME.vec = keyEvent.view:Point2Vec(fakeME.pt, m)
			self:OnMouseMoved(moho, fakeME)
			self:OnMouseUp(moho, fakeME)
		elseif (keyEvent.keyCode == LM.GUI.KEY_RIGHT) then
			self:OnMouseDown(moho, fakeME)
			fakeME.pt.x = fakeME.pt.x + inc
			fakeME.vec = keyEvent.view:Point2Vec(fakeME.pt, m)
			self:OnMouseMoved(moho, fakeME)
			self:OnMouseUp(moho, fakeME)
		end
	end
end

function RL_LostLayerTool:DrawMe(moho, view)
	if (not self.displayOn) then
		return
	end

	local startFrame = moho.layer.fTranslation:GetKeyWhen(0)
	local endFrame = moho.layer.fTranslation:Duration()

	if (endFrame > startFrame) then
		local g = view:Graphics()
		local m = LM.Matrix:new_local()
		local vec = LM.Vector3:new_local()
		local oldVec = LM.Vector3:new_local()
		local origin = moho.layer:Origin()
		local totalTimingOffset = moho.layer:TotalTimingOffset()

		g:SetColor(102, 152, 203)
		g:SetSmoothing(true)
		for frame = startFrame, endFrame do
			moho.layer:GetFullTransform(frame - totalTimingOffset, m, moho.document)
			vec:Set(origin.x, origin.y, 0)
			m:Transform(vec)
			if (frame > startFrame) then
				g:DrawLine(oldVec.x, oldVec.y, vec.x, vec.y)
			end
			if (moho.layer.fTranslation:HasKey(frame)) then
				g:DrawFatMarker(vec.x, vec.y, 3)
			else
				g:DrawFatMarker(vec.x, vec.y, 1)
			end
			oldVec:Set(vec)
		end
		g:SetSmoothing(false)
	end
end

-- **************************************************
-- Layer Effects Dialog (Test: AnimVal fShadingNoiseAmp, fShadingNoiseScale; (Example: ownLayer.fShadowNoiseAmp:SetValue(frame, AnimVal)))
-- **************************************************
local RL_LostLayerToolShadowsDialog = {}

function RL_LostLayerToolShadowsDialog:new()
	local d = LM.GUI.SimpleDialog("Shadow Options", RL_LostLayerToolShadowsDialog)
	local l = d:GetLayout()

	l:AddPadding(-13)
	l:Indent(-5)

	l:PushH(LM.GUI.ALIGN_FILL, 4)
		l:PushV(LM.GUI.ALIGN_TOP, 2)
			l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_closeWindow", "Close", false, LM.GUI.MSG_CANCEL), LM.GUI.ALIGN_CENTER, 6)

			d.shadowsLabel = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_shadowsLabel_v", "Shadows Settings", false, 0)
			l:AddChild(d.shadowsLabel)
		l:Pop()

		l:Unindent(-5)
		l:AddPadding(-7)

		l:PushH(LM.GUI.ALIGN_TOP, 4)
			l:PushV(LM.GUI.ALIGN_RIGHT, 1)  --Vertical 1
				l:PushH(LM.GUI.ALIGN_BOTTOM, 4) --2
					l:PushV(LM.GUI.ALIGN_TOP, 4)
						l:PushH(LM.GUI.ALIGN_TOP, 1)
							d.shadowSettingsLabel = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_layerShadow_h", "Layer Shadow Settings", false, 0)
							l:AddChild(d.shadowSettingsLabel, LM.GUI.ALIGN_RIGHT)
						l:Pop()

						l:AddPadding(-2)

						l:PushH(LM.GUI.ALIGN_BOTTOM, 0)
							d.shadowDirectionButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_shadowAngle", "Shadow Direction", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadowDirectionButton, LM.GUI.ALIGN_TOP, 5) --10

							l:AddPadding(-14) -- -11

							d.shadowDirection = LM.GUI.AngleWidget(RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadowDirection, LM.GUI.ALIGN_CENTER)
						l:Pop()

						l:AddPadding(1)

						l:PushH(LM.GUI.ALIGN_LEFT, 0)
							d.shadowColorButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_color", "Shadow Color", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadowColorButton, LM.GUI.ALIGN_FILL, 0)

							l:AddPadding(0)

							d.shadowColor = LM.GUI.ColorSwatch(true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadowColor)
						l:Pop()
					l:Pop()

					l:PushV(LM.GUI.ALIGN_RIGHT, 1)
						l:PushH(LM.GUI.ALIGN_RIGHT, 0)
							d.shadowOffsetButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_shadowOffset", "Shadow Offset", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadowOffsetButton)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.shadowOffset = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
								d.shadowOffset:SetWheelInc(1)
								l:AddChild(d.shadowOffset)
							l:Pop()
						l:Pop()
						l:AddPadding(-3)
						l:PushH(LM.GUI.ALIGN_RIGHT, 0)
							d.shadowBlurButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_shadowBlur", "Shadow Blur", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadowBlurButton)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.shadowBlur = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
								d.shadowBlur:SetWheelInc(1)
								l:AddChild(d.shadowBlur)
							l:Pop()
						l:Pop()
						l:AddPadding(-3)
						l:PushH(LM.GUI.ALIGN_RIGHT, 0)
							d.shadowExpansionButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_shadowExpan", "Shadow Expansion", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadowExpansionButton)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.shadowExpansion = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
								d.shadowExpansion:SetWheelInc(1)
								l:AddChild(d.shadowExpansion)
							l:Pop()
						l:Pop()

						l:AddPadding(4)
						--[[
						l:PushH(LM.GUI.ALIGN_RIGHT, 0)

							l:AddPadding(-15)
							l:PushV(LM.GUI.ALIGN_CENTER, 1)
								l:AddPadding(6)
								l:AddChild(LM.GUI.Divider(false), LM.GUI.ALIGN_RIGHT, 0)
								l:AddPadding(-11)
								l:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL, 0)
								l:AddPadding(-10)
								l:AddChild(LM.GUI.Divider(false), LM.GUI.ALIGN_RIGHT, 0)
							l:Pop()
							l:AddPadding(-13)

							--l:AddChild(LM.GUI.StaticText("["), LM.GUI.ALIGN_CENTER , 0)--]]

						l:PushH(LM.GUI.ALIGN_RIGHT, 0)
							d.shadowNoiseAmpButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_shadowNoiseAmp", "Shadow Noise Amplitude (Experimental!)", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadowNoiseAmpButton, LM.GUI.ALIGN_BOTTOM)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.shadowNoiseAmp = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
								d.shadowNoiseAmp:SetWheelInc(1)
								l:AddChild(d.shadowNoiseAmp, LM.GUI.ALIGN_BOTTOM)
							l:Pop()
						l:Pop()

						l:AddPadding(-3)

						l:PushH(LM.GUI.ALIGN_RIGHT, 0)
							--l:AddChild(LM.GUI.StaticText("."), LM.GUI.ALIGN_CENTER, -4)
							--d.shadowNoiseLink = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_linkSmall", nil, false, LM.GUI.MSG_OK)
							--l:AddChild(d.shadowNoiseLink)
							d.shadowNoiseScaleButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_shadowNoiseScale", "Shadow Noise Scale (Experimental!)", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadowNoiseScaleButton)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.shadowNoiseScale = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
								d.shadowNoiseScale:SetWheelInc(1)
								l:AddChild(d.shadowNoiseScale)
							l:Pop()
						l:Pop()
					l:Pop()
				l:Pop()
			l:Pop()
		l:Pop()

		l:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL, 0)

		l:PushH(LM.GUI.ALIGN_TOP, 4)
			l:PushV(LM.GUI.ALIGN_RIGHT, 1) --Vertical 3
				l:PushH(LM.GUI.ALIGN_BOTTOM, 4)
					l:PushV(LM.GUI.ALIGN_TOP, 4)
						l:PushH(LM.GUI.ALIGN_RIGHT, 1)
							--l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_closeWindow", "Close", false, LM.GUI.MSG_CANCEL), LM.GUI.ALIGN_LEFT)
							d.shadingSettingsLabel = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_layerShading_h", "Layer Shading Settings", false, 0)
							l:AddChild(d.shadingSettingsLabel, LM.GUI.ALIGN_RIGHT)
						l:Pop()

						l:AddPadding(-2)

						l:PushH(LM.GUI.ALIGN_BOTTOM, 0)
							d.shadingDirectionButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_shadingAngle", "Shading Direction", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadingDirectionButton, LM.GUI.ALIGN_TOP, 5)
							l:AddPadding(-14)
							d.shadingDirection = LM.GUI.AngleWidget(RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadingDirection, LM.GUI.ALIGN_CENTER)
						l:Pop()

						l:AddPadding(1)

						l:PushH(LM.GUI.ALIGN_LEFT, 0)
							d.shadingColorButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_color", "Shading Color", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadingColorButton, LM.GUI.ALIGN_FILL, 0)

							l:AddPadding(0)

							d.shadingColor = LM.GUI.ColorSwatch(true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadingColor)
						l:Pop()
					l:Pop()

					l:PushV(LM.GUI.ALIGN_RIGHT, 1)
						l:PushH(LM.GUI.ALIGN_RIGHT, 0)
							d.shadingOffsetButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_shadingOffset", "Shading Offset", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadingOffsetButton)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.shadingOffset = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
								d.shadingOffset:SetWheelInc(1)
								l:AddChild(d.shadingOffset)
							l:Pop()
						l:Pop()
						l:AddPadding(-3)
						l:PushH(LM.GUI.ALIGN_RIGHT, 0)
							d.shadingBlurButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_shadingBlur", "Shading Blur", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadingBlurButton)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.shadingBlur = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
								d.shadingBlur:SetWheelInc(1)
								l:AddChild(d.shadingBlur)
							l:Pop()
						l:Pop()
						l:AddPadding(-3)
						l:PushH(LM.GUI.ALIGN_RIGHT, 0)
							d.shadingContractionButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_shadingContract", "Shading Contraction", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadingContractionButton)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.shadingContraction = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
								d.shadingContraction:SetWheelInc(1)
								l:AddChild(d.shadingContraction)
							l:Pop()
						l:Pop()
						l:AddPadding(4)
						l:PushH(LM.GUI.ALIGN_BOTTOM, 0)
							d.shadingNoiseAmpButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_shadingNoiseAmp", "Shading Noise Amplitude (Experimental!)", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadingNoiseAmpButton, LM.GUI.ALIGN_BOTTOM)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.shadingNoiseAmp = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
								d.shadingNoiseAmp:SetWheelInc(1)
								l:AddChild(d.shadingNoiseAmp, LM.GUI.ALIGN_BOTTOM)
							l:Pop()
						l:Pop()
						l:AddPadding(-3)
						l:PushH(LM.GUI.ALIGN_CENTER, 0)
							d.shadingNoiseScaleButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_shadingNoiseScale", "Shading Noise Scale (Experimental!)", true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.shadingNoiseScaleButton)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.shadingNoiseScale = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
								d.shadingNoiseScale:SetWheelInc(1)
								l:AddChild(d.shadingNoiseScale)
							l:Pop()
						l:Pop()
					l:Pop()
				l:Pop()
			l:Pop()
		l:Pop()

		l:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL, 0)

		l:PushH(LM.GUI.ALIGN_TOP, 4)
			l:PushV(LM.GUI.ALIGN_RIGHT, 1)  --Vertical 1

				l:PushH(LM.GUI.ALIGN_TOP, 1)
					d.perspSettingsLabel = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_perspShadow_h", "3D Shadow Settings", false, 0)
					l:AddChild(d.perspSettingsLabel, LM.GUI.ALIGN_RIGHT)
				l:Pop()

				l:AddPadding(1)

				l:PushV(LM.GUI.ALIGN_RIGHT, 1)
					l:PushH(LM.GUI.ALIGN_RIGHT, 0)
						d.perspBlurButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_perspBlur", "Perspective Blur", true, RL_LostLayerTool.DLOG_CHANGE)
						l:AddChild(d.perspBlurButton)
						l:PushH(LM.GUI.ALIGN_CENTER, 0)
							l:AddPadding(-2)
							d.perspBlur = LM.GUI.TextControl(0, "00.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
							d.perspBlur:SetWheelInc(1)
							l:AddChild(d.perspBlur)
						l:Pop()
					l:Pop()
					l:AddPadding(-3)
					l:PushH(LM.GUI.ALIGN_RIGHT, 0)
						d.perspScaleButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_perspScale", "Perspective Scale", true, RL_LostLayerTool.DLOG_CHANGE)
						l:AddChild(d.perspScaleButton)
						l:PushH(LM.GUI.ALIGN_CENTER, 0)
							l:AddPadding(-2)
							d.perspScale = LM.GUI.TextControl(0, "00.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_FLOAT)
							d.perspScale:SetWheelInc(1)
							l:AddChild(d.perspScale)
						l:Pop()
					l:Pop()
					l:AddPadding(-3)
					l:PushH(LM.GUI.ALIGN_RIGHT, 0)
						d.perspShearButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_perspShear", "Perspective Shear", true, RL_LostLayerTool.DLOG_CHANGE)
						l:AddChild(d.perspShearButton)
						l:PushH(LM.GUI.ALIGN_CENTER, 0)
							l:AddPadding(-2)
							d.perspShear = LM.GUI.TextControl(0, "00.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_FLOAT)
							d.perspShear:SetWheelInc(1)
							l:AddChild(d.perspShear)
						l:Pop()
					l:Pop()

					l:AddPadding(1)

					l:PushH(LM.GUI.ALIGN_LEFT, 0)
						d.perspColorButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LSB_color", "Perspective Color", true, RL_LostLayerTool.DLOG_CHANGE)
						l:AddChild(d.perspColorButton, LM.GUI.ALIGN_FILL, 0)

						l:PushH(LM.GUI.ALIGN_CENTER, 0)
							l:AddPadding(0)
							d.perspColor = LM.GUI.ColorSwatch(true, RL_LostLayerTool.DLOG_CHANGE)
							l:AddChild(d.perspColor)
						l:Pop()
					l:Pop()
				l:Pop()

			l:Pop()
		l:Pop()

		l:AddPadding(-2)

		l:PushV(LM.GUI.ALIGN_TOP, 0)
			d.motionBlurLabel = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_MB_label_v", "Motion Blur Settings", false, 0)
			l:AddChild(d.motionBlurLabel)
		l:Pop()

		l:AddPadding(-5)

		l:PushH(LM.GUI.ALIGN_TOP, 4)
			l:PushV(LM.GUI.ALIGN_LEFT, 0)

				l:PushH(LM.GUI.ALIGN_LEFT, 0)
					d.mbFrameCountButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_MBB_fCount", "Frame count", true, RL_LostLayerTool.DLOG_CHANGE)
					l:AddChild(d.mbFrameCountButton)
					l:PushH(LM.GUI.ALIGN_CENTER, 0)
						l:AddPadding(-2)
						d.mbFrameCount = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
						d.mbFrameCount:SetWheelInc(1)
						l:AddChild(d.mbFrameCount)
					l:Pop()
				l:Pop()

				l:AddPadding(-1)

				l:PushH(LM.GUI.ALIGN_LEFT, 0)
					d.mbFrameSkipButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_MBB_fSkip", "Frame skip", true, RL_LostLayerTool.DLOG_CHANGE)
					l:AddChild(d.mbFrameSkipButton)
					l:PushH(LM.GUI.ALIGN_CENTER, 0)
						l:AddPadding(-2)
						d.mbFrameSkip = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
						d.mbFrameSkip:SetWheelInc(1)
						l:AddChild(d.mbFrameSkip)
					l:Pop()
				l:Pop()

				l:AddPadding(3)

				l:PushH(LM.GUI.ALIGN_LEFT, 0)
					d.mbStartOpButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_MBB_startOp", "Start Opacity (%)", true, RL_LostLayerTool.DLOG_CHANGE)
					l:AddChild(d.mbStartOpButton)
					l:PushH(LM.GUI.ALIGN_CENTER, 0)
						l:AddPadding(-2)
						d.mbStartOp = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
						d.mbStartOp:SetWheelInc(1)
						l:AddChild(d.mbStartOp)
					l:Pop()
				l:Pop()

				l:AddPadding(-1)

				l:PushH(LM.GUI.ALIGN_LEFT, 0)
					d.mbEndOpButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_MBB_endOp", "End opacity (%)", true, RL_LostLayerTool.DLOG_CHANGE)
					l:AddChild(d.mbEndOpButton)
					l:PushH(LM.GUI.ALIGN_CENTER, 0)
						l:AddPadding(-2)
						d.mbEndOp = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT)
						d.mbEndOp:SetWheelInc(1)
						l:AddChild(d.mbEndOp)
					l:Pop()
				l:Pop()

				l:AddPadding(3)

				l:PushH(LM.GUI.ALIGN_LEFT, 0)
						d.mbRadiusButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_MBB_blur", "Blur radius", true, RL_LostLayerTool.DLOG_CHANGE)
						l:AddChild(d.mbRadiusButton)
					--l:PushH(LM.GUI.ALIGN_CENTER, 0)
						l:AddPadding(-2)
						d.mbRadius = LM.GUI.TextControl(0, "0.0", RL_LostLayerTool.DLOG_CHANGE, LM.GUI.FIELD_UINT) --32
						d.mbRadius:SetWheelInc(1)
						l:AddChild(d.mbRadius)
					--l:Pop()
				l:Pop()
			l:Pop()
		l:Pop()
	l:Pop()

	--l:AddChild(LM.GUI.Button("X", LM.GUI.MSG_CANCEL))
	--d.active= false
	return d

end

function RL_LostLayerToolShadowsDialog:UpdateWidgets()
	if (self.document and self.layer) then

		--self.blurred:SetValue(moho:DocToPixel(moho.layer.fBlur.value)) --Convert the coordinates into a working value to be showed in text field!

		-- ************* Shadow Control **************
		self.shadowsLabel:Enable(self.layer.fLayerShadow.value or self.layer.fLayerShading.value or self.layer.fPerspectiveShadow.value)

		self.shadowDirectionButton:SetValue(self.activeLayer.fShadowAngle:HasKey(self.layerFrame))
		self.shadowDirection:SetValue(self.activeLayer.fShadowAngle.value)
		self.shadowOffsetButton:SetValue(self.activeLayer.fShadowOffset:HasKey(self.layerFrame))
		self.shadowOffset:SetValue(self.activeLayer.fShadowOffset.value * self.document:Height()) --moho.document:Height()
		self.shadowBlurButton:SetValue(self.activeLayer.fShadowBlur:HasKey(self.layerFrame))
		self.shadowBlur:SetValue(self.activeLayer.fShadowBlur.value * self.document:Height())
		self.shadowExpansionButton:SetValue(self.activeLayer.fShadowExpansion:HasKey(self.layerFrame))
		self.shadowExpansion:SetValue(self.activeLayer.fShadowExpansion.value * self.document:Height())
		self.shadowNoiseAmpButton:SetValue(self.activeLayer.fShadowNoiseAmp:HasKey(self.layerFrame))
		self.shadowNoiseAmp:SetValue(self.activeLayer.fShadowNoiseAmp.value * self.document:Height())
		self.shadowNoiseScaleButton:SetValue(self.activeLayer.fShadowNoiseScale:HasKey(self.layerFrame))
		self.shadowNoiseScale:SetValue(self.activeLayer.fShadowNoiseScale.value)
		self.shadowColorButton:SetValue(self.activeLayer.fShadowColor:HasKey(self.layerFrame)) --d.shadowColorButton
		self.shadowColor:SetValue(self.activeLayer.fShadowColor.value)

		self.shadowSettingsLabel:Enable(self.layer.fLayerShadow.value)
		self.shadowDirectionButton:Enable(self.layer.fLayerShadow.value)
		self.shadowDirection:Enable(self.layer.fLayerShadow.value)
		self.shadowOffsetButton:Enable(self.layer.fLayerShadow.value)
		self.shadowOffset:Enable(self.layer.fLayerShadow.value)
		self.shadowBlurButton:Enable(self.layer.fLayerShadow.value)
		self.shadowBlur:Enable(self.layer.fLayerShadow.value)
		self.shadowExpansionButton:Enable(self.layer.fLayerShadow.value)
		self.shadowExpansion:Enable(self.layer.fLayerShadow.value)
		self.shadowNoiseAmpButton:Enable(self.layer.fLayerShadow.value)
		self.shadowNoiseAmp:Enable(self.layer.fLayerShadow.value)
		self.shadowNoiseScaleButton:Enable(self.layer.fLayerShadow.value)
		--self.shadowNoiseLink:Enable(false)
		self.shadowNoiseScale:Enable(self.layer.fLayerShadow.value)
		self.shadowColorButton:Enable(self.layer.fLayerShadow.value)
		self.shadowColor:Enable(self.layer.fLayerShadow.value)

		-- ************* Shading Control **************
		self.shadingDirectionButton:SetValue(self.activeLayer.fShadingAngle:HasKey(self.layerFrame))
		self.shadingDirection:SetValue(self.activeLayer.fShadingAngle.value)
		self.shadingOffsetButton:SetValue(self.activeLayer.fShadingOffset:HasKey(self.layerFrame))
		self.shadingOffset:SetValue(self.activeLayer.fShadingOffset.value * self.document:Height())
		self.shadingBlurButton:SetValue(self.activeLayer.fShadingBlur:HasKey(self.layerFrame))
		self.shadingBlur:SetValue(self.activeLayer.fShadingBlur.value * self.document:Height())
		self.shadingContractionButton:SetValue(self.activeLayer.fShadingContraction:HasKey(self.layerFrame))
		self.shadingContraction:SetValue(self.activeLayer.fShadingContraction.value * self.document:Height())
		self.shadingNoiseAmpButton:SetValue(self.activeLayer.fShadingNoiseAmp:HasKey(self.layerFrame))
		self.shadingNoiseAmp:SetValue(self.activeLayer.fShadingNoiseAmp.value * self.document:Height())
		self.shadingNoiseScaleButton:SetValue(self.activeLayer.fShadingNoiseScale:HasKey(self.layerFrame))
		self.shadingNoiseScale:SetValue(self.activeLayer.fShadingNoiseScale.value)
		self.shadingColorButton:SetValue(self.activeLayer.fShadingColor:HasKey(self.layerFrame))
		self.shadingColor:SetValue(self.activeLayer.fShadingColor.value)

		self.shadingSettingsLabel:Enable(self.layer.fLayerShading.value)
		self.shadingDirectionButton:Enable(self.layer.fLayerShading.value)
		self.shadingDirection:Enable(self.layer.fLayerShading.value)
		self.shadingOffsetButton:Enable(self.layer.fLayerShading.value)
		self.shadingOffset:Enable(self.layer.fLayerShading.value)
		self.shadingBlurButton:Enable(self.layer.fLayerShading.value)
		self.shadingBlur:Enable(self.layer.fLayerShading.value)
		self.shadingContractionButton:Enable(self.layer.fLayerShading.value)
		self.shadingNoiseAmpButton:Enable(self.layer.fLayerShading.value)
		self.shadingNoiseAmp:Enable(self.layer.fLayerShading.value)
		self.shadingNoiseScaleButton:Enable(self.layer.fLayerShading.value)
		--self.shadingNoiseLink:Enable(false)
		self.shadingNoiseScale:Enable(self.layer.fLayerShading.value)
		self.shadingContraction:Enable(self.layer.fLayerShading.value)
		self.shadingColorButton:Enable(self.layer.fLayerShading.value)
		self.shadingColor:Enable(self.layer.fLayerShading.value)

		-- ************* Perspective Control **************
		self.perspBlurButton:SetValue(self.activeLayer.fPerspectiveBlur:HasKey(self.layerFrame))
		self.perspBlur:SetValue(self.activeLayer.fPerspectiveBlur.value * self.document:Height()) --moho.document:Height()
		self.perspScaleButton:SetValue(self.activeLayer.fPerspectiveScale:HasKey(self.layerFrame))
		self.perspScale:SetValue(self.activeLayer.fPerspectiveScale.value)
		self.perspShearButton:SetValue(self.activeLayer.fPerspectiveShear:HasKey(self.layerFrame))
		self.perspShear:SetValue(self.activeLayer.fPerspectiveShear.value)
		self.perspColorButton:SetValue(self.activeLayer.fPerspectiveColor:HasKey(self.layerFrame)) --d.shadowColorButton
		self.perspColor:SetValue(self.activeLayer.fPerspectiveColor.value)

		self.perspSettingsLabel:Enable(self.layer.fPerspectiveShadow.value)
		self.perspBlurButton:Enable(self.layer.fPerspectiveShadow.value)
		self.perspBlur:Enable(self.layer.fPerspectiveShadow.value)
		self.perspScaleButton:Enable(self.layer.fPerspectiveShadow.value)
		self.perspScale:Enable(self.layer.fPerspectiveShadow.value)
		self.perspShearButton:Enable(self.layer.fPerspectiveShadow.value)
		self.perspShear:Enable(self.layer.fPerspectiveShadow.value)
		self.perspColorButton:Enable(self.layer.fPerspectiveShadow.value)
		self.perspColor:Enable(self.layer.fPerspectiveShadow.value)

		-- ************* Motion Blur Control **************
		self.mbFrameCountButton:SetValue(self.activeLayer.fMotionBlurFrames:HasKey(self.layerFrame))
		self.mbFrameCount:SetValue(self.activeLayer.fMotionBlurFrames.value)
		self.mbFrameSkipButton:SetValue(self.activeLayer.fMotionBlurSkip:HasKey(self.layerFrame))
		self.mbFrameSkip:SetValue(self.activeLayer.fMotionBlurSkip.value)
		self.mbStartOpButton:SetValue(self.activeLayer.fMotionBlurAlphaStart:HasKey(self.layerFrame))
		self.mbStartOp:SetValue(self.activeLayer.fMotionBlurAlphaStart.value * 100)
		self.mbEndOpButton:SetValue(self.activeLayer.fMotionBlurAlphaEnd:HasKey(self.layerFrame))
		self.mbEndOp:SetValue(self.activeLayer.fMotionBlurAlphaEnd.value * 100)
		self.mbRadiusButton:SetValue(self.activeLayer.fMotionBlurRadius:HasKey(self.layerFrame))
		self.mbRadius:SetValue(self.activeLayer.fMotionBlurRadius.value * self.document:Height())

		self.motionBlurLabel:Enable(self.layer.fMotionBlur.value)
		self.mbFrameCountButton:Enable(self.layer.fMotionBlur.value)
		self.mbFrameCount:Enable(self.layer.fMotionBlur.value)
		self.mbFrameSkipButton:Enable(self.layer.fMotionBlur.value)
		self.mbFrameSkip:Enable(self.layer.fMotionBlur.value)
		self.mbStartOpButton:Enable(self.layer.fMotionBlur.value)
		self.mbStartOp:Enable(self.layer.fMotionBlur.value)
		self.mbEndOpButton:Enable(self.layer.fMotionBlur.value)
		self.mbEndOp:Enable(self.layer.fMotionBlur.value)
		self.mbRadiusButton:Enable(self.layer.fMotionBlur.value)
		self.mbRadius:Enable(self.layer.fMotionBlur.value)
	end
end

function RL_LostLayerToolShadowsDialog:OnOK()
	self:HandleMessage(RL_LostLayerTool.DLOG_CHANGE) -- send this final message in case the user is in the middle of editing some value
end

function RL_LostLayerToolShadowsDialog:HandleMessage(msg)
	if (not (self.document and self.layer)) then
		return
	end

	if ((msg == RL_LostLayerTool.DLOG_CHANGE) or (msg == LM.GUI.MSG_CANCEL)) then --Testing the (msg == LM.GUI.MSG_CANCEL) part.
		self.document:PrepUndo(self.layer) -- MEND!
		self.document:SetDirty()

		local selCount = self.document:CountSelectedLayers()

	-- ****************** Shadow Normalized Variables *******************
		shadowOffsetButtonValue = self.layer.fShadowOffset:HasKey(self.layerFrame)
		fShadowOffsetValue = LM.Round(self.layer.fShadowOffset.value * self.document:Height())
		--fShadowOffsetValue = self.moho:DocToPixel(self.layer.fShadowOffset.value) print(fShadowOffsetValue) --AS killer...
		--fShadowOffsetValue = self.moho:PixelToDoc(self.layer.fShadowOffset:GetValue(self.layerFrame)) print(fShadowOffsetValue) --AS killer...

		--if (type(self.shadowOffset:Value()) ~= "number") then
			--selfShadowOffsetValue = 0
		--else
			selfShadowOffsetValue = LM.Round(self.shadowOffset:Value())
		--end

		shadowBlurButtonValue = self.layer.fShadowBlur:HasKey(self.layerFrame)
		fShadowBlurValue = LM.Round(self.layer.fShadowBlur.value * self.document:Height())
		selfShadowBlurValue = LM.Round(self.shadowBlur:Value())

		shadowExpansionButtonValue = self.layer.fShadowExpansion:HasKey(self.layerFrame)
		fShadowExpansionValue = LM.Round(self.layer.fShadowExpansion.value * self.document:Height())
		selfShadowExpansionValue = LM.Round(self.shadowExpansion:Value())

		shadowNoiseAmpButtonValue = self.layer.fShadowNoiseAmp:HasKey(self.layerFrame)
		fShadowNoiseAmpValue = LM.Round(self.layer.fShadowNoiseAmp.value * self.document:Height())
		selfShadowNoiseAmpValue = LM.Round(self.shadowNoiseAmp:Value())

		shadowNoiseScaleButtonValue = self.layer.fShadowNoiseScale:HasKey(self.layerFrame)
		fShadowNoiseScaleValue = LM.Round(self.layer.fShadowNoiseScale.value)
		selfShadowNoiseScaleValue = LM.Round(self.shadowNoiseScale:Value())

		shadowDirectionButtonValue = self.layer.fShadowAngle:HasKey(self.layerFrame)

		shadowColorButtonValue = self.layer.fShadowColor:HasKey(self.layerFrame)
		fShadowColorValue = self.activeLayer.fShadowColor.value --print(fShadowColorValue.a)
		selfShadowColorValue = self.shadowColor:Value() --print(selfShadowColorValue.a)

	-- ****************** Shading Normalized Variables *******************
		shadingOffsetButtonValue = self.layer.fShadingOffset:HasKey(self.layerFrame)
		fShadingOffsetValue = LM.Round(self.layer.fShadingOffset.value * self.document:Height())
		selfShadingOffsetValue = LM.Round(self.shadingOffset:Value())

		shadingBlurButtonValue = self.layer.fShadingBlur:HasKey(self.layerFrame)
		fShadingBlurValue = LM.Round(self.layer.fShadingBlur.value * self.document:Height())
		selfShadingBlurValue = LM.Round(self.shadingBlur:Value())

		shadingContractionButtonValue = self.layer.fShadingContraction:HasKey(self.layerFrame)
		fShadingContractionValue = LM.Round(self.layer.fShadingContraction.value * self.document:Height())
		selfShadingContractionValue = LM.Round(self.shadingContraction:Value())

		shadingNoiseAmpButtonValue = self.layer.fShadingNoiseAmp:HasKey(self.layerFrame)
		fShadingNoiseAmpValue = LM.Round(self.layer.fShadingNoiseAmp.value * self.document:Height())
		selfShadingNoiseAmpValue = LM.Round(self.shadingNoiseAmp:Value())

		shadingNoiseScaleButtonValue = self.layer.fShadingNoiseScale:HasKey(self.layerFrame)
		fShadingNoiseScaleValue = LM.Round(self.layer.fShadingNoiseScale.value)
		selfShadingNoiseScaleValue = LM.Round(self.shadingNoiseScale:Value())

		shadingDirectionButtonValue = self.layer.fShadingAngle:HasKey(self.layerFrame)
		fShadingAngleValue = self.activeLayer.fShadingAngle.value
		selfShadingAngleValue = self.shadingDirection:Value()

		shadingColorButtonValue = self.layer.fShadingColor:HasKey(self.layerFrame)
		fShadingColorValue = self.activeLayer.fShadingColor.value
		selfShadingColorValue = self.shadingColor:Value() --print(selfShadingColorValue.a)

	-- ****************** Shadow Normalized Variables *******************
		perspBlurButtonValue = self.layer.fPerspectiveBlur:HasKey(self.layerFrame)
		fPerspectiveBlurValue = LM.Round(self.layer.fPerspectiveBlur.value * self.document:Height())
		selfPerspBlurValue = LM.Round(self.perspBlur:Value())

		perspScaleButtonValue = self.layer.fPerspectiveScale:HasKey(self.layerFrame)

		perspShearButtonValue = self.layer.fPerspectiveShear:HasKey(self.layerFrame)

		perspColorButtonValue = self.layer.fPerspectiveColor:HasKey(self.layerFrame)
		fPerspectiveColorValue = self.activeLayer.fPerspectiveColor.value
		selfPerspColorValue = self.perspColor:Value()

	-- ****************** Motion Blur Normalized Variables *******************
		mbFrameCountButtonValue = self.layer.fMotionBlurFrames:HasKey(self.layerFrame)
		mbFrameSkipButtonValue = self.layer.fMotionBlurSkip:HasKey(self.layerFrame)
		mbStartOpButtonValue = self.layer.fMotionBlurAlphaStart:HasKey(self.layerFrame)
		mbEndOpButtonValue = self.layer.fMotionBlurAlphaEnd:HasKey(self.layerFrame)

		mbRadiusButtonValue = self.layer.fMotionBlurRadius:HasKey(self.layerFrame)
		fmbRadiusValue = LM.Round(self.layer.fMotionBlurRadius.value * self.document:Height())
		selfmbRadiusValue = LM.Round(self.mbRadius:Value())

		if (shadowDirectionButtonValue ~= self.shadowDirectionButton:Value()) then
			if not self.layer.fShadowAngle:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadowAngle:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadowAngle:DeleteKey(self.frame + layer:TotalTimingOffset())
				end
				self.moho:UpdateUI() --Incredible here!!!
			end

		elseif (self.activeLayer.fShadowAngle.value ~= self.shadowDirection:Value()) then
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadowAngle:SetValue(self.frame + layer:TotalTimingOffset(), self.shadowDirection:Value())
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
				--self:UpdateWidgets()
			end
			self:UpdateWidgets()

		elseif (shadowOffsetButtonValue ~= self.shadowOffsetButton:Value()) then
			if not self.layer.fShadowOffset:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadowOffset:StoreValue()
					--self.layer:UpdateCurFrame(true)
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
				end
			else
				if (self.frame ~= 0) then
					for i = 0, selCount - 1 do
						local layer = self.document:GetSelectedLayer(i)
						layer.fShadowOffset:DeleteKey(self.layerFrame)
					end
					self.moho:UpdateUI()
				end
			end

		elseif (fShadowOffsetValue ~= selfShadowOffsetValue) then
			newVal = self.shadowOffset:IntValue()
			if (newVal < 0 or newVal > 1024) then
				newVal = LM.Clamp(newVal, 0, 1024)
				self.shadowOffset:SetValue(newVal)
			end

			local shadowOffsetValue = 0.0
			if self.shadowOffset == 0 then
				shadowOffsetValue = 0.0
			else
				shadowOffsetValue = self.shadowOffset:Value() / self.document:Height() --Convert the imput value into document coordinates!
				--shadowOffsetValue = self.moho:PixelToDoc(self.shadowOffset:Value()) --AS killer...
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadowOffset:SetValue(self.frame + layer:TotalTimingOffset(), shadowOffsetValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
			end
			self:UpdateWidgets()

		elseif (shadowBlurButtonValue ~= self.shadowBlurButton:Value()) then
			if not self.layer.fShadowBlur:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadowBlur:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
				end
			else
				if (self.frame ~= 0) then
					for i = 0, selCount - 1 do
						local layer = self.document:GetSelectedLayer(i)
						layer.fShadowBlur:DeleteKey(self.layerFrame)
					end
					self.moho:UpdateUI()
				end
			end

		elseif (fShadowBlurValue ~= selfShadowBlurValue) then
			newVal = self.shadowBlur:IntValue()
			if (newVal < 0 or newVal > 256) then
				newVal = LM.Clamp(newVal, 0, 256)
				self.shadowBlur:SetValue(newVal)
			end

			local shadowBlurValue = 0.0
			if self.shadowBlur == 0 then
				shadowBlurValue = 0.0
			else
				shadowBlurValue = self.shadowBlur:Value() / self.document:Height()
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadowBlur:SetValue(self.frame + layer:TotalTimingOffset(), shadowBlurValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
			end
			self:UpdateWidgets()

		elseif (shadowExpansionButtonValue ~= self.shadowExpansionButton:Value()) then
			if not self.layer.fShadowExpansion:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadowExpansion:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadowExpansion:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (fShadowExpansionValue ~= selfShadowExpansionValue) then
			newVal = self.shadowExpansion:IntValue()
			if (newVal < 0 or newVal > 30) then
				newVal = LM.Clamp(newVal, 0, 30)
				self.shadowExpansion:SetValue(newVal)
			end

			local shadowExpansionValue = 0.0
			if self.shadowExpansion == 0 then
				shadowExpansionValue = 0.0
			else
				shadowExpansionValue = self.shadowExpansion:Value() / self.document:Height()
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadowExpansion:SetValue(self.frame + layer:TotalTimingOffset(), shadowExpansionValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
			end
			self:UpdateWidgets()

		elseif (shadowNoiseAmpButtonValue ~= self.shadowNoiseAmpButton:Value()) then
			if not self.layer.fShadowNoiseAmp:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadowNoiseAmp:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadowNoiseAmp:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (fShadowNoiseAmpValue ~= selfShadowNoiseAmpValue) then
			newVal = self.shadowNoiseAmp:IntValue()
			if (newVal < 0 or newVal > 2048) then
				newVal = LM.Clamp(newVal, 0, 2048)
				self.shadowNoiseAmp:SetValue(newVal)
			end

			local shadowNoiseAmpValue = 0.0
			if self.shadowNoiseAmp == 0 then
				shadowNoiseAmpValue = 0.0
			else
				shadowNoiseAmpValue = self.shadowNoiseAmp:Value() / self.document:Height()
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadowNoiseAmp:SetValue(self.frame + layer:TotalTimingOffset(), shadowNoiseAmpValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
			end
			self:UpdateWidgets()

		elseif (shadowNoiseScaleButtonValue ~= self.shadowNoiseScaleButton:Value()) then
			if not self.layer.fShadowNoiseScale:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadowNoiseScale:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadowNoiseScale:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (fShadowNoiseScaleValue ~= selfShadowNoiseScaleValue) then
			newVal = self.shadowNoiseScale:IntValue()
			if (newVal < 0 or newVal > 2048) then
				newVal = LM.Clamp(newVal, 0, 2048)
				self.shadowNoiseScale:SetValue(newVal)
			end

			local shadowNoiseScaleValue = 0.0
			if self.shadowNoiseScale == 0 then
				shadowNoiseScaleValue = 0.0
			else
				shadowNoiseScaleValue = self.shadowNoiseScale:Value()
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadowNoiseScale:SetValue(self.frame + layer:TotalTimingOffset(), shadowNoiseScaleValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
			end
			self:UpdateWidgets()

		elseif (shadowColorButtonValue ~= self.shadowColorButton:Value()) then
			if not self.layer.fShadowColor:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadowColor:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
				end
			else
				if (self.frame ~= 0) then
					for i = 0, selCount - 1 do
						local layer = self.document:GetSelectedLayer(i)
						layer.fShadowColor:DeleteKey(self.layerFrame)
					end
					self.moho:UpdateUI()
				end
			end

		elseif (fShadowColorValue.r ~= selfShadowColorValue.r) or (fShadowColorValue.g ~= selfShadowColorValue.g) or (fShadowColorValue.b ~= selfShadowColorValue.b) or (fShadowColorValue.a ~= selfShadowColorValue.a) then
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadowColor:SetValue(self.frame + layer:TotalTimingOffset(), selfShadowColorValue)
				--layer.fShadowColor:StoreValue()
				--self.layer:UpdateCurFrame(true)
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADOW)
				--self:UpdateWidgets()
			end
			self:UpdateWidgets()

	-- ****************** Shading *******************
		elseif (shadingDirectionButtonValue ~= self.shadingDirectionButton:Value()) then
			if not self.layer.fShadingAngle:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadingAngle:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
				end
			else
				if (self.frame ~= 0) then
					for i = 0, selCount - 1 do
						local layer = self.document:GetSelectedLayer(i)
						layer.fShadingAngle:DeleteKey(self.layerFrame)
					end
					self.moho:UpdateUI() --Incredible here!!!
				end
			end

		elseif (self.activeLayer.fShadingAngle.value ~= self.shadingDirection:Value()) then
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadingAngle:SetValue(self.frame + layer:TotalTimingOffset(), self.shadingDirection:Value())
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
			end
			self:UpdateWidgets()

		elseif (shadingOffsetButtonValue ~= self.shadingOffsetButton:Value()) then
			if not self.layer.fShadingOffset:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadingOffset:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadingOffset:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (fShadingOffsetValue ~= selfShadingOffsetValue) then
			newVal = self.shadingOffset:IntValue()
			if (newVal < 0 or newVal > 1024) then
				newVal = LM.Clamp(newVal, 0, 1024)
				self.shadingOffset:SetValue(newVal)
			end

			local shadingOffsetValue = 0.0
			if self.shadingOffset == 0 then
				shadingOffsetValue = 0.0
			else
				shadingOffsetValue = self.shadingOffset:Value() / self.document:Height() --Convert the imput value into document coordinates!
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadingOffset:SetValue(self.frame + layer:TotalTimingOffset(), shadingOffsetValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
			end
			self:UpdateWidgets()

		elseif (shadingBlurButtonValue ~= self.shadingBlurButton:Value()) then
			if not self.layer.fShadingBlur:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadingBlur:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadingBlur:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (fShadingBlurValue ~= selfShadingBlurValue) then
			newVal = self.shadingBlur:IntValue()
			if (newVal < 0 or newVal > 256) then
				newVal = LM.Clamp(newVal, 0, 256)
				self.shadingBlur:SetValue(newVal)
			end

			local shadingBlurValue = 0.0
			if self.shadingBlur == 0 then
				shadingBlurValue = 0.0
			else
				shadingBlurValue = self.shadingBlur:Value() / self.document:Height()
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadingBlur:SetValue(self.frame + layer:TotalTimingOffset(), shadingBlurValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
			end
			self:UpdateWidgets()

		elseif (shadingContractionButtonValue ~= self.shadingContractionButton:Value()) then
			if not self.layer.fShadingContraction:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadingContraction:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadingContraction:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (fShadingContractionValue ~= selfShadingContractionValue) then
			newVal = self.shadingContraction:IntValue()
			if (newVal < 0 or newVal > 30) then
				newVal = LM.Clamp(newVal, 0, 30)
				self.shadingContraction:SetValue(newVal)
			end

			local shadingContractionValue = 0.0
			if self.shadingContraction == 0 then
				shadingContractionValue = 0.0
			else
				shadingContractionValue = self.shadingContraction:Value() / self.document:Height()
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadingContraction:SetValue(self.frame + layer:TotalTimingOffset(), shadingContractionValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
			end
			self:UpdateWidgets()

		elseif (shadingNoiseAmpButtonValue ~= self.shadingNoiseAmpButton:Value()) then
			if not self.layer.fShadingNoiseAmp:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadingNoiseAmp:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadingNoiseAmp:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (fShadingNoiseAmpValue ~= selfShadingNoiseAmpValue) then
			newVal = self.shadingNoiseAmp:IntValue()
			if (newVal < 0 or newVal > 2048) then
				newVal = LM.Clamp(newVal, 0, 2048)
				self.shadingNoiseAmp:SetValue(newVal)
			end

			local shadingNoiseAmpValue = 0.0
			if self.shadingNoiseAmp == 0 then
				shadingNoiseAmpValue = 0.0
			else
				shadingNoiseAmpValue = self.shadingNoiseAmp:Value() / self.document:Height()
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadingNoiseAmp:SetValue(self.frame + layer:TotalTimingOffset(), shadingNoiseAmpValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
			end
			self:UpdateWidgets()

		elseif (shadingNoiseScaleButtonValue ~= self.shadingNoiseScaleButton:Value()) then
			if not self.layer.fShadingNoiseScale:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadingNoiseScale:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadingNoiseScale:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (fShadingNoiseScaleValue ~= selfShadingNoiseScaleValue) then
			newVal = self.shadingNoiseScale:IntValue()
			if (newVal < 0 or newVal > 2048) then
				newVal = LM.Clamp(newVal, 0, 2048)
				self.shadingNoiseScale:SetValue(newVal)
			end

			local shadingNoiseScaleValue = 0.0
			if self.shadingNoiseScale == 0 then
				shadingNoiseScaleValue = 0.0
			else
				shadingNoiseScaleValue = self.shadingNoiseScale:Value()
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadingNoiseScale:SetValue(self.frame + layer:TotalTimingOffset(), shadingNoiseScaleValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
			end
			self:UpdateWidgets()

		elseif (shadingColorButtonValue ~= self.shadingColorButton:Value()) then
			if not self.layer.fShadingColor:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fShadingColor:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
				end
			else
				if (self.frame ~= 0) then
					for i = 0, selCount - 1 do
						local layer = self.document:GetSelectedLayer(i)
						layer.fShadingColor:DeleteKey(self.layerFrame)
					end
					self.moho:UpdateUI()
				end
			end

		elseif (fShadingColorValue.r ~= selfShadingColorValue.r) or (fShadingColorValue.g ~= selfShadingColorValue.g) or (fShadingColorValue.b ~= selfShadingColorValue.b) or (fShadingColorValue.a ~= selfShadingColorValue.a) then
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fShadingColor:SetValue(self.frame + layer:TotalTimingOffset(), selfShadingColorValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_SHADING)
			end
			self:UpdateWidgets()

	-- ****************** Perspective *******************
		elseif (perspBlurButtonValue ~= self.perspBlurButton:Value()) then
			if not self.layer.fPerspectiveBlur:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fPerspectiveBlur:StoreValue()
					--self.layer:UpdateCurFrame(true)
					MOHO.NewKeyframe(CHANNEL_LAYER_PERSPSHADOW)
				end
			else
				if (self.frame ~= 0) then
					for i = 0, selCount - 1 do
						local layer = self.document:GetSelectedLayer(i)
						layer.fPerspectiveBlur:DeleteKey(self.layerFrame)
					end
					self.moho:UpdateUI()
				end
			end

		elseif (fPerspectiveBlurValue ~= selfPerspBlurValue) then
			newVal = self.shadowOffset:IntValue()
			if (newVal < 0 or newVal > 256) then
				newVal = LM.Clamp(newVal, 0, 256)
				self.perspBlur:SetValue(newVal)
			end

			local perspBlurValue = 0.0
			if self.perspBlur == 0 then
				perspBlurValue = 0.0
			else
				perspBlurValue = self.perspBlur:Value() / self.document:Height() --Convert the imput value into document coordinates!
				--shadowOffsetValue = self.moho:PixelToDoc(self.shadowOffset:Value()) --AS killer...
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fPerspectiveBlur:SetValue(self.frame + layer:TotalTimingOffset(), perspBlurValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_PERSPSHADOW)
			end
			self:UpdateWidgets()

		elseif (perspScaleButtonValue ~= self.perspScaleButton:Value()) then
			if not self.layer.fPerspectiveScale:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fPerspectiveScale:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_PERSPSHADOW)
				end
			else
				if (self.frame ~= 0) then
					for i = 0, selCount - 1 do
						local layer = self.document:GetSelectedLayer(i)
						layer.fPerspectiveScale:DeleteKey(self.layerFrame)
					end
					self.moho:UpdateUI()
				end
			end

		elseif (self.activeLayer.fPerspectiveScale.value ~= self.perspScale:FloatValue()) then
			newVal = self.perspScale:FloatValue()
			if (newVal < -1000000 or newVal > 1000000) then
				newVal = LM.Clamp(newVal, -1000000, 1000000)
				self.perspScale:SetValue(newVal)
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fPerspectiveScale:SetValue(self.frame + layer:TotalTimingOffset(), self.perspScale:FloatValue())
				MOHO.NewKeyframe(CHANNEL_LAYER_PERSPSHADOW)
			end
			self:UpdateWidgets()

		elseif (perspShearButtonValue ~= self.perspShearButton:Value()) then
			if not self.layer.fPerspectiveShear:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fPerspectiveShear:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_PERSPSHADOW)
				end
			else
				if (self.frame ~= 0) then
					for i = 0, selCount - 1 do
						local layer = self.document:GetSelectedLayer(i)
						layer.fPerspectiveShear:DeleteKey(self.layerFrame)
					end
					self.moho:UpdateUI()
				end
			end

		elseif (self.activeLayer.fPerspectiveShear.value ~= self.perspShear:FloatValue()) then
			newVal = self.perspShear:FloatValue()
			if (newVal < -1000000 or newVal > 1000000) then
				newVal = LM.Clamp(newVal, -1000000, 1000000)
				self.perspShear:SetValue(newVal)
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fPerspectiveShear:SetValue(self.frame + layer:TotalTimingOffset(), self.perspShear:FloatValue())
				MOHO.NewKeyframe(CHANNEL_LAYER_PERSPSHADOW)
			end
			self:UpdateWidgets()

		elseif (perspColorButtonValue ~= self.perspColorButton:Value()) then
			if not self.layer.fPerspectiveColor:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fPerspectiveColor:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_PERSPSHADOW)
				end
			else
				if (self.frame ~= 0) then
					for i = 0, selCount - 1 do
						local layer = self.document:GetSelectedLayer(i)
						layer.fPerspectiveColor:DeleteKey(self.layerFrame)
					end
					self.moho:UpdateUI()
				end
			end

		elseif (fPerspectiveColorValue.r ~= selfPerspColorValue.r) or (fPerspectiveColorValue.g ~= selfPerspColorValue.g) or (fPerspectiveColorValue.b ~= selfPerspColorValue.b) or (fPerspectiveColorValue.a ~= selfPerspColorValue.a) then
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fPerspectiveColor:SetValue(self.frame + layer:TotalTimingOffset(), selfPerspColorValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_PERSPSHADOW)
			end
			self:UpdateWidgets()

	-- ****************** Motion Blur *******************
		elseif (mbFrameCountButtonValue ~= self.mbFrameCountButton:Value()) then
			if not self.layer.fMotionBlurFrames:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fMotionBlurFrames:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_MB)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fMotionBlurFrames:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (LM.Round(self.activeLayer.fMotionBlurFrames.value) ~= self.mbFrameCount:IntValue()) then
			newVal = self.mbFrameCount:IntValue()
			if (newVal < 0 or newVal > 1024) then
				newVal = LM.Clamp(newVal, 0, 1024)
				self.mbFrameCount:SetValue(newVal)
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fMotionBlurFrames:SetValue(self.frame + layer:TotalTimingOffset(), self.mbFrameCount:IntValue())
				MOHO.NewKeyframe(CHANNEL_LAYER_MB)
			end
			self:UpdateWidgets()

		elseif (mbFrameSkipButtonValue ~= self.mbFrameSkipButton:Value()) then
			if not self.layer.fMotionBlurSkip:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fMotionBlurSkip:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_MB)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fMotionBlurSkip:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (LM.Round(self.activeLayer.fMotionBlurSkip.value) ~= self.mbFrameSkip:IntValue()) then
			newVal = self.mbFrameSkip:IntValue()
			if (newVal < 0 or newVal > 1024) then
				newVal = LM.Clamp(newVal, 0, 1024)
				self.mbFrameSkip:SetValue(newVal)
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fMotionBlurSkip:SetValue(self.frame + layer:TotalTimingOffset(), self.mbFrameSkip:IntValue())
				MOHO.NewKeyframe(CHANNEL_LAYER_MB)
			end
			self:UpdateWidgets()

		elseif (mbStartOpButtonValue ~= self.mbStartOpButton:Value()) then
			if not self.layer.fMotionBlurAlphaStart:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fMotionBlurAlphaStart:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_MB)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fMotionBlurAlphaStart:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (LM.Round(self.activeLayer.fMotionBlurAlphaStart.value * 100) ~= self.mbStartOp:IntValue()) then
			newVal = self.mbStartOp:IntValue()
			if (newVal < 0 or newVal > 100) then
				newVal = LM.Clamp(newVal, 0, 100)
				self.mbStartOp:SetValue(newVal)
			end

			local mbAlphaStart = 0.0
			if self.mbStartOp == 0 then
				mbAlphaStart = 0.0
			else
				mbAlphaStart = self.mbStartOp:IntValue()/100
			end
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fMotionBlurAlphaStart:SetValue(self.frame + layer:TotalTimingOffset(), mbAlphaStart)
				MOHO.NewKeyframe(CHANNEL_LAYER_MB)
			end
			self:UpdateWidgets()

		elseif (mbEndOpButtonValue ~= self.mbEndOpButton:Value()) then
			if not self.layer.fMotionBlurAlphaEnd:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fMotionBlurAlphaEnd:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_MB)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fMotionBlurAlphaEnd:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (LM.Round(self.activeLayer.fMotionBlurAlphaEnd.value * 100) ~= self.mbEndOp:IntValue()) then
			newVal = self.mbEndOp:IntValue()
			if (newVal < 0 or newVal > 100) then
				newVal = LM.Clamp(newVal, 0, 100)
				self.mbEndOp:SetValue(newVal)
			end

			local mbAlphaEnd = 0.0
			if self.mbEndOp == 0 then
				mbAlphaEnd = 0.0
			else
				mbAlphaEnd = self.mbEndOp:IntValue()/100
			end
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fMotionBlurAlphaEnd:SetValue(self.frame + layer:TotalTimingOffset(), mbAlphaEnd)
				MOHO.NewKeyframe(CHANNEL_LAYER_MB)
			end
			self:UpdateWidgets()

		elseif (mbRadiusButtonValue ~= self.mbRadiusButton:Value()) then
			if not self.layer.fMotionBlurRadius:HasKey(self.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fMotionBlurRadius:StoreValue()
					MOHO.NewKeyframe(CHANNEL_LAYER_MB)
				end
			elseif (self.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					layer.fMotionBlurRadius:DeleteKey(self.layerFrame)
				end
				self.moho:UpdateUI()
			end

		elseif (fmbRadiusValue ~= selfmbRadiusValue) then
			newVal = self.mbRadius:IntValue()
			if (newVal < 0 or newVal > 256) then
				newVal = LM.Clamp(newVal, 0, 256)
				self.mbRadius:SetValue(newVal)
			end

			local mbRadiusValue = 0.0
			if self.mbRadius == 0 then
				mbRadiusValue = 0.0
			else
				mbRadiusValue = self.mbRadius:Value() / self.document:Height()
			end

			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				layer.fMotionBlurRadius:SetValue(self.frame + layer:TotalTimingOffset(), mbRadiusValue)
				MOHO.NewKeyframe(CHANNEL_LAYER_MB)
			end
			self:UpdateWidgets()

		else
			if (self.shadowDirection:IsEnabled() ~= self.layer.fLayerShadow.value) then
				self.shadowDirection:Enable(self.layer.fLayerShadow.value)
				self.shadowOffset:Enable(self.layer.fLayerShadow.value)
				self.shadowBlur:Enable(self.layer.fLayerShadow.value)
				self.shadowColor:Enable(self.layer.fLayerShadow.value)
			end

			if (self.shadingDirection:IsEnabled() ~= self.layer.fLayerShading.value) then
				self.shadingDirection:Enable(self.layer.fLayerShading.value)
				self.shadingOffset:Enable(self.layer.fLayerShading.value)
				self.shadingBlur:Enable(self.layer.fLayerShading.value)
				self.shadingColor:Enable(self.layer.fLayerShadow.value)
			end

			if (self.perspBlur:IsEnabled() ~= self.layer.fPerspectiveShadow.value) then
				self.perspBlur:Enable(self.layer.fPerspectiveShadow.value)
				self.perspScale:Enable(self.layer.fPerspectiveShadow.value)
				self.perspShear:Enable(self.layer.fPerspectiveShadow.value)
				self.shadowColor:Enable(self.layer.fPerspectiveShadow.value)
			end

			if (self.mbFrameCount:IsEnabled() ~= self.layer.fMotionBlur.value) then
				self.mbFrameCount:Enable(self.layer.fMotionBlur.value)
				self.mbFrameSkip:Enable(self.layer.fMotionBlur.value)
				self.mbStartOp:Enable(self.layer.fMotionBlur.value)
				self.mbEndOp:Enable(self.layer.fMotionBlur.value)
				self.mbRadius:Enable(self.layer.fMotionBlur.value)
			end
		end

	--self:UpdateWidgets()
	MOHO.Redraw()
	end
end


-- **************************************************
-- Layer Settings Dialog
-- **************************************************
local RL_LostLayerToolVectorsDialog = {}

RL_LostLayerToolVectorsDialog.SET_SOURCE = MOHO.MSG_BASE
RL_LostLayerToolVectorsDialog.RELOAD_SOURCE = MOHO.MSG_BASE + 1

RL_LostLayerToolVectorsDialog.PATHS_ON = MOHO.MSG_BASE + 2
RL_LostLayerToolVectorsDialog.PATHS_OFF = MOHO.MSG_BASE + 3

RL_LostLayerToolVectorsDialog.VECTOR3D_NONE = MOHO.MSG_BASE + 4
RL_LostLayerToolVectorsDialog.VECTOR3D_EXTRUDE = MOHO.MSG_BASE + 5
RL_LostLayerToolVectorsDialog.VECTOR3D_LATHE = MOHO.MSG_BASE + 6
RL_LostLayerToolVectorsDialog.VECTOR3D_INFLATE = MOHO.MSG_BASE + 7

function RL_LostLayerToolVectorsDialog:new()
	local d = LM.GUI.SimpleDialog("Vectors Options", RL_LostLayerToolVectorsDialog)
	local l = d:GetLayout()

	l:AddPadding(-13)
	l:Indent(-5)

	l:PushV(LM.GUI.ALIGN_FILL, 0)
		l:PushH(LM.GUI.ALIGN_FILL, 4)
			l:PushV(LM.GUI.ALIGN_TOP, 2)
				--l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_closeWindow", "Close", false, LM.GUI.MSG_CANCEL), LM.GUI.ALIGN_CENTER, 6)
				d.vectorsLabel = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_vectorsLabel_v", "Vectors Settings", false, 0)
				l:AddChild(d.vectorsLabel, LM.GUI.ALIGN_CENTER, 6)
			l:Pop()

			l:Unindent(-5)
			l:AddPadding(-5)

			l:PushV(LM.GUI.ALIGN_TOP, 0)
				l:PushH(LM.GUI.ALIGN_TOP, 4)
					l:PushV(LM.GUI.ALIGN_TOP, 1)
						d.noisyOutlines = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_VSB_noisyOutlines", "Noisy outlines", true, RL_LostLayerTool.DLOG1_CHANGE)
						l:AddChild(d.noisyOutlines)
						l:AddPadding(-3)
						d.noisyFills = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_VSB_noisyFills", "Noisy fills", true, RL_LostLayerTool.DLOG1_CHANGE)
						l:AddChild(d.noisyFills)
						l:AddPadding(-3)
						d.animatedNoise = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_VSB_animatedNoise", "Animated noise", true, RL_LostLayerTool.DLOG1_CHANGE)
						l:AddChild(d.animatedNoise)
						l:AddPadding(3)
						d.extraSketchy = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_VSB_extraSketchy_h", "Extra sketchy", true, RL_LostLayerTool.DLOG1_CHANGE)
						l:AddChild(d.extraSketchy)
					l:Pop()

					l:PushV(LM.GUI.ALIGN_TOP, 1)
						l:PushH(LM.GUI.ALIGN_RIGHT, 0)
							d.noiseOffsetButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_VSB_offsetPx", "Offset (px)", false, 0)
							l:AddChild(d.noiseOffsetButton)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.noiseOffset = LM.GUI.TextControl(34, "", RL_LostLayerTool.DLOG1_CHANGE, LM.GUI.FIELD_UINT)
								d.noiseOffset:SetWheelInc(1)
								l:AddChild(d.noiseOffset)
							l:Pop()
						l:Pop()
						l:AddPadding(-3)
						l:PushH(LM.GUI.ALIGN_RIGHT, 0)
							d.noiseScaleButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_VSB_scalePx", "Scale (px)", false, 0)
							l:AddChild(d.noiseScaleButton)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.noiseScale = LM.GUI.TextControl(34, "", RL_LostLayerTool.DLOG1_CHANGE, LM.GUI.FIELD_UINT)
								d.noiseScale:SetWheelInc(1)
								l:AddChild(d.noiseScale)
							l:Pop()
						l:Pop()
						l:AddPadding(-3)
						l:PushH(LM.GUI.ALIGN_RIGHT, 0)
							d.noiseLineCountButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_VSB_lineCount", "Line count", false, 0)
							l:AddChild(d.noiseLineCountButton)
							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-2)
								d.noiseLineCount = LM.GUI.TextControl(34, "", RL_LostLayerTool.DLOG1_CHANGE, LM.GUI.FIELD_UINT)
								d.noiseLineCount:SetWheelInc(1)
								l:AddChild(d.noiseLineCount)
							l:Pop()
						l:Pop()

						l:AddPadding(3)

						l:PushH(LM.GUI.ALIGN_RIGHT, 0)
							d.pathsOn = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_pathsOn", "Paths On", false, RL_LostLayerToolVectorsDialog.PATHS_ON)
							l:AddChild(d.pathsOn, LM.GUI.ALIGN_BOTTOM)
							l:AddPadding(-1)
							d.pathsOff = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_pathsOFF", "Paths Off", false, RL_LostLayerToolVectorsDialog.PATHS_OFF)
							l:AddChild(d.pathsOff, LM.GUI.ALIGN_BOTTOM)

							l:AddPadding(7)

							d.gapFilling = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_VSB_gapFilling_h", "Gap filling", true, RL_LostLayerTool.DLOG1_CHANGE)
							l:AddChild(d.gapFilling, LM.GUI.ALIGN_BOTTOM)
						l:Pop()
					l:Pop()

					l:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL, 0)

					self.dddModeButtons = {} --groupMaskButtons parece ser la tabla que contendr  las variables self.groupMaskButtons[1], self.groupMaskButtons[2], self.groupMaskButtons[3]; que a su vez que contendr  cada uno de los bot nes.
					table.insert(self.dddModeButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_3dMode_none", "None", true, RL_LostLayerToolVectorsDialog.VECTOR3D_NONE))
					table.insert(self.dddModeButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_3dMode_extrude", "Exclude", true, RL_LostLayerToolVectorsDialog.VECTOR3D_EXTRUDE))
					table.insert(self.dddModeButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_3dMode_lathe", "Lathe", true, RL_LostLayerToolVectorsDialog.VECTOR3D_LATHE))
					table.insert(self.dddModeButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_3dMode_inflate", "Inflate", true, RL_LostLayerToolVectorsDialog.VECTOR3D_INFLATE))

					l:PushV(LM.GUI.ALIGN_RIGHT, 0)
						for i, dddModeButton in ipairs(self.dddModeButtons) do
							l:AddChild(dddModeButton)
							l:AddPadding(-1)
						end
					l:Pop()

				l:Pop()
			l:Pop()

			l:PushV(LM.GUI.ALIGN_TOP, 2)
				d.dddOptionsLabel = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_3dOptionsLabel_v", "3D Options", false, 0)
				l:AddChild(d.dddOptionsLabel, LM.GUI.ALIGN_CENTER, 0)
			l:Pop()

			l:PushV(LM.GUI.ALIGN_TOP, 3)
				l:PushH(LM.GUI.ALIGN_TOP, 4)
					l:PushV(LM.GUI.ALIGN_TOP, 0)
						l:PushH(LM.GUI.ALIGN_LEFT, 0)
							d.dddDefaultColorButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_3d_defaultColor", "Default Color", false, 0)
							l:AddChild(d.dddDefaultColorButton, LM.GUI.ALIGN_FILL, 0)

							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-24)
								d.dddDefaultColor = LM.GUI.ColorSwatch(false, RL_LostLayerTool.DLOG1_CHANGE)
								l:AddChild(d.dddDefaultColor)
							l:Pop()
						l:Pop()
						l:AddPadding(-2)
						l:PushH(LM.GUI.ALIGN_LEFT, 0)
							d.dddEdgeColorButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_3d_edgeColor", "Edge Color", false, 0)
							l:AddChild(d.dddEdgeColorButton, LM.GUI.ALIGN_FILL, 0)

							l:PushH(LM.GUI.ALIGN_CENTER, 0)
								l:AddPadding(-24)
								d.dddEdgeColor = LM.GUI.ColorSwatch(false, RL_LostLayerTool.DLOG1_CHANGE)
								l:AddChild(d.dddEdgeColor)
							l:Pop()
						l:Pop()
					l:Pop()

					l:PushV(LM.GUI.ALIGN_TOP, 1)
						d.dddPolyOrient = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_3d_poligonOrient", "Polygon Orientation (CW/CCW)", true, RL_LostLayerTool.DLOG1_CHANGE)
						l:AddChild(d.dddPolyOrient)
						--[[ASP_7
						d.dddResetZBuffer = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_3d_resetZBuf", "Reset Z Buffer", true, RL_LostLayerTool.DLOG1_CHANGE)
						l:AddChild(d.dddResetZBuffer)--]]
					l:Pop()
				l:Pop()

				l:PushH(LM.GUI.ALIGN_CENTER, 0)
					d.dddEdgeOffsetButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_3d_edgeOffset", "Edge Offset", false, RL_LostLayerTool.DLOG1_CHANGE)
					l:AddChild(d.dddEdgeOffsetButton)

					l:PushH(LM.GUI.ALIGN_CENTER, 0)
						l:AddPadding(-2)
						d.dddEdgeOffset = LM.GUI.TextControl(45, "", RL_LostLayerTool.DLOG1_CHANGE, LM.GUI.FIELD_UFLOAT)
						d.dddEdgeOffset:SetWheelInc(0.01)
						l:AddChild(d.dddEdgeOffset)
					l:Pop()
				l:Pop()
			l:Pop()
		l:Pop()

		l:AddPadding(2)

		l:AddChild(LM.GUI.Divider(false), LM.GUI.ALIGN_FILL, 4)

		l:AddPadding(1)

		l:PushH(LM.GUI.ALIGN_TOP, 0)
			d.sourceButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_source", "Source...", false, RL_LostLayerToolVectorsDialog.SET_SOURCE)
			l:AddChild(d.sourceButton, LM.GUI.ALIGN_TOP)

			d.sourceText = LM.GUI.TextControl(184, "Source...", RL_LostLayerTool.DLOG1_CHANGE, LM.GUI.FIELD_TEXT) --88
			l:AddChild(d.sourceText, LM.GUI.ALIGN_TOP)

			d.sourceReloadButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_sourceReload", "Reload Source", false, RL_LostLayerToolVectorsDialog.RELOAD_SOURCE)
			l:AddChild(d.sourceReloadButton, LM.GUI.ALIGN_TOP)
		l:Pop()
	l:Pop()
	--d.active= false
	return d
end

function RL_LostLayerToolVectorsDialog:UpdateWidgets()

	local dddCol = LM.rgb_color:new_local()
	dddCol.r = 96
	dddCol.g = 96
	dddCol.b = 96

	self.vectorsLabel:Enable(false)

	self.noisyOutlines:Enable(false)
	self.noisyFills:Enable(false)
	self.animatedNoise:Enable(false)
	self.extraSketchy:Enable(false)

	self.noiseOffsetButton:Enable(false)
	self.noiseOffset:Enable(false)
	self.noiseOffset:SetValue("")
	self.noiseScaleButton:Enable(false)
	self.noiseScale:Enable(false)
	self.noiseScale:SetValue("")
	self.noiseLineCountButton:Enable(false)
	self.noiseLineCount:Enable(false)
	self.noiseLineCount:SetValue("") -- +1 ...WTF???

	self.pathsOn:Enable(false)
	self.pathsOff:Enable(false)
	self.gapFilling:Enable(false)

	for i, dddModeButton in ipairs(RL_LostLayerToolVectorsDialog.dddModeButtons) do
		RL_LostLayerToolVectorsDialog.dddModeButtons[i]:Enable(false)
	end

	self.dddOptionsLabel:Enable(false)

	self.dddDefaultColorButton:Enable(false)
	self.dddDefaultColor:Enable(false)
	self.dddDefaultColor:SetValue(dddCol)
	self.dddEdgeColorButton:Enable(false)
	self.dddEdgeColor:Enable(false)
	self.dddEdgeColor:SetValue(dddCol)
	self.dddPolyOrient:Enable(false)
	--self.dddResetZBuffer:Enable(false) --ASP_7
	self.dddEdgeOffsetButton:Enable(false)
	self.dddEdgeOffset:Enable(false)

	self.sourceButton:Enable(false)
	self.sourceText:Enable(false)
	self.sourceReloadButton:Enable(false)

	self.sourceButton:Enable(false)
	self.sourceReloadButton:Enable(false)


	if (self.document and self.layer:LayerType() == MOHO.LT_VECTOR) then
		self.vectorsLabel:Enable(true)
	-- ************* Check Boxes **************
		self.noisyOutlines:SetValue(self.layer.fNoisyLines)
		self.noisyFills:SetValue(self.layer.fNoisyShapes)
		self.animatedNoise:SetValue(self.layer.fAnimatedNoise)
		self.extraSketchy:SetValue(self.layer.fExtraSketchy)

		self.gapFilling:SetValue(self.layer.fGapFilling)

		self.noisyOutlines:Enable(true)
		self.noisyFills:Enable(true)
		self.animatedNoise:Enable(self.layer.fNoisyLines or self.layer.fNoisyShapes)
		self.extraSketchy:Enable(self.layer.fNoisyLines)

	-- ************* Text Fields **************
		self.noiseOffset:SetValue(self.layer.fNoiseAmp * self.document:Height())
		self.noiseScale:SetValue(self.layer.fNoiseScale * self.document:Height())
		self.noiseLineCount:SetValue(self.layer.fExtraLines + 1) -- +1 ...WTF???

		self.noiseOffsetButton:Enable(true)
		self.noiseOffset:Enable(self.layer.fNoisyLines or self.layer.fNoisyShapes)
		self.noiseScaleButton:Enable(true)
		self.noiseScale:Enable(self.layer.fNoisyLines or self.layer.fNoisyShapes)
		self.noiseLineCountButton:Enable(true)
		self.noiseLineCount:Enable(self.layer.fNoisyLines)

		self.pathsOn:Enable(true)
		self.pathsOff:Enable(true)
		self.gapFilling:Enable(true)

		for i, dddModeButton in ipairs(RL_LostLayerToolVectorsDialog.dddModeButtons) do
			RL_LostLayerToolVectorsDialog.dddModeButtons[i]:Enable(true)

			if (self.layer.f3DMode == MOHO.VECTOR3D_NONE +i -1) then
				dddModeButton:SetValue(true)
			else
				dddModeButton:SetValue(false)
			end
		end

	-- ************* Sensitive Source Settings **************
	elseif (self.document and self.layer:LayerType() == MOHO.LT_IMAGE) then
		self.sourceButton:Enable(true)
		self.sourceText:Enable(true)
		self.sourceReloadButton:Enable(true)
		self.sourceText:SetValue(self.layer:SourceImage())
	elseif (self.document and (self.layer:IsAudioType() and self.layer:LayerType() ~= MOHO.LT_IMAGE)) then
		self.sourceButton:Enable(true)
		self.sourceText:Enable(true)
		self.sourceText:SetValue(self.layer:AudioFile())
		self.sourceReloadButton:Enable(true)
	elseif (self.document and self.layer:LayerType() == MOHO.LT_BONE or self.layer:LayerType() == MOHO.LT_SWITCH) then
		self.pathsOn:Enable(true)
		self.pathsOff:Enable(true)
	elseif (self.document and self.layer:LayerType() == MOHO.LT_3D) then
		self.dddOptionsLabel:Enable(true)
		self.dddDefaultColorButton:Enable(true)
		self.dddDefaultColor:Enable(true)
		self.dddEdgeColorButton:Enable(true)
		self.dddEdgeColor:Enable(true)
		self.dddPolyOrient:Enable(true)
		--self.dddResetZBuffer:Enable(true) --ASP_7
		self.dddEdgeOffsetButton:Enable(true)
		self.dddEdgeOffset:Enable(true)

		self.sourceButton:Enable(true)
		self.sourceText:Enable(true)
		self.sourceReloadButton:Enable(true)

		if ((self.defaultColor and self.edgeColor) ~= nil) then
			self.dddDefaultColor:SetValue(self.defaultColor)
			self.dddEdgeColor:SetValue(self.edgeColor)
		end

		self.dddPolyOrient:SetValue(self.dddClockwise)
		--self.dddResetZBuffer:SetValue(self.activeLayer:ResetZ()) --ASP_7
		self.dddEdgeOffset:SetValue(self.layer:EdgeOffset())

		if (#self.moho:LayerAs3D(self.layer):SourceMesh() ~= 0) then
			self.sourceText:SetValue(self.moho:LayerAs3D(self.layer):SourceMesh()) --moho:LayerAs3D(moho.layer)
		else
			self.sourceText:SetValue("The 3D object is internal.")
			self.sourceReloadButton:Enable(false)
		end
	else
		self.sourceText:SetValue("No external resources.")
		self.sourceText:Enable(false)
	end
end

function RL_LostLayerToolVectorsDialog:OnOK()
	if (self.layer == nil) then
		return
	end

	if (self.layer:LayerType() == MOHO.LT_3D) then
		self.document:PrepMultiUndo()
		self.document:SetDirty()

		-- *************   3D Buttons   **************
		self.mesh3D:SetClockwise(self.dddPolyOrient:Value())
		--self.layer:SetResetZ(self.dddResetZBuffer:Value()) --ASP_7
		self.mesh3D:SetDefaultColor(self.dddDefaultColor:Value())
		self.mesh3D:SetDefaultEdgeColor(self.dddEdgeColor:Value())
		self.moho:LayerAs3D(self.layer):SetEdgeOffset(self.dddEdgeOffset:Value())
		--self.moho:LayerAs3D(self.layer):SetSourceMesh(self.sourceText:Value())

		--self:UpdateWidgets()

	elseif (self.layer:LayerType() == MOHO.LT_IMAGE) then
		self.document:PrepMultiUndo()
		self.document:SetDirty()

		--self.layer:SetSourceImage(self.sourceText:Value())

	elseif (self.layer:IsAudioType()) then
		self.document:PrepMultiUndo()
		self.document:SetDirty()

		--self.layer:SetAudioFile(self.sourceText:Value())
	end

	--self:HandleMessage(RL_LostLayerTool.DLOG1_CHANGE) -- send this final message in case the user is in the middle of editing some value

	--self:UpdateWidgets()
	MOHO.Redraw()
end

function RL_LostLayerToolVectorsDialog:HandleMessage(msg)
	if (not (self.document and self.layer)) then
		return
	end

	if ((msg == RL_LostLayerTool.DLOG1_CHANGE) or (msg == LM.GUI.MSG_CANCEL)) and (self.layer:LayerType() == MOHO.LT_VECTOR) then

		self.document:PrepMultiUndo()
		self.document:SetDirty()

		--self:OnOK()

		local selCount = self.document:CountSelectedLayers()

	-- *************   Vector Buttons   **************
		if (self.layer.fNoisyLines ~= self.noisyOutlines:Value()) then
			--newVal = self.layer.fNoisyLines
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				if (layer:LayerType() == MOHO.LT_VECTOR) then
					self.moho:LayerAsVector(layer).fNoisyLines = self.noisyOutlines:Value()
				end
			end
			self:UpdateWidgets()
			MOHO.Redraw()

		elseif (self.activeLayer.fNoisyShapes ~= self.noisyFills:Value()) then
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				if (layer:LayerType() == MOHO.LT_VECTOR) then
					self.moho:LayerAsVector(layer).fNoisyShapes = self.noisyFills:Value()
				end
			end
			self:UpdateWidgets()
			MOHO.Redraw()

		elseif (self.activeLayer.fAnimatedNoise ~= self.animatedNoise:Value()) then
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				if (layer:LayerType() == MOHO.LT_VECTOR) then
					self.moho:LayerAsVector(layer).fAnimatedNoise = self.animatedNoise:Value()
				end
			end
			--self:UpdateWidgets()
			MOHO.Redraw()

		elseif (self.activeLayer.fExtraSketchy ~= self.extraSketchy:Value()) then
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				if (layer:LayerType() == MOHO.LT_VECTOR) then
					self.moho:LayerAsVector(layer).fExtraSketchy = self.extraSketchy:Value()
				end
			end
			--self:UpdateWidgets()
			MOHO.Redraw()

		elseif (self.activeLayer.fGapFilling ~= self.gapFilling:Value()) then
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				if (layer:LayerType() == MOHO.LT_VECTOR) then
					self.moho:LayerAsVector(layer).fGapFilling = self.gapFilling:Value()
				end
			end
			self:UpdateWidgets()
			MOHO.Redraw()

	-- ************* Vector Text Fields **************
		elseif (LM.Round(self.activeLayer.fNoiseAmp * self.document:Height())) ~= LM.Round(self.noiseOffset:Value()) then
			newVal = self.noiseOffset:IntValue()
			if (newVal < 1 or newVal > 1024) then
				newVal = LM.Clamp(newVal, 1, 1024)
				self.noiseOffset:SetValue(newVal)
			end
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				if (layer:LayerType() == MOHO.LT_VECTOR) then
					self.moho:LayerAsVector(layer).fNoiseAmp = self.noiseOffset:Value() / self.document:Height()
					--self.layer:UpdateCurFrame(true)
				end
			end
			MOHO.Redraw()

		elseif (LM.Round(self.activeLayer.fNoiseScale * self.document:Height())) ~= LM.Round(self.noiseScale:Value()) then
			newVal = self.noiseScale:IntValue()
			if (newVal < 1 or newVal > 1024) then
				newVal = LM.Clamp(newVal, 1, 1024)
				self.noiseScale:SetValue(newVal)
			end
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				if (layer:LayerType() == MOHO.LT_VECTOR) then
					self.moho:LayerAsVector(layer).fNoiseScale = self.noiseScale:Value() / self.document:Height()
				end
			end
			MOHO.Redraw()

		elseif ((self.activeLayer.fExtraLines + 1) ~= self.noiseLineCount:IntValue()) then
			newVal = self.noiseLineCount:IntValue()
			if (newVal < 1 or newVal > 16) then
				newVal = LM.Clamp(newVal, 1, 16)
				self.noiseLineCount:SetValue(newVal)
			end
			for i = 0, selCount - 1 do
				local layer = self.document:GetSelectedLayer(i)
				if (layer:LayerType() == MOHO.LT_VECTOR) then
					self.moho:LayerAsVector(layer).fExtraLines = (self.noiseLineCount:IntValue() - 1)
				end
			end
			MOHO.Redraw()
		end

	elseif ((msg == RL_LostLayerTool.DLOG1_CHANGE) or (msg == LM.GUI.MSG_CANCEL)) and (self.layer:LayerType() == MOHO.LT_3D) then
		self:OnOK()

	-- ************* Source Settings **************
	elseif (msg == RL_LostLayerToolVectorsDialog.SET_SOURCE) and (self.layer:LayerType() == MOHO.LT_3D) then
		local path = LM.GUI.OpenFile("Select OBJ File")
		if (path == "") then
			return
		end
		self.moho:LayerAs3D(self.layer):SetSourceMesh(path)
		self:UpdateWidgets()
		MOHO.Redraw()

	elseif (msg == RL_LostLayerToolVectorsDialog.RELOAD_SOURCE) and (self.layer:LayerType() == MOHO.LT_3D) then
		local path = self.layer:SourceMesh()
		if (path == "") then
			return
		end
		self.moho:LayerAs3D(self.layer):SetSourceMesh(path)
		MOHO.Redraw()

	elseif (msg == RL_LostLayerToolVectorsDialog.SET_SOURCE) and (self.layer:LayerType() == MOHO.LT_IMAGE) then
		local path = LM.GUI.OpenFile("Select Image")
		if (path == "") then
			return
		end
		self.layer:SetSourceImage(path)
		self:UpdateWidgets()
		MOHO.Redraw()

	elseif (msg == RL_LostLayerToolVectorsDialog.RELOAD_SOURCE) and (self.layer:LayerType() == MOHO.LT_IMAGE) then
		local path = self.layer:SourceImage()
		if (path == "") then
			return
		end
		self.layer:SetSourceImage(path)
		MOHO.Redraw()

	elseif (msg == RL_LostLayerToolVectorsDialog.SET_SOURCE) and (self.layer:IsAudioType()) then
		local path = LM.GUI.OpenFile("Select Audio")
		if (path == "") then
			return
		end
		self.layer:SetAudioFile(path)
		self:UpdateWidgets()
		MOHO.Redraw()

	elseif (msg == RL_LostLayerToolVectorsDialog.RELOAD_SOURCE) and (self.layer:IsAudioType()) then
		local path = self.layer:AudioFile()
		if (path == "") then
			return
		end
		self.layer:SetAudioFile(path)
		MOHO.Redraw()

	elseif (msg == RL_LostLayerToolVectorsDialog.PATHS_ON) then
		self.document:PrepMultiUndo()
		self.document:SetDirty()

		local selCount = self.document:CountSelectedLayers()
		for i = 0, selCount - 1 do
			local layer = self.document:GetSelectedLayer(i)
			layer:ShowConstructionCurves(true)
		end
		self.moho:Click()
		MOHO.Redraw()

	elseif (msg == RL_LostLayerToolVectorsDialog.PATHS_OFF) then
		self.document:PrepMultiUndo()
		self.document:SetDirty()

		local selCount = self.document:CountSelectedLayers()
		for i = 0, selCount - 1 do
			local layer = self.document:GetSelectedLayer(i)
			layer:ShowConstructionCurves(false)
		end
		self.moho:Click()
		MOHO.Redraw()
	---[[
	elseif (msg >= RL_LostLayerToolVectorsDialog.VECTOR3D_NONE and msg <= RL_LostLayerToolVectorsDialog.VECTOR3D_INFLATE) then
		self.document:PrepMultiUndo()
		self.document:SetDirty()

		local selCount = self.document:CountSelectedLayers()

		self.dddMode = msg
		for i, dddModeButton in ipairs(RL_LostLayerToolVectorsDialog.dddModeButtons) do
			if (msg == RL_LostLayerToolVectorsDialog.VECTOR3D_NONE) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					--dddModeButton:SetValue(self.dddMode == RL_LostLayerToolVectorsDialog.VECTOR3D_NONE + i - 1)
					if (layer:LayerType() == MOHO.LT_VECTOR) then
						self.moho:LayerAsVector(layer).f3DMode = MOHO.VECTOR3D_NONE
					end
				end
			elseif (msg == RL_LostLayerToolVectorsDialog.VECTOR3D_EXTRUDE) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					--dddModeButton:SetValue(self.dddMode == RL_LostLayerToolVectorsDialog.VECTOR3D_NONE + i - 1)
					if (layer:LayerType() == MOHO.LT_VECTOR) then
						self.moho:LayerAsVector(layer).f3DMode = MOHO.VECTOR3D_EXTRUDE
					end
				end
			elseif (msg == RL_LostLayerToolVectorsDialog.VECTOR3D_LATHE) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					--dddModeButton:SetValue(self.dddMode == RL_LostLayerToolVectorsDialog.VECTOR3D_NONE + i - 1)
					if (layer:LayerType() == MOHO.LT_VECTOR) then
						self.moho:LayerAsVector(layer).f3DMode = MOHO.VECTOR3D_LATHE
					end
				end
			elseif (msg == RL_LostLayerToolVectorsDialog.VECTOR3D_INFLATE) then
				for i = 0, selCount - 1 do
					local layer = self.document:GetSelectedLayer(i)
					--dddModeButton:SetValue(self.dddMode == RL_LostLayerToolVectorsDialog.VECTOR3D_NONE + i - 1)
					if (layer:LayerType() == MOHO.LT_VECTOR) then
						self.moho:LayerAsVector(layer).f3DMode = MOHO.VECTOR3D_INFLATE
					end
				end
			end
		end

		self:UpdateWidgets()
		MOHO.Redraw()
		--self.moho:UpdateUI()
	end

	--self:UpdateWidgets()
	--MOHO.Redraw()
end

-- **************************************************
-- Particle Settings Dialog
-- **************************************************
local RL_LostLayerToolParticlesDialog = {}

RL_LostLayerToolParticlesDialog.RESET = MOHO.MSG_BASE
RL_LostLayerToolParticlesDialog.RESEED = MOHO.MSG_BASE + 1

function RL_LostLayerToolParticlesDialog:new()
	local d = LM.GUI.SimpleDialog("Particles Options", RL_LostLayerToolParticlesDialog)
	local l = d:GetLayout()

	l:AddPadding(-13)
	l:Indent(-5)

	l:PushH(LM.GUI.ALIGN_FILL, 4)
		l:Unindent(-5)
		l:AddPadding(-4)
		l:PushV(LM.GUI.ALIGN_TOP, 2)
			d.partSettingsLabel = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesLabel_v", "Particle Settings", false, 0)
			l:AddChild(d.partSettingsLabel, LM.GUI.ALIGN_FILL, 0)

			l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_resetSettings", "RESET", false, RL_LostLayerToolParticlesDialog.RESET), LM.GUI.ALIGN_BOTTOM, 0)
		l:Pop()

		l:PushV(LM.GUI.ALIGN_TOP, 0)
			l:PushH(LM.GUI.ALIGN_TOP, 5)
				l:PushV(LM.GUI.ALIGN_TOP, 0)
					l:PushH(LM.GUI.ALIGN_TOP, 4)
						l:PushV(LM.GUI.ALIGN_TOP, 1)
							l:PushH(LM.GUI.ALIGN_RIGHT, 0)
								l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesCount", "Particle Count", false, 0))
								l:PushH(LM.GUI.ALIGN_CENTER, 0)
									l:AddPadding(-2)
									d.partCount = LM.GUI.TextControl(0, "0.00", RL_LostLayerTool.DLOG2_CHANGE, LM.GUI.FIELD_UINT)
									d.partCount:SetWheelInc(1)
									l:AddChild(d.partCount)
								l:Pop()
							l:Pop()
							l:AddPadding(-4)
							l:PushH(LM.GUI.ALIGN_RIGHT, 0)
								l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesPrev", "Preview Particles", false, 0))
								l:PushH(LM.GUI.ALIGN_CENTER, 0)
									l:AddPadding(-2)
									d.partPrevCount = LM.GUI.TextControl(0, "0.00", RL_LostLayerTool.DLOG2_CHANGE, LM.GUI.FIELD_UINT)
									d.partPrevCount:SetWheelInc(1)
									l:AddChild(d.partPrevCount)
								l:Pop()
							l:Pop()
							l:AddPadding(-4)
							l:PushH(LM.GUI.ALIGN_RIGHT, 0)
								l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesLifetime", "Lifetime (Frames)", false, 0))
								l:PushH(LM.GUI.ALIGN_CENTER, 0)
									l:AddPadding(-2)
									d.partLifetime = LM.GUI.TextControl(0, "0.00", RL_LostLayerTool.DLOG2_CHANGE, LM.GUI.FIELD_UINT)
									d.partLifetime:SetWheelInc(1)
									l:AddChild(d.partLifetime)
								l:Pop()
							l:Pop()
						l:Pop()
					l:Pop()
				l:Pop()

				l:PushV(LM.GUI.ALIGN_TOP, 0)
					l:PushH(LM.GUI.ALIGN_TOP, 4)
						l:PushV(LM.GUI.ALIGN_TOP, 1)
							l:PushH(LM.GUI.ALIGN_RIGHT, 0)
								l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesWidth", "Source Width", false, 0))
								l:PushH(LM.GUI.ALIGN_CENTER, 0)
									l:AddPadding(-2)
									d.partWidth = LM.GUI.TextControl(0, "0.00", RL_LostLayerTool.DLOG2_CHANGE, LM.GUI.FIELD_UFLOAT)
									d.partWidth:SetWheelInc(1)
									l:AddChild(d.partWidth)
								l:Pop()
							l:Pop()
							l:AddPadding(-4)
							l:PushH(LM.GUI.ALIGN_RIGHT, 0)
								l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesHeight", "Source Height", false, 0))
								l:PushH(LM.GUI.ALIGN_CENTER, 0)
									l:AddPadding(-2)
									d.partHeight = LM.GUI.TextControl(0, "0.00", RL_LostLayerTool.DLOG2_CHANGE, LM.GUI.FIELD_UFLOAT)
									d.partHeight:SetWheelInc(1)
									l:AddChild(d.partHeight)
								l:Pop()
							l:Pop()
							l:AddPadding(-4)
							l:PushH(LM.GUI.ALIGN_RIGHT, 0)
								l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesDepth", "Source Depth", false, 0))
								l:PushH(LM.GUI.ALIGN_CENTER, 0)
									l:AddPadding(-2)
									d.partDepth = LM.GUI.TextControl(0, "0.00", RL_LostLayerTool.DLOG2_CHANGE, LM.GUI.FIELD_UFLOAT)
									d.partDepth:SetWheelInc(1)
									l:AddChild(d.partDepth)
								l:Pop()
							l:Pop()
						l:Pop()
					l:Pop()
				l:Pop()

				l:PushV(LM.GUI.ALIGN_TOP, 0)
					l:PushH(LM.GUI.ALIGN_TOP, 4)
						l:PushV(LM.GUI.ALIGN_TOP, 1)
							l:PushH(LM.GUI.ALIGN_RIGHT, 0)
								l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesVel", "Velocity", false, 0))
								l:PushH(LM.GUI.ALIGN_CENTER, 0)
									l:AddPadding(-2)
									d.partVelocity = LM.GUI.TextControl(0, "0.00", RL_LostLayerTool.DLOG2_CHANGE, LM.GUI.FIELD_UFLOAT)
									d.partVelocity:SetWheelInc(1)
									l:AddChild(d.partVelocity)
								l:Pop()
							l:Pop()
							l:AddPadding(-4)
							l:PushH(LM.GUI.ALIGN_RIGHT, 0)
								l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesVelSpread", "Velocity Spread", false, 0))
								l:PushH(LM.GUI.ALIGN_CENTER, 0)
									l:AddPadding(-2)
									d.partVelSpread = LM.GUI.TextControl(0, "0.00", RL_LostLayerTool.DLOG2_CHANGE, LM.GUI.FIELD_UFLOAT)
									d.partVelSpread:SetWheelInc(1)
									l:AddChild(d.partVelSpread)
								l:Pop()
							l:Pop()
							l:AddPadding(-4)
							l:PushH(LM.GUI.ALIGN_RIGHT, 0)
								l:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesDamping", "Damping", false, 0))
								l:PushH(LM.GUI.ALIGN_CENTER, 0)
									l:AddPadding(-2)
									d.partDamping = LM.GUI.TextControl(0, "0.00", RL_LostLayerTool.DLOG2_CHANGE, LM.GUI.FIELD_UFLOAT)
									d.partDamping:SetWheelInc(1)
									l:AddChild(d.partDamping)
								l:Pop()
							l:Pop()
						l:Pop()
					l:Pop()
				l:Pop()
			l:Pop()

			l:AddPadding(-3)

			l:PushH(LM.GUI.ALIGN_CENTER, 3)
				l:PushH(LM.GUI.ALIGN_TOP, 2)
					l:PushV(LM.GUI.ALIGN_BOTTOM, 0)
						l:AddChild(LM.GUI.Divider(false), LM.GUI.ALIGN_FILL, -2)
						l:AddPadding(8)
						d.partDirSpread = LM.GUI.TextControl(34, "", RL_LostLayerTool.DLOG2_CHANGE, LM.GUI.FIELD_UFLOAT)
						l:AddChild(d.partDirSpread, LM.GUI.ALIGN_RIGHT)

						l:PushV(LM.GUI.ALIGN_CENTER, 0)
							l:AddPadding(-4)
							d.partDirSpreadButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesSpread_h", "Direction Spread", false, 0)
							l:AddChild(d.partDirSpreadButton, LM.GUI.ALIGN_FILL)
						l:Pop()
					l:Pop()
					l:AddPadding(-5)
					l:PushH(LM.GUI.ALIGN_BOTTOM, 0)
						d.partDirAngleButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesDir_v", "Particles Direction", false, 0)
						l:AddChild(d.partDirAngleButton, LM.GUI.ALIGN_TOP, 5) --10

						l:AddPadding(-14) -- -11

						d.partDirAngle = LM.GUI.AngleWidget(RL_LostLayerTool.DLOG2_CHANGE)
						l:AddChild(d.partDirAngle, LM.GUI.ALIGN_CENTER)
					l:Pop()
				l:Pop()

				l:PushH(LM.GUI.ALIGN_TOP, 2)
					l:PushH(LM.GUI.ALIGN_BOTTOM, 0)
						d.partAccelAngleButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesAcc_v", "Particles Acceleration", false, 0)
						l:AddChild(d.partAccelAngleButton, LM.GUI.ALIGN_TOP, 5) --10

						l:AddPadding(-14) -- -11

						d.partAccelAngle = LM.GUI.AngleWidget(RL_LostLayerTool.DLOG2_CHANGE)
						l:AddChild(d.partAccelAngle, LM.GUI.ALIGN_CENTER)
					l:Pop()
					l:AddPadding(-5)
					l:PushV(LM.GUI.ALIGN_BOTTOM, 0)
						l:AddChild(LM.GUI.Divider(false), LM.GUI.ALIGN_FILL, 0)
						l:AddPadding(8)
						d.partAccelRate = LM.GUI.TextControl(31, "", RL_LostLayerTool.DLOG2_CHANGE, LM.GUI.FIELD_UFLOAT)
						l:AddChild(d.partAccelRate, LM.GUI.ALIGN_LEFT)

						l:PushV(LM.GUI.ALIGN_CENTER, 0)
							l:AddPadding(-4)
							d.partAccelRateButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesRate_h", "Acceleration Rate", false, 0)
							l:AddChild(d.partAccelRateButton, LM.GUI.ALIGN_FILL)
						l:Pop()
					l:Pop()
				l:Pop()
			l:Pop()
		l:Pop()

		l:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL, 0)

		l:PushV(LM.GUI.ALIGN_LEFT, 1)
			d.partOnStart = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesOnAtStart_h", "On at Start", true, RL_LostLayerTool.DLOG2_CHANGE)
			l:AddChild(d.partOnStart, LM.GUI.ALIGN_BOTTOM)

			d.partFullStart = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesFullSpeedStart_h", "Full Speed Start", true, RL_LostLayerTool.DLOG2_CHANGE)
			l:AddChild(d.partFullStart, LM.GUI.ALIGN_BOTTOM)

			d.partOrient = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesOrient_h", "Orient Particles", true, RL_LostLayerTool.DLOG2_CHANGE)
			l:AddChild(d.partOrient, LM.GUI.ALIGN_BOTTOM)

			d.partFreeFloat = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesFreeFloat_h", "Free Floating", true, RL_LostLayerTool.DLOG2_CHANGE)
			l:AddChild(d.partFreeFloat, LM.GUI.ALIGN_BOTTOM)

			d.partEvenlySpaced = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesEvenlySpaced_h", "Evenly Spaced", true, RL_LostLayerTool.DLOG2_CHANGE)
			l:AddChild(d.partEvenlySpaced, LM.GUI.ALIGN_BOTTOM)

			d.partRandomPlay = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesRandomPlayback_h", "Randomize Playback", true, RL_LostLayerTool.DLOG2_CHANGE)
			l:AddChild(d.partRandomPlay, LM.GUI.ALIGN_BOTTOM)

			l:AddPadding(1)

			d.partReseed = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesRandomSeed", "Randomize Seed", false, RL_LostLayerToolParticlesDialog.RESEED)
			l:AddChild(d.partReseed, LM.GUI.ALIGN_BOTTOM)
		l:Pop()
	l:Pop()

	--d.active= false
	return d
end

function RL_LostLayerToolParticlesDialog:UpdateWidgets()

	if (self.layer == nil or self.layer:LayerType() ~= MOHO.LT_PARTICLE) then
		return
	end

	-- ************* Text Fields **************
	local a = 0
	local b = 0

	a, b = self.layer:GetNumParticles(a, b)
	self.partCount:SetValue(a)
	self.partPrevCount:SetValue(b)

	self.partLifetime:SetValue(self.layer:Lifetime())

	local dim = self.layer:SourceDimensions()
	self.partWidth:SetValue(dim.x)
	self.partHeight:SetValue(dim.y)
	self.partDepth:SetValue(dim.z)

	a, b = self.layer:GetVelocity(a, b)
	self.partVelocity:SetValue(a)
	self.partVelSpread:SetValue(b)
	self.partDamping:SetValue(self.layer:Damping())

	-- ************* Check Boxes **************
	self.partOnStart:SetValue(self.layer:RunningTrack():GetValue(0))
	self.partFullStart:SetValue(self.layer:FullSpeedStart())
	self.partFullStart:Enable(self.partOnStart:Value())

	self.partOrient:SetValue(self.layer:Orientation())
	self.partFreeFloat:SetValue(self.layer:FreeFloating())
	self.partEvenlySpaced:SetValue(self.layer:EvenlySpaced())
	self.partRandomPlay:SetValue(self.layer:RandomStartTime())

	-- ************* Angle Controls **************
	a, b = self.layer:GetDirection(a, b)
	self.partDirAngle:SetValue(a)
	self.partDirSpread:SetValue(math.deg(b)*2)
	a, b = self.layer:GetAcceleration(a, b)
	self.partAccelAngle:SetValue(a)
	self.partAccelRate:SetValue(b)
end

function RL_LostLayerToolParticlesDialog:OnOK()
	if (self.layer == nil or self.layer:LayerType() ~= MOHO.LT_PARTICLE) then
		return
	end

	self.document:PrepUndo(self.layer)
	self.document:SetDirty()

	-- ************* Text Fields **************
	self.layer:SetNumParticles(self.partCount:IntValue(), self.partPrevCount:IntValue())
	self.layer:SetLifetime(self.partLifetime:IntValue())

	local v = LM.Vector3:new_local()
	v:Set(self.partWidth:FloatValue(), self.partHeight:FloatValue(), self.partDepth:FloatValue())
	self.layer:SetSourceDimensions(v)

	self.layer:SetVelocity(self.partVelocity:FloatValue(), self.partVelSpread:FloatValue())
	self.layer:SetDamping(self.partDamping:IntValue())

	-- ************* Check Boxes **************
	self.layer:RunningTrack():SetValue(0, self.partOnStart:Value())
	self.layer:SetFullSpeedStart(self.partFullStart:Value())
	self.layer:SetOrientation(self.partOrient:Value())
	self.layer:SetFreeFloating(self.partFreeFloat:Value())
	self.layer:SetEvenlySpaced(self.partEvenlySpaced:Value())
	self.layer:SetRandomStartTime(self.partRandomPlay:Value())

	-- ************* Angle Controls **************
	self.layer:SetDirection(self.partDirAngle:Value(), math.rad(self.partDirSpread:FloatValue())/2)
	self.layer:SetAcceleration(self.partAccelAngle:Value(), self.partAccelRate:FloatValue())

	-- ************* Finalize **************
	self.layer:FinalizeSettings()
	MOHO.Redraw()

	--self:HandleMessage(RL_LostLayerTool.DLOG2_CHANGE) --send this final message in case the user is in the middle of editing some value
end

function RL_LostLayerToolParticlesDialog:HandleMessage(msg)
	if (not (self.document and self.layer:LayerType() == MOHO.LT_PARTICLE)) then
		return
	end

	if ((msg == RL_LostLayerTool.DLOG2_CHANGE) or (msg == LM.GUI.MSG_CANCEL)) then
		--self.document:PrepUndo(self.layer)
		--self.document:SetDirty()
		self:OnOK()
		self:UpdateWidgets()

	elseif (msg == RL_LostLayerToolParticlesDialog.RESET) then
		if (self.layer ~= nil) then
			self.document:PrepUndo(self.layer)
			self.document:SetDirty()

			self.layer:SetNumParticles(100, 20)
			self.layer:SetLifetime(24)
			local v = LM.Vector3:new_local()
			v:Set(0.1, 0.1, 0)
			self.layer:SetSourceDimensions(v)
			self.layer:SetVelocity(2, 0.5)
			self.layer:SetDamping(0)
			self.layer:RunningTrack():SetValue(0, true)
			self.layer:SetFullSpeedStart(true)
			self.layer:SetOrientation(true)
			self.layer:SetFreeFloating(true)
			self.layer:SetEvenlySpaced(false)
			self.layer:SetRandomStartTime(false)
			self.layer:SetDirection(math.rad(90), math.rad(20))
			self.layer:SetAcceleration(math.rad(270), 4)

			self:UpdateWidgets()
			self.layer:FinalizeSettings()
			self.moho:Click()
			MOHO.Redraw()
		end

	elseif (msg == RL_LostLayerToolParticlesDialog.RESEED) then
		self.document:PrepUndo(self.layer)
		self.document:SetDirty()

		self.layer:SetRandomSeed(math.random(1, 16777216))
		--self.moho:SetCurFrame(self.frame) -- force the particles to be recalculated
		self.moho:Click()
		MOHO.Redraw()
	end

	--self:UpdateWidgets()
	--self.layer:FinalizeSettings()
	--MOHO.Redraw()
end

-- **************************************************
-- About... Dialog
-- **************************************************
---[[
local RL_LostLayerToolAboutDialog = {}

RL_LostLayerToolAboutDialog.CHANGE = MOHO.MSG_BASE
RL_LostLayerToolAboutDialog.RESET = MOHO.MSG_BASE + 1
RL_LostLayerToolAboutDialog.OPEN_LINK_000 = MOHO.MSG_BASE + 2 --Logo
RL_LostLayerToolAboutDialog.OPEN_LINK_001 = MOHO.MSG_BASE + 3 --Check for Updates
RL_LostLayerToolAboutDialog.OPEN_LINK_002 = MOHO.MSG_BASE + 4 --Bug Reports & Suggestions
RL_LostLayerToolAboutDialog.OPEN_LINK_003 = MOHO.MSG_BASE + 5 --Visit Webpage

RL_LostLayerToolAboutDialog.SPECIAL_THANKS_NAME = MOHO.MSG_BASE + 6

RL_LostLayerToolAboutDialog.randomThanks = nil

function RL_LostLayerToolAboutDialog:new(moho) --moho
	local d = LM.GUI.SimpleDialog("About ''Woa Layer Tool''", RL_LostLayerToolAboutDialog)
	local l = d:GetLayout()

	d.moho = moho

	l:PushV()
		l:PushH(LM.GUI.ALIGN_FILL, 12)
			l:PushV(LM.GUI.ALIGN_FILL, 0)
				l:AddPadding(-6)
				l:AddChild(LM.GUI.DynamicText(RL_LostLayerTool:Name() .."", 0), LM.GUI.ALIGN_LEFT)

				l:AddPadding(4)

				l:PushV(LM.GUI.ALIGN_LEFT, 0)
					l:AddChild(LM.GUI.DynamicText("VERSION: "..RL_LostLayerTool:Version(), 0), LM.GUI.ALIGN_LEFT)
					l:AddPadding(-2)
					l:PushH(LM.GUI.ALIGN_LEFT, 0)
						d.linkButton001 = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_checkForUpdates", "Check for Updates", false, self.OPEN_LINK_001)
						l:AddChild(d.linkButton001)

						d.checkUpdatesText = LM.GUI.TextControl(203, "http://lostastools.blogspot.com", 0, LM.GUI.FIELD_TEXT)
						l:AddChild(d.checkUpdatesText, LM.GUI.ALIGN_BOTTOM)
					l:Pop()

					l:AddPadding(2)

					l:AddChild(LM.GUI.DynamicText("AUTHOR: "..RL_LostLayerTool:Creator(), 0), LM.GUI.ALIGN_LEFT)

					l:AddPadding(-2)

					l:PushH(LM.GUI.ALIGN_LEFT, 0)
						d.linkButton002 = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_support", "Support (Bug Reports & Suggestions)", false, self.OPEN_LINK_002)
						l:AddChild(d.linkButton002)

						l:AddChild(LM.GUI.TextControl(203, "lostAStools@gmail.com", 0, LM.GUI.FIELD_TEXT), LM.GUI.ALIGN_BOTTOM)
					l:Pop()

					l:AddPadding(2)

					l:AddChild(LM.GUI.StaticText("SPECIAL THANKS TO..."), LM.GUI.ALIGN_TOP)

					l:AddPadding(-2)

					l:PushH(LM.GUI.ALIGN_LEFT, 0)
						d.linkButton003 = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_visitWebpage", "Visit Webpage", false, self.OPEN_LINK_003)
						l:AddChild(d.linkButton003)

						d.specialThanksMenu = LM.GUI.Menu("Special thanks to...") --"LM.GUI.Menu(the menu's title)" creates a new LM_Menu object that can then be added to a dialog or toolbar.
						d.specialThanksPopup = LM.GUI.PopupMenu(203, true) --LM.GUI.PopupMenu(width, radioMode)
						d.specialThanksPopup:SetMenu(d.specialThanksMenu) --Use "SetMenu(the menu object to display when the user clicks on the popup menu.)" function to attach a menu to the widget so that when the user clicks on it, the menu appears.
						l:AddChild(d.specialThanksPopup)
					l:Pop()--]]
				l:Pop()

				l:AddPadding(8)

				l:AddChild(LM.GUI.Divider(false), LM.GUI.ALIGN_FILL)
			l:Pop()

			d.linkButton000 = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_lostLayerToolLogo", "Lost AS Tools Site", false, self.OPEN_LINK_000)
			l:AddChild(d.linkButton000, LM.GUI.ALIGN_TOP)
		l:Pop()
	l:Pop()

	--[[
	-- Explicit Descriptor/handle (which you can have multiple input files and output files open simultaneously)
	f = io.open(filename, "r")
	if (f ~= nil) then
	 local t = f:read("*all")
	 f:close()
	else
	 print("Cannot not open", filename)
	end--]]

	return d
end

function RL_LostLayerToolAboutDialog:Update(moho)
	if (moho.layer == nil) then
		return
	end

	local layer = moho.layer

	self.moho = moho
	self.app = moho:AppDir()
	--self.click = moho:Click()
	--print(tostring(moho:AppDir()))

	self.checkUpdatesText:SetValue("http://lostastools.blogspot.com/2010/05/lost-layer-tool.html")

	self.specialThanksMenu:RemoveAllItems()
	for i, nameInfo in ipairs (RL_LostLayerTool.dlog3SpecialThanksLabels) do
		self.specialThanksMenu:AddItem(nameInfo.name, 0, self.SPECIAL_THANKS_NAME + i) --void AddItem(label, shortcut, msg)
	end

	self.specialThanksMenu:SetCheckedLabel(RL_LostLayerTool.dlog3SpecialThanksLabels[RL_LostLayerTool.dlog3RandomThanks].name, true)
	self.specialThanksPopup:Redraw()

	if RL_LostLayerTool.dlog3SpecialThanksLabels[self.specialThanksMenu:FirstChecked()+1].info ~= "" then
		self.linkButton003:Enable(true)
	else
		self.linkButton003:Enable(false)
	end
end

function RL_LostLayerToolAboutDialog:OnOK()
	RL_LostLayerTool.aboutWnd = nil -- mark the window closed
	--self.windowStatus = nil
end

function RL_LostLayerToolAboutDialog:HandleMessage(msg)
	--assert(io.popen('"C:\\Archivos de programa\\Smith Micro\\Anime Studio Pro 6\\Resources\\ScriptResources\\rl_lost_layer_tool\\.001.url"'))
	--print(tostring(self.moho:AppDir()))
	local appDir = self.app

	if (msg == self.OPEN_LINK_000) then
		local resDir = tostring("\\Resources\\ScriptResources\\rl_lost_layer_tool\\rl_lostLayerToolLogo.url")
		--print('"' .. appDir .. resDir .. '"')
		--assert(io.popen('"C:\\Archivos de programa\\Smith Micro\\Anime Studio Pro 6\\Resources\\ScriptResources\\rl_lost_layer_tool\\.001.url"'))
		assert(io.popen(tostring('"' .. appDir .. resDir .. '"'	)))
		self.moho:Click()
		--print(tostring(self.app))

	elseif (msg == self.OPEN_LINK_001) then
		local resDir = tostring("\\Resources\\ScriptResources\\rl_lost_layer_tool\\rl_checkForUpdates.url")
		assert(io.popen(tostring('"' .. appDir .. resDir .. '"'	)))
		self.moho:Click()

	elseif (msg == self.OPEN_LINK_002) then
		local resDir = tostring("\\Resources\\ScriptResources\\rl_lost_layer_tool\\rl_support.url")
		assert(io.popen('"' .. appDir .. resDir .. '"'))
		self.moho:Click()

	elseif (msg == self.OPEN_LINK_003) then
		local resDir = tostring("\\Resources\\ScriptResources\\rl_lost_layer_tool\\" .. RL_LostLayerTool.dlog3SpecialThanksLabels[self.specialThanksMenu:FirstChecked()+1].info)
		assert(io.popen('"' .. appDir .. resDir .. '"'))
		self.moho:Click()

	elseif (msg >= self.SPECIAL_THANKS_NAME) then
		RL_LostLayerTool.dlog3RandomThanks = (msg - self.SPECIAL_THANKS_NAME)
		self.moho:UpdateUI()
	end
end

---[[
function RL_LostLayerToolAboutDialog_Update(moho)
	if (RL_LostLayerTool.aboutWnd) then
		RL_LostLayerTool.aboutWnd:Update(moho)
	end
end

-- register the layer window to be updated when changes are made
table.insert(MOHO.UpdateTable, RL_LostLayerToolAboutDialog_Update)

--]]

-- **************************************************
-- Tool options - create and respond to tool's UI
-- **************************************************

RL_LostLayerTool.CHANGE = MOHO.MSG_BASE

RL_LostLayerTool.TRANSLATION_BUTTON = MOHO.MSG_BASE + 1  --pasar  a tener el valor de 10000 - 1
RL_LostLayerTool.TRANSLATION = MOHO.MSG_BASE + 2
RL_LostLayerTool.RESET = MOHO.MSG_BASE + 3
RL_LostLayerTool.TOGGLE_DISPLAY = MOHO.MSG_BASE + 4
RL_LostLayerTool.CAPTURE = MOHO.MSG_BASE + 5
RL_LostLayerTool.angleTolerance = 6


RL_LostLayerTool.TOGGLE_FLIP_H = MOHO.MSG_BASE + 7
RL_LostLayerTool.TOGGLE_FLIP_V = MOHO.MSG_BASE + 8

RL_LostLayerTool.TOGGLE_VISIBLE = MOHO.MSG_BASE + 9

RL_LostLayerTool.TOGGLE_ANIMATED_FX = MOHO.MSG_BASE + 10
RL_LostLayerTool.BLUR_BUTTON = MOHO.MSG_BASE + 11
RL_LostLayerTool.BLUR = MOHO.MSG_BASE + 12
RL_LostLayerTool.ALPHA_BUTTON = MOHO.MSG_BASE + 13
RL_LostLayerTool.ALPHA = MOHO.MSG_BASE + 14

RL_LostLayerTool.LAYER_BLENDING_MODE = MOHO.MSG_BASE + 15 --16 17 18 19 20 21 22 23 24

RL_LostLayerTool.TOGGLE_SHADOW = MOHO.MSG_BASE + 25
RL_LostLayerTool.TOGGLE_SHADING = MOHO.MSG_BASE + 26
RL_LostLayerTool.TOGGLE_PERSPECTIVE_SHADOW = MOHO.MSG_BASE + 27
RL_LostLayerTool.TOGGLE_MOTION_BLUR = MOHO.MSG_BASE + 28

RL_LostLayerTool.DLOG_BEGIN = MOHO.MSG_BASE + 29
RL_LostLayerTool.DLOG_CHANGE = MOHO.MSG_BASE + 30

RL_LostLayerTool.NO_MASKING_IN_THIS_GROUP = MOHO.MSG_BASE + 31
RL_LostLayerTool.REVEAL_ALL = MOHO.MSG_BASE + 32
RL_LostLayerTool.HIDE_ALL = MOHO.MSG_BASE + 33

RL_LostLayerTool.MASK_LAYER = MOHO.MSG_BASE + 34
RL_LostLayerTool.DONT_MASK_LAYER = MOHO.MSG_BASE + 35
RL_LostLayerTool.ADD_TO_MASK = MOHO.MSG_BASE + 36
--RL_LostLayerTool.SUB_FROM_MASK = MOHO.MSG_BASE + n --Hidden??
RL_LostLayerTool.ADD_TO_MASK_INVIS = MOHO.MSG_BASE + 37
RL_LostLayerTool.SUB_FROM_MASK = MOHO.MSG_BASE + 38
RL_LostLayerTool.CLEAR_ADD_MASK = MOHO.MSG_BASE + 39
RL_LostLayerTool.CLEAR_ADD_MASK_INVIS = MOHO.MSG_BASE + 40
RL_LostLayerTool.EXCLUDE_STROKES = MOHO.MSG_BASE + 41

RL_LostLayerTool.SWITCH_BUTTON = MOHO.MSG_BASE + 42
RL_LostLayerTool.SWITCH_VALUE = MOHO.MSG_BASE + 53 --ALWAYS LAST!!!

RL_LostLayerTool.PARTICLES_BUTTON = MOHO.MSG_BASE + 43

RL_LostLayerTool.AUDIO_LEVEL_BUTTON = MOHO.MSG_BASE + 44
RL_LostLayerTool.AUDIO_LEVEL = MOHO.MSG_BASE + 45
RL_LostLayerTool.AUDIO_JUMP_BUTTON = MOHO.MSG_BASE + 46

--RL_LostLayerTool.TOGGLE_BINDING_MODE = MOHO.MSG_BASE + n

RL_LostLayerTool.DLOG1_BEGIN = MOHO.MSG_BASE + 47
RL_LostLayerTool.DLOG1_CHANGE = MOHO.MSG_BASE + 48

RL_LostLayerTool.DLOG2_BEGIN = MOHO.MSG_BASE + 49
RL_LostLayerTool.DLOG2_CHANGE = MOHO.MSG_BASE + 50

RL_LostLayerTool.DLOG3_BEGIN = MOHO.MSG_BASE + 51 --if (RL_LostLayerTool.aboutWnd == nil) and (self.windowStatus == (self.DLOG3_BEGIN)) then
RL_LostLayerTool.DLOG3_CHANGE = MOHO.MSG_BASE + 52

--RL_LostLayerTool.ABOUT = MOHO.MSG_BASE + n

RL_LostLayerTool.displayOn = true --Show path option!
RL_LostLayerTool.layerInfoTable = {}

function RL_LostLayerTool:DoLayout(moho, layout)
	layout:PushH(LM.GUI.ALIGN_CENTER, 4)
		layout:PushH(LM.GUI.ALIGN_CENTER, 0)
			self.translationButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_layer_t_button", "Layer Translation", true, self.TRANSLATION_BUTTON)
			layout:AddChild(self.translationButton)

			layout:PushH(LM.GUI.ALIGN_CENTER, 0)
				layout:AddPadding(-2)
				self.textX = LM.GUI.TextControl(0, "00.00", self.TRANSLATION, LM.GUI.FIELD_FLOAT)
				layout:AddChild(self.textX)
				layout:AddPadding(-1)

				self.textY = LM.GUI.TextControl(0, "00.00", self.TRANSLATION, LM.GUI.FIELD_FLOAT)
				layout:AddChild(self.textY)
				layout:AddPadding(-1)

				self.textZ = LM.GUI.TextControl(0, "00.00", self.TRANSLATION, LM.GUI.FIELD_FLOAT)
				layout:AddChild(self.textZ)
				layout:AddPadding(-2)

				layout:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_resetButton", "Reset", false, self.RESET))
				layout:Pop()
		layout:Pop()

			self.displayCheck = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_showPathButton_small", "Show path", true, self.TOGGLE_DISPLAY)
			layout:AddChild(self.displayCheck)

		layout:PushH(LM.GUI.ALIGN_CENTER, 0)
			self.captureButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_layerMoCap_half", "MouseCap! [Angle Tolerance]", true, self.CAPTURE)
			layout:AddChild(self.captureButton)

			layout:PushH(LM.GUI.ALIGN_CENTER, 0)
				layout:AddPadding(-2)
				self.angleText = LM.GUI.TextControl(0, "0", self.CHANGE, LM.GUI.FIELD_UINT)
				self.angleText:SetWheelInc(1)
				layout:AddChild(self.angleText)
			layout:Pop()
		layout:Pop()

		layout:PushH(LM.GUI.ALIGN_CENTER, 0)
			self.flipHButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_flipLayerH_v", MOHO.Localize("/Scripts/Tool/SetOrigin/FlipH=Flip Layer Horizontally"), true, self.TOGGLE_FLIP_H)
			layout:AddChild(self.flipHButton)

			self.flipVButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_flipLayerV_v", MOHO.Localize("/Scripts/Tool/SetOrigin/FlipV=Flip Layer Vertically"), true, self.TOGGLE_FLIP_V)
			layout:AddChild(self.flipVButton)
		layout:Pop()

		layout:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL)

		self.isVisible = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_layerVis", "Visibility", true, self.TOGGLE_VISIBLE) --print(self.TOGGLE_VISIBLE) --self.isVisible parece ser la variable que contiene el bot n, self.TOGGLE_VISIBLE (msg) is the message value that is triggered when the button is pressed.
		layout:AddChild(self.isVisible) --Esto parece a adir el bot n, ahora como variable "self.isVisible" y valor msg: "self.TOGGLE_VISIBLE", al layout.

		self.animatedFx = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_allowAnimatedLayerFx_v", "Allow Animated Layer FX", true, self.TOGGLE_ANIMATED_FX)
		layout:AddChild(self.animatedFx)

		layout:PushH(LM.GUI.ALIGN_CENTER, 0)
			self.blurredButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_layerBlur", "Blur", true, self.BLUR_BUTTON)
			layout:AddChild(self.blurredButton)

			layout:PushH(LM.GUI.ALIGN_CENTER, 0)
				layout:AddPadding(-2)
				self.blurred = LM.GUI.TextControl(0, "0.", self.BLUR, LM.GUI.FIELD_INT)
				self.blurred:SetWheelInc(1)
				layout:AddChild(self.blurred)
			layout:Pop()
		layout:Pop()

		layout:PushH(LM.GUI.ALIGN_CENTER, 0)
			self.opacityButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_layerAlpha", "Opacity (%)", true, self.ALPHA_BUTTON)
			layout:AddChild(self.opacityButton)

			layout:PushH(LM.GUI.ALIGN_CENTER, 0)
				layout:AddPadding(-2)
				self.opacity = LM.GUI.TextControl(0, "0.", self.ALPHA, LM.GUI.FIELD_INT)
				self.opacity:SetWheelInc(1)
				layout:AddChild(self.opacity)
			layout:Pop()
		layout:Pop()

		self.lbmMenu = LM.GUI.Menu("Layer blending mode") --"LM.GUI.Menu(the menu's title)" creates a new LM_Menu object that can then be added to a dialog or toolbar.
		self.lbmPopup = LM.GUI.PopupMenu(50, true) --LM.GUI.PopupMenu(width, radioMode)
		self.lbmPopup:SetMenu(self.lbmMenu) --Use "SetMenu(the menu object to display when the user clicks on the popup menu.)" function to attach a menu to the widget so that when the user clicks on it, the menu appears.
		layout:AddChild(self.lbmPopup)

		layout:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL)

		layout:PushH(LM.GUI.ALIGN_CENTER, 0)
			self.shadowOn = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_channel_layer_shadow", "Shadow On", true, self.TOGGLE_SHADOW)
			layout:AddChild(self.shadowOn) --Esto parece a adir el bot n, ahora como variable "self.isVisible" y valor msg: "self.TOGGLE_VISIBLE", al layout.

			self.shadingOn = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_channel_layer_shading", "Shading On", true, self.TOGGLE_SHADING)
			layout:AddChild(self.shadingOn) --Esto parece a adir el bot n, ahora como variable "self.isVisible" y valor msg: "self.TOGGLE_VISIBLE", al layout.

			self.perspectiveOn = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_channel_layer_perspective", "Perspective Shadow On", true, self.TOGGLE_PERSPECTIVE_SHADOW)
			layout:AddChild(self.perspectiveOn) --Esto parece a adir el bot n, ahora como variable "self.isVisible" y valor msg: "self.TOGGLE_VISIBLE", al layout.

			self.hasMotionBlur = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_MB", "Motion Blur", true, self.TOGGLE_MOTION_BLUR)
			layout:AddChild(self.hasMotionBlur)

			layout:PushH(LM.GUI.ALIGN_CENTER, 0)
				layout:AddPadding(-101) ---340
				self.dlog = RL_LostLayerToolShadowsDialog:new()
				self.popup = LM.GUI.PopupDialog("_" .. rl_lostASutilities:dialogueDisplacer(19), true, self.DLOG_BEGIN) --"_                                                                               "
				self.popup:SetDialog(self.dlog)
				layout:AddChild(self.popup)
			layout:Pop()
		layout:Pop()

		layout:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL)

		self.groupMaskButtons = {} --groupMaskButtons parece ser la tabla que contendr  las variables self.groupMaskButtons[1], self.groupMaskButtons[2], self.groupMaskButtons[3]; que a su vez que contendr  cada uno de los bot nes.
		table.insert(self.groupMaskButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_GMB_noMask_h", "No Masking in this group", true, self.NO_MASKING_IN_THIS_GROUP))
		table.insert(self.groupMaskButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_GMB_revealAll_h", "Reveal all", true, self.REVEAL_ALL))
		table.insert(self.groupMaskButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_GMB_hideAll_h", "Hide all", true, self.HIDE_ALL))
		--se han insertado los botones en la tabla "self.groupMaskButtons"

		self.layerMaskingButtons = {}
		table.insert(self.layerMaskingButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LMB_maskLayer_small", "Mask this layer", true, self.MASK_LAYER)) --0
		table.insert(self.layerMaskingButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LMB_dontMaskLayer_small", "Don't mask this layer", true, self.DONT_MASK_LAYER)) --1
		table.insert(self.layerMaskingButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LMB_Add2Mask_small", "+ Add to mask", true, self.ADD_TO_MASK)) --2
		--table.insert(self.layerMaskingButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_layerMaskingButton", "+ Subtract from mask", true, self.SUB_FROM_MASK)) --Hidden?? 3
		table.insert(self.layerMaskingButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LMB_Add2MaskInvis_small", "+ Add to mask, but keep invisible", true, self.ADD_TO_MASK_INVIS))--4
		table.insert(self.layerMaskingButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LMB_subFromMaskInvis_small", "- Subtract from mask (this layer will be invisible)", true, self.SUB_FROM_MASK)) --5
		table.insert(self.layerMaskingButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LMB_clearThenAdd_small", "+ Clear the mask, then add this layer to it", true, self.CLEAR_ADD_MASK)) --6
		table.insert(self.layerMaskingButtons, LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LMB_clearThenAddInvis_small", "+ Clear the mask, then add this layer invisibly to it", true, self.CLEAR_ADD_MASK_INVIS)) --7

		layout:PushV(LM.GUI.ALIGN_CENTER, 1)
			layout:AddPadding(-4)
			layout:PushH(LM.GUI.ALIGN_CENTER, 2)
				for i, groupMaskButton in ipairs(self.groupMaskButtons) do
					layout:AddChild(groupMaskButton)
				end
				--con este loop se consigue indexar y a adir cada bot n, ahora como variable "groupMaskButton[1]" y valor (self.NO_MASKING_IN_THIS_GROUP), "groupMaskButton"[2] y valor (self.REVEAL_ALL), "groupMaskButton"[3] y val (self.HIDE_ALL)" al layout.
			layout:Pop()

			layout:PushH(LM.GUI.ALIGN_CENTER, 1)
				for i, layerMaskingButton in ipairs(self.layerMaskingButtons) do
					layout:AddChild(layerMaskingButton)
				end
				layout:AddPadding(2)
				self.strokesExcluded = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_LMB_excludeStrokes_small", "Exclude Strokes", true, self.EXCLUDE_STROKES)
				layout:AddChild(self.strokesExcluded)
			layout:Pop()
			layout:AddPadding(0)
		layout:Pop()


		layout:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL)

		layout:PushH(LM.GUI.ALIGN_CENTER, 0)
			self.switchButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_switchButton", "Switch Value", true, self.SWITCH_BUTTON)
			layout:AddChild(self.switchButton)

			layout:PushH(LM.GUI.ALIGN_CENTER, 0)
				layout:AddPadding(-4)
				self.switchMenu = LM.GUI.Menu("Select Switch Layer") --"LM.GUI.Menu(the menu's title)" creates a new LM_Menu object that can then be added to a dialog or toolbar.

				self.switchPopup = LM.GUI.PopupMenu(rl_lostASutilities:paddingUnixAdapter(24) + 2, true)
				self.switchPopup:SetMenu(self.switchMenu) --Use "SetMenu(the menu object to display when the user clicks on the popup menu.)" function to attach a menu to the widget so that when the user clicks on it, the menu appears.
				layout:AddChild(self.switchPopup)
			layout:Pop()
		layout:Pop()

		layout:AddPadding(-6)

		layout:PushH(LM.GUI.ALIGN_CENTER, 0)
			self.particlesOnButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_particlesOn", "Particles On/Off", true, self.PARTICLES_BUTTON)
			layout:AddChild(self.particlesOnButton)

			layout:PushH(LM.GUI.ALIGN_CENTER, 0)
				layout:AddPadding(rl_lostASutilities:paddingUnixAdapter(-18)) ---77
				self.dlog2 = RL_LostLayerToolParticlesDialog:new()
				self.popup2 = LM.GUI.PopupDialog("", false, self.DLOG2_BEGIN) --"_             "
				self.popup2:SetDialog(self.dlog2)
				layout:AddChild(self.popup2)
			layout:Pop()
		layout:Pop()

		layout:AddPadding(-6)

		layout:PushH(LM.GUI.ALIGN_CENTER, 0)
			self.audioLevelButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_audioLevel", "Audio Level", true, self.AUDIO_LEVEL_BUTTON)
			layout:AddChild(self.audioLevelButton)

			layout:PushH(LM.GUI.ALIGN_CENTER, 0)
				layout:AddPadding(-2)
				self.audioLevelText = LM.GUI.TextControl(32, "1", self.AUDIO_LEVEL, LM.GUI.FIELD_FLOAT)
				self.audioLevelText:SetWheelInc(0.01)
				layout:AddChild(self.audioLevelText)
			layout:Pop()

			self.audioJumpButton = LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_audioJump", "Audio Jump", true, self.AUDIO_JUMP_BUTTON)
			layout:AddChild(self.audioJumpButton)
		layout:Pop()

		layout:PushH(LM.GUI.ALIGN_FILL, 0)
			layout:AddChild(LM.GUI.Divider(true),LM.GUI.ALIGN_CENTER , 0)
		layout:Pop()

		layout:AddPadding(-9)
		layout:PushH(LM.GUI.ALIGN_CENTER, 0)
			layout:AddPadding(rl_lostASutilities:paddingUnixAdapter(-18))
			layout:PushV(LM.GUI.ALIGN_CENTER, 0)
				layout:AddPadding(9)
				self.dlog1 = RL_LostLayerToolVectorsDialog:new()
				self.popup1 = LM.GUI.PopupDialog("", false, self.DLOG1_BEGIN)
				self.popup1:SetDialog(self.dlog1)
				layout:AddChild(self.popup1)

				layout:PushV(LM.GUI.ALIGN_CENTER, 0)
					layout:AddPadding(-12)
					self.greyedStaticText = LM.GUI.StaticText("     ...")
					layout:AddChild(self.greyedStaticText)
				layout:Pop()
			layout:Pop()
		layout:Pop()

		--[[
		layout:PushH(LM.GUI.ALIGN_CENTER, 0)
			self.dlog2 = RL_LostLayerToolParticlesDialog:new()
			self.popup2 = LM.GUI.PopupDialog("..", false, self.DLOG2_BEGIN)
			self.popup2:SetDialog(self.dlog2)
			layout:AddChild(self.popup2)
		layout:Pop()--]]


		self.dlog3 = RL_LostLayerToolAboutDialog:new()
		layout:AddChild(LM.GUI.ImageButton("ScriptResources/rl_lost_layer_tool/rl_about", "About...", false, self.DLOG3_BEGIN), LM.GUI.ALIGN_CENTER)

		layout:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL)

		layout:PushV(LM.GUI.ALIGN_CENTER, 0) --LM.GUI.ALIGN_LEFT
			self.layerInfo = LM.GUI.DynamicText("", 960)
			layout:AddChild(self.layerInfo)
		layout:Pop()

	layout:Pop()

end

function RL_LostLayerTool:UpdateWidgets(moho)
	self.translationButton:SetValue(moho.layer.fTranslation:HasKey(moho.layerFrame))
	self.textX:SetValue(moho.layer.fTranslation.value.x)
	self.textY:SetValue(moho.layer.fTranslation.value.y)
	self.textZ:SetValue(moho.layer.fTranslation.value.z)

	self.displayCheck:SetValue(self.displayOn)

	if (moho.frame < 1) then
		self.dragCapture = false
		self.captureButton:SetValue(self.dragCapture)
	end
	self.captureButton:Enable(moho.frame > 0)
	self.angleText:Enable(moho.frame > 0)
	self.angleText:SetValue(RL_LostLayerTool.angleTolerance)

	self.flipHButton:SetValue(moho.layer.fFlipH.value)
	self.flipVButton:SetValue(moho.layer.fFlipV.value)

	self.isVisible:SetValue(moho.layer.fVisibility.value) --print(tostring(moho.layer.fVisibility.value)) --Asigna al bot n el valor "true" (activado) si la capa est  visible o "false" (desactivado) si la capa no es visible.
	--print(tostring(self.isVisible:Value())) --si fuese necesario, es la forma de obtener el valor (true or false) que devuelve la funci n del bot n!!!
	self.animatedFx:SetValue(moho.layer:HasAnimatedLayerEffects())

	self.blurredButton:SetValue(moho.layer.fBlur:HasKey(moho.layerFrame))
	self.blurred:SetValue(moho:DocToPixel(moho.layer.fBlur.value)) --Convert the coordinates into a working value to be showed in text field!

	self.opacityButton:SetValue(moho.layer.fAlpha:HasKey(moho.layerFrame))
	self.opacity:SetValue(moho.layer.fAlpha.value*100)

	self.layerBlendingLabels = {"Nor. ................... Chế độ mặc định pha trộn của lớp.", "Mul. ................ Lớp màu trắng trở nên trong suốt.", "Scr. .................. Lớp màu đen trở nên trong suốt.",
	"Ove. ................. Thêm cường độ cho các lớp bên dưới.", "Add ...... Giữ màu sắc, làm sáng thấp hơn không có màu đen.", "Dif. ........ Màu đen bị bỏ qua, màu trắng đảo ngược màu sắc thấp hơn.", "Hue .................. Màu sắc trên đầu thay thế màu sắc bên dưới.",
	"Sat. ...... Màu sắc hàng đầu xác định mức độ bão hòa thấp hơn.", "Col. ....... Màu sắc hàng đầu thay thế tất cả nhưng màu đen nguyên chất bên dưới.", "Lum. ... Giàng Hùng."}
	self.lbmMenu:RemoveAllItems()
	for i = 0, 10 - 1 do
		self.lbmMenu:AddItem(self.layerBlendingLabels[i +1], 0, self.LAYER_BLENDING_MODE + i) --void AddItem(label, shortcut, msg)
	end
	self.lbmMenu:SetCheckedLabel(self.layerBlendingLabels[moho.layer:BlendingMode() + 1], true) --moho.layer:BlendingMode()
	self.lbmPopup:Redraw()

	self.shadowOn:SetValue(moho.layer.fLayerShadow.value)

	self.shadingOn:SetValue(moho.layer.fLayerShading.value)

	self.perspectiveOn:SetValue(moho.layer.fPerspectiveShadow.value)

	self.hasMotionBlur:SetValue(moho.layer.fMotionBlur.value)

	if (moho.layer:IsGroupType()) and ((moho.layer:LayerType() ~= MOHO.LT_SWITCH) and (moho.layer:LayerType() ~= MOHO.LT_PARTICLE)) then
		self.groupMaskButtons[1]:Enable(true)
		self.groupMaskButtons[2]:Enable(true)
		self.groupMaskButtons[3]:Enable(true)

		for i, groupMaskButton in ipairs(self.groupMaskButtons) do
			if (moho:LayerAsGroup(moho.layer):GetGroupMask() == MOHO.GROUP_MASK_NONE +i -1) then
				groupMaskButton:SetValue(true)
			else
				groupMaskButton:SetValue(false)
			end
		end
	else
		self.groupMaskButtons[1]:Enable(false)
		self.groupMaskButtons[2]:Enable(false)
		self.groupMaskButtons[3]:Enable(false)
		local parentLayer = moho.layer:Parent()

		if (parentLayer ~= nil) and  (parentLayer:IsGroupType()) and ((parentLayer:LayerType() ~= MOHO.LT_SWITCH) and (parentLayer:LayerType() ~= MOHO.LT_PARTICLE)) then
			for i, groupMaskButton in ipairs(self.groupMaskButtons) do
				if (moho:LayerAsGroup(parentLayer):GetGroupMask() == MOHO.GROUP_MASK_NONE +i -1) then
					groupMaskButton:SetValue(true)
				else
					groupMaskButton:SetValue(false)
				end
			end
		else
			for i, groupMaskButton in ipairs(self.groupMaskButtons) do
				--if (moho:LayerAsGroup(moho.layer):GetGroupMask() == MOHO.GROUP_MASK_NONE +i -1) then
					groupMaskButton:SetValue(false)
				--end

			end
		end
	end

	--[[
	for i, layerMaskingButton in ipairs(self.layerMaskingButtons) do
		if (moho.layer:MaskingMode() == MOHO.MM_MASKED +i -1) then
			layerMaskingButton:SetValue(true)
		else
			layerMaskingButton:SetValue(false)
		end
	end--]]

	if (moho.layer:MaskingMode() == MOHO.MM_MASKED) then --Optimizar!
		self.layerMaskingButtons[1]:SetValue(true)
	else
		self.layerMaskingButtons[1]:SetValue(false)
	end
	if (moho.layer:MaskingMode() == MOHO.MM_NOTMASKED) then
		self.layerMaskingButtons[2]:SetValue(true)
	else
		self.layerMaskingButtons[2]:SetValue(false)
	end
	if (moho.layer:MaskingMode() == MOHO.MM_ADD_MASK) then
		self.layerMaskingButtons[3]:SetValue(true)
	else
		self.layerMaskingButtons[3]:SetValue(false)
	end
	if (moho.layer:MaskingMode() == MOHO.MM_ADD_MASK_INVIS) then
		self.layerMaskingButtons[4]:SetValue(true)
	else
		self.layerMaskingButtons[4]:SetValue(false)
	end
	if (moho.layer:MaskingMode() == MOHO.MM_SUB_MASK_INVIS) then
		self.layerMaskingButtons[5]:SetValue(true)
	else
		self.layerMaskingButtons[5]:SetValue(false)
	end
	if (moho.layer:MaskingMode() == MOHO.MM_CLEAR_ADD_MASK) then
		self.layerMaskingButtons[6]:SetValue(true)
	else
		self.layerMaskingButtons[6]:SetValue(false)
	end
	if (moho.layer:MaskingMode() == MOHO.MM_CLEAR_ADD_MASK_INVIS) then
		self.layerMaskingButtons[7]:SetValue(true)
	else
		self.layerMaskingButtons[7]:SetValue(false)
	end

	if (moho:LayerAsVector(moho.layer)) and ((moho.layer:MaskingMode() == MOHO.MM_ADD_MASK) or (moho.layer:MaskingMode() == MOHO.MM_ADD_MASK_INVIS) or (moho.layer:MaskingMode() == MOHO.MM_CLEAR_ADD_MASK) or (moho.layer:MaskingMode() == MOHO.MM_CLEAR_ADD_MASK_INVIS)) then
		self.strokesExcluded:Enable(true)
		if (moho.layer.fExcludeLinesFromMask == true) then
			self.strokesExcluded:SetValue(true)
		else
			self.strokesExcluded:SetValue(false)
		end
	else
		self.strokesExcluded:Enable(false)
	end--]]

	self.switchButton:Enable(false) --self.switchButton:Enable(moho.layer:LayerType() == MOHO.LT_SWITCH)
	self.switchButton:SetValue(false)
	self.switchPopup:Enable(false)

	if moho.frame == 0 then
		 self.layerInfo:Enable(true) else self.layerInfo:Enable(false)
	end

	if (moho.layer:LayerType() == MOHO.LT_SWITCH) then
		self.switchButton:Enable(true)
		self.switchPopup:Enable(true)
		local switchLayer = moho:LayerAsSwitch(moho.layer)

		self.switchButton:SetValue(moho:LayerAsSwitch(moho.layer):SwitchValues():HasKey(moho.layerFrame))

		self.switchMenu:RemoveAllItems()
		for i = 0, switchLayer:CountLayers() - 1 do
			self.switchMenu:AddItem(switchLayer:Layer(i):Name(), 0, self.SWITCH_VALUE + i)
		end
		self.switchMenu:SetCheckedLabel(switchLayer:SwitchValues():GetValue(moho.layerFrame), true)
		self.switchPopup:Redraw()

		if (switchLayer:SwitchValues():GetValue(moho.layerFrame) ~= "") then
			self.layerInfoTable.switchValue = tostring('"' .. rl_lostASutilities:compactString(tostring(switchLayer:SwitchValues():GetValue(moho.layerFrame)), 14) .. '"')
			self.layerInfoTable.switchValueDiv = " | "
		else
			self.layerInfoTable.switchValue = "Unswitched"
			self.layerInfoTable.switchValueDiv = " | "
		end

	elseif (moho.layer:Parent() ~= nil) and (moho.layer:Parent():LayerType() == MOHO.LT_SWITCH) then
		self.switchButton:Enable(true)
		self.switchPopup:Enable(true)
		local parentSwitchLayer = moho:LayerAsSwitch(moho.layer:Parent())

		self.switchButton:SetValue(moho:LayerAsSwitch(moho.layer:Parent()):SwitchValues():HasKey(moho.layerFrame)) --moho.layerFrame

		self.switchMenu:RemoveAllItems()
		for i = 0, parentSwitchLayer:CountLayers() - 1 do
			self.switchMenu:AddItem(parentSwitchLayer:Layer(i):Name(), 0, self.SWITCH_VALUE + i)
		end

		self.switchMenu:SetCheckedLabel(parentSwitchLayer:SwitchValues():GetValue(moho.layerFrame), true)
		self.switchPopup:Redraw()

		if (parentSwitchLayer:SwitchValues():GetValue(moho.layerFrame) ~= "") then
			self.layerInfoTable.switchValue = tostring('"' .. rl_lostASutilities:compactString(tostring(parentSwitchLayer:SwitchValues():GetValue(moho.layerFrame)), 14) ..'"')
			self.layerInfoTable.switchValueDiv = " | "
		else
			self.layerInfoTable.switchValue = "Unswitched"
			self.layerInfoTable.switchValueDiv = " | "
		end

	else
		self.layerInfoTable.switchValue = ""
		self.layerInfoTable.switchValueDiv = ""
	end

	if ((moho.layer:LayerType() == MOHO.LT_VECTOR)) then
		local mesh = moho:Mesh()
		local points = mesh:CountPoints()
		local groups = mesh:CountGroups()
		local curves = mesh:CountCurves()
		local shapes = mesh:CountShapes()

		if points > 0 then
			self.layerInfoTable.points = points .. " Points" else self.layerInfoTable.points = ""
		end
		if groups > 0 then
			self.layerInfoTable.groups = ", " .. groups .. " Groups" else self.layerInfoTable.groups = ""
		end
		if curves > 0 then
			self.layerInfoTable.curves = ", " .. curves .. " Curves" else self.layerInfoTable.curves = ""
		end
		if shapes > 0 then
			self.layerInfoTable.shapes = ", " .. shapes .. " Shapes" else self.layerInfoTable.shapes = ""
		end

		self.layerInfoTable.vectorInfoDiv = " | "
		self.layerInfoTable.vectorInfo = tostring(self.layerInfoTable.points .. self.layerInfoTable.groups .. self.layerInfoTable.curves .. self.layerInfoTable.shapes)
	else
		self.layerInfoTable.vectorInfo = ""
		self.layerInfoTable.vectorInfoDiv = ""
	end

	if ((moho.layer:LayerType() == MOHO.LT_IMAGE)) then
		local imageLayer = moho:LayerAsImage(moho.layer)
		local movieLayer = moho:LayerAsImage(moho.layer):IsMovieLayer()
		local source = tostring(imageLayer:SourceImage())
		local duration = imageLayer:MovieDuration()
		local fps = imageLayer:MovieFps()
		local width = imageLayer:PixelWidth()
		local height = imageLayer:PixelHeight()
		local trackers = imageLayer:CountTrackingPoints()

		if movieLayer then
			self.layerInfoTable.duration = duration .. " f" else self.layerInfoTable.duration = ""
		end
		if movieLayer then
			self.layerInfoTable.fps = " (" .. fps .. " fps), " else self.layerInfoTable.fps = ""
		end
		if (source ~= "") then
			self.layerInfoTable.width = width .. " x "
			self.layerInfoTable.height = height .. "px"
			self.layerInfoTable.ratio = " (" .. string.sub(tostring(width / height), 1 , 5) .. ")"
			self.layerInfoTable.missed = ""
		else
			self.layerInfoTable.width = ""
			self.layerInfoTable.height = ""
			self.layerInfoTable.ratio = ""
			self.layerInfoTable.missed = "Missed Source"
		end
		if trackers > 0 then
			self.layerInfoTable.trackers = ", " .. trackers .. " Trackers" else self.layerInfoTable.trackers = ""
		end

		self.layerInfoTable.imageInfoDiv = " | "
		self.layerInfoTable.imageInfo = tostring(self.layerInfoTable.duration .. self.layerInfoTable.fps .. self.layerInfoTable.width .. self.layerInfoTable.height .. self.layerInfoTable.ratio .. self.layerInfoTable.trackers .. self.layerInfoTable.missed)
	else
		self.layerInfoTable.imageInfo = ""
		self.layerInfoTable.imageInfoDiv = ""
	end

	if (moho.layer:IsGroupType()) then
		local groupLayer = moho:LayerAsGroup(moho.layer)
		local childs = groupLayer:CountLayers()

		if (childs > 0) then
			self.layerInfoTable.childs = childs .. " Childs"
			self.layerInfoTable.groupInfoDiv = " | "
		else
			self.layerInfoTable.childs = ""
			self.layerInfoTable.groupInfoDiv = ""
		end
		self.layerInfoTable.groupInfo = tostring(self.layerInfoTable.childs)

		if (groupLayer:IsBoneType()) then
			local skel = moho:Skeleton()
			local bones = skel:CountBones()

			if bones > 0 then
				self.layerInfoTable.bones = bones .. " Bones"
				self.layerInfoTable.boneInfo = tostring(self.layerInfoTable.groupInfoDiv .. self.layerInfoTable.bones)
				self.layerInfoTable.boneInfoDiv = " | "
			else
				self.layerInfoTable.bones = ""
				self.layerInfoTable.boneInfo = ""
				self.layerInfoTable.boneInfoDiv = ""
			end

		elseif (groupLayer:LayerType() == MOHO.LT_PARTICLE) then
			self.layerInfoTable.boneInfo = ""
			self.layerInfoTable.boneInfoDiv = ""
		else
			self.layerInfoTable.boneInfo = ""
			self.layerInfoTable.boneInfoDiv = ""
		end

	else
		self.layerInfoTable.groupInfo = ""
		self.layerInfoTable.groupInfoDiv = ""
		self.layerInfoTable.boneInfo = ""
		self.layerInfoTable.boneInfoDiv = ""
	end

	if (moho.layer:IsAudioType()) then
		local audioLayer = moho:LayerAsAudio(moho.layer)
		local maxAmp = string.sub(audioLayer:MaxAmplitude(), 1, 5)
		local audioPan = string.sub(audioLayer:GetStereoPosition(moho.frame), 1 , 5)

		self.layerInfoTable.audioInfoDiv = " | "
		self.layerInfoTable.audioInfo = tostring(self.layerInfoTable.imageInfoDiv .. "MaxAmp: " .. maxAmp .. ", " .. "AudioPan: " .. audioPan)
	else
		self.layerInfoTable.audioInfo = ""
		self.layerInfoTable.audioInfoDiv = ""
	end

	if ((moho.layer:LayerType() == MOHO.LT_3D)) then
		local mesh3D = moho:Mesh3D()
		local vertexes = mesh3D:CountPoints()
		local texPoints = mesh3D:CountTexturePoints()
		local faces = mesh3D:CountFaces()
		local mats = mesh3D:CountMaterials()

		if vertexes > 0 then
			self.layerInfoTable.vertexes = vertexes .. " Points" else self.layerInfoTable.vertexes = ""
		end
		if texPoints > 0 then
			self.layerInfoTable.texPoints = ", " .. texPoints .. " TexPoints" else self.layerInfoTable.texPoints = ""
		end
		if faces > 0 then self.layerInfoTable.faces = ", " .. faces .. " Faces" else self.layerInfoTable.faces = ""
		end
		if mats > 0 then
			self.layerInfoTable.mats = ", " .. mats .. " Mats" else self.layerInfoTable.mats = ""
		end

		self.layerInfoTable.dddInfoDiv = " | "
		self.layerInfoTable.dddInfo = tostring(self.layerInfoTable.vertexes .. self.layerInfoTable.texPoints .. self.layerInfoTable.faces .. self.layerInfoTable.mats)
	else
		self.layerInfoTable.dddInfo = ""
		self.layerInfoTable.dddInfoDiv = ""
	end

	if (tostring(self.layerInfoTable.vectorInfo .. self.layerInfoTable.imageInfo .. self.layerInfoTable.groupInfo .. self.layerInfoTable.boneInfo .. self.layerInfoTable.audioInfo .. self.layerInfoTable.dddInfo) == "") then
		self.layerInfoTable.layerInfoLabel = ""
	else
		self.layerInfoTable.layerInfoLabel = self.layerInfoTable.switchValueDiv .. "Info: "
	end

	self.particlesOnButton:Enable(moho.layer:LayerType() == MOHO.LT_PARTICLE)
	self.particlesOnButton:SetValue(false)
	self.popup2:Enable(moho.layer:LayerType() == MOHO.LT_PARTICLE)

	if (moho.layer:LayerType() == MOHO.LT_PARTICLE) then
		self.particlesOnButton:SetValue(moho:LayerAsParticle(moho.layer):RunningTrack():GetValue(moho.layerFrame))
	end

	self.audioLevelButton:Enable(moho.layer:IsAudioType())
	self.audioLevelText:Enable(moho.layer:IsAudioType())
	self.audioJumpButton:Enable(moho.layer:IsAudioType())

	if (moho.layer:IsAudioType()) then
		self.audioLevelButton:SetValue(moho:LayerAsAudio(moho.layer).fAudioLevel:HasKey(moho.layerFrame))
		self.audioLevelText:SetValue(moho:LayerAsAudio(moho.layer).fAudioLevel.value)
		self.audioJumpButton:SetValue(moho:LayerAsAudio(moho.layer).fJumpToFrame:HasKey(moho.layerFrame))
	end

	self.popup1:Enable(true)
	self.greyedStaticText:Enable(true)
	if (moho.layer:LayerType() == MOHO.LT_GROUP) or (moho.layer:LayerType() == MOHO.LT_PARTICLE) or (moho.layer:LayerType() == MOHO.LT_NOTE) then
		self.popup1:Enable(false)
		self.greyedStaticText:Enable(false)
	end

	self.layerInfo:SetValue(self.layerInfoTable.switchValue .. self.layerInfoTable.layerInfoLabel .. self.layerInfoTable.vectorInfo .. self.layerInfoTable.imageInfo .. self.layerInfoTable.groupInfo .. self.layerInfoTable.boneInfo .. self.layerInfoTable.audioInfo .. self.layerInfoTable.dddInfo)

---------------- Layer Effects Dialogue ----------------
	self.dlog.document = moho.document
	self.dlog.layer = moho.layer
	self.dlog.activeLayer = moho.layer
	self.dlog.frame = moho.frame
	self.dlog.layerFrame = moho.layerFrame
	self.dlog:UpdateWidgets()
	self.dlog.moho = moho
	--self.dlog.setCurFrame = moho:SetCurFrame(moho.frame) --Testing...

---------------- Layer Settings Dialogue ----------------
	self.dlog1.moho = moho
	self.dlog1.document = moho.document
	self.dlog1.layer = moho.layer
	self.dlog1.activeLayer = moho.layer
	self.dlog1.layer3d = moho:LayerAs3D(moho.layer)
	self.dlog1.frame = moho.frame
	self.dlog1.layerFrame = moho.layerFrame
	--[[
	if (moho.layer:LayerType() == MOHO.LT_3D) then
		local mesh3D = moho:Mesh3D()
		self.dlog1.mesh3D = moho:Mesh3D()
		self.dlog1.defaultColor = mesh3D:DefaultColor()
		self.dlog1.edgeColor = mesh3D:DefaultEdgeColor()
		self.dlog1.dddClockwise = mesh3D:Clockwise()
	end--]]
	self.dlog1:UpdateWidgets()
	--self.popup1:Redraw()

---------------- Particles Settings Dialogue ----------------
	self.dlog2.document = moho.document
	self.dlog2.layer = moho.layer
	self.dlog2.moho = moho
	--self.dlog2.activeLayer = moho.layer
	--self.dlog2.frame = moho.frame
	--self.dlog2.layerFrame = moho.layerFrame
	--self.dlog2:UpdateWidgets()

---------------- About Window Dialogue ----------------
	--[[
	if (self.dlog3) then
		self.dlog3:Update(moho)
	end--]]

	if (RL_LostLayerTool.aboutWnd == nil) and (self.windowStatus == (self.DLOG3_BEGIN)) then
		RL_LostLayerTool.aboutWnd = RL_LostLayerToolAboutDialog:new()
		RL_LostLayerTool.aboutWnd:DoModeless()
	end
	self.windowStatus = nil

	self.dlog3.moho = moho
	self.dlog3.app = moho:AppDir()
end

function RL_LostLayerTool:HandleMessage(moho, view, msg)
	local newVal = LM.Vector3:new_local()
	local layer = moho.layer
	local selCount = moho.document:CountSelectedLayers()

	translationButtonValue = moho.layer.fTranslation:HasKey(moho.frame)
	blurredButtonValue = moho.layer.fBlur:HasKey(moho.frame)
	opacityButtonValue = moho.layer.fAlpha:HasKey(moho.frame)

	self.windowStatus = msg

	if (msg == self.CHANGE) then
		self.angleTolerance = self.angleText:FloatValue()
		self.angleTolerance = LM.Clamp(self.angleTolerance, 0, 30)

	elseif (msg == self.RESET) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()

		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			if (moho.frame == 0) then
				newVal:Set(0, 0, 0)
				layer.fTranslation:SetValue(0, newVal)
			else
				newVal:Set(layer.fTranslation:GetValue(0))
				layer.fTranslation:SetValue(moho.frame + layer:TotalTimingOffset(), newVal)
			end
		end
		self:UpdateWidgets(moho)
		moho:NewKeyframe(CHANNEL_LAYER_T)
		moho.document:DepthSort()

	elseif (msg == self.TRANSLATION_BUTTON) then --and (translationButtonValue ~= self.translationButton:Value()) then
		if not moho.layer.fTranslation:HasKey(moho.layerFrame) then
			for i = 0, selCount - 1 do
				local layer = moho.document:GetSelectedLayer(i)
				layer.fTranslation:StoreValue()
				MOHO.NewKeyframe(CHANNEL_LAYER_T)
			end
		else
			if (moho.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = moho.document:GetSelectedLayer(i)
					layer.fTranslation:DeleteKey(moho.frame + layer:TotalTimingOffset())
				end
			end
		end

	elseif (msg == self.TRANSLATION) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()

		newVal.x = self.textX:FloatValue()
		newVal.y = self.textY:FloatValue()
		newVal.z = self.textZ:FloatValue()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			local vec = layer.fTranslation:GetValue(moho.frame + layer:TotalTimingOffset()) - newVal
			if (vec:Mag() > 0.0001) then --0.0001
				layer.fTranslation:SetValue(moho.frame + layer:TotalTimingOffset(), newVal)
				moho:NewKeyframe(CHANNEL_LAYER_T)
			end
		end
		moho.document:DepthSort()

	elseif (msg == self.TOGGLE_DISPLAY) then
		self.displayOn = self.displayCheck:Value()

	elseif (msg == self.CAPTURE) then
		self.dragCapture = self.captureButton:Value()

	elseif (msg == self.TOGGLE_FLIP_H) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		newVal = moho.layer.fFlipH.value
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer.fFlipH:SetValue(moho.frame + layer:TotalTimingOffset(), not newVal)
			moho:NewKeyframe(CHANNEL_LAYER_FLIP_H)
		end

	elseif (msg == self.TOGGLE_FLIP_V) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		newVal = moho.layer.fFlipV.value
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer.fFlipV:SetValue(moho.frame + layer:TotalTimingOffset(), not newVal)
			moho:NewKeyframe(CHANNEL_LAYER_FLIP_V)
		end

	elseif (msg == self.TOGGLE_VISIBLE) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		newVal = moho.layer.fVisibility.value
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer.fVisibility:SetValue(moho.frame + layer:TotalTimingOffset(), not newVal)
			moho:NewKeyframe(CHANNEL_LAYER_VIS)
		end

	elseif (msg == self.TOGGLE_ANIMATED_FX) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)

			if (layer:HasAnimatedLayerEffects()) and ((layer.fBlur:Duration() + layer.fAlpha:Duration() +
			layer.fLayerShadow:Duration() + layer.fShadowAngle:Duration() + layer.fShadowOffset:Duration() + layer.fShadowBlur:Duration() + layer.fShadowExpansion:Duration() + layer.fShadowColor:Duration() +
			layer.fLayerShading:Duration() + layer.fShadingAngle:Duration() + layer.fShadingOffset:Duration() + layer.fShadingBlur:Duration() + layer.fShadingContraction:Duration() + layer.fShadingColor:Duration() +
			layer.fPerspectiveShadow:Duration() + layer.fPerspectiveBlur:Duration() + layer.fPerspectiveScale:Duration() + layer.fPerspectiveShear:Duration() + layer.fPerspectiveColor:Duration() +
			layer.fMotionBlur:Duration() + layer.fMotionBlurFrames:Duration() + layer.fMotionBlurSkip:Duration() + layer.fMotionBlurAlphaStart:Duration() + layer.fMotionBlurAlphaEnd:Duration() + layer.fMotionBlurRadius:Duration() ) > 0) then
				local doIt = LM.GUI.Alert(LM.GUI.ALERT_WARNING, "Layer FX animation will be lost!", nil, nil, "Proceed", "Cancel", nil)
				if doIt ~= 0 then
					moho:UpdateUI()
					return
				end
			end
			layer:SetAnimatedLayerEffects(self.animatedFx:Value())
		end

	elseif (msg == self.BLUR_BUTTON) then --and (blurredButtonValue ~= self.blurredButton:Value()) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		if not moho.layer.fBlur:HasKey(moho.layerFrame) then
			for i = 0, selCount - 1 do
				local layer = moho.document:GetSelectedLayer(i)
				layer.fBlur:StoreValue()
				MOHO.NewKeyframe(CHANNEL_LAYER_BLUR)
			end
		else
			for i = 0, selCount - 1 do
				local layer = moho.document:GetSelectedLayer(i)
				if (moho.frame ~= 0) then
					layer.fBlur:DeleteKey(moho.frame + layer:TotalTimingOffset())
				end
			end
		end

	elseif (msg == self.BLUR) then
		newVal = self.blurred:FloatValue()
		if (newVal < 0 or newVal > 256) then
			newVal = LM.Clamp(newVal, 0, 256)
			self.blurred:SetValue(newVal)
		end --...to here.

		local blurValue = 0.0
		if self.blurred == 0 then
			blurValue = 0.0
		else
			blurValue = moho:PixelToDoc(self.blurred:IntValue()) --Convert the imput value into document coordinates!
		end
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer.fBlur:SetValue(moho.frame + layer:TotalTimingOffset(), blurValue)
			moho:NewKeyframe(CHANNEL_LAYER_BLUR)
		end

	elseif (msg == self.ALPHA_BUTTON) then --and (opacityButtonValue ~= self.opacityButton:Value()) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		if not moho.layer.fAlpha:HasKey(moho.layerFrame) then
			for i = 0, selCount - 1 do
				local layer = moho.document:GetSelectedLayer(i)
				layer.fAlpha:StoreValue()
				MOHO.NewKeyframe(CHANNEL_LAYER_ALPHA)
			end
		else
			for i = 0, selCount - 1 do
				local layer = moho.document:GetSelectedLayer(i)
				if (moho.frame ~= 0) then
					layer.fAlpha:DeleteKey(moho.frame + layer:TotalTimingOffset())
				end
			end
		end

	elseif (msg == self.ALPHA) then
		newVal = self.opacity:FloatValue()
		if (newVal < 0 or newVal > 100) then
			newVal = LM.Clamp(newVal, 0, 100)
			self.opacity:SetValue(newVal)
		end --...to here.

		local alphaValue = 0.0
		if self.opacity == 0 then
			alphaValue = 0.0
		else
			alphaValue = self.opacity:IntValue()/100
		end
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer.fAlpha:SetValue(moho.frame + layer:TotalTimingOffset(), alphaValue)
			moho:NewKeyframe(CHANNEL_LAYER_ALPHA)
		end

	elseif (msg >= self.LAYER_BLENDING_MODE and msg <= self.LAYER_BLENDING_MODE + 9) then
		moho.document:PrepMultiUndo() --(moho.layer)
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer:SetBlendingMode(self.lbmMenu:FirstChecked())
		end

	elseif (msg == self.TOGGLE_SHADOW) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		newVal = moho.layer.fLayerShadow.value
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer.fLayerShadow:SetValue(moho.frame + layer:TotalTimingOffset(), not newVal)
			moho:NewKeyframe(CHANNEL_LAYER_SHADOW)
			--moho:UpdateUI()
		end

	elseif (msg == self.TOGGLE_SHADING) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		newVal = moho.layer.fLayerShading.value
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer.fLayerShading:SetValue(moho.frame + layer:TotalTimingOffset(), not newVal)
			moho:NewKeyframe(CHANNEL_LAYER_SHADING)
		end

	elseif (msg == self.TOGGLE_PERSPECTIVE_SHADOW) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		newVal = moho.layer.fPerspectiveShadow.value
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer.fPerspectiveShadow:SetValue(moho.frame + layer:TotalTimingOffset(), not newVal)
			moho:NewKeyframe(CHANNEL_LAYER_PERSPSHADOW)
		end

	elseif (msg == self.TOGGLE_MOTION_BLUR) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		newVal = moho.layer.fMotionBlur.value
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer.fMotionBlur:SetValue(moho.frame + layer:TotalTimingOffset(), not newVal)
			moho:NewKeyframe(CHANNEL_LAYER_MB)
		end

	elseif (msg >= self.NO_MASKING_IN_THIS_GROUP and msg <= self.HIDE_ALL) then
		self.groupMaskMode = msg
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		for i, groupMaskButton in ipairs(self.groupMaskButtons) do
			--but:SetValue(self.groupMaskMode == self.NO_MASKING_IN_THIS_GROUP + i - 1)
			if (msg == self.NO_MASKING_IN_THIS_GROUP) then
				groupMaskButton:SetValue(self.groupMaskMode == RL_LostLayerTool.NO_MASKING_IN_THIS_GROUP + i - 1)
				moho:LayerAsGroup(moho.layer):SetGroupMask(MOHO.GROUP_MASK_NONE)
			elseif (msg == self.REVEAL_ALL) then
				groupMaskButton:SetValue(self.groupMaskMode == RL_LostLayerTool.NO_MASKING_IN_THIS_GROUP + i - 1)
				moho:LayerAsGroup(moho.layer):SetGroupMask(MOHO.GROUP_MASK_SHOW_ALL)
			elseif (msg == self.HIDE_ALL) then
				groupMaskButton:SetValue(self.groupMaskMode == RL_LostLayerTool.NO_MASKING_IN_THIS_GROUP + i - 1)
				moho:LayerAsGroup(moho.layer):SetGroupMask(MOHO.GROUP_MASK_HIDE_ALL)
			end
		end

	elseif (msg >= self.MASK_LAYER and msg <= self.CLEAR_ADD_MASK_INVIS) then
		self.layerMaskingMode = msg
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		for i, layerMaskingButton in ipairs(self.layerMaskingButtons) do
			--but:SetValue(self.groupMaskMode == self.NO_MASKING_IN_THIS_GROUP + i - 1)
			if (msg == self.MASK_LAYER) then --0
				layerMaskingButton:SetValue(self.layerMaskingMode == RL_LostLayerTool.MASK_LAYER + i - 1)
				moho.layer:SetMaskingMode(MOHO.MM_MASKED)
			elseif (msg == self.DONT_MASK_LAYER) then --1
				layerMaskingButton:SetValue(self.layerMaskingMode == RL_LostLayerTool.MASK_LAYER + i - 1)
				moho.layer:SetMaskingMode(MOHO.MM_NOTMASKED)
			elseif (msg == self.ADD_TO_MASK) then --2
				layerMaskingButton:SetValue(self.layerMaskingMode == RL_LostLayerTool.MASK_LAYER + i - 1)
				moho.layer:SetMaskingMode(MOHO.MM_ADD_MASK)
			--[[elseif (msg == self.SUB_FROM_MASK) then --Hidden?? --3
				layerMaskingButton:SetValue(self.layerMaskingMode == RL_LostLayerTool.MASK_LAYER + i - 1)
				moho.layer:SetMaskingMode(MOHO.MM_SUB_MASK)--]]
			elseif (msg == self.ADD_TO_MASK_INVIS) then --4
				layerMaskingButton:SetValue(self.layerMaskingMode == RL_LostLayerTool.MASK_LAYER + i - 1)
				moho.layer:SetMaskingMode(MOHO.MM_ADD_MASK_INVIS)
			elseif (msg == self.SUB_FROM_MASK) then --5
				layerMaskingButton:SetValue(self.layerMaskingMode == RL_LostLayerTool.MASK_LAYER + i - 1)
				moho.layer:SetMaskingMode(MOHO.MM_SUB_MASK_INVIS)
			elseif (msg == self.CLEAR_ADD_MASK) then --6
				layerMaskingButton:SetValue(self.layerMaskingMode == RL_LostLayerTool.MASK_LAYER + i - 1)
				moho.layer:SetMaskingMode(MOHO.MM_CLEAR_ADD_MASK)
			elseif (msg == self.CLEAR_ADD_MASK_INVIS) then --7
				layerMaskingButton:SetValue(self.layerMaskingMode == RL_LostLayerTool.MASK_LAYER + i - 1)
				moho.layer:SetMaskingMode(MOHO.MM_CLEAR_ADD_MASK_INVIS)
			end
			moho:UpdateUI()
		end
--------------------------------------------------------------
	elseif (msg == self.EXCLUDE_STROKES) then
		--self.excludeStrokesMode = msg
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		local vectorLayer = moho:LayerAsVector(moho.layer)
		if vectorLayer then
			vectorLayer.fExcludeLinesFromMask = not vectorLayer.fExcludeLinesFromMask
		end
--------------------------------------------------------------
	elseif (msg == self.SWITCH_BUTTON) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		if (moho.layer:LayerType() == MOHO.LT_SWITCH) then
			if not moho.layer:SwitchValues():HasKey(moho.layerFrame) then
				for i = 0, selCount - 1 do
					local layer = moho.document:GetSelectedLayer(i)
					if layer:LayerType() == MOHO.LT_SWITCH then
						moho:LayerAsSwitch(layer):SwitchValues():StoreValue()
						MOHO.NewKeyframe(CHANNEL_SWITCH)
					end
				end
			elseif (moho.frame ~= 0) then
				for i = 0, selCount - 1 do
					local layer = moho.document:GetSelectedLayer(i)
					if layer:LayerType() == MOHO.LT_SWITCH then
						moho:LayerAsSwitch(layer):SwitchValues():DeleteKey(moho.layerFrame)
					end
				end
			end

		elseif (moho.layer:Parent() ~= nil) and (moho.layer:Parent():LayerType() == MOHO.LT_SWITCH) then
			if not moho.layer:Parent():SwitchValues():HasKey(moho.frame + moho.layer:Parent():TotalTimingOffset()) then
				moho:LayerAsSwitch(moho.layer:Parent()):SwitchValues():StoreValue()

			elseif (moho.frame ~= 0) then
				moho:LayerAsSwitch(moho.layer:Parent()):SwitchValues():DeleteKey(moho.frame + moho.layer:Parent():TotalTimingOffset())
			end
		end

	elseif (msg >= self.SWITCH_VALUE) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			if (layer:LayerType() == MOHO.LT_SWITCH) then
				for i = 0, layer:CountLayers() - 1 do
					if (tostring(layer:Layer(i):Name()) == tostring(self.switchMenu:FirstCheckedLabel())) then
						moho:LayerAsSwitch(layer):SwitchValues():SetValue(moho.frame + layer:TotalTimingOffset(), self.switchMenu:FirstCheckedLabel())
						moho:NewKeyframe(CHANNEL_SWITCH)
					end
				end

			elseif (moho.layer:Parent() ~= nil) and (moho.layer:Parent():LayerType() == MOHO.LT_SWITCH) then
				local parentLayer = moho.layer:Parent()
				for i = 0, parentLayer:CountLayers() - 1 do
					if (tostring(parentLayer:Layer(i):Name()) == tostring(self.switchMenu:FirstCheckedLabel())) then
						moho:LayerAsSwitch(parentLayer):SwitchValues():SetValue(moho.frame + layer:TotalTimingOffset(), self.switchMenu:FirstCheckedLabel())
						moho:NewKeyframe(CHANNEL_SWITCH)
					end
				end
			end
		end
--------------------------------------------------------------
	elseif (msg == self.PARTICLES_BUTTON) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		--newVal = moho.layer.fLayerShadow.value
		newVal = moho:LayerAsParticle(moho.layer):RunningTrack():GetValue(moho.layerFrame)
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			if  moho:LayerAsParticle(layer) then
				layer:RunningTrack():SetValue(moho.frame + layer:TotalTimingOffset(), not newVal)
				moho:NewKeyframe(CHANNEL_PARTICLE)
			end
		end

	elseif (msg == self.AUDIO_LEVEL_BUTTON) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		if not moho:LayerAsAudio(moho.layer).fAudioLevel:HasKey(moho.layerFrame) then
			for i = 0, selCount - 1 do
				local layer = moho.document:GetSelectedLayer(i)
				if  moho:LayerAsAudio(layer) then
					layer.fAudioLevel:StoreValue()
					MOHO.NewKeyframe(CHANNEL_AUDIO_LEVEL)
				end
			end
		else
			for i = 0, selCount - 1 do
				local layer = moho.document:GetSelectedLayer(i)
				if (moho.frame ~= 0) and  moho:LayerAsAudio(layer) then
					layer.fAudioLevel:DeleteKey(moho.frame + layer:TotalTimingOffset())
				end
			end
		end

	elseif (msg == self.AUDIO_LEVEL) then
		newVal = self.audioLevelText:FloatValue()
		if (newVal < -1000 or newVal > 1000) then
			newVal = LM.Clamp(newVal, -1000, 1000)
			self.audioLevelText:SetValue(newVal)
		end

		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			if moho:LayerAsAudio(layer) then
				layer.fAudioLevel:SetValue(moho.frame + layer:TotalTimingOffset(), self.audioLevelText:FloatValue())
				MOHO.NewKeyframe(CHANNEL_AUDIO_LEVEL)
			end
		end

	elseif (msg == self.AUDIO_JUMP_BUTTON) then
		moho.document:PrepMultiUndo()
		moho.document:SetDirty()
		if not moho:LayerAsAudio(moho.layer).fJumpToFrame:HasKey(moho.layerFrame) then
			for i = 0, selCount - 1 do
				local layer = moho.document:GetSelectedLayer(i)
				if  moho:LayerAsAudio(layer) then
					layer.fJumpToFrame:AddKey(moho.frame + layer:TotalTimingOffset()) 	--layer.fJumpToFrame:StoreValue() ???
					MOHO.NewKeyframe(CHANNEL_AUDIO_JUMP)
				end
			end
		else
			for i = 0, selCount - 1 do
				local layer = moho.document:GetSelectedLayer(i)
				if (moho.frame ~= 0) and  moho:LayerAsAudio(layer) then
					layer.fJumpToFrame:DeleteKey(moho.frame + layer:TotalTimingOffset())
				end
			end
		end

--------------- Layer Effects Dialogue ----------------
	elseif (msg == self.DLOG_BEGIN) then
		self.dlog.document = moho.document
		self.dlog.layer = layer
		--self.dlog.activeLayer = moho.layer
		self.dlog.frame = moho.frame
		self.dlog.layerFrame = moho.layerFrame
		self.dlog.moho = moho
		--self.dlog.DocToPixel = moho:DocToPixel(1) --it doesn't works...
		if (self.dlogState == false) then
			self.dlogState = true
		else
			self.dlogState = false
		end
		--print(tostring(self.dlogState))
		--print("DLOG_BEGIN has been activated!")

	elseif (msg == self.DLOG_CHANGE) then
		-- Nothing really happens here - it is a message that came from the popup dialog.
		-- However, the important thing is that this message then flows back into the Moho app, forcing a redraw.
		moho:UpdateUI()
		--moho:SetCurFrame(moho.frame)
		--moho.layer:UpdateCurFrame(true)
		--print("DLOG has changed!")

---------------- Layer Settings Dialogue ----------------
	elseif (msg == self.DLOG1_BEGIN) then
		self.dlog1.moho = moho
		self.dlog1.document = moho.document
		self.dlog1.layer = layer
		--self.dlog.activeLayer = moho.layer
		self.dlog1.frame = moho.frame
		self.dlog1.layerFrame = moho.layerFrame

		if (moho.layer:LayerType() == MOHO.LT_VECTOR) then
			local mesh = moho:Mesh()
			--self.dlog1.points = mesh:CountPoints()

		elseif (moho.layer:LayerType() == MOHO.LT_3D) then
			local mesh3D = moho:Mesh3D()
			self.dlog1.mesh3D = moho:Mesh3D()
			self.dlog1.defaultColor = mesh3D:DefaultColor()
			self.dlog1.edgeColor = mesh3D:DefaultEdgeColor()
			self.dlog1.dddClockwise = mesh3D:Clockwise()
		end

		if (self.dlog1State == false) then
			self.dlog1State = true
		else
			self.dlog1State = false
		end
		--self.dlog1State = false
		--print(tostring(self.dlog1State))
		--print("DLOG_BEGIN1 has been activated!")

	elseif (msg == self.DLOG1_CHANGE) then
		-- Nothing really happens here...
		-- However...
		--print("DLOG1 has changed!")
		--moho:UpdateUI()

---------------- Particles Settings Dialogue ----------------
	elseif (msg == self.DLOG2_BEGIN) then
		self.dlog2.document = moho.document
		self.dlog2.layer = layer --moho:LayerAsParticle(layer)
		--self.dlog2.frame = moho.frame
		--self.dlog2.layerFrame = moho.layerFrame
		--self.dlog2.moho = moho
		if (self.dlog2State == false) then
			self.dlog2State = true
		else
			self.dlog2State = false
		end
		--self.dlog1State = false
		--print(tostring(self.dlog2State))
		--print("DLOG2_BEGIN has been activated!")

	elseif (msg == self.DLOG2_CHANGE) then
		-- Nothing really happens here...
		-- However...
		--print("DLOG2 has changed!")

---------------- About Window Dialogue ----------------
	elseif (msg == self.DLOG3_BEGIN) then
		self.dlog3.moho = moho
		self.dlog3.app = moho:AppDir()

		if (self.dlog3State == false) then
			self.dlog3State = true
		else
			self.dlog3State = false
		end

		self.dlog3SpecialThanksLabels = {
		{name = "Animator Forums", info = "rl_visitWebpage001.url"},
		{name = "J. Wesley Fowler (synthsin75)", info = "rl_visitWebpage002.url"},
		{name = "Mike Kelley (mkelley)", info = "rl_visitWebpage003.url"},
		{name = "Victor Paredes (selgin)", info = "rl_visitWebpage004.url"},
		{name = "onionskin", info = "rl_visitWebpage005.url"},
		{name = "Ulrik Boden", info = "rl_visitWebpage006.url"}
		}

		self.dlog3RandomThanks = math.random(1, #self.dlog3SpecialThanksLabels)
		--self.dlog3.aboutWindow = true
		--self.windowStatus = msg
		--print(tostring(self.DLOG3_BEGIN))
		--print("DLOG3_BEGIN has been activated!")

	elseif (msg == self.DLOG3_CHANGE) then
		-- Nothing really happens here...
		-- However...
		--print("DLOG3 has changed!")

	end
	--MOHO.Redraw()
	moho:UpdateUI()
	--moho:SetCurFrame(moho.frame)
end
