-- GH_SwitchAutoStep 1.0 - standalone embedded Bone Layer script, Moho 14.4.
-- Attach through Layer Settings > General > Embedded script file.
-- Exact, case-sensitive substring: "Switch". Main timeline only.
-- This enforces interpolation on existing keys; it never creates keys.

local running = false
local lastError = nil

local function isMainline(object)
    local action = object:CurrentAction()
    -- Moho 14.4 returns "" for a layer, but nil for a mainline channel.
    return action == nil or action == ""
end

local function stepChannel(channel)
    if channel == nil or not isMainline(channel) then
        return false
    end

    local changed = false
    local interp = nil
    for keyID = 0, channel:CountKeys() - 1 do
        if channel:GetKeyInterpModeByID(keyID) ~= MOHO.INTERP_STEP then
            if interp == nil then
                interp = MOHO.InterpSetting:new_local()
            end
            -- Preserve tags, interval, hold, flags and other key settings.
            channel:GetKeyInterpByID(keyID, interp)
            interp.interpMode = MOHO.INTERP_STEP
            channel:SetKeyInterpByID(keyID, interp)
            changed = true
        end
    end
    return changed
end

local function stepPosition(channel)
    if channel == nil or not isMainline(channel) then
        return false
    end
    if channel:AreDimensionsSplit() then
        local xChanged = stepChannel(channel:DimensionChannel(0))
        local yChanged = stepChannel(channel:DimensionChannel(1))
        return xChanged or yChanged
    end
    return stepChannel(channel)
end

local function enforce(moho)
    local layer = moho.layer
    if layer == nil or not isMainline(layer) then
        return
    end
    local boneLayer = moho:LayerAsBone(layer)
    if boneLayer == nil then
        return
    end
    local skeleton = boneLayer:Skeleton()
    if skeleton == nil then
        return
    end

    for boneID = 0, skeleton:CountBones() - 1 do
        local bone = skeleton:Bone(boneID)
        if bone ~= nil and string.find(bone:Name(), "Switch", 1, true) then
            -- Do not short-circuit: all three channels must be processed.
            local posChanged = stepPosition(bone.fAnimPos)
            local angleChanged = stepChannel(bone.fAnimAngle)
            local scaleChanged = stepChannel(bone.fAnimScale)
            if (posChanged or angleChanged or scaleChanged) and moho.document then
                moho.document:SetDirty()
            end
        end
    end
end

function LayerScript(moho)
    if running or moho == nil then
        return
    end
    running = true
    -- Always release the guard, including after an API error.
    local ok, message = pcall(enforce, moho)
    running = false
    if ok then
        lastError = nil
    elseif message ~= lastError then
        lastError = message
        print("GH_SwitchAutoStep: " .. tostring(message))
    end
    -- No UpdateCurFrame/UpdateUI here: those can recursively invoke LayerScript.
    -- No PrepUndo here: frame evaluation must not add its own undo entries.
end
