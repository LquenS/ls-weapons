-- Variables
local LS_CORE = exports["ls-core"]:GetCoreObject()
local QBCore = LS_CORE.Config.FRAMEWORK == "QB" and exports["qb-core"]:GetCoreObject() or exports["es_extended"]:getSharedObject()
local PlayerData = LS_CORE.Functions.GetPlayerData()
local CurrentWeaponData, CanShoot, MultiplierAmount, inAttachment = {}, true, 0, false

-- Handlers

AddEventHandler('LS_CORE:PLAYER:CREATED', function()
    PlayerData = LS_CORE.Functions.GetPlayerData()
    LS_CORE.Callback.Functions.TriggerCallback("weapons:server:GetConfig", function(RepairPoints)
        for k, data in pairs(RepairPoints) do
            Config.WeaponRepairPoints[k].IsRepairing = data.IsRepairing
            Config.WeaponRepairPoints[k].RepairingData = data.RepairingData
        end
    end)
end)

RegisterNetEvent('LS_CORE:PLAYER:PLAYERUNLOAD', function()
    for k in pairs(Config.WeaponRepairPoints) do
        Config.WeaponRepairPoints[k].IsRepairing = false
        Config.WeaponRepairPoints[k].RepairingData = {}
    end
end)


SendNotification = function(text, type)
    if LS_CORE.Config.FRAMEWORK == "QB" then
        QBCore.Functions.Notify(text, type)
    else
        QBCore.ShowNotification(text)
    end
end

-- Functions

local function DrawText3Ds(x, y, z, text)
	SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

-- Events

RegisterNetEvent("weapons:client:SyncRepairShops", function(NewData, key)
    Config.WeaponRepairPoints[key].IsRepairing = NewData.IsRepairing
    Config.WeaponRepairPoints[key].RepairingData = NewData.RepairingData
end)

RegisterNetEvent("addAttachment", function(component, newItem)
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    local WeaponData = Config.Weapons[weapon]
    GiveWeaponComponentToPed(ped, GetHashKey(WeaponData.name), GetHashKey(component))

    if inAttachment then
        CurrentWeaponData = newItem
        updateAttachmentUI()
    end
end)

RegisterNetEvent('weapons:client:EquipTint', function(tint)
    local player = PlayerPedId()
    local weapon = GetSelectedPedWeapon(player)
    SetPedWeaponTintIndex(player, weapon, tint)
end)

RegisterNetEvent('weapons:client:SetCurrentWeapon', function(data, bool)
    if data ~= false then
        CurrentWeaponData = data
    else
        CurrentWeaponData = {}
    end
    CanShoot = bool
end)

RegisterNetEvent('weapons:client:SetWeaponQuality', function(amount)
    if CurrentWeaponData and next(CurrentWeaponData) then
        TriggerServerEvent("weapons:server:SetWeaponQuality", CurrentWeaponData, amount)
    end
end)

