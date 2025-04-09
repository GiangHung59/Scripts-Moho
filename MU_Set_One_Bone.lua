-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "MU_SetOneBone"

-- **************************************************
-- General information about this script
-- **************************************************

MU_SetOneBone = {}

function MU_SetOneBone:Name()
    return self:Localize('UILabel')
end

function MU_SetOneBone:Version()
    return '2.9.2' -- Tăng version để theo dõi thay đổi . ỔN ĐỊNH

end

function MU_SetOneBone:UILabel()
    return self:Localize('UILabel')
end

function MU_SetOneBone:Creator()
    return 'MoeU33(Hailey Lee), Eugene Babich'
end

function MU_SetOneBone:Description()
    return self:Localize('Description') .. '\n Cập nhật: 26/03/2025'
end

function MU_SetOneBone:ColorizeIcon()
    return true
end

-- **************************************************
-- Is Relevant / Is Enabled
-- **************************************************

function MU_SetOneBone:IsRelevant(moho)
    local layerType = moho.layer:LayerType()
    return layerType ~= MOHO.LT_AUDIO and layerType ~= MOHO.LT_3D
end

function MU_SetOneBone:IsEnabled(moho)
    return true
end

-- **************************************************
-- Recurring Values
-- **************************************************

MU_SetOneBone.textControl1 = 0
MU_SetOneBone.textControl2 = 0
MU_SetOneBone.textControl3 = 0
MU_SetOneBone.textControl4 = 0
MU_SetOneBone.autoCreateSkeleton = true
MU_SetOneBone.isMouseDragging = false
MU_SetOneBone.selRect = LM.Rect:new_local()

-- **************************************************
-- Prefs
-- **************************************************

function MU_SetOneBone:LoadPrefs(prefs)
    self.textControl1 = prefs:GetFloat("MU_SetOneBone.textControl1", 0)
    self.textControl2 = prefs:GetFloat("MU_SetOneBone.textControl2", 0)
    self.textControl3 = prefs:GetFloat("MU_SetOneBone.textControl3", 0)
    self.textControl4 = prefs:GetFloat("MU_SetOneBone.textControl4", 0)
end

function MU_SetOneBone:SavePrefs(prefs)
    prefs:SetFloat("MU_SetOneBone.textControl1", self.textControl1)
    prefs:SetFloat("MU_SetOneBone.textControl2", self.textControl2)
    prefs:SetFloat("MU_SetOneBone.textControl3", self.textControl3)
    prefs:SetFloat("MU_SetOneBone.textControl4", self.textControl4)
end

function MU_SetOneBone:ResetPrefs()
    self.textControl1 = 0
    self.textControl2 = 0
    self.textControl3 = 0
    self.textControl4 = 0
end

-- **************************************************
-- Keyboard/Mouse Control
-- **************************************************

function MU_SetOneBone:OnMouseDown(moho, mouseEvent)
    local skel = moho:Skeleton()
    local mesh = moho:Mesh()
    if not skel and not mesh then
        return
    end

    self.isMouseDragging = true
    self.selRect.left = mouseEvent.pt.x
    self.selRect.top = mouseEvent.pt.y
    self.selRect.right = mouseEvent.pt.x
    self.selRect.bottom = mouseEvent.pt.y

    -- Nếu không giữ Shift, Ctrl hoặc Alt, xóa lựa chọn hiện tại
    if not mouseEvent.shiftKey and not mouseEvent.ctrlKey and not mouseEvent.altKey then
        if skel then
            skel:SelectNone()
        elseif mesh then
            mesh:SelectNone()
        end
    end

    mouseEvent.view:DrawMe()
end

function MU_SetOneBone:OnMouseMoved(moho, mouseEvent)
    local skel = moho:Skeleton()
    local mesh = moho:Mesh()
    if not skel and not mesh then
        return
    end

    if self.isMouseDragging then
        local g = mouseEvent.view:Graphics()
        g:SelectionRect(self.selRect)
        self.selRect.right = mouseEvent.pt.x
        self.selRect.bottom = mouseEvent.pt.y
        g:SelectionRect(self.selRect)
        mouseEvent.view:RefreshView()
        mouseEvent.view:DrawMe()
    end
end

