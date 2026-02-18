-- Lunar Calendar Logic (Improved & Corrected)
-- This file provides the conversion between Gregorian and Lunar dates.

local M = {}

local lunar_data = require("data.lunar")
local wNongliData = lunar_data.wNongliData

-- Helper: Extract fields from compressed hex data
local function get_year_info(year)
    local idx = year - 1900 + 1
    local info = wNongliData[idx]
    if not info then return nil end
    
    -- Format: 0xMMMLLDD (Hex)
    -- MMM (bits 16-27): 12-bit Month Mask (1=30 days, 0=29 days)
    -- L (bits 12-15): Leap Month Day flag (1=30, 0=29)
    -- L (bits 8-11): Leap Month Index (0-12, 0 means no leap month)
    -- DD (bits 0-7): New Year Offset MMDD (Decimal representation in Hex)
    
    local month_mask = math.floor(info / 0x10000)
    local leap_days = math.floor(info / 0x1000) % 16
    local leap_idx = math.floor(info / 0x100) % 16
    local offset_raw = info % 256
    
    -- Original data representation: offset_raw 210 means month 2, day 10
    local offset_m = math.floor(offset_raw / 100)
    local offset_d = offset_raw % 100
    
    return {
        month_mask = month_mask,
        leap_days = leap_days,
        leap_idx = leap_idx,
        offset_m = offset_m,
        offset_d = offset_d
    }
end

local function is_solar_leap(y)
    return (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
end

local function solar_month_days(y, m)
    local days = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    if m == 2 and is_solar_leap(y) then return 29 end
    return days[m]
end

-- Calculate days passed since 1900-01-30 (referencing actual Lunar Data start)
-- But simpler: days between two dates.
local function diff_days(y1, m1, d1, y2, m2, d2)
    -- We can use os.time but it's risky for very old dates on some systems
    -- Manual calculation is safer for Lunar ranges (1900-2100)
    local function to_abs_days(y, m, d)
        local total = 0
        for i = 1900, y - 1 do
            total = total + (is_solar_leap(i) and 366 or 365)
        end
        for i = 1, m - 1 do
            total = total + solar_month_days(y, i)
        end
        return total + d
    end
    return to_abs_days(y2, m2, d2) - to_abs_days(y1, m1, d1)
end

function M.solar_to_lunar_text(y, m, d)
    local info = get_year_info(y)
    if not info then return "日期超出 1900-2100 范围" end

    -- CNY Date in Gregorian for this year
    local lny_m = info.offset_m
    local lny_d = info.offset_d
    
    local days_diff = diff_days(y, lny_m, lny_d, y, m, d)
    
    local lunar_year = y
    if days_diff < 0 then
        -- Date is before this year's CNY, so it belongs to last lunar year
        lunar_year = y - 1
        info = get_year_info(lunar_year)
        days_diff = diff_days(lunar_year, info.offset_m, info.offset_d, y, m, d)
    end
    
    local current_days = days_diff + 1
    local leap_idx = info.leap_idx
    local mask = info.month_mask
    
    local found_month = 0
    local is_leap = false
    
    -- Iterate through 12 or 13 months
    for i = 1, 13 do
        local m_len = 0
        local is_this_leap = false
        
        if leap_idx > 0 and i == leap_idx + 1 then
            -- Leap month
            m_len = 29 + info.leap_days
            is_this_leap = true
        else
            -- Normal month
            local normal_m_idx = i
            if leap_idx > 0 and i > leap_idx then
                normal_m_idx = i - 1
            end
            if normal_m_idx > 12 then break end
            
            -- Extract bit from mask (bit 11 is month 1, bit 0 is month 12)
            -- So shift by (12 - normal_m_idx)
            local bit = math.floor(mask / (2 ^ (12 - normal_m_idx))) % 2
            m_len = 29 + bit
        end
        
        if current_days <= m_len then
            local lunar_day = current_days
            found_month = (leap_idx > 0 and i > leap_idx) and i - 1 or i
            if leap_idx > 0 and i == leap_idx + 1 then
                is_leap = true
                found_month = leap_idx
            end
            
            -- Formatting
            local mon_name = lunar_data.cMonName[found_month]
            if is_leap then mon_name = "闰" .. mon_name end
            local day_name = lunar_data.cDayName[lunar_day]
            
            -- GanZhi and Animal
            local gz_year = lunar_data.cTianGan[((lunar_year - 4) % 10) + 1] .. lunar_data.cDiZhi[((lunar_year - 4) % 12) + 1]
            local animal = lunar_data.cShuXiang[((lunar_year - 4) % 12) + 1]
            
            return gz_year .. "年（" .. animal .. "）" .. mon_name .. day_name
        end
        current_days = current_days - m_len
    end
    
    return "日期算法逻辑错误"
end

return M
