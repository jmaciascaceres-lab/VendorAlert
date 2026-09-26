-- VendorAlert: núcleo
-- Alerta sonora al ver un vendedor conocido con las bolsas casi llenas o el equipo dañado,
-- vende objetos grises, repara automáticamente y avisa de durabilidad baja.
local ADDON_NAME, ns = ...
ns.onLoad = {} -- funciones de otros módulos que se ejecutan al cargar los datos
local L = ns.L  -- textos traducidos (Locales.lua)
local f = CreateFrame("Frame")
local DB

local DEFAULTS = {
    threshold     = 0.80,  -- % de bolsas llenas para la alerta
    cooldown      = 60,    -- segundos antes de repetir aviso para el mismo vendedor
    sound         = true,
    autoSell      = true,  -- vender grises al abrir un vendedor
    autoRepair    = true,  -- reparar al abrir un vendedor que repare
    durThreshold  = 0.30,  -- avisar si algún objeto baja de este % de durabilidad
    customSound   = true,  -- usar Sounds\alerta.mp3 (o alert.mp3, .ogg) si existe
    lang          = "auto", -- "auto" (según el cliente), "en" o "es"
    minimap       = { angle = 200, hide = false },
    window        = { shown = false, minimized = false, tab = "notes" },
    vendors       = {},    -- [npcId] = { name = "...", repair = true/false }
}

local lastAlert, lastByNpc, lastScan = 0, {}, 0
local durWarned = false
local merchantOpen = false

local function Print(s) print("|cffffd100VendorAlert:|r " .. s) end

local CoinString = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString)
    or GetCoinTextureString or GetMoneyString

local function Money(copper)
    copper = math.floor(copper or 0)
    if CoinString then return CoinString(copper) end
    return string.format("%dg %ds %dc", copper / 10000, (copper / 100) % 100, copper % 100)
end

local SOUND_DIR = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Sounds\\"

-- Reproduce el sonido personalizado si existe; si no, el aviso de banda del juego
local function PlayAlert()
    if not DB.sound then return end
    if DB.customSound and PlaySoundFile then
        for _, file in ipairs({ "alerta.mp3", "alerta.ogg", "alert.mp3", "alert.ogg" }) do
            if PlaySoundFile(SOUND_DIR .. file, "Master") then return end
        end
    end
    PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
end

local function Pct(x) return math.floor(x * 100 + 0.5) end

----------------------------------------------------------------------
-- Compatibilidad de API (C_Container nuevo o funciones antiguas)
----------------------------------------------------------------------
local function NumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    return GetContainerNumSlots(bag)
end

local function FreeSlots(bag)
    if C_Container and C_Container.GetContainerNumFreeSlots then
        return C_Container.GetContainerNumFreeSlots(bag)
    end
    return GetContainerNumFreeSlots(bag)
end

-- Devuelve link, cantidad, sinValor
local function ItemInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then return info.hyperlink, info.stackCount, info.hasNoValue end
        return
    end
    local _, count, _, _, _, _, link, _, noValue = GetContainerItemInfo(bag, slot)
    return link, count, noValue
end

-- GetItemInfo global ya no existe en clientes nuevos: usar C_Item si está disponible
local GetItemInfoCompat = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-- Devuelve calidad y precio de venta unitario de un objeto
local function ItemQualityPrice(link)
    if not GetItemInfoCompat then return end
    local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfoCompat(link)
    return quality, price
end

local function UseItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(bag, slot)
    else
        UseContainerItem(bag, slot)
    end
end

----------------------------------------------------------------------
-- Bolsas y durabilidad
----------------------------------------------------------------------
-- Porcentaje de llenado (ignora carcajes, bolsas de munición y de almas)
local function BagFill()
    local total, free = 0, 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = NumSlots(bag) or 0
        if slots > 0 then
            local nFree, bagType = FreeSlots(bag)
            if (bagType or 0) == 0 then
                total = total + slots
                free  = free + (nFree or 0)
            end
        end
    end
    if total == 0 then return 0, 0, 0 end
    return (total - free) / total, total - free, total
end

-- Durabilidad más baja del equipo puesto (1 = perfecto)
local function LowestDurability()
    local lowest = 1
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            lowest = math.min(lowest, cur / max)
        end
    end
    return lowest
end

-- Utilidades compartidas con los otros módulos
ns.Print, ns.Money, ns.Pct = Print, Money, Pct
ns.BagFill, ns.LowestDurability = BagFill, LowestDurability

----------------------------------------------------------------------
-- Vendedores conocidos
----------------------------------------------------------------------
local function NpcId(unit)
    local guid = UnitGUID(unit)
    if not guid then return end
    local unitType, _, _, _, _, id = strsplit("-", guid)
    if unitType == "Creature" then return tonumber(id) end