function MU_SetOneBone:OnMouseUp(moho, mouseEvent)
    local skel = moho:Skeleton()
    local mesh = moho:Mesh()
    if not skel and not mesh then
        return
    end

    local mouseDist = math.abs(mouseEvent.pt.x - mouseEvent.startPt.x) + math.abs(mouseEvent.pt.y - mouseEvent.startPt.y)
    self.isMouseDragging = false

    -- Xử lý nhấp chuột đơn
    if mouseDist < 8 then
        local id
        if skel then
            id = mouseEvent.view:PickBone(mouseEvent.pt, mouseEvent.vec, moho.layer, true)
            if not mouseEvent.shiftKey and not mouseEvent.ctrlKey and not mouseEvent.altKey then
                skel:SelectNone()
            end
            if id ~= -1 then
                local bone = skel:Bone(id)
                bone.fSelected = not mouseEvent.altKey
                if mouseEvent.ctrlKey or mouseEvent.altKey then
                    -- Ctrl: Gán vào Pos 1, Alt: Gán vào Pos 2
                    local pos = LM.Vector2:new_local()
                    if mouseEvent.altKey and not bone:IsZeroLength() then
                        pos:Set(bone.fLength, 0) -- Đầu xương
                    else
                        pos:Set(0, 0) -- Gốc xương
                    end
                    if moho.frame == 0 then
                        bone.fRestMatrix:Transform(pos)
                    else
                        bone.fMovedMatrix:Transform(pos)
                    end
                    pos = self:GetGlobalPos(moho, moho.layer, pos)
                    if mouseEvent.ctrlKey then
                        self.textControl1 = pos.x
                        self.textControl2 = pos.y
                    elseif mouseEvent.altKey then
                        self.textControl3 = pos.x
                        self.textControl4 = pos.y
                    end
                    self:UpdateWidgets(moho)
                end
            end
        elseif mesh then
            id = mouseEvent.view:PickPoint(mouseEvent.pt)
            if id ~= -1 then
                local point = mesh:Point(id)
                if not mouseEvent.shiftKey and not mouseEvent.ctrlKey and not mouseEvent.altKey then
                    mesh:SelectNone()
                    point.fSelected = true
                elseif mouseEvent.ctrlKey or mouseEvent.altKey then
                    -- Ctrl: Gán vào Pos 1, Alt: Gán vào Pos 2
                    local pos = LM.Vector2:new_local()
                    pos:Set(point.fPos)
                    pos = self:GetGlobalPos(moho, moho.layer, pos)
                    if mouseEvent.ctrlKey then
                        self.textControl1 = pos.x
                        self.textControl2 = pos.y
                    elseif mouseEvent.altKey then
                        self.textControl3 = pos.x
                        self.textControl4 = pos.y
                    end
                    self:UpdateWidgets(moho)
                else
                    point.fSelected = not mouseEvent.altKey
                end
            else
                -- Chọn viền và toàn bộ shape chứa viền đó
                local curveID = -1
                local segID = -1
                curveID, segID = mouseEvent.view:PickEdge(mouseEvent.pt, curveID, segID)
                if curveID >= 0 and segID >= 0 then
                    if not mouseEvent.shiftKey and not mouseEvent.ctrlKey and not mouseEvent.altKey then
                        mesh:SelectNone()
                    end
                    for i = 0, mesh:CountShapes() - 1 do
                        local shape = mesh:Shape(i)
                        if shape:ContainsCurve(curveID) then
                            for j = 0, shape:CountEdges() - 1 do
                                local cID, sID = shape:GetEdge(j, curveID, segID)
                                local curve = mesh:Curve(cID)
                                if not mouseEvent.altKey then
                                    curve:Point(sID).fSelected = true
                                    if sID + 1 < curve:CountPoints() then
                                        curve:Point(sID + 1).fSelected = true
                                    end
                                else
                                    curve:Point(sID).fSelected = false
                                    if sID + 1 < curve:CountPoints() then
                                        curve:Point(sID + 1).fSelected = false
                                    end
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    -- Xử lý chọn vùng
    elseif mouseDist >= 8 then
        local v = LM.Vector2:new_local()
        local screenPt = LM.Point:new_local()
        local m = LM.Matrix:new_local()

        if moho.layer:LayerType() == MOHO.LT_BONE and skel then
            self.selRect:Normalize()
            moho.layer:GetFullTransform(moho.frame, m, moho.document)
            for i = 0, skel:CountBones() - 1 do
                local bone = skel:Bone(i)
                local boneMatrix = bone.fMovedMatrix
                for j = 0, 10 do
                    v:Set(bone.fLength * j / 10.0, 0)
                    boneMatrix:Transform(v)
                    m:Transform(v)
                    mouseEvent.view:Graphics():WorldToScreen(v, screenPt)
                    if self.selRect:Contains(screenPt) then
                        bone.fSelected = not mouseEvent.altKey
                        break
                    end
                end
            end
        elseif moho.layer:LayerType() == MOHO.LT_VECTOR and mesh then
            self.selRect:Normalize()
            moho.drawingLayer:GetFullTransform(moho.frame, m, moho.document)
            for i = 0, mesh:CountPoints() - 1 do
                local pt = mesh:Point(i)
                if not pt.fHidden then
                    v:Set(pt.fPos)
                    m:Transform(v)
                    mouseEvent.view:Graphics():WorldToScreen(v, screenPt)
                    if self.selRect:Contains(screenPt) then
                        pt.fSelected = not mouseEvent.altKey
                    end
                end
            end
        end
    end

    moho:UpdateSelectedChannels()
    mouseEvent.view:DrawMe()
