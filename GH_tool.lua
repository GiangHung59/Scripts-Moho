-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "GH_tool"

-- **************************************************
-- General information about this script 
--05/04/2025
-- **************************************************

GH_tool = {}

function GH_tool:Name()
    return self:Localize('UILabel')
end

function GH_tool:Version()
    return '1.5'
end

function GH_tool:UILabel()
    return 'Hungs59_Tool'
end

function GH_tool:Creator()
    return 'Hungs59, Lukas Krepel (Xóa Layers Tắt), davoodice (Màu Nhãn Nhóm)'
end

function GH_tool:Description()
    return self:Localize('Đây là mô tả')
end

function GH_tool:ColorizeIcon()
    return true
end

-- **************************************************
-- Is Relevant / Is Enabled
-- **************************************************

function GH_tool:IsRelevant(moho)
    return true
end

function GH_tool:IsEnabled(moho)
    return true
end

-- **************************************************
-- Recurring Values
-- **************************************************

GH_tool.tickChoVui = false
GH_tool.newName = ""
GH_tool.isExpanded = false
GH_tool.deleteRefLayers = false
GH_tool.deleteStoryboardLayers = false
GH_tool.deleteAudioLayers = false
GH_tool.deleteEmptyGroups = true

-- **************************************************
-- Prefs
-- **************************************************

function GH_tool:LoadPrefs(prefs)
    self.tickChoVui = prefs:GetBool("GH_tool.tickChoVui", false)
    self.isExpanded = prefs:GetBool("GH_tool.isExpanded", false)
end

function GH_tool:SavePrefs(prefs)
    prefs:SetBool("GH_tool.tickChoVui", self.tickChoVui)
    prefs:SetBool("GH_tool.isExpanded", self.isExpanded)
end

function GH_tool:ResetPrefs()
    self.tickChoVui = false
    self.isExpanded = false
end

-- **************************************************
-- Keyboard/Mouse Control
-- **************************************************

function GH_tool:OnMouseDown(moho, mouseEvent)
    LM_SelectPoints.allowShapePicking = false
    LM_SelectPoints:OnMouseDown(moho, mouseEvent)
    LM_SelectBone:OnMouseDown(moho, mouseEvent)
end

function GH_tool:OnMouseMoved(moho, mouseEvent)
    LM_SelectPoints:OnMouseMoved(moho, mouseEvent)
end

function GH_tool:OnMouseUp(moho, mouseEvent)
    LM_SelectPoints:OnMouseUp(moho, mouseEvent)
end

function GH_tool:OnKeyDown(moho, keyEvent)
    LM_SelectPoints:OnKeyDown(moho, keyEvent)
end

function GH_tool:DrawMe(moho, view)
    LM_SelectPoints:DrawMe(moho, view)
end

-- Dialog for renaming
local GH_toolDialog = {}

function GH_toolDialog:new(moho, name)
    local d = LM.GUI.SimpleDialog(GH_tool:Localize('UILabel') .. ' v' .. GH_tool:Version(), GH_toolDialog)
    local l = d:GetLayout()
    l:AddChild(LM.GUI.StaticText(GH_tool:Localize('enterNewName') .. name .."':"), LM.GUI.ALIGN_LEFT)
    d.textInput = LM.GUI.TextControl(400, name)
    l:AddChild(d.textInput, LM.GUI.ALIGN_LEFT)    
    return d
end

function GH_toolDialog:OnValidate()
    local b = true
    if self.textInput:Value() == "" then
        b = false
    end
    return b
end

function GH_toolDialog:OnOK()
    GH_tool.newName = self.textInput:Value()
end

-- Utility function for bone renaming
function GH_tool:GetAllWhatNeeded(moho, layer)
    local boneLayer, skeleton, id, bone, name, parent
    
    boneLayer = moho:LayerAsBone(layer)
    if boneLayer then
        skeleton = layer:Skeleton()
        if skeleton then
            id = skeleton:SelectedBoneID()
        end
    end
    
    if layer and skeleton and id > -1 then
        bone = skeleton:Bone(id)
        name = bone:Name()
        return boneLayer, bone, name
    else
        parent = layer:Parent()
        if parent then
            return self:GetAllWhatNeeded(moho, parent)
        end
    end
    
    return nil
