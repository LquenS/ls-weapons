local LS_CORE = exports["ls-core"]:GetCoreObject()
local QBCore = LS_CORE.Config.FRAMEWORK == "QB" and exports["qb-core"]:GetCoreObject() or exports["es_extended"]:getSharedObject()

-- Functions

local function IsWeaponBlocked(WeaponName)
    local retval = false
    for _, name in pairs(Config.DurabilityBlockedWeapons) do
        if name == WeaponName then
            retval = true
            break
        end
    end
    return retval
end

local function HasAttachment(component, attachments)
    local retval = false
    local key = nil
    for k, v in pairs(attachments) do
        if v.component == component then
            key = k
            retval = true
        end
    end
    return retval, key
end

local function GetAttachmentType(attachments)
    local attype = nil
    for _, v in pairs(attachments) do
        attype = v.type
    end
    return attype
end

-- Callback

LS_CORE.Callback.Functions.CreateCallback("weapons:server:GetConfig", function(_, cb)
    cb(Config.WeaponRepairPoints)
end)

LS_CORE.Callback.Functions.CreateCallback("weapon:server:GetWeaponAmmo", function(source, cb, WeaponData)
    local Player = LS_CORE.Functions.GetPlayer(source)
    local retval = 0
    if WeaponData then
        if Player then
            local ItemData = Player.Functions.GetItemBySlot(WeaponData.slot)
            if ItemData then
                retval = ItemData.info.ammo and ItemData.info.ammo or 0
            end
        end
    end
    cb(retval, WeaponData.name)
end)

FindClipAttachment = function (weaponname, itemname)
    for k,v in pairs(WeaponAttachments[weaponname]) do
        if (v.item == itemname) then
            return tostring(k)
        end
    end
end

LS_CORE.Callback.Functions.CreateCallback('weapons:server:RemoveAttachment', function(source, cb, AttachmentData, ItemData)
    local src = source
    local Player = LS_CORE.Functions.GetPlayer(src)
    local Inventory = Player.DATA.items
    local AttachmentComponent = WeaponAttachments[ItemData.name:upper()][AttachmentData.attachment] ~= nil and WeaponAttachments[ItemData.name:upper()][AttachmentData.attachment] or WeaponAttachments[ItemData.name:upper()][FindClipAttachment(ItemData.name:upper(), AttachmentData.item)]
    if Inventory[ItemData.slot] then
        if Inventory[ItemData.slot].info.attachments and next(Inventory[ItemData.slot].info.attachments) then
            local HasAttach, key = HasAttachment(AttachmentComponent.component, Inventory[ItemData.slot].info.attachments)
            if HasAttach then
                table.remove(Inventory[ItemData.slot].info.attachments, key)
                Player.Functions.SetPlayerData(Player.DATA)
                Player.Functions.AddItem(AttachmentComponent.item, 1)
                TriggerClientEvent('inventory:client:ItemBox', src, Config.Shared.Items[AttachmentComponent.item], "add")
                cb(Inventory[ItemData.slot])
            else
                cb(false)
            end
        else
            cb(false)
        end
    else
        cb(false)
    end
end)