end

function MU_SetOneBone:OnKeyDown(moho, keyEvent)
end

function MU_SetOneBone:DrawMe(moho, view)
    if self.isMouseDragging then
        local g = view:Graphics()
        g:SelectionRect(self.selRect)
    end
end

-- **************************************************
-- Tool Panel Layout
-- **************************************************

MU_SetOneBone.GP_1 = MOHO.MSG_BASE
MU_SetOneBone.GP_1_A = MOHO.MSG_BASE + 1
MU_SetOneBone.TEXT_CONTROL_1 = MOHO.MSG_BASE + 2
MU_SetOneBone.TEXT_CONTROL_2 = MOHO.MSG_BASE + 3
MU_SetOneBone.SET_P_BONE_1 = MOHO.MSG_BASE + 4
MU_SetOneBone.reset_btn_1 = MOHO.MSG_BASE + 5
MU_SetOneBone.ExChange = MOHO.MSG_BASE + 6
MU_SetOneBone.GP_2 = MOHO.MSG_BASE + 7
MU_SetOneBone.GP_2_A = MOHO.MSG_BASE + 8
MU_SetOneBone.TEXT_CONTROL_3 = MOHO.MSG_BASE + 9
MU_SetOneBone.TEXT_CONTROL_4 = MOHO.MSG_BASE + 10
MU_SetOneBone.SET_P_BONE_2 = MOHO.MSG_BASE + 11
MU_SetOneBone.reset_btn_2 = MOHO.MSG_BASE + 12
MU_SetOneBone.SetBone_btn = MOHO.MSG_BASE + 13
MU_SetOneBone.MovePB_1_btn = MOHO.MSG_BASE + 14
MU_SetOneBone.MovePB_2_btn = MOHO.MSG_BASE + 15
MU_SetOneBone.ChangeB_P_BONE = MOHO.MSG_BASE + 16
MU_SetOneBone.GENERIC = MOHO.MSG_BASE + 17

function MU_SetOneBone:DoLayout(moho, layout)
    layout:AddPadding(5)

    self.get_pos_1 = LM.GUI.ImageButton('ScriptResources/mu_set1bone/getcoord', self:Localize('GET_POS_1'), false, self.GP_1)
    self.get_pos_1:SetAlternateMessage(self.GP_1_A)
    layout:AddChild(self.get_pos_1, LM.GUI.ALIGN_LEFT, 0)

    self.textControl1Input = LM.GUI.TextControl(0, '0.0000', self.GENERIC, LM.GUI.FIELD_FLOAT, 'X:')
    layout:AddChild(self.textControl1Input, LM.GUI.ALIGN_LEFT, 0)

    self.textControl2Input = LM.GUI.TextControl(0, '0.0000', self.GENERIC, LM.GUI.FIELD_FLOAT, 'Y:')
    layout:AddChild(self.textControl2Input, LM.GUI.ALIGN_LEFT, 0)

    self.set_point_bone_1 = LM.GUI.ImageButton('ScriptResources/mu_set1bone/set0bone', self:Localize('SET_POINT_BONE'), false, self.SET_P_BONE_1)
    layout:AddChild(self.set_point_bone_1, LM.GUI.ALIGN_LEFT, 0)

    self.move_PB_1 = LM.GUI.ImageButton('ScriptResources/mu_set1bone/movetonew', self:Localize('MOVE_PB_1'), false, self.MovePB_1_btn)
    layout:AddChild(self.move_PB_1, LM.GUI.ALIGN_LEFT, 0)

    self.reset_cd_1 = LM.GUI.ImageButton('ScriptResources/mu_set1bone/reset', self:Localize('RESET'), false, self.reset_btn_1)
    layout:AddChild(self.reset_cd_1, LM.GUI.ALIGN_LEFT, 0)

    layout:AddPadding(5)
    layout:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL)
    layout:AddPadding(5)

    self.button8Button = LM.GUI.ImageButton('ScriptResources/mu_set1bone/exchange', self:Localize('EXCHANGE'), false, self.ExChange)
    layout:AddChild(self.button8Button, LM.GUI.ALIGN_LEFT, 0)

    layout:AddPadding(5)
    layout:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL)
    layout:AddPadding(5)

    self.get_pos_2 = LM.GUI.ImageButton('ScriptResources/mu_set1bone/getcoord', self:Localize('GET_POS_2'), false, self.GP_2)
    self.get_pos_2:SetAlternateMessage(self.GP_2_A)
    layout:AddChild(self.get_pos_2, LM.GUI.ALIGN_CENTER, 0)

    self.textControl3Input = LM.GUI.TextControl(0, '0.0000', self.GENERIC, LM.GUI.FIELD_FLOAT, 'X:')
    layout:AddChild(self.textControl3Input, LM.GUI.ALIGN_LEFT, 0)

    self.textControl4Input = LM.GUI.TextControl(0, '0.0000', self.GENERIC, LM.GUI.FIELD_FLOAT, 'Y:')
    layout:AddChild(self.textControl4Input, LM.GUI.ALIGN_LEFT, 0)

    self.set_point_bone_2 = LM.GUI.ImageButton('ScriptResources/mu_set1bone/set0bone', self:Localize('SET_POINT_BONE'), false, self.SET_P_BONE_2)
    layout:AddChild(self.set_point_bone_2, LM.GUI.ALIGN_LEFT, 0)

    self.move_PB_2 = LM.GUI.ImageButton('ScriptResources/mu_set1bone/movetonew', self:Localize('MOVE_PB_2'), false, self.MovePB_2_btn)
    layout:AddChild(self.move_PB_2, LM.GUI.ALIGN_LEFT, 0)

    self.reset_cd_2 = LM.GUI.ImageButton('ScriptResources/mu_set1bone/reset', self:Localize('RESET'), false, self.reset_btn_2)
    layout:AddChild(self.reset_cd_2, LM.GUI.ALIGN_LEFT, 0)

    layout:AddPadding(5)
    layout:AddChild(LM.GUI.Divider(true), LM.GUI.ALIGN_FILL)
    layout:AddPadding(5)

    self.set_1_bone = LM.GUI.ImageButton('ScriptResources/mu_set1bone/set1bone', self:Localize('SET_ONE_BONE'), false, self.SetBone_btn)
    layout:AddChild(self.set_1_bone, LM.GUI.ALIGN_LEFT, 0)

    self.Change_bone = LM.GUI.ImageButton('ScriptResources/mu_set1bone/movetonew', self:Localize('CHANGE_BONE'), false, self.ChangeB_P_BONE)
    layout:AddChild(self.Change_bone, LM.GUI.ALIGN_LEFT, 0)
