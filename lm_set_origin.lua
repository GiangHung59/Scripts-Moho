-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "LM_SetOrigin"

-- **************************************************
-- General information about this script
--Giàng Hùng Việt hóa 3/8/2024
-- **************************************************

LM_SetOrigin = {}

LM_SetOrigin.BASE_STR = 2325

function LM_SetOrigin:Name()
	return "Set Origin"
end

function LM_SetOrigin:Version()
	return "6.0"
end

function LM_SetOrigin:Description()
	return MOHO.Localize("/Scripts/Tool/SetOrigin/Description=Bấm để đặt tâm của lớp này (điểm lớp xoay xung quanh)")
end

function LM_SetOrigin:Creator()
	return "Smith Micro Software, Inc."
end

function LM_SetOrigin:UILabel()
	return(MOHO.Localize("/Scripts/Tool/SetOrigin/SetOrigin=Set Origin"))
end

-- **************************************************
-- Recurring values
-- **************************************************

LM_SetOrigin.matrix = LM.Matrix:new_local()
LM_SetOrigin.layerSettingsWnd = nil

-- **************************************************
-- The guts of this script
-- **************************************************

function LM_SetOrigin:OnInputDeviceEvent(moho, deviceEvent)
	return LM_TransformLayer:OnInputDeviceEvent(moho, deviceEvent)
end

function LM_SetOrigin:OnMouseDown(moho, mouseEvent)
	moho.document:PrepUndo(moho.layer, true)
	moho.document:SetDirty()

	self:SetOrigin(moho, mouseEvent)
	mouseEvent.view:DrawMe()
end

function LM_SetOrigin:OnMouseMoved(moho, mouseEvent)
	self:SetOrigin(moho, mouseEvent)
	mouseEvent.view:DrawMe()
end

function LM_SetOrigin:SetOrigin(moho, mouseEvent)
	local matrix = LM.Matrix:new_local()
	local beforeVec = LM.Vector3:new_local()
	local afterVec = LM.Vector3:new_local()

	moho.layer:GetFullTransform(moho.frame, matrix, nil)
	matrix:Transform(beforeVec)

	moho.layer:GetFullTransform(moho.frame, matrix, moho.document)
	moho.layer:SetOrigin(mouseEvent.view:Point2Vec(mouseEvent.pt, matrix))

	moho.layer:GetFullTransform(moho.frame, matrix, nil)
	matrix:Transform(afterVec)

	local newLayerPos = moho.layer.fTranslation.value + beforeVec - afterVec
	local v = newLayerPos - moho.layer.fTranslation.value
	if (v:Mag() > 0.000001) then
		moho.layer.fTranslation:SetValue(moho.layerFrame, newLayerPos)
		moho:NewKeyframe(CHANNEL_LAYER_T)
	end

	moho.document:DepthSort()
end

-- **************************************************
-- Layer Settings dialog
-- **************************************************

local LM_LayerSettingsDialog = {}

LM_LayerSettingsDialog.CHANGE = MOHO.MSG_BASE
LM_LayerSettingsDialog.RESET = MOHO.MSG_BASE + 1

