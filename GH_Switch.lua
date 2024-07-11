-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "GH_Switch"

-- **************************************************
-- General information about this script
-- **************************************************

GH_Switch = {}

function GH_Switch:Name()
	return 'Switcher_s59'
end

function GH_Switch:Version()
	return '1.0'
end

function GH_Switch:UILabel()
	return 'Switcher_s59'
end

function GH_Switch:Creator()
	return 'Aleksei Maletin_GiangHungfix'
end

function GH_Switch:Description()
	return 'Kích hoạt tất cả các lớp chuyển đổi'
end


-- **************************************************
-- Is Relevant / Is Enabled
-- **************************************************

function GH_Switch:IsRelevant(moho)
	local layer = moho.layer
	local switch = moho:LayerAsSwitch(layer)
	return switch ~= nil
end

function GH_Switch:IsEnabled(moho)
	local layer = moho.layer
	local switch = moho:LayerAsSwitch(layer)
	return switch ~= nil
end

-- **************************************************
-- The guts of this script
-- **************************************************

function GH_Switch:Run(moho)
	moho.document:SetDirty()
	moho.document:PrepUndo(nil)
	
	-- Your code here:
	local layer = moho.layer
	local switch = moho:LayerAsSwitch(layer)
	if switch then
		for i = 0, switch:CountLayers()-1 do
			switch:SwitchValues():SetValue(i+1, switch:Layer(i):Name())
		end
	end
end