end

function MU_SetOneBone:UpdateWidgets(moho)
    self.textControl1Input:SetValue(self.textControl1)
    self.textControl2Input:SetValue(self.textControl2)
    self.textControl3Input:SetValue(self.textControl3)
    self.textControl4Input:SetValue(self.textControl4)
end

function MU_SetOneBone:HandleMessage(moho, view, msg)
    local skel = moho:Skeleton()
    local mesh = moho:Mesh() 

    if msg == self.GP_1 then
        if skel then
            if moho:CountSelectedBones(true) > 0 then
                local boneId = skel:SelectedBoneID()
                local bone = skel:Bone(boneId)
                local pos = LM.Vector2:new_local()
                pos:Set(0, 0)
                if moho.frame == 0 then
                    bone.fRestMatrix:Transform(pos)
                else
                    bone.fMovedMatrix:Transform(pos)
                end
                pos:Set(self:GetGlobalPos(moho, moho.layer, pos))
                self.textControl1 = pos.x
                self.textControl2 = pos.y
            end
        elseif not skel then
            local selectedPoints = moho:CountSelectedPoints()
            if selectedPoints == 0 then
                local layer = moho.layer
                local layerOrigin = moho.layer:Origin()
                local globalLayerOrigin = self:GetGlobalPos(moho, layer, layerOrigin)
                self.textControl1 = globalLayerOrigin.x
                self.textControl2 = globalLayerOrigin.y
            elseif selectedPoints == 1 then
                for i = 0, mesh:CountPoints() - 1 do
                    local point = mesh:Point(i)
                    if point.fSelected then
                        local pos = LM.Vector2:new_local()
                        pos:Set(point.fPos)
                        pos:Set(self:GetGlobalPos(moho, moho.layer, pos))
                        self.textControl1 = pos.x
                        self.textControl2 = pos.y
                        break
                    end
                end
            elseif selectedPoints > 1 then
                local pos = LM.Vector2:new_local()
                pos:Set(mesh:SelectedCenter())
                pos:Set(self:GetGlobalPos(moho, moho.layer, pos))
                self.textControl1 = pos.x
                self.textControl2 = pos.y
            end
        end
        self:UpdateWidgets(moho)
    elseif msg == self.GP_1_A then
        if skel then
            if moho:CountSelectedBones(true) > 0 then
                local boneId = skel:SelectedBoneID()
                local bone = skel:Bone(boneId)
                local pos = LM.Vector2:new_local()
                if bone:IsZeroLength() then
                    pos:Set(0, 0)
                else
                    pos:Set(bone.fLength, 0)
                end
                if moho.frame == 0 then
                    bone.fRestMatrix:Transform(pos)
                else
                    bone.fMovedMatrix:Transform(pos)
                end
                pos:Set(self:GetGlobalPos(moho, moho.layer, pos))
                self.textControl1 = pos.x
                self.textControl2 = pos.y
                self:UpdateWidgets(moho)
            end
        elseif not skel then
            local selectedPoints = moho:CountSelectedPoints()
            if selectedPoints == 0 then
                local layer = moho.layer
                local layerOrigin = moho.layer:Origin()
                local globalLayerOrigin = self:GetGlobalPos(moho, layer, layerOrigin)
                self.textControl1 = globalLayerOrigin.x
                self.textControl2 = globalLayerOrigin.y
            elseif selectedPoints == 1 then
                for i = 0, mesh:CountPoints() - 1 do
                    local point = mesh:Point(i)
                    if point.fSelected then
                        local pos = LM.Vector2:new_local()
                        pos:Set(point.fPos)
                        pos:Set(self:GetGlobalPos(moho, moho.layer, pos))
                        self.textControl1 = pos.x
                        self.textControl2 = pos.y
                        break
                    end
                end
            end
        end
        self:UpdateWidgets(moho)
    elseif msg == self.SET_P_BONE_1 then
        local skel, skelLayer = self:GetSkeleton(moho)
        local curLayer = moho.layer
        if skel and skelLayer then
            moho.document:SetDirty()
            moho.document:PrepUndo(skelLayer, true)
            local localPos1 = LM.Vector2:new_local()
            localPos1:Set(self.textControl1, self.textControl2)
            localPos1:Set(self:GetLocalPos(moho, skelLayer, localPos1))
            self:CreateBone(moho, skelLayer, localPos1, localPos1, true)
        else
            if self.autoCreateSkeleton then
                moho.document:SetDirty()
                moho.document:PrepUndo(nil)
                skelLayer = moho:CreateNewLayer(MOHO.LT_BONE)
                skel = moho:LayerAsBone(skelLayer):Skeleton()
                local localPos1 = LM.Vector2:new_local()
                localPos1:Set(self.textControl1, self.textControl2)
                localPos1:Set(self:GetLocalPos(moho, skelLayer, localPos1))
                self:CreateBone(moho, skelLayer, localPos1, localPos1, true)
                moho:PlaceLayerInGroup(curLayer, moho:LayerAsGroup(skelLayer), true, false)
            end
        end
        if mesh then
            local curFrame = moho.frame
            if curFrame == 0 then
                moho:SetCurFrame(1)
                moho:SetCurFrame(0)
            else
                moho:SetCurFrame(0)
                moho:SetCurFrame(curFrame)
            end
        end
        curLayer:UpdateCurFrame()
        moho:UpdateUI()
    elseif msg == self.MovePB_1_btn then
        local layer = moho.layer
        moho.document:SetDirty()
        moho.document:PrepUndo(layer, true)
        if skel then
            for i = 0, skel:CountBones() - 1 do
                local bone = skel:Bone(i)
                if bone.fSelected then
                    local vec2 = LM.Vector2:new_local()
                    local newX = self.textControl1
                    local newY = self.textControl2
                    vec2:Set(newX, newY)
                    vec2:Set(self:GetLocalPos(moho, layer, vec2))
                    bone.fAnimPos:SetValue(moho.layerFrame, vec2)
                end
            end
        else
            if mesh then
                for i = 0, mesh:CountPoints() - 1 do
                    local point = mesh:Point(i)
                    if point.fSelected then
                        local vec2 = LM.Vector2:new_local()
                        local newX = self.textControl1
                        local newY = self.textControl2
                        vec2:Set(newX, newY)
                        vec2:Set(self:GetLocalPos(moho, layer, vec2))
                        point.fAnimPos:SetValue(moho.layerFrame, vec2)
                    end
                end
            end
        end
        moho.layer:UpdateCurFrame()
        moho:UpdateUI()
    elseif msg == self.reset_btn_1 then
        self.textControl1 = 0
        self.textControl2 = 0
        self:UpdateWidgets(moho)
    elseif msg == self.ExChange then
        local text1 = self.textControl1
        local text2 = self.textControl2
        local text3 = self.textControl3
        local text4 = self.textControl4
        self.textControl1 = text3
        self.textControl2 = text4
        self.textControl3 = text1
        self.textControl4 = text2
        self:UpdateWidgets(moho)
    elseif msg == self.GP_2 then
        if skel then
            if moho:CountSelectedBones(true) > 0 then
                local boneId = skel:SelectedBoneID()
                local bone = skel:Bone(boneId)
                local pos = LM.Vector2:new_local()
                pos:Set(0, 0)
                if moho.frame == 0 then
                    bone.fRestMatrix:Transform(pos)
                else
                    bone.fMovedMatrix:Transform(pos)
                end
                pos:Set(self:GetGlobalPos(moho, moho.layer, pos))
                self.textControl3 = pos.x
                self.textControl4 = pos.y
            end
        elseif not skel then
            local selectedPoints = moho:CountSelectedPoints()
            if selectedPoints == 0 then
                local layer = moho.layer
                local layerOrigin = moho.layer:Origin()
                local globalLayerOrigin = self:GetGlobalPos(moho, layer, layerOrigin)
                self.textControl3 = globalLayerOrigin.x
                self.textControl4 = globalLayerOrigin.y
            elseif selectedPoints == 1 then
                for i = 0, mesh:CountPoints() - 1 do
                    local point = mesh:Point(i)
                    if point.fSelected then
                        local pos = LM.Vector2:new_local()
                        pos:Set(point.fPos)
                        pos:Set(self:GetGlobalPos(moho, moho.layer, pos))
                        self.textControl3 = pos.x
                        self.textControl4 = pos.y
                        break
                    end
                end
            elseif selectedPoints > 1 then
                local pos = LM.Vector2:new_local()
                pos:Set(mesh:SelectedCenter())
                pos:Set(self:GetGlobalPos(moho, moho.layer, pos))
                self.textControl3 = pos.x
                self.textControl4 = pos.y
            end
        end
        self:UpdateWidgets(moho)
    elseif msg == self.GP_2_A then
        if skel then
            if moho:CountSelectedBones(true) > 0 then
                local boneId = skel:SelectedBoneID()
                local bone = skel:Bone(boneId)
                local pos = LM.Vector2:new_local()
                if bone:IsZeroLength() then
                    pos:Set(0, 0)
                else
                    pos:Set(bone.fLength, 0)
                end
                if moho.frame == 0 then
                    bone.fRestMatrix:Transform(pos)
                else
                    bone.fMovedMatrix:Transform(pos)
                end
                pos:Set(self:GetGlobalPos(moho, moho.layer, pos))
                self.textControl3 = pos.x
                self.textControl4 = pos.y
                self:UpdateWidgets(moho)
            end
        elseif not skel then
            local selectedPoints = moho:CountSelectedPoints()
            if selectedPoints == 0 then
                local layer = moho.layer
                local layerOrigin = moho.layer:Origin()
                local globalLayerOrigin = self:GetGlobalPos(moho, layer, layerOrigin)
                self.textControl3 = globalLayerOrigin.x
                self.textControl4 = globalLayerOrigin.y
            elseif selectedPoints == 1 then
                for i = 0, mesh:CountPoints() - 1 do
                    local point = mesh:Point(i)
                    if point.fSelected then
                        local pos = LM.Vector2:new_local()
                        pos:Set(point.fPos)
                        pos:Set(self:GetGlobalPos(moho, moho.layer, pos))
                        self.textControl3 = pos.x
                        self.textControl4 = pos.y
                        break
                    end
                end
            end
        end
        self:UpdateWidgets(moho)
    elseif msg == self.SET_P_BONE_2 then
        local skel, skelLayer = self:GetSkeleton(moho)
        local curLayer = moho.layer
        if skel and skelLayer then
            moho.document:SetDirty()
            moho.document:PrepUndo(skelLayer, true)
            local localPos2 = LM.Vector2:new_local()
            localPos2:Set(self.textControl3, self.textControl4)
            localPos2:Set(self:GetLocalPos(moho, skelLayer, localPos2))
            self:CreateBone(moho, skelLayer, localPos2, localPos2, true)
        else
            if self.autoCreateSkeleton then
                moho.document:SetDirty()
                moho.document:PrepUndo(nil)
                skelLayer = moho:CreateNewLayer(MOHO.LT_BONE)
                skel = moho:LayerAsBone(skelLayer):Skeleton()
                local localPos2 = LM.Vector2:new_local()
                localPos2:Set(self.textControl3, self.textControl4)
                localPos2:Set(self:GetLocalPos(moho, skelLayer, localPos2))
                self:CreateBone(moho, skelLayer, localPos2, localPos2, true)
                moho:PlaceLayerInGroup(curLayer, moho:LayerAsGroup(skelLayer), true, false)
            end
        end
        if mesh then
            local curFrame = moho.frame
            if curFrame == 0 then
                moho:SetCurFrame(1)
                moho:SetCurFrame(0)
            else
                moho:SetCurFrame(0)
                moho:SetCurFrame(curFrame)
            end
        end
        curLayer:UpdateCurFrame()
        moho:UpdateUI()
    elseif msg == self.MovePB_2_btn then
        local layer = moho.layer
        moho.document:SetDirty()
        moho.document:PrepUndo(layer, true)
        if skel then
            for i = 0, skel:CountBones() - 1 do
                local bone = skel:Bone(i)
                if bone.fSelected then
                    local vec2 = LM.Vector2:new_local()
                    local newX = self.textControl3
                    local newY = self.textControl4
                    vec2:Set(newX, newY)
                    vec2:Set(self:GetLocalPos(moho, layer, vec2))
                    bone.fAnimPos:SetValue(moho.layerFrame, vec2)
                end
            end
        else
            if mesh then
                for i = 0, mesh:CountPoints() - 1 do
                    local point = mesh:Point(i)
                    if point.fSelected then
                        local vec2 = LM.Vector2:new_local()
                        local newX = self.textControl3
                        local newY = self.textControl4
                        vec2:Set(newX, newY)
                        vec2:Set(self:GetLocalPos(moho, layer, vec2))
                        point.fAnimPos:SetValue(moho.layerFrame, vec2)
                    end
                end
            end
        end
        moho.layer:UpdateCurFrame()
        moho:UpdateUI()
    elseif msg == self.reset_btn_2 then
        self.textControl3 = 0
        self.textControl4 = 0
        self:UpdateWidgets(moho)
    elseif msg == self.SetBone_btn then
        local skel, skelLayer = self:GetSkeleton(moho)
        local curLayer = moho.layer
        if skel and skelLayer then
            moho.document:SetDirty()
            moho.document:PrepUndo(skelLayer, true)
            local localPos1 = LM.Vector2:new_local()
            local localPos2 = LM.Vector2:new_local()
            localPos1:Set(self.textControl1, self.textControl2)
            localPos1:Set(self:GetLocalPos(moho, skelLayer, localPos1))
            localPos2:Set(self.textControl3, self.textControl4)
            localPos2:Set(self:GetLocalPos(moho, skelLayer, localPos2))
            self:CreateBone(moho, skelLayer, localPos1, localPos2, false)
        else
            if self.autoCreateSkeleton then
                moho.document:SetDirty()
                moho.document:PrepUndo(nil)
                skelLayer = moho:CreateNewLayer(MOHO.LT_BONE)
                skel = moho:LayerAsBone(skelLayer):Skeleton()
                local localPos1 = LM.Vector2:new_local()
                local localPos2 = LM.Vector2:new_local()
                localPos1:Set(self.textControl1, self.textControl2)
                localPos1:Set(self:GetLocalPos(moho, skelLayer, localPos1))
                localPos2:Set(self.textControl3, self.textControl4)
                localPos2:Set(self:GetLocalPos(moho, skelLayer, localPos2))
                self:CreateBone(moho, skelLayer, localPos1, localPos2, false)
                moho:PlaceLayerInGroup(curLayer, moho:LayerAsGroup(skelLayer), true, false)
            end
        end
        if mesh then
            local curFrame = moho.frame
            if curFrame == 0 then
                moho:SetCurFrame(1)
                moho:SetCurFrame(0)
            else
                moho:SetCurFrame(0)
                moho:SetCurFrame(curFrame)
            end
        end
        curLayer:UpdateCurFrame()
        moho:UpdateUI()
    elseif msg == self.ChangeB_P_BONE then
        local skel = moho:Skeleton()
        if skel == nil then return LM.GUI.Alert(LM.GUI.ALERT_INFO, (self:Localize('Warning'))) end
        if skel then
            moho.document:SetDirty()
            moho.document:PrepUndo(moho.layer, true)
            local skelLayer = moho.layer
            local pos1 = LM.Vector2:new_local()
            local pos2 = LM.Vector2:new_local()
            pos1:Set(self.textControl1, self.textControl2)
            pos1:Set(self:GetLocalPos(moho, skelLayer, pos1))
            pos2:Set(self.textControl3, self.textControl4)
            pos2:Set(self:GetLocalPos(moho, skelLayer, pos2))

            for i = 0, skel:CountBones() - 1 do
                local bone = skel:Bone(i)
                if bone.fSelected then
                    bone.fLength = math.sqrt((pos1.x - pos2.x)^2 + (pos1.y - pos2.y)^2)
                    bone.fAnimAngle:SetValue(0, math.atan2((pos2.y - pos1.y), (pos2.x - pos1.x)))
                    local startPos = LM.Vector2:new_local()
                    startPos:Set(pos1.x, pos1.y)
                    bone.fAnimPos:SetValue(0, startPos)
                end
            end
        end
        moho.layer:UpdateCurFrame()
        moho:UpdateUI()
    elseif msg == self.GENERIC then
        self.textControl1 = self.textControl1Input:FloatValue()
        self.textControl2 = self.textControl2Input:FloatValue()
        self.textControl3 = self.textControl3Input:FloatValue()
        self.textControl4 = self.textControl4Input:FloatValue()
        self:UpdateWidgets(moho)
    end