LS_CORE.Callback.Functions.CreateCallback("weapons:server:RepairWeapon", function(source, cb, RepairPoint, data)
    local src = source
    local Player = LS_CORE.Functions.GetPlayer(src)
    local minute = 60 * 1000
    local Timeout = math.random(5 * minute, 10 * minute)
    local WeaponData = Config.Weapons[GetHashKey(data.name)]
    local WeaponClass = (Config.Shared.SplitStr(WeaponData.ammotype, "_")[2]):lower()

    if Player.DATA.items[data.slot] then
        if Player.DATA.items[data.slot].info.quality then
            if Player.DATA.items[data.slot].info.quality ~= 100 then
                if Player.Functions.RemoveMoney('cash', Config.WeaponRepairCosts[WeaponClass]) then
                    Config.WeaponRepairPoints[RepairPoint].IsRepairing = true
                    Config.WeaponRepairPoints[RepairPoint].RepairingData = {
                        CitizenId = Player.PlayerData.citizenid,
                        WeaponData = Player.DATA.items[data.slot],
                        Ready = false,
                    }
                    if not Player.Functions.RemoveItem(data.name, 1, data.slot) then
                        return Player.Functions.AddMoney('cash', Config.WeaponRepairCosts[WeaponClass])
                    end
                    TriggerClientEvent('inventory:client:ItemBox', src, Config.Shared.Items[data.name], "remove")
                    TriggerClientEvent("inventory:client:CheckWeapon", src, data.name)
                    TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)

                    SetTimeout(Timeout, function()
                        Config.WeaponRepairPoints[RepairPoint].IsRepairing = false
                        Config.WeaponRepairPoints[RepairPoint].RepairingData.Ready = true
                        TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)
                        SetTimeout(7 * 60000, function()
                            if Config.WeaponRepairPoints[RepairPoint].RepairingData.Ready then
                                Config.WeaponRepairPoints[RepairPoint].IsRepairing = false
                                Config.WeaponRepairPoints[RepairPoint].RepairingData = {}
                                TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)
                            end
                        end)
                    end)
                    cb(true)
                else
                    cb(false)
                end
            else
                TriggerClientEvent("QBCore:Notify", src, Config.Language['error.no_damage_on_weapon'], "error")
                cb(false)
            end
        else
            TriggerClientEvent("QBCore:Notify", src, Config.Language['error.no_damage_on_weapon'], "error")
            cb(false)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Config.Language['error.no_weapon_in_hand'], "error")
        TriggerClientEvent('weapons:client:SetCurrentWeapon', src, {}, false)
        cb(false)
    end
end)

LS_CORE.Callback.Functions.CreateCallback('prison:server:checkThrowable', function(source, cb, weapon)
    local Player = LS_CORE.Functions.GetPlayer(source)

    if not Player then return cb(false) end
    local throwable = false
    for _,v in pairs(Config.Throwables) do
        if Config.Weapons[weapon].name == 'weapon_'..v then
            if not Player.Functions.RemoveItem('weapon_'..v, 1) then return cb(false) end
            throwable = true
            break
        end
    end
    cb(throwable)
end)

-- Events

RegisterNetEvent("weapons:server:UpdateWeaponAmmo", function(CurrentWeaponData, amount)
    local src = source
    local Player = LS_CORE.Functions.GetPlayer(src)
    amount = tonumber(amount)
    if CurrentWeaponData then
        if Player.DATA.items[CurrentWeaponData.slot] then
            Player.DATA.items[CurrentWeaponData.slot].info.ammo = amount
        end
        Player.Functions.SetPlayerData(Player.DATA)
    end
end)

RegisterNetEvent("weapons:server:TakeBackWeapon", function(k)
    local src = source
    local Player = LS_CORE.Functions.GetPlayer(src)
    if not Player then return end
    local itemdata = Config.WeaponRepairPoints[k].RepairingData.WeaponData
    itemdata.info.quality = 100
    Player.Functions.AddItem(itemdata.name, 1, false, itemdata.info)
    TriggerClientEvent('inventory:client:ItemBox', src, Config.Shared.Items[itemdata.name], "add")
    Config.WeaponRepairPoints[k].IsRepairing = false
    Config.WeaponRepairPoints[k].RepairingData = {}
    TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[k], k)
end)

RegisterNetEvent("weapons:server:SetWeaponQuality", function(data, hp)
    local src = source
    local Player = LS_CORE.Functions.GetPlayer(src)
    if not Player then return end
    local WeaponSlot = Player.DATA.items[data.slot]
    WeaponSlot.info.quality = hp
    Player.Functions.SetPlayerData(Player.DATA)
end)