end

-- Migra datos de la versión 1.0 (vendors[id] = "nombre")
local function MigrateVendors()
    for id, v in pairs(DB.vendors) do
        if type(v) == "string" then DB.vendors[id] = { name = v, repair = false } end
    end
end

----------------------------------------------------------------------
-- Alerta de proximidad
----------------------------------------------------------------------
local function Alert(name, reasons)
    local msg = L.VENDOR_NEAR:format(name) .. " " .. table.concat(reasons, ", ")
    PlayAlert()
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
    end
    Print(msg)
end

local function CheckUnit(unit)
    if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local id = NpcId(unit)
    local vendor = id and DB.vendors[id]
    if not vendor then return end

    local reasons = {}
    local fill = BagFill()
    if fill >= DB.threshold then
        table.insert(reasons, L.REASON_BAGS:format(Pct(fill)))
    end
    local dur = LowestDurability()
    if vendor.repair and dur < DB.durThreshold then
        table.insert(reasons, L.REASON_DUR:format(Pct(dur)))
    end
    if #reasons == 0 then return end

    local now = GetTime()
    if now - lastAlert < 10 then return end
    if lastByNpc[id] and now - lastByNpc[id] < DB.cooldown then return end
    lastAlert, lastByNpc[id] = now, now

    Alert(UnitName(unit) or vendor.name, reasons)
end

local function ScanNameplates()
    local now = GetTime()
    if now - lastScan < 2 then return end
    lastScan = now
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then CheckUnit(unit) end
    end
end

----------------------------------------------------------------------
-- Aviso de durabilidad baja
----------------------------------------------------------------------
local function CheckDurability()
    local dur = LowestDurability()
    if dur < DB.durThreshold then
        if not durWarned then
            durWarned = true
            PlayAlert()
            local msg = L.LOW_DUR:format(Pct(dur))
            if RaidNotice_AddMessage and RaidWarningFrame then
                RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
            end
            Print(msg)
        end
    else
        durWarned = false -- se vuelve a avisar tras reparar
    end
end

----------------------------------------------------------------------
-- Reparar y vender grises
----------------------------------------------------------------------
local function AutoRepair()
    if not DB.autoRepair or not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost == 0 then return end
    if GetMoney() >= cost then
        RepairAllItems()
        Print(L.REPAIRED:format(Money(cost)))
    else
        Print(L.NO_GOLD:format(Money(cost)))
    end
end

local soldTotal, soldCount = 0, 0

-- Vende en tandas pequeñas para no saturar al servidor
local function SellJunkPass()
    if not merchantOpen then return end
    local sold = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (NumSlots(bag) or 0) do
            local link, count, noValue = ItemInfo(bag, slot)
            if link and not noValue then
                local quality, price = ItemQualityPrice(link)
                if quality == 0 and price and price > 0 then
                    UseItem(bag, slot)
                    soldTotal = soldTotal + price * (count or 1)
                    soldCount = soldCount + 1
                    sold = sold + 1
                    if sold >= 10 then
                        if C_Timer and C_Timer.After then C_Timer.After(0.3, SellJunkPass) end
                        return
                    end
                end
            end
        end
    end
    if soldCount > 0 then
        Print(L.SOLD:format(soldCount, Money(soldTotal)))
    end
end

local function AutoSell()
    if not DB.autoSell then return end
    soldTotal, soldCount = 0, 0
    SellJunkPass()
end

----------------------------------------------------------------------
-- Eventos
----------------------------------------------------------------------
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        VendorAlertDB = VendorAlertDB or {}
        for k, v in pairs(DEFAULTS) do
            if VendorAlertDB[k] == nil then VendorAlertDB[k] = v end
        end
        DB = VendorAlertDB
        MigrateVendors()
        VendorAlertCharDB = VendorAlertCharDB or {}
        ns.DB, ns.CharDB = DB, VendorAlertCharDB
        ns.SetLanguage(DB.lang)
        for _, fn in ipairs(ns.onLoad) do fn() end

    elseif event == "PLAYER_ENTERING_WORLD" then
        CheckDurability()

    elseif event == "MERCHANT_SHOW" then
        merchantOpen = true
        local id = NpcId("npc")
        if id then
            local repair = CanMerchantRepair() and true or false
            local vendor = DB.vendors[id]
            if not vendor then
                DB.vendors[id] = { name = UnitName("npc") or "?", repair = repair }
                Print(L.LEARNED:format(DB.vendors[id].name) .. (repair and L.LEARNED_REPAIR or ""))
            else
                vendor.repair = repair
            end
            lastByNpc[id] = GetTime() -- ya estás en el vendedor, no avisar
        end
        if ns.OnMerchantShow then ns.OnMerchantShow() end -- registro de gastos antes de reparar
        AutoRepair()
        AutoSell()

    elseif event == "MERCHANT_CLOSED" then
        merchantOpen = false

    elseif event == "UPDATE_INVENTORY_DURABILITY" then
        CheckDurability()

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        CheckUnit(arg1)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        CheckUnit("mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" then
        CheckUnit("target")
    elseif event == "BAG_UPDATE_DELAYED" then
        ScanNameplates()
    end
end)