end

-- Function to determine if a layer should be deleted
function GH_tool:ShouldDelete(layer)
    local deleteLayer = true
    if layer:IsVisible() then
        deleteLayer = false
    end
    if deleteLayer then
        if layer:IsAudioType() then
            if not self.deleteAudioLayers then
                deleteLayer = true -- Loại trừ layer âm thanh
            end
        end
    end
    if deleteLayer then
        local lowercase = string.lower(layer:Name())
        if string.match(lowercase, "ref") then
            if not self.deleteRefLayers then
                deleteLayer = false -- Loại trừ layer REF
            end
        elseif string.match(lowercase, "stb") then
            if not self.deleteStoryboardLayers then
                deleteLayer = false -- Loại trừ layer STB
            end
        end
    end
    return deleteLayer
end

-- Function to add empty groups to delete list
function GH_tool:AddEmptyGroupsToTable(moho, deleteLayers)
    local layers = FO_Utilities:AllLayers(moho)
    for i = 1, #layers do
        local layer = layers[i]
        if layer:IsGroupType() then
            if layer:CountLayers() < 1 then
                if not (self:tableContains(deleteLayers, layer)) then
                    table.insert(deleteLayers, layer)
                end
            end
        end
    end
end

-- Utility function to check if an element is in a table
function GH_tool:tableContains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- **************************************************
-- Tool Panel Layout
-- **************************************************

GH_tool.BUTTON_1 = MOHO.MSG_BASE
GH_tool.BUTTON_2 = MOHO.MSG_BASE + 1
GH_tool.BUTTON_3 = MOHO.MSG_BASE + 2
GH_tool.BUTTON_4 = MOHO.MSG_BASE + 3
GH_tool.BUTTON_5 = MOHO.MSG_BASE + 4
GH_tool.BUTTON_6 = MOHO.MSG_BASE + 5
GH_tool.BUTTON_7 = MOHO.MSG_BASE + 6
GH_tool.BUTTON_8 = MOHO.MSG_BASE + 7
GH_tool.TICK_CHO_VUI = MOHO.MSG_BASE + 8
GH_tool.COL_PLAIN = MOHO.MSG_BASE + 9
GH_tool.COL_RED = MOHO.MSG_BASE + 10
GH_tool.COL_ORANGE = MOHO.MSG_BASE + 11
GH_tool.COL_YELLOW = MOHO.MSG_BASE + 12
GH_tool.COL_GREEN = MOHO.MSG_BASE + 13
GH_tool.COL_BLUE = MOHO.MSG_BASE + 14
GH_tool.COL_PURPLE = MOHO.MSG_BASE + 15
GH_tool.COL_TAN = MOHO.MSG_BASE + 16
GH_tool.COL_PINK = MOHO.MSG_BASE + 17
GH_tool.COL_TURQUOISE = MOHO.MSG_BASE + 18
GH_tool.COL_CADETBLUE = MOHO.MSG_BASE + 19
GH_tool.COL_CORAL = MOHO.MSG_BASE + 20
GH_tool.ONLY_PLAIN = MOHO.MSG_BASE + 21