RegisterNetEvent('weapons:server:UpdateWeaponQuality', function(data, RepeatAmount)
    local src = source
    local Player = LS_CORE.Functions.GetPlayer(src)
    local WeaponData = Config.Weapons[GetHashKey(data.name)]
    local WeaponSlot = Player.DATA.items[data.slot]
    local DecreaseAmount = Config.DurabilityMultiplier[data.name]
    if WeaponSlot then
        if not IsWeaponBlocked(WeaponData.name) then
            if WeaponSlot.info.quality then
                for _ = 1, RepeatAmount, 1 do
                    if WeaponSlot.info.quality - DecreaseAmount > 0 then
                        WeaponSlot.info.quality = WeaponSlot.info.quality - DecreaseAmount
                    else
                        WeaponSlot.info.quality = 0
                        TriggerClientEvent('inventory:client:UseWeapon', src, data, false)
                        TriggerClientEvent('QBCore:Notify', src, Config.Language['error.weapon_broken_need_repair'], "error")
                        break
                    end
                end
            else
                WeaponSlot.info.quality = 100
                for _ = 1, RepeatAmount, 1 do
                    if WeaponSlot.info.quality - DecreaseAmount > 0 then
                        WeaponSlot.info.quality = WeaponSlot.info.quality - DecreaseAmount
                    else
                        WeaponSlot.info.quality = 0
                        TriggerClientEvent('inventory:client:UseWeapon', src, data, false)
                        TriggerClientEvent('QBCore:Notify', src, Config.Language['error.weapon_broken_need_repair'], "error")
                        break
                    end
                end
            end
        end
    end
    Player.Functions.SetPlayerData(Player.DATA)
end)

RegisterNetEvent("weapons:server:EquipAttachment", function(ItemData, CurrentWeaponData, AttachmentData)
    local src = source
    local Player = LS_CORE.Functions.GetPlayer(src)
    local Inventory = Player.DATA.items
    local GiveBackItem = nil
    if Inventory[CurrentWeaponData.slot] then
        if Inventory[CurrentWeaponData.slot].info.attachments and next(Inventory[CurrentWeaponData.slot].info.attachments) then
            local currenttype = GetAttachmentType(Inventory[CurrentWeaponData.slot].info.attachments)
            local HasAttach, key = HasAttachment(AttachmentData.component, Inventory[CurrentWeaponData.slot].info.attachments)
            if not HasAttach then
                if AttachmentData.type ~=nil and currenttype == AttachmentData.type then
                    for _, v in pairs(Inventory[CurrentWeaponData.slot].info.attachments) do
                        if v.type and v.type == currenttype then
                            GiveBackItem = tostring(v.item):lower()
                            table.remove(Inventory[CurrentWeaponData.slot].info.attachments, key)
                            TriggerClientEvent('inventory:client:ItemBox', src, Config.Shared.Items[GiveBackItem], "add")
                        end
                    end
                end
                Inventory[CurrentWeaponData.slot].info.attachments[#Inventory[CurrentWeaponData.slot].info.attachments+1] = {
                    component = AttachmentData.component,
                    label = Config.Shared.Items[AttachmentData.item].label,
                    item = AttachmentData.item,
                    type = AttachmentData.type,
                    image = Config.Shared.Items[AttachmentData.item].image,
                }
                TriggerClientEvent("addAttachment", src, AttachmentData.component, Inventory[CurrentWeaponData.slot])
                Player.Functions.SetPlayerData(Player.DATA)
                Player.Functions.RemoveItem(ItemData.name, 1)
                SetTimeout(1000, function()
                    TriggerClientEvent('inventory:client:ItemBox', src, ItemData, "remove")
                end)
            else
                TriggerClientEvent("QBCore:Notify", src, Config.Language['error.attachment_already_on_weapon'], "error", 3500)
            end
        else
            Inventory[CurrentWeaponData.slot].info.attachments = {}
            Inventory[CurrentWeaponData.slot].info.attachments[#Inventory[CurrentWeaponData.slot].info.attachments+1] = {
                component = AttachmentData.component,
                label = Config.Shared.Items[AttachmentData.item].label,
                item = AttachmentData.item,
                type = AttachmentData.type,
                image = Config.Shared.Items[AttachmentData.item].image,
            }
            TriggerClientEvent("addAttachment", src, AttachmentData.component,  Inventory[CurrentWeaponData.slot])
            Player.Functions.SetPlayerData(Player.DATA)
            Player.Functions.RemoveItem(ItemData.name, 1)
            SetTimeout(1000, function()
                TriggerClientEvent('inventory:client:ItemBox', src, ItemData, "remove")
            end)
        end
    end
    if GiveBackItem then
        Player.Functions.AddItem(GiveBackItem, 1, false)
    end
end)