for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "MERCHANT_SHOW", "MERCHANT_CLOSED",
                     "UPDATE_INVENTORY_DURABILITY", "NAME_PLATE_UNIT_ADDED",
                     "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "BAG_UPDATE_DELAYED" }) do
    f:RegisterEvent(e)
end

----------------------------------------------------------------------
-- Comandos: /va
----------------------------------------------------------------------
SLASH_VENDORALERT1, SLASH_VENDORALERT2 = "/va", "/vendoralert"

-- Cada comando acepta la palabra en inglés y en español
local COMMANDS = {
    threshold = "threshold", umbral = "threshold",
    durability = "durability", durabilidad = "durability",
    sell = "sell", vender = "sell",
    repair = "repair", reparar = "repair",
    sound = "sound", sonido = "sound",
    tone = "tone", tono = "tone",
    test = "test", prueba = "test",
    notes = "notes", notas = "notes",
    stats = "stats", expenses = "stats", gastos = "stats",
    resetstats = "resetstats", borrargastos = "resetstats",
    icon = "icon", icono = "icon",
    lang = "lang", language = "lang", idioma = "lang",
    reset = "reset",
}

SlashCmdList.VENDORALERT = function(input)
    local word, arg = (input or ""):lower():match("^(%S*)%s*(.-)$")
    local cmd = COMMANDS[word]
    local onoff = function(b) return b and L.ON or L.OFF end

    if cmd == "threshold" and tonumber(arg) then
        DB.threshold = math.max(1, math.min(100, tonumber(arg))) / 100
        Print(L.SET_THRESHOLD:format(Pct(DB.threshold)))
    elseif cmd == "durability" and tonumber(arg) then
        DB.durThreshold = math.max(1, math.min(100, tonumber(arg))) / 100
        durWarned = false
        Print(L.SET_DUR:format(Pct(DB.durThreshold)))
        CheckDurability()
    elseif cmd == "sell" then
        DB.autoSell = not DB.autoSell
        Print(L.SET_SELL:format(onoff(DB.autoSell)))
    elseif cmd == "repair" then
        DB.autoRepair = not DB.autoRepair
        Print(L.SET_REPAIR:format(onoff(DB.autoRepair)))
    elseif cmd == "sound" then
        DB.sound = not DB.sound
        Print(L.SET_SOUND:format(onoff(DB.sound)))
    elseif cmd == "tone" then
        DB.customSound = not DB.customSound
        Print(L.SET_TONE:format(onoff(DB.customSound)))
    elseif cmd == "test" then
        Alert(L.TEST_NAME, { L.REASON_BAGS:format(Pct((BagFill()))) })
    elseif cmd == "notes" then
        ns.ToggleWindow("notes")
    elseif cmd == "stats" then
        ns.PrintStats()
    elseif cmd == "resetstats" then
        ns.ResetStats()
    elseif cmd == "icon" then
        DB.minimap.hide = not DB.minimap.hide
        ns.UpdateMinimapButton()
        Print(DB.minimap.hide and L.ICON_HIDDEN or L.ICON_SHOWN)
    elseif cmd == "lang" then
        if arg == "auto" or ns.LANGS[arg] then
            DB.lang = arg
            ns.SetLanguage(arg)
            Print(L.LANG_SET)
        else
            Print(L.LANG_USAGE)
        end
    elseif cmd == "reset" then
        wipe(DB.vendors)
        Print(L.VENDORS_CLEARED)
    else
        local fill, used, total = BagFill()
        local count, repairers = 0, 0
        for _, v in pairs(DB.vendors) do
            count = count + 1
            if v.repair then repairers = repairers + 1 end
        end
        Print(L.STATUS1:format(used, total, Pct(fill), Pct(LowestDurability()), count, repairers))
        Print(L.STATUS2:format(Pct(DB.threshold), Pct(DB.durThreshold),
            onoff(DB.autoSell), onoff(DB.autoRepair), onoff(DB.sound)))
        Print(L.HELP1)
        Print(L.HELP2)
    end
end
