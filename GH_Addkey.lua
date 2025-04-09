-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "GH_Addkey"

-- **************************************************
-- General information about this script
-- **************************************************

GH_Addkey = {}

function GH_Addkey:Name()
    return "GH_Addkey"
end

function GH_Addkey:Version()
    return "1.2"
end

function GH_Addkey:Description()
    return "Adds a keyframe in bone/point/layer channels"
end

function GH_Addkey:Creator()
    return "Stan from 2danimator.ru"
end

function GH_Addkey:UILabel()
    return "Add Keyframe"
end

-- **************************************************
-- The guts of this script
-- **************************************************

-- Set all options to true by default
function GH_Addkey:Run(moho)
    moho.document:PrepUndo(moho.layer)
    moho.document:SetDirty()
    
    local keyBones = true
    local keyPoints = true
    local keyWidth = true
    local keyCurvature = true
    local keyLayer = true
    local keyRotation = false
        
    local boneLayer = moho:LayerAsBone(moho.layer)
    if boneLayer and keyBones then
        local skel = boneLayer:Skeleton()
        for i=0, skel:CountBones()-1 do
            local bone = skel:Bone(i)
            self:CreateKeyframe(moho, bone.fAnimPos)
            self:CreateKeyframe(moho, bone.fAnimAngle)
            self:CreateKeyframe(moho, bone.fAnimScale)
        end
    end
    
    local vectorLayer = moho:LayerAsVector(moho.layer)
    if vectorLayer then
        local mesh = vectorLayer:Mesh()
        for i=0, mesh:CountCurves()-1 do
            local curve = mesh:Curve(i)
            for q=0, curve:CountPoints()-1 do
                if keyCurvature then
                    local c = curve:GetCurvature(q, moho.layerFrame)
                    curve:SetCurvature(q, c, moho.layerFrame)
                end
                if keyPoints or keyWidth then
                    local point = curve:Point(q)
                    if keyPoints then
                        self:CreateKeyframe(moho, point.fAnimPos)
                    end
                    if keyWidth then
                        local width = point.fWidth
                        if (width.value < 0) then
                            local lineWidth = 0
                            for f = 0, mesh:CountShapes() - 1 do
                                local shape = mesh:Shape(f)
                                if (shape.fHasOutline and shape:ContainsPoint(mesh:PointID(point))) then
                                    lineWidth = shape.fMyStyle.fLineWidth
                                    if ((shape.fInheritedStyle ~= nil) and shape.fInheritedStyle.fDefineLineWidth and (not shape.fMyStyle.fDefineLineWidth)) then
                                        lineWidth = shape.fInheritedStyle.fLineWidth
                                    end
                                    if ((shape.fInheritedStyle2 ~= nil) and shape.fInheritedStyle2.fDefineLineWidth and (not shape.fMyStyle.fDefineLineWidth)) then
                                        lineWidth = shape.fInheritedStyle2.fLineWidth
                                    end
                                    break
                                end
                            end
                            width:SetValue(moho.layerFrame, lineWidth)
                        else
                            width:SetValue(moho.layerFrame, width:GetValue(moho.layerFrame))
                        end
                    end
                end
            end
        end
        if keyCurvature then 
            moho:NewKeyframe(CHANNEL_CURVE)
        end
    end
    
    local layer = moho.layer
    if keyRotation then
        self:CreateKeyframe(moho, layer.fRotationX)
        self:CreateKeyframe(moho, layer.fRotationY)
    end
    if keyLayer then
        self:CreateKeyframe(moho, layer.fTranslation)
        self:CreateKeyframe(moho, layer.fRotationZ)
        self:CreateKeyframe(moho, layer.fScale)
    end        
end

function GH_Addkey:CreateKeyframe(moho, channel)
    -- Check if channel has the AreDimensionsSplit method
    if channel.AreDimensionsSplit then
        local andTheyAreSplit = channel:AreDimensionsSplit()
        if andTheyAreSplit then
            for i = 0, 2 do
                subChannel = channel:DimensionChannel(i)
                if subChannel then
                    subChannel:SetValue(moho.layerFrame, subChannel:GetValue(moho.layerFrame))
                end
            end
        else
            channel:SetValue(moho.layerFrame, channel:GetValue(moho.layerFrame))
        end
    else
        channel:SetValue(moho.layerFrame, channel:GetValue(moho.layerFrame))
    end
end