end

function MU_SetOneBone:GetSkeleton(moho) 
    local layerToSearchForBoneParent = moho.layer
    local skel = moho:Skeleton()
    if skel then
        skelLayer = moho.layer
    else
        skelLayer = layerToSearchForBoneParent:ControllingBoneLayer()
        if skelLayer then
            skel = moho:LayerAsBone(skelLayer):Skeleton()
        end
        if not skel then
            repeat
                local parent = layerToSearchForBoneParent:Parent()
                if parent then
                    if parent:LayerType() == MOHO.LT_BONE then
                        skelLayer = parent
                        skel = moho:LayerAsBone(parent):Skeleton()
                        moho:ShowLayerInLayersPalette(parent)
                        break
                    else
                        layerToSearchForBoneParent = parent
                    end
                end
            until not parent
        end
    end
    return skel, skelLayer
end

function MU_SetOneBone:CreateBone(moho, layer, pos1, pos2, pin)--gốc
    local skel = moho:LayerAsBone(layer):Skeleton()
    local bone = skel:AddBone(0)
    
    local selectedBoneID = -1
    for i = 0, skel:CountBones() - 1 do
        if skel:Bone(i).fSelected then
            selectedBoneID = i
            break
        end
    end
    
    if selectedBoneID >= 0 then
        bone.fParent = selectedBoneID
    else
        bone.fParent = -1
    end
    
    bone.fShy = false
    bone.fStrength = 0
    if pin then
        bone.fLength = 0
        bone.fAnimAngle:SetValue(0, 0)
    else
        bone.fLength = math.sqrt((pos1.x - pos2.x)^2 + (pos1.y - pos2.y)^2)
        bone.fAnimAngle:SetValue(0, math.atan2((pos2.y - pos1.y), (pos2.x - pos1.x)))
    end
    local startPos = LM.Vector2:new_local()
    startPos:Set(pos1.x, pos1.y)
    bone.fAnimPos:SetValue(0, startPos)