RegisterNetEvent('weapons:client:AddAmmo', function(type, amount, itemData)
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    if CurrentWeaponData then
        if Config.Weapons[weapon]["name"] ~= "weapon_unarmed" and Config.Weapons[weapon]["ammotype"] == type:upper() then
            local total = GetAmmoInPedWeapon(ped, weapon)
            local _, maxAmmo = GetMaxAmmo(ped, weapon)
            if total < maxAmmo then
                if LS_CORE.Config.FRAMEWORK == "QB" then
                    QBCore.Functions.Progressbar("taking_bullets", Config.Language['loading_bullets'], Config.ReloadTime, false, true, {
                        disableMovement = false,
                        disableCarMovement = false,
                        disableMouse = false,
                        disableCombat = true,
                    }, {}, {}, {}, function() -- Done
                        if Config.Weapons[weapon] then
                            AddAmmoToPed(ped,weapon,amount)
                            TaskReloadWeapon(ped)
                            TriggerServerEvent("weapons:server:UpdateWeaponAmmo", CurrentWeaponData, total + amount)
                            TriggerServerEvent('weapons:server:removeWeaponAmmoItem', itemData)
                            TriggerEvent('inventory:client:ItemBox', Config.Shared.Items[itemData.name], "remove")
                            SendNotification(Config.Language['reloaded'], "success")
                        end
                    end, function()
                        SendNotification(Config.Language['canceled'], "error")
                    end)
                else
                    QBCore.Progressbar("Loading Bullets", Config.AmmoTime,{
                        FreezePlayer = false, 
                        onFinish = function()
                            if Config.Weapons[weapon] then
                                AddAmmoToPed(ped,weapon,amount)
                                TaskReloadWeapon(ped)
                                TriggerServerEvent("weapons:server:UpdateWeaponAmmo", CurrentWeaponData, total + amount)
                                TriggerServerEvent('weapons:server:removeWeaponAmmoItem', itemData)
                                TriggerEvent('inventory:client:ItemBox', Config.Shared.Items[itemData.name], "remove")
                                SendNotification(Config.Language['reloaded'], "success")
                            end
                    end, onCancel = function()
                        SendNotification(Config.Language['canceled'], "error")
                    end
                    })
                end
            else
                SendNotification(Config.Language['max_ammo'], "error")
            end
        else
            SendNotification(Config.Language['no_weapon'], "error")
        end
    else
        SendNotification(Config.Language['no_weapon'], "error")
    end
end)

RegisterNetEvent("weapons:client:EquipAttachment", function(ItemData, attachment)
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    local WeaponData = Config.Weapons[weapon]
    if weapon ~= `WEAPON_UNARMED` then
        WeaponData.name = WeaponData.name:upper()
        if WeaponAttachments[WeaponData.name] then
            if WeaponAttachments[WeaponData.name][attachment]['item'] == ItemData.name then
                TriggerServerEvent("weapons:server:EquipAttachment", ItemData, CurrentWeaponData, WeaponAttachments[WeaponData.name][attachment])
            else
                SendNotification(Config.Language['no_support_attachment'], "error")
            end
        end
    else
        SendNotification(Config.Language['no_weapon_in_hand'], "error")
    end
end)

-- Threads

CreateThread(function()
    SetWeaponsNoAutoswap(true)
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedArmed(ped, 7) == 1 and (IsControlJustReleased(0, 24) or IsDisabledControlJustReleased(0, 24)) then
            local weapon = GetSelectedPedWeapon(ped)
            local ammo = GetAmmoInPedWeapon(ped, weapon)
            TriggerServerEvent("weapons:server:UpdateWeaponAmmo", CurrentWeaponData, tonumber(ammo))
            if MultiplierAmount > 0 then
                TriggerServerEvent("weapons:server:UpdateWeaponQuality", CurrentWeaponData, MultiplierAmount)
                MultiplierAmount = 0
            end
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            if CurrentWeaponData and next(CurrentWeaponData) then
                if IsPedShooting(ped) or IsControlJustPressed(0, 24) then
                    local weapon = GetSelectedPedWeapon(ped)
                    if CanShoot then
                        if weapon and weapon ~= 0 and Config.Weapons[weapon] then
                            LS_CORE.Callback.Functions.TriggerCallback('prison:server:checkThrowable', function(result)
                                if result or GetAmmoInPedWeapon(ped, weapon) <= 0 then return end
                                MultiplierAmount += 1
                            end, weapon)
                            Wait(200)
                        end
                    else
                        if weapon ~= `WEAPON_UNARMED` then
                            TriggerEvent('inventory:client:CheckWeapon', Config.Weapons[weapon]["name"])
                            SendNotification(Config.Language['weapon_broken'], "error")
                            MultiplierAmount = 0
                        end
                    end
                end
            end
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            local inRange = false
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            for k, data in pairs(Config.WeaponRepairPoints) do
                local distance = #(pos - data.coords)
                if distance < 10 then
                    inRange = true
                    if distance < 1 then
                        if data.IsRepairing then
                            if data.RepairingData.CitizenId ~= PlayerData.citizenid then
                                DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Config.Language['repairshop_not_usable'])
                            else
                                if not data.RepairingData.Ready then
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Config.Language['weapon_will_repair'])
                                else
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Config.Language['take_weapon_back'])
                                end
                            end
                        else
                            if CurrentWeaponData and next(CurrentWeaponData) then
                                if not data.RepairingData.Ready then
                                    local WeaponData = Config.Weapons[GetHashKey(CurrentWeaponData.name)]
                                    local WeaponClass = (SplitStr(WeaponData.ammotype, "_")[2]):lower()
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Config.Language['repair_weapon_price'])
                                    if IsControlJustPressed(0, 38) then
                                        LS_CORE.Callback.Functions.TriggerCallback('weapons:server:RepairWeapon', function(HasMoney)
                                            if HasMoney then
                                                CurrentWeaponData = {}
                                            end
                                        end, k, CurrentWeaponData)
                                    end
                                else
                                    if data.RepairingData.CitizenId ~= PlayerData.citizenid then
                                        DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Config.Language['repairshop_not_usable'])
                                    else
                                        DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Config.Language['take_weapon_back'])
                                        if IsControlJustPressed(0, 38) then
                                            TriggerServerEvent('weapons:server:TakeBackWeapon', k, data)
                                        end
                                    end
                                end
                            else
                                if data.RepairingData.CitizenId == nil then
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Config.Language['no_weapon_in_hand'])
                                elseif data.RepairingData.CitizenId == PlayerData.citizenid then
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Config.Language['take_weapon_back'])
                                    if IsControlJustPressed(0, 38) then
                                        TriggerServerEvent('weapons:server:TakeBackWeapon', k, data)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if not inRange then
                Wait(1000)
            end
        end
        Wait(0)
    end