RegisterNetEvent('weapons:server:removeWeaponAmmoItem', function(item)
    local Player = LS_CORE.Functions.GetPlayer(source)
    if Player == nil then return end
    
    if not Player or type(item) ~= 'table' or not item.name or not item.slot then return Player.Functions.RemoveItem(item, 1) end

    Player.Functions.RemoveItem(item.name, 1, item.slot)
end)

if LS_CORE.Config.FRAMEWORK == "QB" then
-- Commands
QBCore.Commands.Add("repairweapon", "Repair Weapon (God Only)", {{name="hp", help=Config.Language['info.hp_of_weapon']}}, true, function(source, args)
    TriggerClientEvent('weapons:client:SetWeaponQuality', source, tonumber(args[1]))
end, "god")

-- Items

-- AMMO
QBCore.Functions.CreateUseableItem('pistol_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_PISTOL', 12, item)
end)

QBCore.Functions.CreateUseableItem('rifle_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_RIFLE', 30, item)
end)

QBCore.Functions.CreateUseableItem('smg_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_SMG', 20, item)
end)

QBCore.Functions.CreateUseableItem('shotgun_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_SHOTGUN', 10, item)
end)

QBCore.Functions.CreateUseableItem('mg_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_MG', 30, item)
end)

QBCore.Functions.CreateUseableItem('snp_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_SNIPER', 10, item)
end)

QBCore.Functions.CreateUseableItem('emp_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_EMPLAUNCHER', 10, item)
end)

-- TINTS
QBCore.Functions.CreateUseableItem('weapontint_black', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 0)
end)

QBCore.Functions.CreateUseableItem('weapontint_green', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 1)
end)

QBCore.Functions.CreateUseableItem('weapontint_gold', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 2)
end)

QBCore.Functions.CreateUseableItem('weapontint_pink', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 3)
end)

QBCore.Functions.CreateUseableItem('weapontint_army', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 4)
end)

QBCore.Functions.CreateUseableItem('weapontint_lspd', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 5)
end)

QBCore.Functions.CreateUseableItem('weapontint_orange', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 6)
end)

QBCore.Functions.CreateUseableItem('weapontint_plat', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 7)
end)

-- ATTACHMENTS
QBCore.Functions.CreateUseableItem('pistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('pistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('pistol_flashlight', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'flashlight')
end)

QBCore.Functions.CreateUseableItem('pistol_suppressor', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'suppressor')
end)