end

function MU_SetOneBone:GetGlobalPos(moho, layer, pos)
    local globalPos = LM.Vector2:new_local()
    globalPos:Set(pos)
    local layerMatrix = LM.Matrix:new_local()
    layer:GetFullTransform(moho.frame, layerMatrix, nil)
    layerMatrix:Transform(globalPos)
    return globalPos
end

function MU_SetOneBone:GetLocalPos(moho, layer, globalPos)
    local localPos = LM.Vector2:new_local()
    localPos:Set(globalPos)
    local selLayer = layer
    local selLayerMatrix = LM.Matrix:new_local()
    selLayer:GetFullTransform(0, selLayerMatrix, nil)
    selLayerMatrix:Invert()
    selLayerMatrix:Transform(localPos)
    return localPos
end

-- **************************************************
-- Localization
-- **************************************************

function MU_SetOneBone:Localize(text)
    local phrase = {}

    phrase['Description'] = 'Nhấp chuột trái để chọn, Ctrl+nhấp chuột trái để gắn vào Pos 1, Alt+nhấp chuột trái để gắn vào Pos 2 (đầu xương nếu là xương).'
    phrase['UILabel'] = 'Set One Bone'
    phrase['GET_POS_1'] = 'Lấy tọa độ gốc của xương/điểm được chọn'
    phrase['X:'] = 'X:'
    phrase['Y:'] = 'Y:'
    phrase['SET_POINT_BONE'] = 'Set Point Bone'
    phrase['RESET'] = 'Reset'
    phrase['EXCHANGE'] = 'Exchange Coordinate'
    phrase['GET_POS_2'] = 'Lấy tọa độ gốc của xương/điểm được chọn'
    phrase['SET_ONE_BONE'] = 'Set One Bone'
    phrase['MOVE_PB_1'] = 'Move To Coordinate 1'
    phrase['MOVE_PB_2'] = 'Move To Coordinate 2'
    phrase['CHANGE_BONE'] = 'Change Bone'
    phrase['Warning'] = 'Vui lòng chọn lớp xương'

    local fileWord = MOHO.Localize("/Menus/File/File=File")
    if fileWord == "文件" then
        phrase['Description'] = '左键单击选择，Ctrl+左键单击附到Pos 1，Alt+左键单击附到Pos 2（如果是骨骼则为尖端）。'
        phrase['UILabel'] = '在位置上添加骨骼'
        phrase['GET_POS_1'] = '获取选定骨骼/点的起始坐标'
        phrase['X:'] = 'X:'
        phrase['Y:'] = 'Y:'
        phrase['SET_POINT_BONE'] = '建立点骨'
        phrase['RESET'] = '重置'
        phrase['EXCHANGE'] = '交换坐标'
        phrase['GET_POS_2'] = '获取选定骨骼/点的起始坐标'
        phrase['SET_ONE_BONE'] = '建立一根骨骼'
        phrase['MOVE_PB_1'] = '移动至位置 1'
        phrase['MOVE_PB_2'] = '移动至位置 2'
        phrase['CHANGE_BONE'] = '修改该骨骼'
        phrase['Warning'] = '请在骨骼层上操作'
    end

    return phrase[text]
end