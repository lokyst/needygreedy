RollWatcher = LibStub("AceAddon-3.0"):NewAddon("RollWatcher", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")

LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("RollWatcher", {
          type = "launcher",
          icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
          OnClick = function(clickedframe, button)
                     RollWatcher:ToggleDisplay()
          end,
})

local report = {}
local items = {}

local options = {
    name = "RollWatcher",
    desc = "Displays a table of items and the roll choices players have made on them",
    handler = RollWatcher,
    type = "group",
    args = {
        nitems = {
            name = "Display Items",
            desc = "Number of item columns in the display window",
            type = "range",
            min = 1,
            max = 10,
            step = 1,
            get = "GetNItems",
            set = "SetNItems"
        },
        expiry = {
            name = "Expiry Time",
            desc = "Minutes after item is received before it is removed from display (0 = forever)",
            type = "range",
            min = 0,
            max = 60,
            step = 1,
            get = "GetExpiry",
            set = "SetExpiry"
        },
        quality = {
            name = "Minimum Quality",
            desc = "Minimum quality of item to be displayed",
            type = "select",
            values = {
                [ITEM_QUALITY_UNCOMMON] = ITEM_QUALITY2_DESC,
                [ITEM_QUALITY_RARE] = ITEM_QUALITY3_DESC,
                [ITEM_QUALITY_EPIC] = ITEM_QUALITY4_DESC
            },
            style = "dropdown",
            get = "GetQuality",
            set = "SetQuality"
        },
        displayIcons = {
            name = "Display Icons",
            desc = "Display icons for rolls types instead of text strings",
            type = "toggle",
            get = "GetDisplayIcons",
            set = "SetDisplayIcons",
        }
    }
}

local defaults = {
    profile = {
        nitems = 2,
        namelistwidth = 100,
        scale = 1,
        expiry = 5,
        quality = ITEM_QUALITY_EPIC,
        displayIcons = false,
    }
}

local iconSize = 27
local ROLLWATCHER_CHOICE = {
    ["need"] = {
        ["string"] = "|c00FF0000" .. NEED .. "|r",
        ["icon"] = "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:" .. iconSize .. "|t",
    },
    ["greed"] = {
        ["string"] = "|c0000FF00" .. GREED .. "|r",
        ["icon"] = "|TInterface\\Buttons\\UI-GroupLoot-Coin-Up:" .. iconSize .. "|t",
    },
    ["pass"] = {
        ["string"] = "|c00CCCCCC" .. PASS .. "|r",
        ["icon"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:16|t",
    },
    ["disenchant"] = {
        ["string"] = "|c00FF00FF" .. ROLL_DISENCHANT .. "|r",
        ["icon"] = "|TInterface\\Buttons\\UI-GroupLoot-DE-Up:" .. iconSize .. "|t",
    }
}

function RollWatcher:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RollWatcherDB", defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshTooltip")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshTooltip")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshTooltip")
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("RollWatcher", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("RollWatcher")
    self:RegisterChatCommand("rwt", "TestItemList")
    self:RegisterChatCommand("rollwatcher", function() InterfaceOptionsFrame_OpenToCategory("RollWatcher") end)
end

function RollWatcher:OnEnable()
    self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:RegisterEvent("START_LOOT_ROLL")
    self:RegisterEvent("CHAT_MSG_LOOT")
    self:ScheduleRepeatingTimer("ExpireItems", 1)
end

function RollWatcher:OnDisable()
    if self.tooltip then
        self:HideReportFrame()
    end
end

function RollWatcher:ToggleDisplay()
    if self.tooltip then
        self:HideReportFrame()
    else
        self:ShowReportFrame()
    end
end

function RollWatcher:PARTY_MEMBERS_CHANGED()
    if self.tooltip then
        self:RefreshTooltip()
    end
end



-- Chat scanning and loot recording
function RollWatcher:START_LOOT_ROLL(event, rollid)
    local texture, name, count, quality = GetLootRollItemInfo(rollid)
    local link = GetLootRollItemLink(rollid)
    if quality >= self.db.profile.quality then
        items[rollid] = {
            texture = texture,
            link = link,
            assigned = "",
            received = 0,
            choices = {},
            rolls = {}
        }
        self:UpdateReport()
    end
end

function RollWatcher:CHAT_MSG_LOOT(event, msg)
    local me = UnitName("player")
    local player, link, number

    link = self:unformat(LOOT_ROLL_YOU_WON, msg)
    if link then
        self:RecordAwarded(link, me)
        return
    end

    player, link = self:unformat(LOOT_ROLL_WON, msg)
    if player then
        self:RecordAwarded(link, player)
        return
    end

    link = self:unformat(LOOT_ROLL_ALL_PASSED, msg)
    if link then
        self:RecordAwarded(link, "---")
        return
    end

    player, link = self:unformat(LOOT_ROLL_PASSED_AUTO, msg)
    if player then
        self:RecordChoice(link, player, "pass")
        return
    end

    player, link = self:unformat(LOOT_ROLL_PASSED_AUTO_FEMALE, msg)
    if player then
        self:RecordChoice(link, player, "pass")
        return
    end

    link = self:unformat(LOOT_ROLL_NEED_SELF, msg)
    if link then
        self:RecordChoice(link, me, "need")
        return
    end

    link = self:unformat(LOOT_ROLL_GREED_SELF, msg)
    if link then
        self:RecordChoice(link, me, "greed")
        return
    end

    link = self:unformat(LOOT_ROLL_PASSED_SELF, msg)
    if link then
        self:RecordChoice(link, me, "pass")
        return
    end

    link = self:unformat(LOOT_ROLL_PASSED_SELF_AUTO, msg)
    if link then
        self:RecordChoice(link, me, "pass")
        return
    end

    player, link = self:unformat(LOOT_ROLL_NEED, msg)
    if player then
        self:RecordChoice(link, player, "need")
        return
    end

    player, link = self:unformat(LOOT_ROLL_GREED, msg)
    if player then
        self:RecordChoice(link, player, "greed")
        return
    end

    player, link = self:unformat(LOOT_ROLL_PASSED, msg)
    if player then
        self:RecordChoice(link, player, "pass")
        return
    end

    number, link, player = self:unformat(LOOT_ROLL_ROLLED_NEED, msg)
    if number then
        self:RecordRoll(link, player, number)
        return
    end

    number, link, player = self:unformat(LOOT_ROLL_ROLLED_GREED, msg)
    if number then
        self:RecordRoll(link, player, number)
        return
    end

    link = self:unformat(LOOT_ITEM_PUSHED_SELF, msg)
    if link then
        self:RecordReceived(link)
        return
    end

    link, number = self:unformat(LOOT_ITEM_PUSHED_SELF_MULTIPLE, msg)
    if link then
        self:RecordReceived(link)
        return
    end

    link = self:unformat(LOOT_ITEM_SELF, msg)
    if link then
        self:RecordReceived(link)
        return
    end

    link, number = self:unformat(LOOT_ITEM_SELF_MULTIPLE, msg)
    if link then
        self:RecordReceived(link)
        return
    end

    player, link = self:unformat(LOOT_ITEM, msg)
    if player then
        self:RecordReceived(link)
        return
    end

    player, link, number = self:unformat(LOOT_ITEM_MULTIPLE, msg)
    if player then
        self:RecordReceived(link)
        return
    end

    -- To handle new disenchant rules
    link = self:unformat(LOOT_ROLL_DISENCHANT_SELF, msg)
    if link then
        self:RecordChoice(link, me, "disenchant")
        return
    end

    player, link = self:unformat(LOOT_ROLL_DISENCHANT, msg)
    if link then
        self:RecordChoice(link, player, "disenchant")
        return
    end

    player, link = self:unformat(LOOT_ROLL_DISENCHANT, msg)
    if link then
        self:RecordChoice(link, player, "disenchant")
        return
    end

    number, link, player = self:unformat(LOOT_ROLL_ROLLED_DE, msg)
    if number then
        self:RecordRoll(link, player, number)
        return
    end
end

function RollWatcher:RecordChoice(link, player, choice)
    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.choices[player] = choice
            break
        end
    end
    self:UpdateReport()
end

function RollWatcher:RecordRoll(link, player, number)
    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.rolls[player] = number
            break
        end
    end
    self:UpdateReport()
end

function RollWatcher:RecordAwarded(link, player)
    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.assigned = player
            break
        end
    end
    self:UpdateReport()
end

function RollWatcher:RecordReceived(link)
    for rollid, record in pairs(items) do
        if record.received == 0 and record.link == link then
            record.received = GetTime()
            break
        end
    end
    self:UpdateReport()
end



-- Tooltip Information Formatting
function RollWatcher:PageLeft()
    report.firstitem = report.firstitem - self.db.profile.nitems
    if report.firstitem < 1 then
        report.firstitem = 1
    end
    self:UpdateReport()
end

function RollWatcher:PageRight()
    local count = RollWatcher:CountItems()
    report.firstitem = report.firstitem + self.db.profile.nitems
    if count == 0 then
        report.firstitem = 1
    elseif report.firstitem > count then
        report.firstitem = count
    end
    self:UpdateReport()
end

function RollWatcher:GetSortedPlayers()
    local list = {}

    if GetNumRaidMembers() > 0 then
        for i = 1,MAX_RAID_MEMBERS do
            name = GetRaidRosterInfo(i)
            if name then
                table.insert(list, name)
            end
        end
    else
        for _, unit in ipairs({"player", "party1", "party2", "party3", "party4"}) do
            local name = UnitName(unit)
            if name then
                table.insert(list, name)
            end
        end
    end
    table.sort(list)
    return list
end

function RollWatcher:GetNumPlayers()
    local nraid = GetNumRaidMembers()
    if nraid > 0 then
        return nraid
    else
        return GetNumPartyMembers() + 1
    end
end

function RollWatcher:ColorizeName(name)
    -- Derived by hand from RAID_CLASS_COLORS because deriving it in lua seemed tricky
    -- Might not be that hard: str_format("%02x%02x%02x", r * 255, g * 255, b * 255)
    local map = {
        HUNTER = "|c00ABD473",
        WARLOCK = "|c009482C9",
        PRIEST = "|c00FFFFFF",
        PALADIN = "|c00F58CBA",
        MAGE = "|c0069CCF0",
        ROGUE = "|c00FFF569",
        DRUID = "|c00FF7D0A",
        SHAMAN = "|c002459FF",
        WARRIOR = "|c00C79C6E",
        DEATHKNIGHT = "|c00C41F3A"
    }
    local _, class = UnitClass(name)
    local color

    if class then
        color = map[class]
    end
    if not color then
        color = GRAY_FONT_COLOR_CODE
    end
    return color .. name .. "|r"
end

function RollWatcher:ChoiceText(choice)
    local style = "string"
    if self.db.profile.displayIcons == true then style = "icon" end

    if choice then
          if ROLLWATCHER_CHOICE[choice][style] then
              return ROLLWATCHER_CHOICE[choice][style]
          end
    end
    return ""
end

function RollWatcher:RollText(number)
    if number then
        return " " .. number
    else
        return ""
    end
end

function RollWatcher:AssignedText(item)
    if item.received == 0 then
        return "|c00FF0000" .. item.assigned .. "|r"
    else
        return "|c0000FF00" .. item.assigned .. "|r"
    end
end

-- Return a list of rollids ordered from most recent to least recent
function RollWatcher:SortRollids()
    local rollids = {}
    for rollid, _ in pairs(items) do
        table.insert(rollids, rollid)
    end
    table.sort(rollids, function(a, b) return a > b end)
    return rollids
end

function RollWatcher:CountItems()
    local i = 0
    for _, _ in pairs(items) do
        i = i + 1
    end
    return i
end

function RollWatcher:ExpireItems()
    local now = GetTime()
    local update = false

    if self.db.profile.expiry == 0 then
        return
    end
    for rollid, record in pairs(items) do
        if record.received > 0 and now - record.received >= self.db.profile.expiry * 60 then
            items[rollid] = nil
            update = true
        end
    end
    if update then
        self:UpdateReport()
    end
end

function RollWatcher:unformat(fmt, msg)
    local pattern = string.gsub(string.gsub(fmt, "(%%s)", "(.+)"), "(%%d)", "(.+)")
    local _, _, a1, a2, a3, a4 = string.find(msg, pattern)
    return a1, a2, a3, a4
end



-- Config option getters and setters
function RollWatcher:GetNItems(info)
    return self.db.profile.nitems
end

function RollWatcher:SetNItems(info, nitems)
    self.db.profile.nitems = nitems
    self:RefreshTooltip()
end

function RollWatcher:GetExpiry(info)
    return self.db.profile.expiry
end

function RollWatcher:SetExpiry(info, expiry)
    self.db.profile.expiry = expiry
    self:ExpireItems()
end

function RollWatcher:GetQuality(info)
    return self.db.profile.quality
end

function RollWatcher:SetQuality(info, quality)
    self.db.profile.quality = quality
end

function RollWatcher:GetDisplayIcons(info)
    return self.db.profile.displayIcons
end

function RollWatcher:SetDisplayIcons(info, displayIcons)
    self.db.profile.displayIcons = displayIcons
    self:UpdateReport()
end


-- Detachable QTip Frames
local LibQTip = LibStub('LibQTip-1.0')

function RollWatcher:ShowReportFrame()
    -- Acquire a tooltip
    self.tooltip = LibQTip:Acquire("RollWatcherReport", 1, "LEFT")
    -- Add columns here because tooltip:Clear() preserves columns
    for i = 1, self.db.profile.nitems do
        self.tooltip:AddColumn("LEFT")
    end
    -- Add two columns for left and right dialog buttons
    self.tooltip:AddColumn("RIGHT")
    self.tooltip:AddColumn("LEFT")

    RollWatcher:PopulateReportTooltip()

    -- To make tooltip detached
    self.tooltip:ClearAllPoints()
    self.tooltip:SetFrameStrata("FULLSCREEN")
    self.tooltip:EnableMouse(true)
    self.tooltip:SetResizable(true)
    self.tooltip:SetFrameLevel(1)
    self.tooltip:SetMovable(true)
    self.tooltip:SetClampedToScreen(true)

    if not self.db.profile.reportFramePos then
        self.db.profile.reportFramePos = {
            anchor1 = "CENTER",
            anchor2 = "CENTER",
            x = 0,
            y = 0
        }
    end
    self.tooltip:SetPoint(self.db.profile.reportFramePos.anchor1, nil, self.db.profile.reportFramePos.anchor2, self.db.profile.reportFramePos.x, self.db.profile.reportFramePos.y)

    -- Make it move !
    self.tooltip:SetScript("OnMouseDown", function() self.tooltip:StartMoving() end)
    self.tooltip:SetScript("OnMouseUp", function()
        -- Make it remember
        self.tooltip:StopMovingOrSizing()
        local anchor1, _, anchor2, x, y = self.tooltip:GetPoint()
        self.db.profile.reportFramePos.anchor1 = anchor1
        self.db.profile.reportFramePos.anchor2 = anchor2
        self.db.profile.reportFramePos.x = x
        self.db.profile.reportFramePos.y = y
    end)

    -- Show it, et voilà !
    self.tooltip:Show()
end

function RollWatcher:HideReportFrame()
    self.tooltip:Hide()
    LibQTip:Release(self.tooltip)
    self.tooltip = nil
end

function RollWatcher:PopulateReportTooltip()
    local nItems = self.db.profile.nitems
    local players = self:GetSortedPlayers()
    self.tooltip:Clear()

    -- Verify that report.firstitem is set reasonably
    local sorted = self:SortRollids()
    local count = self:CountItems()

    if not(report.firstitem) then report.firstitem = 1 end
    if count == 0 then
        report.firstitem = 1
    elseif report.firstitem > count then
        report.firstitem = count
    end

    -- Create headers
    local itemHeaders = {"Party"}
    local headerline = self.tooltip:AddHeader(unpack(itemHeaders))
    for i = 1, nItems do
        local index = report.firstitem + i - 1
        local texture = ""
        local item = nil
        if index <= count then
            local rollID = sorted[index]
            item = items[rollID]
            texture = "|T" .. item.texture .. ":40|t"
        end
        self.tooltip:SetCell(headerline, i + 1, texture, nil, nil, nil, nil, nil, nil, nil, 60)
        if item then
            self.tooltip:SetCellScript(headerline, i + 1, "OnEnter", function()
                GameTooltip:SetOwner(self.tooltip, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(item.link)
            end )
            self.tooltip:SetCellScript(headerline, i + 1, "OnLeave", function()
                GameTooltip:Hide()
            end )
        end
    end

    self.tooltip:AddSeparator()

    -- Create table with party names and their rolls
    for i, name in ipairs(players) do
        local rollTable = {}
        table.insert(rollTable, self:ColorizeName(name))

        for i = 1, nItems do
            local index = report.firstitem + i - 1
            if index <= count then
                local rollID = sorted[index]
                local item = items[rollID]
                table.insert(rollTable, self:ChoiceText(item.choices[name]) .. self:RollText(item.rolls[name]))
            end
        end

        self.tooltip:AddLine(unpack(rollTable))
    end

    self.tooltip:AddSeparator()

    -- Display winner
    local winnerTable = {"Winner"}
    for i = 1, nItems do
        local index = report.firstitem + i - 1
        if index <= count then
            local rollID = sorted[index]
            local item = items[rollID]
            table.insert(winnerTable, self:AssignedText(item))
        end
    end
    self.tooltip:AddLine(unpack(winnerTable))

    -- Display left and right arrows
    local arrowTable = {""}
    for i = 1, nItems do
        table.insert(arrowTable, "")
    end
    local lineNum, _ = self.tooltip:AddLine(unpack(arrowTable))
    local colNum = nItems + 2
    if report.firstitem > 1 then
        self.tooltip:SetCell(lineNum, colNum, "|TInterface\\Buttons\\UI-SpellbookIcon-PrevPage-Up:" .. iconSize .. "|t")
        self.tooltip:SetCellScript(lineNum, colNum, "OnMouseUp", function() self:PageLeft() end)
    else
        self.tooltip:SetCell(lineNum, colNum, "|TInterface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled:" .. iconSize .. "|t")
    end
    if report.firstitem + nItems - 1 < count then
        self.tooltip:SetCell(lineNum, colNum + 1, "|TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Up:" .. iconSize .. "|t")
        self.tooltip:SetCellScript(lineNum, colNum + 1, "OnMouseUp", function() self:PageRight() end)
    else
        self.tooltip:SetCell(lineNum, colNum + 1, "|TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled:" .. iconSize .. "|t")
    end
end

function RollWatcher:UpdateReport()
    if self.tooltip and self.tooltip:IsShown() then
        self:PopulateReportTooltip()
    end
end

function RollWatcher:RefreshTooltip()
    if self.tooltip then
        self:HideReportFrame()
        self:ShowReportFrame()
    end
end



-- Unit tests
function RollWatcher:TestItemList()
    items[1] = {
        texture = "Interface\\Icons\\INV_Weapon_ShortBlade_04",
        link = "|cff0070dd|Hitem:2169:0:0:0:0:0:0:1016630800:80|h[Buzzer Blade]|h|r",
        assigned = "",
        received = 0,
        choices = {},
        rolls = {}
    }
    items[2] = {
        texture = "Interface\\Icons\\INV_Weapon_ShortBlade_05",
        link = "|cff0070dd|Hitem:2169:0:0:0:0:0:0:1016630800:80|h[Buzzer Blade]|h|r",
        assigned = "",
        received = 0,
        choices = {Matsuri = "disenchant", Lubov = "greed"},
        rolls = {Matsuri = "- 61", Lubov = "- 98"}
    }
    items[3] = {
        texture = "Interface\\Icons\\INV_Weapon_ShortBlade_06",
        link = "|cff0070dd|Hitem:2169:0:0:0:0:0:0:1016630800:80|h[Buzzer Blade]|h|r",
        assigned = "Matsuri",
        received = 15130,
        choices = {Shalii = "pass", Matsuri = "need"},
        rolls = {Shalii = "", Matsuri = " - 42"}
    }
    self:UpdateReport()
end