QBCore.Functions.CreateUseableItem('pistol_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('combatpistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('combatpistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('combatpistol_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('appistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('appistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('appistol_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('pistol50_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('pistol50_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('pistol50_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('heavypistol_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('revolver_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('doubleaction_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('revolver_vipvariant', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'vipvariant')
end)

QBCore.Functions.CreateUseableItem('revolver_bodyguardvariant', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'bodyguardvariant')
end)

QBCore.Functions.CreateUseableItem('snspistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('snspistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('snspistol_grip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'grip')
end)

QBCore.Functions.CreateUseableItem('heavypistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('heavypistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('heavypistol_grip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'grip')
end)

QBCore.Functions.CreateUseableItem('vintagepistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('vintagepistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('combatpistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('microsmg_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('microsmg_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.Functions.CreateUseableItem('microsmg_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('smg_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('smg_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('smg_suppressor', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'suppressor')
end)

QBCore.Functions.CreateUseableItem('smg_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.Functions.CreateUseableItem('smg_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.Functions.CreateUseableItem('smg_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('assaultsmg_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('assaultsmg_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('pumpshotgun_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('sawnoffshotgun_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('assaultsmg_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('minismg_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('minismg_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('machinepistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('machinepistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('machinepistol_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.Functions.CreateUseableItem('combatpdw_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('combatpdw_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('combatpistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('emplauncher_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('combatpdw_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.Functions.CreateUseableItem('combatpdw_grip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'grip')
end)

QBCore.Functions.CreateUseableItem('combatpdw_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.Functions.CreateUseableItem('shotgun_suppressor', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'suppressor')
end)

QBCore.Functions.CreateUseableItem('pumpshotgun_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('sawnoffshotgun_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('sniper_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('assaultshotgun_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('assaultshotgun_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('heavyshotgun_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('heavyshotgun_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('heavyshotgun_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.Functions.CreateUseableItem('assaultrifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('assaultrifle_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('assaultrifle_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.Functions.CreateUseableItem('rifle_flashlight', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'flashlight')
end)

QBCore.Functions.CreateUseableItem('rifle_grip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'grip')
end)

QBCore.Functions.CreateUseableItem('rifle_suppressor', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'suppressor')
end)

QBCore.Functions.CreateUseableItem('sniperrifle_suppressor', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'suppressor')
end)

QBCore.Functions.CreateUseableItem('assaultrifle_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('carbinerifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('carbinerifle_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('carbinerifle_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.Functions.CreateUseableItem('combatpdw_grip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'grip')
end)

QBCore.Functions.CreateUseableItem('carbinerifle_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.Functions.CreateUseableItem('carbinerifle_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('advancedrifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('advancedrifle_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('advancedrifle_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('specialcarbine_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('specialcarbine_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('bullpupshotgun_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('specialcarbine_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.Functions.CreateUseableItem('specialcarbine_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('bullpuprifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('bullpuprifle_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('bullpuprifle_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('compactrifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('compactrifle_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('compactrifle_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.Functions.CreateUseableItem('gusenberg_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('gusenberg_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('microsmg_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('microsmg_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('sniperrifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('sniper_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.Functions.CreateUseableItem('snipermax_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.Functions.CreateUseableItem('sniper_grip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'grip')
end)

QBCore.Functions.CreateUseableItem('heavysniper_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('heavysniper_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('marksmanrifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.Functions.CreateUseableItem('marksmanrifle_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.Functions.CreateUseableItem('marksmanrifle_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.Functions.CreateUseableItem('marksmanrifle_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.Functions.CreateUseableItem('snspistol_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

else
-- Commands
QBCore.RegisterCommand('repairweapon', 'admin', function(Player, args, showError)
    TriggerClientEvent('weapons:client:SetWeaponQuality', Player.source, tonumber(args.hp))
end, true, {
	help = Config.Language['info.hp_of_weapon'],
	validate = true,
	arguments = {
		{ name = 'hp',    help = "HP",    type = 'number' }
	}
})

-- Items

-- AMMO
QBCore.RegisterUsableItem('pistol_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_PISTOL', 12, item)
end)

QBCore.RegisterUsableItem('rifle_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_RIFLE', 30, item)
end)

QBCore.RegisterUsableItem('smg_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_SMG', 20, item)
end)

QBCore.RegisterUsableItem('shotgun_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_SHOTGUN', 10, item)
end)

QBCore.RegisterUsableItem('mg_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_MG', 30, item)
end)

QBCore.RegisterUsableItem('snp_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_SNIPER', 10, item)
end)

QBCore.RegisterUsableItem('emp_ammo', function(source, item)
    TriggerClientEvent('weapons:client:AddAmmo', source, 'AMMO_EMPLAUNCHER', 10, item)
end)

-- TINTS
QBCore.RegisterUsableItem('weapontint_black', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 0)
end)

QBCore.RegisterUsableItem('weapontint_green', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 1)
end)

QBCore.RegisterUsableItem('weapontint_gold', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 2)
end)

QBCore.RegisterUsableItem('weapontint_pink', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 3)
end)

QBCore.RegisterUsableItem('weapontint_army', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 4)
end)

QBCore.RegisterUsableItem('weapontint_lspd', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 5)
end)

QBCore.RegisterUsableItem('weapontint_orange', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 6)
end)

QBCore.RegisterUsableItem('weapontint_plat', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 7)
end)

-- ATTACHMENTS
QBCore.RegisterUsableItem('pistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('pistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('pistol_flashlight', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'flashlight')
end)

QBCore.RegisterUsableItem('pistol_suppressor', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'suppressor')
end)

QBCore.RegisterUsableItem('pistol_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('combatpistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('combatpistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('combatpistol_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('appistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('appistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('appistol_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('pistol50_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('pistol50_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('pistol50_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('heavypistol_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('revolver_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('doubleaction_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('revolver_vipvariant', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'vipvariant')
end)

QBCore.RegisterUsableItem('revolver_bodyguardvariant', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'bodyguardvariant')
end)

QBCore.RegisterUsableItem('snspistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('snspistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('snspistol_grip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'grip')
end)

QBCore.RegisterUsableItem('heavypistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('heavypistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('heavypistol_grip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'grip')
end)

QBCore.RegisterUsableItem('vintagepistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('vintagepistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('combatpistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('microsmg_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('microsmg_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.RegisterUsableItem('microsmg_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('smg_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('smg_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('smg_suppressor', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'suppressor')
end)

QBCore.RegisterUsableItem('smg_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.RegisterUsableItem('smg_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.RegisterUsableItem('smg_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('assaultsmg_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('assaultsmg_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('pumpshotgun_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('sawnoffshotgun_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('assaultsmg_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('minismg_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('minismg_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('machinepistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('machinepistol_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('machinepistol_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.RegisterUsableItem('combatpdw_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('combatpdw_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('combatpistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('emplauncher_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('combatpdw_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.RegisterUsableItem('combatpdw_grip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'grip')
end)

QBCore.RegisterUsableItem('combatpdw_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.RegisterUsableItem('shotgun_suppressor', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'suppressor')
end)

QBCore.RegisterUsableItem('pumpshotgun_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('sawnoffshotgun_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('sniper_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('assaultshotgun_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('assaultshotgun_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('heavyshotgun_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('heavyshotgun_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('heavyshotgun_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.RegisterUsableItem('assaultrifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('assaultrifle_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('assaultrifle_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.RegisterUsableItem('rifle_flashlight', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'flashlight')
end)

QBCore.RegisterUsableItem('rifle_grip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'grip')
end)

QBCore.RegisterUsableItem('rifle_suppressor', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'suppressor')
end)

QBCore.RegisterUsableItem('sniperrifle_suppressor', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'suppressor')
end)

QBCore.RegisterUsableItem('assaultrifle_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('carbinerifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('carbinerifle_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('carbinerifle_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.RegisterUsableItem('combatpdw_grip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'grip')
end)

QBCore.RegisterUsableItem('carbinerifle_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.RegisterUsableItem('carbinerifle_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('advancedrifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('advancedrifle_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('advancedrifle_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('specialcarbine_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('specialcarbine_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('bullpupshotgun_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('specialcarbine_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.RegisterUsableItem('specialcarbine_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('bullpuprifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('bullpuprifle_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('bullpuprifle_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('compactrifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('compactrifle_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('compactrifle_drum', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'drum')
end)

QBCore.RegisterUsableItem('gusenberg_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('gusenberg_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('microsmg_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('microsmg_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('sniperrifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('sniper_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.RegisterUsableItem('snipermax_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.RegisterUsableItem('sniper_grip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'grip')
end)

QBCore.RegisterUsableItem('heavysniper_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('heavysniper_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('marksmanrifle_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)

QBCore.RegisterUsableItem('marksmanrifle_extendedclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'extendedclip')
end)

QBCore.RegisterUsableItem('marksmanrifle_scope', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'scope')
end)

QBCore.RegisterUsableItem('marksmanrifle_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)

QBCore.RegisterUsableItem('snspistol_luxuryfinish', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'luxuryfinish')
end)
end