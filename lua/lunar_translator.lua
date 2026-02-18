-- Chinese Lunar Calendar Translator (Rime Lua Plugin)
-- Optimized with modular logic and robust date parsing.

-- Global Candidate and yield are provided by Rime's Lua environment inside the translator scope.
-- However, we must ensure the required modules are accessible.

local function lunar_translator(input, seg, env)
    -- Load library inside or outside? Inside is safer for hot-reloading if Rime supports it, 
    -- but outside is more efficient. Let's do a safe load.
    local success, lunar_lib = pcall(require, "lib.lunar_lib")
    if not success then return end

    -- Fetch configuration
    local config = env.engine.schema.config
    local lunar_key = config:get_string('recognizer/patterns/lunar_cmd') or 'lunar'
    local solar_pattern = config:get_string('recognizer/patterns/gregorian_to_lunar') or ''
    local solar_prefix = solar_pattern:match("^%^?(%a)") or 'N'

    -- Helper to output translation
    local function output_lunar(y, m, d)
        local status, text = pcall(lunar_lib.solar_to_lunar_text, y, m, d)
        if status and text then
            -- Rime global: Candidate(type, start, end, text, comment)
            local cand = Candidate("lunar", seg.start, seg._end, text, " 农历")
            cand.quality = 1000
            yield(cand)
        end
    end

    -- Case 1: Active by "lunar" command (current date)
    if input == lunar_key then
        local t = os.date("*t")
        output_lunar(t.year, t.month, t.day)
        return
    end

    -- Case 2: Active by "N" + 8-digit date (e.g., N20240218)
    if input:sub(1,1) == solar_prefix then
        local date_str = input:sub(2)
        if #date_str == 8 then
            local y = tonumber(date_str:sub(1,4))
            local m = tonumber(date_str:sub(5,6))
            local d = tonumber(date_str:sub(7,8))
            if y and m and d then
                output_lunar(y, m, d)
            end
        end
    end
end

return lunar_translator