function GH_tool:DoLayout(moho, layout)
    self.button1Button = LM.GUI.Button(self:Localize('Del Action Empty'), self.BUTTON_1)
    layout:AddChild(self.button1Button, LM.GUI.ALIGN_CENTER, 0)

    self.button2Button = LM.GUI.Button(self:Localize('Del All Action'), self.BUTTON_2)
    layout:AddChild(self.button2Button, LM.GUI.ALIGN_CENTER, 0)

    self.button3Button = LM.GUI.Button(self:Localize('Rename Bone'), self.BUTTON_3)
    layout:AddChild(self.button3Button, LM.GUI.ALIGN_CENTER, 0)

    self.button4Button = LM.GUI.Button(self:Localize('Gộp Layer'), self.BUTTON_4)
    layout:AddChild(self.button4Button, LM.GUI.ALIGN_CENTER, 0)
    
    self.button5Button = LM.GUI.Button(self:Localize('Đổi Màu Xương'), self.BUTTON_5)
    layout:AddChild(self.button5Button, LM.GUI.ALIGN_CENTER, 0)
    
    self.button6Button = LM.GUI.Button(self:Localize('Đổi Màu Xương Chọn'), self.BUTTON_6)
    layout:AddChild(self.button6Button, LM.GUI.ALIGN_CENTER, 0)
    
    self.button7Button = LM.GUI.Button(self:Localize('Xóa Layers TẮT'), self.BUTTON_7)
    layout:AddChild(self.button7Button, LM.GUI.ALIGN_CENTER, 0)
    
    self.button8Button = LM.GUI.Button(self:Localize('Expand Collapse'), self.BUTTON_8)
    layout:AddChild(self.button8Button, LM.GUI.ALIGN_CENTER, 0)
    
    self.tickChoVuiCheckbox = LM.GUI.CheckBox(self:Localize('Tick cho vui'), self.TICK_CHO_VUI)
    layout:AddChild(self.tickChoVuiCheckbox, LM.GUI.ALIGN_CENTER, 0)
    
    self.onlyPlainColor = LM.GUI.CheckBox(self:Localize('Giữ nguyên màu hiện tại'), self.ONLY_PLAIN)
    layout:AddChild(self.onlyPlainColor)
    
    self.colorMenu = LM.GUI.Menu(self:Localize('Màu Nhãn Lớp'))
    self.colorMenu:AddItem(self:Localize('=Tím'), 0, self.COL_PURPLE)
    self.colorMenu:AddItemAlphabetically(self:Localize('=Xanh dương'), 0, self.COL_BLUE)
    self.colorMenu:AddItemAlphabetically(self:Localize('=Xanh lá'), 0, self.COL_GREEN)
    self.colorMenu:AddItemAlphabetically(self:Localize('=Vàng'), 0, self.COL_YELLOW)
    self.colorMenu:AddItemAlphabetically(self:Localize('=Cam'), 0, self.COL_ORANGE)
    self.colorMenu:AddItemAlphabetically(self:Localize('=Đỏ'), 0, self.COL_RED)
    self.colorMenu:AddItemAlphabetically(self:Localize('=Nâu nhạt'), 0, self.COL_TAN)
    self.colorMenu:AddItemAlphabetically(self:Localize('=Hồng'), 0, self.COL_PINK)
    self.colorMenu:AddItemAlphabetically(self:Localize('=Ngọc lam'), 0, self.COL_TURQUOISE)
    self.colorMenu:AddItemAlphabetically(self:Localize('=Xanh cadet'), 0, self.COL_CADETBLUE)
    self.colorMenu:AddItemAlphabetically(self:Localize('=San hô'), 0, self.COL_CORAL)
    self.colorMenu:InsertItem(0, "", 0, 0)
    self.colorMenu:InsertItem(0, self:Localize('=Không màu'), 0, self.COL_PLAIN)
    
    self.colorPopup = LM.GUI.PopupMenu(120, true)
    self.colorPopup:SetMenu(self.colorMenu)
    layout:AddChild(self.colorPopup)
end

function GH_tool:UpdateWidgets(moho)
    self.tickChoVuiCheckbox:SetValue(self.tickChoVui)
end

GH_tool.destructive = true
GH_tool.elemColID = 1