function LM_LayerSettingsDialog:new()
	local d = LM.GUI.SimpleDialog("Layer Settings", LM_LayerSettingsDialog)
	local l = d:GetLayout()

	l:PushH()
		l:PushV()
			l:AddChild(LM.GUI.StaticText("Position (X, Y, Z)"), LM.GUI.ALIGN_LEFT)
			l:AddChild(LM.GUI.StaticText("Scale (X, Y, Z)"), LM.GUI.ALIGN_LEFT)
			l:AddChild(LM.GUI.StaticText("Rotation (X, Y, Z)"), LM.GUI.ALIGN_LEFT)
			l:AddChild(LM.GUI.StaticText("Shear (X, Y, Z)"), LM.GUI.ALIGN_LEFT)
			l:AddChild(LM.GUI.StaticText("Origin (X, Y)"), LM.GUI.ALIGN_LEFT)
		l:Pop()
		l:PushV()
			l:PushH()
				d.pX = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.pX, LM.GUI.ALIGN_LEFT)
				d.pY = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.pY, LM.GUI.ALIGN_LEFT)
				d.pZ = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.pZ, LM.GUI.ALIGN_LEFT)
			l:Pop()
			l:PushH()
				d.sX = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.sX, LM.GUI.ALIGN_LEFT)
				d.sY = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.sY, LM.GUI.ALIGN_LEFT)
				d.sZ = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.sZ, LM.GUI.ALIGN_LEFT)
			l:Pop()
			l:PushH()
				d.rX = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.rX, LM.GUI.ALIGN_LEFT)
				d.rY = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.rY, LM.GUI.ALIGN_LEFT)
				d.rZ = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.rZ, LM.GUI.ALIGN_LEFT)
			l:Pop()
			l:PushH()
				d.shX = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.shX, LM.GUI.ALIGN_LEFT)
				d.shY = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.shY, LM.GUI.ALIGN_LEFT)
				d.shZ = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.shZ, LM.GUI.ALIGN_LEFT)
			l:Pop()
			l:PushH()
				d.oX = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.oX, LM.GUI.ALIGN_LEFT)
				d.oY = LM.GUI.TextControl(0, "00.0000", 0, LM.GUI.FIELD_FLOAT)
				l:AddChild(d.oY, LM.GUI.ALIGN_LEFT)
			l:Pop()
		l:Pop()
	l:Pop()

	l:AddChild(LM.GUI.Button("Reset", LM_LayerSettingsDialog.RESET))

	return d
end

function LM_LayerSettingsDialog:Update(moho)
	if (moho.layer == nil) then
		return
	end

	local layer = moho.layer

	self.pX:SetValue(layer.fTranslation.value.x)
	self.pY:SetValue(layer.fTranslation.value.y)
	self.pZ:SetValue(layer.fTranslation.value.z)

	self.sX:SetValue(layer.fScale.value.x)
	self.sY:SetValue(layer.fScale.value.y)
	self.sZ:SetValue(layer.fScale.value.z)

	self.rX:SetValue(layer.fRotationX.value)
	self.rY:SetValue(layer.fRotationY.value)
	self.rZ:SetValue(layer.fRotationZ.value)

	self.shX:SetValue(layer.fShear.value.x)
	self.shY:SetValue(layer.fShear.value.y)
	self.shZ:SetValue(layer.fShear.value.z)

	local origin = layer:Origin()
	self.oX:SetValue(origin.x)
	self.oY:SetValue(origin.y)
end

function LM_LayerSettingsDialog:OnOK()
	LM_SetOrigin.layerSettingsWnd = nil -- mark the window closed
end

function LM_LayerSettingsDialog_Update(moho)
	if (LM_SetOrigin.layerSettingsWnd) then
		LM_SetOrigin.layerSettingsWnd:Update(moho)
	end
end

-- register the layer window to be updated when changes are made
table.insert(MOHO.UpdateTable, LM_LayerSettingsDialog_Update)

-- **************************************************
-- Tool options - create and respond to tool's UI
-- **************************************************

LM_SetOrigin.CHANGE = MOHO.MSG_BASE
LM_SetOrigin.RESET = MOHO.MSG_BASE + 1
LM_SetOrigin.FLIP_H = MOHO.MSG_BASE + 2
LM_SetOrigin.FLIP_V = MOHO.MSG_BASE + 3
LM_SetOrigin.ALIGNORIGIN = MOHO.MSG_BASE + 4 -- goes to 12
LM_SetOrigin.DUMMY = MOHO.MSG_BASE + 13

