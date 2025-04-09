-- **************************************************
-- Provide Moho with the name of this script object
-- **************************************************

ScriptName = "JJ_Save"

-- **************************************************
-- General information about this script
-- **************************************************

JJ_Save = {}

--! Returns the name of the script.
--! @retval LM_String
function JJ_Save:Name()
	return "Increment Save"
end

--! Returns the version of the script.
--! @retval LM_String
function JJ_Save:Version()
	return "1.3"
end

--! Returns a localized description of the script's functionality.
--! @retval LM_String
function JJ_Save:Description()
	return MOHO.Localize("/Scripts/tool/SaveIncrement/Description=Save and Backups")
end

--! Always returns "Smith Micro Software, Inc."
--! @retval LM_String
function JJ_Save:Creator()
	return "Jeremy Jones - AnimeStudioTutor.com"
end

--! Returns the localized label for the automation test function.
--! @retval LM_String
function JJ_Save:UILabel()
	return(MOHO.Localize("/Scripts/tool/SaveIncrement/SaveIncrement=Save and Backups"))
end


function JJ_Save:Run(moho)    
local path = moho.document:Path()
if (path == "") then     
    local alert =  LM.GUI.Alert(LM.GUI.ALERT_WARNING,
                MOHO.Localize("/Scripts/tool/SaveIncrement/FirstSave=Vui lòng lưu một bản sao chính trước"),
                nil,
                nil,
                MOHO.Localize("/Scripts/OK=OK"),
                MOHO.Localize("/Scripts/CANCEL=CANCEL"),
                nil)
            if alert == 1 then       
                do return end 
            end    
    moho.FileSave()  
else
   local OS1 = package.config:sub(1,1)
    if OS1 ~= "/" then
     OS1 = "\\"
     end  
   local name = moho.document:Name()
   local version_number = 1 
   local save_path = path
   local file_name_part = string.gsub(name,".moho", "")
   local backup_folder = file_name_part.."_backups"..OS1    
   local path = path:gsub(name, "")..backup_folder
    moho:BeginFileListing(path)
	local fileName = moho:GetNextFile()
    while fileName ~= nil do
		sepPos = string.find(fileName, ".", 1, true)
		if (sepPos ~= nil) then
			local extn = string.sub(fileName, sepPos + 1)
			if (extn == "moho") then        
                local corr = string.find(fileName, "_%d+.moho")  
                if (corr ~= nil) then  
                        local current = tonumber(string.match(string.match(fileName, "_%d+.moho"), "%d+"))
                        if( current >= version_number) then
                            version_number = current+1
                        end
                end           
            end
        end  
        fileName = moho:GetNextFile()
    end   
local new = file_name_part .. '_'..version_number..'.moho'
path = path .. new
local test = io.open(path, "rb")
        if (test) then
            io.close(test)
            local alert =  LM.GUI.Alert(LM.GUI.ALERT_WARNING,
                MOHO.Localize("/Scripts/tool/SaveIncrement/Confirm="..new.." đã tồn tại! Bạn có chắc chắn muốn thay thế không?"),
                nil,
                nil,
                MOHO.Localize("/Scripts/OK=OK"),
                MOHO.Localize("/Scripts/CANCEL=CANCEL"),
                nil)
            if alert == 1 then       
                do return end 
            end
        else
            moho:FileSaveAs(path)
            moho:FileSaveAs(save_path)
        end
    end                  
end