-- Function to change bone color
function GH_tool:ChangeBoneColor(moho)
    local colors = {
        LM.ColorOps.Black, LM.ColorOps.Blue, LM.ColorOps.Cyan, LM.ColorOps.Green,
        LM.ColorOps.Magenta, LM.ColorOps.Red, LM.ColorOps.White, LM.ColorOps.Yellow
    }
    local skel = moho:Skeleton()
    if skel == nil then return end

    if moho:CountSelectedBones(true) > 0 then
        if GH_tool.elemColID < 9 then
            local rgbCol = colors[GH_tool.elemColID]
            MOHO.MohoGlobals.ElemCol = rgbCol
            GH_tool.elemColID = GH_tool.elemColID + 1
        else
            GH_tool.elemColID = 1
            local rgbCol = colors[GH_tool.elemColID]
            MOHO.MohoGlobals.ElemCol = rgbCol
            GH_tool.elemColID = GH_tool.elemColID + 1
        end
        moho:UpdateUI()
    end
end

-- Handle messages (button clicks)
function GH_tool:HandleMessage(moho, view, msg)
    if msg == self.BUTTON_1 then
        -- Delete Empty Actions
        local ScanDoc, ScanGroup, Clear
        local count = 0
        local showProgress = true
        
        Clear = function(layer)
            local actionsToRemove = {}
            local actionName
            for a=0, layer:CountActions()-1 do
                actionName = layer:ActionName(a)
                if layer:ActionDuration(actionName) < 1 then
                    table.insert(actionsToRemove, actionName)
                end
            end
            if #actionsToRemove > 0 then 
                for _,name in ipairs(actionsToRemove) do
                    count = count + 1
                    layer:DeleteAction(name)
                end
                if showProgress then print (#actionsToRemove.." hành động đã xóa '"..layer:Name().."'") end
            end
        end
        
        ScanGroup = function(group)
            local groupLayer = moho:LayerAsGroup(group)
            local layer
            for i=0, groupLayer:CountLayers()-1 do
                layer = group:Layer(i)
                if layer:CountActions()>0 then
                    Clear(layer)
                end
                if layer:IsGroupType() then
                    ScanGroup(layer)
                end
            end
        end 

        ScanDoc = function()
            for l = 0, moho.document:CountLayers()-1 do
                local layer = moho.document:Layer(l)
                if layer:CountActions()>0 then
                    Clear(layer)
                end
                if layer:IsGroupType() then
                    ScanGroup(layer)
                end
            end
        end
        
        moho.document:PrepMultiUndo()
        moho.document:SetDirty()
        ScanDoc()
        
        if showProgress then
            print("    Tổng: "..count)
            print("___________________")
        end
        
    elseif msg == self.BUTTON_2 then
        -- Delete All Actions
        local ScanDoc, ScanGroup, Clear
        local count = 0
        local showProgress = true
        
        Clear = function(layer)
            local actionsToRemove = {}
            local actions = layer:CountActions()
            local actionName
            if actions == 0 then return end
            for a=0, actions-1 do
                actionName = layer:ActionName(a)
                table.insert(actionsToRemove, actionName)
            end
            for _,name in ipairs(actionsToRemove) do
                layer:DeleteAction(name)
            end
            count = count + actions
            if showProgress then print(actions.." hành động đã xóa từ '"..layer:Name().."'") end
        end
        
        ScanGroup = function(group)
            local groupLayer = moho:LayerAsGroup(group)
            local layer
            for i=0, groupLayer:CountLayers()-1 do
                layer = group:Layer(i)
                if layer:CountActions()>0 then
                    Clear(layer)
                end
                if layer:IsGroupType() then
                    ScanGroup(layer)
                end
            end
        end 

        ScanDoc = function()
            for i = 0, moho.document:CountSelectedLayers()-1 do
                local layer = moho.document:GetSelectedLayer(i)
                if layer:CountActions()>0 then
                    Clear(layer)
                end
                if layer:IsGroupType() then
                    ScanGroup(layer)
                end
            end
        end
        
        moho.document:PrepMultiUndo()
        moho.document:SetDirty()
        ScanDoc()
        
        if showProgress then
            print("    Tổng: "..count)
            print("___________________")
        end
        
    elseif msg == self.BUTTON_3 then
        -- Rename Bone
        local layer, bone, name = self:GetAllWhatNeeded(moho, moho.layer)
        if not layer or not bone then
            print("No bone selected or found!")
            return
        end
        
        local dlog = GH_toolDialog:new(moho, name)
        if (dlog:DoModal() == LM.GUI.MSG_CANCEL) then
            return
        end
        
        moho.document:PrepMultiUndo()
        moho.document:SetDirty()
        
        bone:SetName(GH_tool.newName)
        layer:RenameAction(name, GH_tool.newName)
        layer:RenameAction(name .. ' 2', GH_tool.newName .. ' 2')
        moho:UpdateUI()

    elseif msg == self.BUTTON_4 then
        -- Merge Layers
        moho.document:PrepUndo()
        moho.document:SetDirty()
        
        local layers = {}
        local count = 0
        repeat
            local layer = moho.document:LayerByAbsoluteID(count)
            if layer then
                count = count + 1
                if (layer:SecondarySelection() and layer:LayerType() == MOHO.LT_VECTOR) then
                    table.insert(layers, moho:LayerAsVector(layer))
                end
            end
        until not layer
        local merge
        if (not self.destructive) then
            merge = moho:CreateNewLayer(MOHO.LT_VECTOR, false)
            merge:SetName("Merged "..count.." vector layers")
        else
            merge = moho.layer
        end
        moho:SetSelLayer(merge)
        for i,v in ipairs(layers) do
            if (v ~= merge) then
                v:Mesh():SelectAll()
                moho:Copy(v:Mesh())
                moho:Paste()
            end
        end
        if (not self.destructive) then
            moho:SetSelLayer(layers[1])
        end
        for i=#layers, 1, -1 do
            if (self.destructive and layers[i] ~= merge) then
                moho:DeleteLayer(layers[i])
            elseif (not self.destructive) then
                layers[i]:SetSecondarySelection(true)
            end
        end
        
    elseif msg == self.BUTTON_5 then
        -- Change Bone Color
        self:ChangeBoneColor(moho)
        
    elseif msg == self.BUTTON_6 then
        -- Change Selected Bone Color
        GH_tool.selColID = GH_tool.selColID or 1
        local colors = {LM.ColorOps.Black, LM.ColorOps.Blue, LM.ColorOps.Cyan, LM.ColorOps.Green, 
                       LM.ColorOps.Magenta, LM.ColorOps.Red, LM.ColorOps.White, LM.ColorOps.Yellow}
        if GH_tool.selColID < 9 then
            local rgbCol = colors[GH_tool.selColID]
            MOHO.MohoGlobals.SelCol = rgbCol
            GH_tool.selColID = GH_tool.selColID + 1
        else
            GH_tool.selColID = 1
            local rgbCol = colors[GH_tool.selColID]
            MOHO.MohoGlobals.SelCol = rgbCol
            GH_tool.selColID = GH_tool.selColID + 1
        end
        
    elseif msg == self.BUTTON_7 then
        -- Delete Invisible Layers (Updated from GH_XoaLayersTat)
        moho.document:PrepUndo("", moho.layer, false)
        moho.document:SetDirty()
        local deleteLayers = {}

        local function collectLayers(layer, depth)
            if self:ShouldDelete(layer) then
                table.insert(deleteLayers, layer)
            end
            if layer:IsGroupType() then
                local group = moho:LayerAsGroup(layer)
                for i = 0, group:CountLayers() - 1 do
                    local subLayer = group:Layer(i)
                    collectLayers(subLayer, depth + 1)
                end
            end
        end

        for i = 0, moho.document:CountLayers() - 1 do
            local layer = moho.document:Layer(i)
            collectLayers(layer, 0)
        end

        if self.deleteEmptyGroups then
            self:AddEmptyGroupsToTable(moho, deleteLayers)
        end

        local totalLayers = #deleteLayers
        if totalLayers == 0 then
            FO_Utilities:Alert("Không có layer nào TẮT.")
            return
        end

        local msg1 = totalLayers == 1 and totalLayers .. " layer đang" or totalLayers .. " layer đang"
        local msg2 = ""
        local maxPerColumn = 15
        local numColumns = math.ceil(totalLayers / maxPerColumn)
        if numColumns > 10 then numColumns = 10 end
        local columnWidth = 15
        local columnSpacing = string.rep(" ", 5)

        if numColumns > 1 then
            local layersPerColumn = math.ceil(totalLayers / numColumns)
            for row = 1, layersPerColumn do
                local line = ""
                for col = 1, numColumns do
                    local idx = (col - 1) * layersPerColumn + row
                    if idx <= totalLayers then
                        local layerName = deleteLayers[idx]:Name()
                        if #layerName > columnWidth - 3 then
                            layerName = string.sub(layerName, 1, columnWidth - 6) .. "..."
                        end
                        local paddedName = layerName .. string.rep(" ", columnWidth - #layerName)
                        line = line .. paddedName
                        if col < numColumns then
                            line = line .. columnSpacing
                        end
                    end
                end
                if line ~= "" then
                    msg2 = msg2 .. line .. "\n"
                end
            end
        else
            for i = 1, totalLayers do
                local layerName = deleteLayers[i]:Name()
                if #layerName > columnWidth - 3 then
                    layerName = string.sub(layerName, 1, columnWidth - 6) .. "..."
                end
                msg2 = msg2 .. "- " .. layerName .. "\n"
            end
        end

        -- Sử dụng FO_Utilities:YesNoQuestion như trong script gốc
        if not FO_Utilities:YesNoQuestion("?", msg1 .. " tắt. Bạn muốn xóa?", msg2) then
            return
        end

        local batchSize = 5
        for i = totalLayers, 1, -1 do
            local layer = deleteLayers[i]
            if layer ~= nil then
                if i == 1 and moho.document:CountLayers() == 1 then
                    moho:CreateNewLayer(MOHO.LT_VECTOR):SetName("New Layer")
                end
                moho:DeleteLayer(layer)
                table.remove(deleteLayers, i)
            end
            if (totalLayers - i + 1) % batchSize == 0 then
                -- os.execute("sleep 0.1")
            end
        end
        
    elseif msg == self.BUTTON_8 then
        -- Expand/Collapse All Layers
        local function ToggleLayers(layer, expand)
            local groupLayer = moho:LayerAsGroup(layer)
            if groupLayer then
                groupLayer:Expand(expand)
                for i = 0, groupLayer:CountLayers() - 1 do
                    ToggleLayers(groupLayer:Layer(i), expand)
                end
            end
        end

        self.isExpanded = not self.isExpanded
        for i = 0, moho.document:CountLayers() - 1 do
            ToggleLayers(moho.document:Layer(i), self.isExpanded)
        end
        moho:UpdateUI()
        --print("All layers are now " .. (self.isExpanded and "EXPANDED" or "COLLAPSED"))
        
    elseif msg == self.TICK_CHO_VUI then
        -- Render High Quality (Toggle)
        self.tickChoVui = not self.tickChoVui
        local RenderHigh = {}
        
        function RenderHigh:ToggleQuality(layer, enableHigh)
            if layer:IsGroupType() then
                local group = moho:LayerAsGroup(layer)
                for i = 0, group:CountLayers()-1 do
                    local sublayer = group:Layer(i)
                    self:ToggleQuality(sublayer, enableHigh)
                end
            else
                if layer:LayerType() == MOHO.LT_IMAGE then 
                    moho:LayerAsImage(layer):SetQualityLevel(enableHigh and 2 or 0)
                end
            end
        end

        function RenderHigh:Run(moho, enableHigh)
            moho.document:SetDirty()
            for i = 0, moho.document:CountSelectedLayers()-1 do
                local layer = moho.document:GetSelectedLayer(i)
                self:ToggleQuality(layer, enableHigh)
            end
        end

        RenderHigh:Run(moho, self.tickChoVui)
        moho:UpdateUI()
        
    elseif (msg >= self.COL_PLAIN and msg <= self.COL_CORAL) then
        -- Handle Set Layer Color
        moho.document:PrepUndo(true)
        local tag = 0
        if (msg == self.COL_RED) then tag = 1
        elseif (msg == self.COL_ORANGE) then tag = 2
        elseif (msg == self.COL_YELLOW) then tag = 3
        elseif (msg == self.COL_GREEN) then tag = 4
        elseif (msg == self.COL_BLUE) then tag = 5
        elseif (msg == self.COL_PURPLE) then tag = 6
        elseif (msg == self.COL_TAN) then tag = 7
        elseif (msg == self.COL_PINK) then tag = 8
        elseif (msg == self.COL_TURQUOISE) then tag = 9
        elseif (msg == self.COL_CADETBLUE) then tag = 10
        elseif (msg == self.COL_CORAL) then tag = 11
        end
        
        local colorIndex = tag
        local onlyPlain = self.onlyPlainColor:Value()
        for i = 0, moho.document:CountSelectedLayers()-1 do
            local group = moho.document:GetSelectedLayer(i)
            if (group:IsGroupType()) then
                moho:LayerAsGroup(group)
                if (onlyPlain) then 
                    if (group:LabelColor() ~= 0) then goto continue2 end
                end                
                group:SetLabelColor(colorIndex)
                ::continue2::
                local count = 0
                repeat
                    local layer = moho.document:LayerByAbsoluteID(count)
                    if layer then
                        count = count + 1
                        local isMyChild = group:IsMyChild(layer)
                        if (isMyChild) then
                            if (onlyPlain) then 
                                if (layer:LabelColor() ~= 0) then goto continue end
                            end
                            layer:SetLabelColor(colorIndex)
                        end
                    end
                    ::continue::
                until not layer            
            else
                if (onlyPlain) then 
                   -- if (group:LabelColor() != 0) then goto continue3 end
                end
                group:SetLabelColor(colorIndex)
                ::continue3::
            end
        end
        moho:UpdateUI()
    end    
end

-- **************************************************
-- Localization
-- **************************************************
function GH_tool:Localize(text)
    local phrase = {
        ['Description'] = 'Xóa action trống/mọi action, đổi tên bone, gộp layer, đổi màu xương, xóa layer tắt, mở/thu gọn layer, render chất lượng cao.',
        ['UILabel'] = 'Đổi tên Bone & Smart Bone - Giàng Hùng ',
        ['Del Action Empty'] = 'Xóa Action Trống',
        ['Del All Action'] = 'Xóa Mọi Action',
        ['Rename Bone'] = 'Đổi tên Action Bone',
        ['Đổi Màu Xương'] = 'Đổi Màu Xương',
        ['Gộp Layer'] = 'Gộp Layer',
        ['Tick cho vui'] = 'Render High',
        ['Xóa Layers TẮT'] = 'Xóa Layers TẮT',
        ['Expand Collapse'] = 'Mở/Thu Gọn Tất Cả',
        ['Giữ nguyên màu hiện tại'] = 'Giữ nguyên màu hiện tại',
        ['Màu Nhãn Lớp'] = 'Màu Nhãn Lớp',
        ['=Không màu'] = 'Không màu',
        ['=Tím'] = 'Tím',
        ['=Xanh dương'] = 'Xanh dương',
        ['=Xanh lá'] = 'Xanh lá',
        ['=Vàng'] = 'Vàng',
        ['=Cam'] = 'Cam',
        ['=Đỏ'] = 'Đỏ',
        ['=Nâu nhạt'] = 'Nâu nhạt',
        ['=Hồng'] = 'Hồng',
        ['=Ngọc lam'] = 'Ngọc lam',
        ['=Xanh cadet'] = 'Xanh cadet',
        ['=San hô'] = 'San hô',
        ['enterNewName'] = "Nhập tên mới cho '"
    }
    return phrase[text] or text
end