function LM_SetOrigin:DoLayout(moho, layout)
	layout:AddChild(LM.GUI.StaticText(MOHO.Localize("/Scripts/Tool/SetOrigin/Origin=Origin")))

	layout:AddChild(LM.GUI.StaticText(MOHO.Localize("/Scripts/Tool/SetOrigin/X=X:")))
	self.textX = LM.GUI.TextControl(0, "00.0000", self.CHANGE, LM.GUI.FIELD_FLOAT)
	layout:AddChild(self.textX)

	layout:AddChild(LM.GUI.StaticText(MOHO.Localize("/Scripts/Tool/SetOrigin/Y=Y:")))
	self.textY = LM.GUI.TextControl(0, "00.0000", self.CHANGE, LM.GUI.FIELD_FLOAT)
	layout:AddChild(self.textY)

	layout:AddChild(LM.GUI.Button(MOHO.Localize("/Scripts/Tool/SetOrigin/Reset=Reset"), self.RESET))

	layout:AddChild(LM.GUI.ImageButton("ScriptResources/flip_layer_h", MOHO.Localize("/Scripts/Tool/SetOrigin/FlipH=Lật Ngang"), false, self.FLIP_H))
	layout:AddChild(LM.GUI.ImageButton("ScriptResources/flip_layer_v", MOHO.Localize("/Scripts/Tool/SetOrigin/FlipV=Lật Dọc"), false, self.FLIP_V))
	
	self.menu = LM.GUI.Menu(MOHO.Localize("/Scripts/Tool/SetOrigin/AlignOrigin=Align Origin"))
	self.menu:AddItem(MOHO.Localize("/Scripts/Tool/TLeft=Trên Trái"), 0, self.ALIGNORIGIN + 2)
	self.menu:AddItem(MOHO.Localize("/Scripts/Tool/TCenter=Trên Giữa"), 0 , self.ALIGNORIGIN + 5)
	self.menu:AddItem(MOHO.Localize("/Scripts/Tool/TRight=Trên Phải"), 0 , self.ALIGNORIGIN + 8)
	self.menu:AddItem(MOHO.Localize("/Scripts/Tool/CLeft=Giữa Trái"), 0, self.ALIGNORIGIN + 1)
	self.menu:AddItem(MOHO.Localize("/Scripts/Tool/CCenter=Giữa Giữa"), 0, self.ALIGNORIGIN + 4)
	self.menu:AddItem(MOHO.Localize("/Scripts/Tool/CRight=Giữa Phải"), 0 , self.ALIGNORIGIN + 7)
	self.menu:AddItem(MOHO.Localize("/Scripts/Tool/BLeft=Dưới Trái"), 0,  self.ALIGNORIGIN)
	self.menu:AddItem(MOHO.Localize("/Scripts/Tool/BCenter=Dưới Giữa"), 0, self.ALIGNORIGIN + 3)
	self.menu:AddItem(MOHO.Localize("/Scripts/Tool/BRight=Dưới Phải"), 0 , self.ALIGNORIGIN + 6)
	self.popup = LM.GUI.ImagePopupMenu("ScriptResources/align_origin", false)
	self.popup:SetMenu(self.menu)
	layout:AddChild(self.popup)

	--if (self.layerSettingsWnd == nil) then
	--	self.layerSettingsWnd = LM_LayerSettingsDialog:new()
	--	self.layerSettingsWnd:DoModeless()
	--end
end

function LM_SetOrigin:UpdateWidgets(moho)
	local origin = moho.layer:Origin()
	self.textX:SetValue(origin.x)
	self.textY:SetValue(origin.y)
	if (self.layerSettingsWnd) then
		self.layerSettingsWnd:Update(moho)
	end
end