end)

function SplitStr(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(str, delimiter, from)
    while delim_from do
        result[#result + 1] = string.sub(str, from, delim_from - 1)
        from = delim_to + 1
        delim_from, delim_to = string.find(str, delimiter, from)
    end
    result[#result + 1] = string.sub(str, from)
    return result
end





-- Attachment Screen --  

WeaponObject, CameraObject, weaponItem = nil, nil, nil

CreateThread(function()
    while true do
        local sleep = 1000
            local pos = GetEntityCoords(PlayerPedId())
            local craftObject = GetClosestObjectOfType(pos, 2.0, GetHashKey(Config.AttachmentObject), false, false, false)
            if craftObject ~= 0 and not inAttachment then
                local objectPos = GetEntityCoords(craftObject)
                if #(pos - objectPos) < 1.5 then
                    sleep = 0
                    DrawText3Ds(objectPos.x, objectPos.y, objectPos.z + 1.3, "G - Attachment")
                    if IsControlJustReleased(0, 47) then
                        exports["ls-weapons"]:AttachmentScreen()
                        sleep = 100
                    end
                end
            end
        Wait(sleep)
    end
end)

OpenAttachmentScreen = function()
    if not CurrentWeaponData or not CurrentWeaponData.name then return SendNotification(Config.Language["no_weapon"], "error") end
    SendNUIMessage({
        action = "open",
    })
    SetNuiFocus(true, true)
    inAttachment = true

    local ped = PlayerPedId()

    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    RemoveAllPedWeapons(ped, true)

    CreateThread(function()
        setupAttachmentUI()
    end)
end

updateAttachmentUI = function()

    Wait(100)

    local weaponAttachment = {}
    for k,v in pairs(Config.WeaponBones) do
        local bi = GetEntityBoneIndexByName(WeaponObject, k)
        if bi ~= -1 then
            local cord = GetWorldPositionOfEntityBone(WeaponObject, bi)
            local _, xx, yy = GetScreenCoordFromWorldCoord(cord[1], cord[2], cord[3])
            
            xx = xx * 100
            yy = yy * 100

            weaponAttachment[k] = { x = xx, y = yy, label = v.label, attach_component = v.attach_component, slot = v.slot, display = true } 
        else
            weaponAttachment[k] = { attach_component = v.attach_component, display = false } 
        end 
    end

    for _, attachment in pairs(CurrentWeaponData.info.attachments) do
        local model = GetWeaponComponentTypeModel(attachment.component)
        RequestModel(model)
        while not HasModelLoaded(model) do Citizen.Wait(10) end
    
        GiveWeaponComponentToWeaponObject(WeaponObject, GetHashKey(attachment.component))
    end

    SendNUIMessage({
        action = "update",
        attachments = weaponAttachment,
        items = LS_CORE.Functions.GetPlayerData().items,
        attachmentItems = WeaponAttachments[weaponItem:upper()],
        weaponData = CurrentWeaponData
    })
end

setupAttachmentUI = function()
    local craftObject = GetClosestObjectOfType(GetEntityCoords(PlayerPedId()), 2.0, GetHashKey(Config.AttachmentObject), false, false, false)
        
    local objectPos = GetEntityCoords(craftObject)
    weaponItem = CurrentWeaponData.name
    local weaponHashKey = GetHashKey(weaponItem)

    RequestWeaponAsset(weaponHashKey, 31, 0)
    while not HasWeaponAssetLoaded(weaponHashKey) do Citizen.Wait(10) end

    WeaponObject = CreateWeaponObject(weaponHashKey,  120, objectPos.x, objectPos.y, objectPos.z+1.05 , true, 1.0, 0)
    SetEntityRotation(WeaponObject, 90.0, 0.0, GetEntityHeading(craftObject)-180, false, true)

    SetEntityHeading(GetEntityHeading(craftObject))
    FreezeEntityPosition(WeaponObject, true)

    CameraObject = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", objectPos.x, objectPos.y, objectPos.z+1.7, 270.0 , 0.0, GetEntityHeading(craftObject), 60.00, false, 0)
    --PointCamAtEntity(CameraObject, WeaponObject, 0,0,0, true)

    SetCamActive(CameraObject, true)
    RenderScriptCams(CameraObject, false, 1, true, true)

    ClearPedTasksImmediately(PlayerPedId())

    SetEntityHeading(PlayerPedId(), GetEntityHeading(craftObject))

    Wait(100)

    local weaponAttachment = {}
    for k,v in pairs(Config.WeaponBones) do
        local bi = GetEntityBoneIndexByName(WeaponObject, k)
        if bi ~= -1 then
            local cord = GetWorldPositionOfEntityBone(WeaponObject, bi)
            local _, xx, yy = GetScreenCoordFromWorldCoord(cord[1], cord[2], cord[3])
            
            xx = xx * 100
            yy = yy * 100

            weaponAttachment[k] = { x = xx, y = yy, label = v.label, attach_component = v.attach_component, slot = v.slot, display = true } 
        else
            weaponAttachment[k] = { attach_component = v.attach_component, display = false } 
        end 
    end

    if CurrentWeaponData.info.attachments then
        for _, attachment in pairs(CurrentWeaponData.info.attachments) do
            local model = GetWeaponComponentTypeModel(attachment.component)
            RequestModel(model)
            while not HasModelLoaded(model) do Citizen.Wait(10) end
        
            GiveWeaponComponentToWeaponObject(WeaponObject, GetHashKey(attachment.component))
        end
    end

    SendNUIMessage({
        action = "updateWeaponAttachmentMenu",
        attachments = weaponAttachment,
        items = LS_CORE.Functions.GetPlayerData().items,
        attachmentItems = WeaponAttachments[weaponItem:upper()],
        weaponData = CurrentWeaponData
    })
end

exports("AttachmentScreen", OpenAttachmentScreen)
exports("isInAttachmentScreen", function() return inAttachment end)

RegisterNuiCallback("closeAttachment", function(data, cb)
    inAttachment = false
    SetNuiFocus(false, false)

    local ped = PlayerPedId()

    local weaponName = tostring(CurrentWeaponData.name)
    local weaponHash = joaat(CurrentWeaponData.name)
    local ammo = tonumber(CurrentWeaponData.info.ammo) or 0

    if weaponName == "weapon_petrolcan" or weaponName == "weapon_fireextinguisher" then ammo = 4000 end

    GiveWeaponToPed(ped, weaponHash, ammo, false, false)
    SetPedAmmo(ped, weaponHash, ammo)
    SetCurrentPedWeapon(ped, weaponHash, true)

    if CurrentWeaponData.info.attachments then
        for _, attachment in pairs(CurrentWeaponData.info.attachments) do
            GiveWeaponComponentToPed(ped, weaponHash, joaat(attachment.component))
        end
    end

    CloseAttachment()
end)

LoadAnim = function(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(10)
    end
end

RegisterNuiCallback("attachAttachment", function(data, cb)
    local animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
    local animName = "machinic_loop_mechandplayer"

    LoadAnim(animDict)

    TaskPlayAnim(PlayerPedId(), animDict, animName, 2.0, 2.0, 2000, 16, 0, false, false, false)

    Wait(2000)
    local attachTo = WeaponAttachments[weaponItem:upper()][data.item.attachableto] ~= nil and data.item.attachableto or data.item.attachmenttype
    if WeaponAttachments[weaponItem:upper()][attachTo] == nil then attachTo = FindClipAttachment(data.item.name) end

    local result = WeaponAttachments[weaponItem:upper()][attachTo].component

    local model = GetWeaponComponentTypeModel(result)
    RequestModel(model)
    while not HasModelLoaded(model) do Citizen.Wait(10) end

    GiveWeaponComponentToWeaponObject(WeaponObject, GetHashKey(result))

    SetModelAsNoLongerNeeded(model)

    TriggerServerEvent("weapons:server:EquipAttachment", data.item, CurrentWeaponData, WeaponAttachments[CurrentWeaponData.name:upper()][FindAttachment(data.item)])

end)

FindAttachment = function(iteminfo)
    for k,v in pairs(WeaponAttachments[CurrentWeaponData.name:upper()]) do
        if (v.item == iteminfo.name) then
            return k
        end
    end
end

FindClipAttachment = function (itemname)
    for k,v in pairs(WeaponAttachments[weaponItem:upper()]) do
        if (v.item == itemname) then
            return tostring(k)
        end
    end
end

RegisterNuiCallback("removeAttachment", function(data, cb)
    local animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
    local animName = "machinic_loop_mechandplayer"

    LoadAnim(animDict)

    TaskPlayAnim(PlayerPedId(), animDict, animName, 2.0, 2.0, 2000, 16, 0, false, false, false)

    Wait(2000)

    local attachTo = WeaponAttachments[weaponItem:upper()][data.item.attachableto] ~= nil and data.item.attachableto or data.item.attachmenttype
    if WeaponAttachments[weaponItem:upper()][attachTo] == nil then attachTo = FindClipAttachment(data.item.item) end

    local result = WeaponAttachments[weaponItem:upper()][attachTo].component

    if ( result.type and result.type == "clip" ) then
        result = WeaponAttachments[weaponItem:upper()]["defaultclip"].component
    end

    local model = GetWeaponComponentTypeModel(result)
    RequestModel(model)
    while not HasModelLoaded(model) do Citizen.Wait(10) end

    RemoveWeaponComponentFromWeaponObject(WeaponObject, GetHashKey(result))

    SetModelAsNoLongerNeeded(model)

    
    --  function(source, cb, AttachmentData, ItemData)
    local item = data.item
    item.attachment = item.attachableto
    LS_CORE.Callback.Functions.TriggerCallback("weapons:server:RemoveAttachment", function(RemoveResult)
        
        if RemoveResult then
            CurrentWeaponData = RemoveResult
            Wait( 100 )

            RemoveWeaponComponentFromPed(PlayerPedId(), GetHashKey(CurrentWeaponData.name), GetHashKey(result))

            updateAttachmentUI()
        end
    end, item, CurrentWeaponData)

    
end)

CloseAttachment = function()
    DeleteObject(WeaponObject)
    SetCamActive(CameraObject, false)
    DestroyCam(CameraObject, true)
    RenderScriptCams(false, false, 1, true, true)
end

AddEventHandler('onResourceStop', function(resourceName)
    CloseAttachment()
end)