-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "GH_select_Bone_layer"

-- **************************************************
-- General information about this script 12.7.2024
-- **************************************************

GH_select_Bone_layer = {}

function GH_select_Bone_layer:Name()
    return 'Select Bonelayer'
end

function GH_select_Bone_layer:Version()
    return '2.0'
end

function GH_select_Bone_layer:UILabel()
    return 'Select Bonelayer'
end

function GH_select_Bone_layer:Creator()
    return 'Aleksei Maletin-Hungs59'
end

function GH_select_Bone_layer:Description()
    return 'Select Bonelayer'
end
--Test 1---
function GH_select_Bone_layer:Run(moho)
    if self:IsSelectedLargestBoneOrGroup(moho) then
        self:CollapseAllGroups(moho)
    else
        self:SelectBoneLayer(moho)
    end
end

function GH_select_Bone_layer:IsSelectedLargestBoneOrGroup(moho)
    local selectedLayer = moho.layer
    
    -- Kiểm tra nếu lớp đang được chọn là xương hoặc nhóm lớn nhất
    local largestGroupLayer = nil
    local largestBoneLayer = nil
    local layerToCheck = selectedLayer
    
    while layerToCheck do
        if layerToCheck:LayerType() == MOHO.LT_BONE then
            -- Nếu là xương và là xương lớn nhất được tìm thấy
            if largestBoneLayer == nil or layerToCheck:CountLayers() > largestBoneLayer:CountLayers() then
                largestBoneLayer = layerToCheck
            end
             else if layerToCheck:LayerType() == MOHO.LT_GROUP then
    -- Nếu là nhóm và là nhóm lớn nhất được tìm thấy
             local countLayers
             if layerToCheck.CountLayers then
                countLayers = layerToCheck:CountLayers()
             elseif layerToCheck.LayerList then
    -- Nếu không có CountLayers() thì sử dụng LayerList() và Count()
            local layerList = layerToCheck:LayerList()
                  countLayers = layerList:Count()
            else
    -- Xử lý trường hợp không có cả CountLayers() và LayerList()
                  countLayers = 0  -- hoặc báo lỗi tùy vào logic của ứng dụng
end

    
        if largestGroupLayer == nil or countLayers > largestGroupLayer:CountLayers() then
        largestGroupLayer = layerToCheck
        end
    end
	end

        layerToCheck = layerToCheck:Parent()
    end
    
    -- Kiểm tra xem lớp được chọn có phải là xương lớn nhất hoặc nhóm lớn nhất không
    return selectedLayer == largestBoneLayer or selectedLayer == largestGroupLayer
end

function GH_select_Bone_layer:CollapseAllGroups(moho)
    local count = 0
    repeat
        local layer = moho.document:LayerByAbsoluteID(count)
        if layer then
            count = count + 1
            local groupLayer = moho:LayerAsGroup(layer)
            if groupLayer and groupLayer:IsExpanded() then
                groupLayer:Expand(false)
            end
        end
    until not layer   
    moho:UpdateUI()
end

function GH_select_Bone_layer:SelectBoneLayer(moho)
    local layerToSearchForBoneParent = moho.layer
    local layerParentBone = layerToSearchForBoneParent:ControllingBoneLayer()
    
    if layerParentBone then
        moho:SetSelLayer(layerParentBone)
    else
        local largestGroupLayer = nil
        repeat
            local parent = layerToSearchForBoneParent:Parent()
            if parent then
                if parent:LayerType() == MOHO.LT_BONE then
                    moho:SetSelLayer(parent)
                    moho:ShowLayerInLayersPalette(parent)
                    return
                elseif parent:LayerType() == MOHO.LT_GROUP then
                    -- Check if this group is larger than the current largest group found
                    if largestGroupLayer == nil or parent:CountLayers() > largestGroupLayer:CountLayers() then
                        largestGroupLayer = parent
                    end
                end
                layerToSearchForBoneParent = parent
            end	
        until not parent
        
        -- If a largest group layer was found, select it
        if largestGroupLayer then
            moho:SetSelLayer(largestGroupLayer)
            moho:ShowLayerInLayersPalette(largestGroupLayer)
        end
    end
end