function LM_SetOrigin:HandleMessage(moho, view, msg)
	local newVal = LM.Vector2:new_local()
	local selCount = moho.document:CountSelectedLayers()

	if (msg == self.RESET) then
		moho.document:PrepMultiUndo(true)
		moho.document:SetDirty()

		newVal:Set(0, 0)
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer:SetOrigin(newVal)
		end
		self:UpdateWidgets(moho)
	elseif (msg == self.CHANGE) then
		moho.document:PrepUndo(moho.layer, true)
		moho.document:SetDirty()

		newVal.x = self.textX:FloatValue()
		newVal.y = self.textY:FloatValue()
		moho.layer:SetOrigin(newVal)
	elseif (msg == self.FLIP_H) then
		moho.document:PrepMultiUndo(true)
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer.fFlipH:SetValue(moho.frame + layer:TotalTimingOffset(), not layer.fFlipH.value)
			moho:NewKeyframe(CHANNEL_LAYER_FLIP_H)
		end
	elseif (msg == self.FLIP_V) then
		moho.document:PrepMultiUndo(true)
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			layer.fFlipV:SetValue(moho.frame + layer:TotalTimingOffset(), not layer.fFlipV.value)
			moho:NewKeyframe(CHANNEL_LAYER_FLIP_V)
		end
	--DKWROOT ADDITION
	elseif (msg == self.ALIGNORIGIN) then -- Lower Left
		moho.document:PrepMultiUndo(true)
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			local bbox = layer:Bounds(moho.frame)
			newVal:Set(bbox.fMin.x,bbox.fMin.y)
			layer:SetOrigin(newVal)
		end
	elseif (msg == self.ALIGNORIGIN+1) then -- Center Left
		moho.document:PrepMultiUndo(true)
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			local bbox = layer:Bounds(moho.frame)
			newVal:Set(bbox.fMin.x,bbox.fMin.y+((bbox.fMax.y-bbox.fMin.y)/2))
			layer:SetOrigin(newVal)
		end
	elseif (msg == self.ALIGNORIGIN+2) then -- Top Left
		moho.document:PrepMultiUndo(true)
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			local bbox = layer:Bounds(moho.frame)
			newVal:Set(bbox.fMin.x,bbox.fMax.y)
			layer:SetOrigin(newVal)
		end
	elseif (msg == self.ALIGNORIGIN+3) then -- Lower Center
		moho.document:PrepMultiUndo(true)
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			local bbox = layer:Bounds(moho.frame)
			newVal:Set(bbox.fMin.x+((bbox.fMax.x-bbox.fMin.x)/2),bbox.fMin.y)
			layer:SetOrigin(newVal)
		end
	elseif (msg == self.ALIGNORIGIN+4) then -- Center
		moho.document:PrepMultiUndo(true)
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			local bbox = layer:Bounds(moho.frame)
			newVal:Set(bbox.fMin.x+((bbox.fMax.x-bbox.fMin.x)/2),bbox.fMin.y+((bbox.fMax.y-bbox.fMin.y)/2))
			layer:SetOrigin(newVal)
		end
	elseif (msg == self.ALIGNORIGIN+5) then -- Top Center
		moho.document:PrepMultiUndo(true)
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			local bbox = layer:Bounds(moho.frame)
			newVal:Set(bbox.fMin.x+((bbox.fMax.x-bbox.fMin.x)/2),bbox.fMax.y)
			layer:SetOrigin(newVal)
		end
	elseif (msg == self.ALIGNORIGIN+6) then -- Lower Right
		moho.document:PrepMultiUndo(true)
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			local bbox = layer:Bounds(moho.frame)
			newVal:Set(bbox.fMax.x,bbox.fMin.y)
			layer:SetOrigin(newVal)
		end
	elseif (msg == self.ALIGNORIGIN+7) then -- Center Right
		moho.document:PrepMultiUndo(true)
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			local bbox = layer:Bounds(moho.frame)
			newVal:Set(bbox.fMax.x,bbox.fMin.y+((bbox.fMax.y-bbox.fMin.y)/2))
			layer:SetOrigin(newVal)
		end
	elseif (msg == self.ALIGNORIGIN+8) then -- Top Right
		moho.document:PrepMultiUndo(true)
		moho.document:SetDirty()
		for i = 0, selCount - 1 do
			local layer = moho.document:GetSelectedLayer(i)
			local bbox = layer:Bounds(moho.frame)
			newVal:Set(bbox.fMax.x,bbox.fMax.y)
			layer:SetOrigin(newVal)
		end
		
	end
end
