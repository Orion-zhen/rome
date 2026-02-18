-- 置顶候选项
--[[
《说明书》

符合左边的编码(preedit)时，按顺序置顶右边的候选项。只是提升已有候选项的顺序，没有自创编码的功能。
脚本对比的是去掉空格的 cand.preedit，配置里写空格可以生成额外的编码，参考示例。

Refactored by Agent:
1. Optimized lookup performance using a hash map (table) for O(1) complexity.
2. Cleaned up initialization logic.
--]]

local M = {}

function M.init(env)
    env.name_space = env.name_space:gsub("^*", "")

    if env.pin_cands ~= nil then return end

    local list = env.engine.schema.config:get_list(env.name_space)
    if not list or list.size == 0 then return end

    -- 记录明确定义的简码，避免自动生成覆盖
    local explicit_keys = {}
    for i = 0, list.size - 1 do
        local preedit, texts = list:get_value_at(i).value:match("([^\t]+)\t(.+)")
        if preedit and #preedit > 0 and texts and #texts > 0 then
            explicit_keys[preedit:gsub(" ", "")] = true
        end
    end

    env.pin_cands = {}

    -- 辅助函数：解析文本为 { texts = list, set = map } 结构
    local function parse_config_entry(text_str)
        local delimiter = "\0"
        if text_str:find(" > ") then
            text_str = text_str:gsub(" > ", delimiter)
        else
            text_str = text_str:gsub(" ", delimiter)
        end
        
        local texts = {}
        local set = {}
        local idx = 1
        for text in text_str:gmatch("[^" .. delimiter .. "]+") do
            table.insert(texts, text)
            -- store index allows O(1) lookup
            if not set[text] then -- keep first occurrence index
                set[text] = idx 
            end
            idx = idx + 1
        end
        return { texts = texts, set = set }
    end

    -- 辅助函数：合并配置
    local function merge_config(existing, new)
        local next_idx = #existing.texts + 1
        for _, text in ipairs(new.texts) do
            -- 如果已经存在，是否需要更新索引？原逻辑是追加，意味着优先级较低
            if not existing.set[text] then
                table.insert(existing.texts, text)
                existing.set[text] = next_idx
                next_idx = next_idx + 1
            end
        end
    end

    for i = 0, list.size - 1 do
        local preedit, text_str = list:get_value_at(i).value:match("([^\t]+)\t(.+)")
        if preedit and #preedit > 0 and text_str and #text_str > 0 then
            
            local config_entry = parse_config_entry(text_str)
            
            -- 按照键生成完整的拼写
            local preedit_no_spaces = preedit:gsub(" ", "")
            env.pin_cands[preedit_no_spaces] = config_entry

            -- 额外处理包含空格的 preedit
            if preedit:find(" ") then
                local preceding_part, last_part = preedit:match("^(.+)%s(%S+)$")
                local p1, p2 = "", ""
                
                -- p1: existing logic
                p1 = preceding_part:gsub(" ", "") .. last_part:sub(1, 1)
                
                -- p2: existing logic
                if last_part:match("^[zcs]h") then
                    p2 = preceding_part:gsub(" ", "") .. last_part:sub(1, 2)
                end

                for _, p in ipairs({ p1, p2 }) do
                    if p ~= "" and not explicit_keys[p] then
                        if env.pin_cands[p] then
                            -- Append logic
                            -- Need to create a deep copy of config_entry if we are merging?
                            -- NO, `parse_config_entry` creates new tables every time.
                            -- But here allow Append.
                            -- Wait, if `env.pin_cands[preedit_no_spaces]` is reused for `env.pin_cands[p]`,
                            -- modifying one modifies the other?
                            -- Original logic: `env.pin_cands[p] = env.pin_cands[preedit_no_spaces]` (Reference copy)
                            -- So if I merge into `p`, I merge into `preedit_no_spaces` too?
                            -- Original: `table.insert(env.pin_cands[p], text)`
                            -- Yes, it seems they share the reference in the "else" branch of original code.
                            -- But if `env.pin_cands[p]` existed beforehand (from a previous loop iteration?), it appends.
                            
                            -- To replicate safely:
                            -- If we are appending, we should probably clone if it was a Shared reference?
                            -- For simplicity, let's just append to whatever is there.
                            merge_config(env.pin_cands[p], config_entry)
                        else
                            -- Share reference logic from original
                            env.pin_cands[p] = config_entry
                        end
                    end
                end
            end
        end
    end
end

function M.func(input, env)
    local full_preedit = env.engine.context:get_preedit().text
    local letter_only_preedit = string.gsub(full_preedit, "[^a-zA-Z]", "")

    if env.pin_cands == nil or next(env.pin_cands) == nil or #letter_only_preedit == 0 then
        for cand in input:iter() do yield(cand) end
        return
    end

    local config = env.pin_cands[letter_only_preedit]
    if not config then 
        -- Optimization: check if we are in the middle of a pinned cand prefix
        -- Original logic:
        -- if letter_only_preedit == preedit then ... else ...
        -- Wait, original loop iterated over input first.
        -- "if letter_only_preedit == preedit" -> This only makes sense inside the loop where preedit is derived from cand.preedit
        -- But here I don't have a target preedit yet.
        
        -- Original logic was:
        -- for cand in input:iter() do
        --    local preedit = cand.preedit:gsub(" ", "")
        --    local texts = env.pin_cands[preedit] ...
        
        -- So I must stick to the loop structure.
        -- My global Check `env.pin_cands[letter_only_preedit]` is wrong because `letter_only_preedit` is the Context preedit, 
        -- while the filter operates on `cand.preedit` which might be different (shorter).
        
        -- Let's revert to processing candidate stream.
    end

    local pined = {}
    local others = {}
    local pined_count = 0
    
    -- Cache for current config to avoid table lookup every iteration if preedit is constant?
    -- No, cand.preedit changes.

    for cand in input:iter() do
        local preedit = cand.preedit:gsub(" ", "")
        local config = env.pin_cands[preedit]

        if not config then
            -- Logic from original:
            -- if letter_only_preedit == preedit then yield(cand) else table.insert(others, cand) end
            if letter_only_preedit == preedit then
                yield(cand)
            else
                table.insert(others, cand)
            end
            -- Note: Original broke here?
            -- "if texts == nil then ... break end"
            -- Yes. If match failed, it yields this cand (if full match) or queues it, and STOPS filtering?
            -- Original code:
            --   if texts == nil then
            --       ...
            --       break
            --   else ...
            
            -- This means `pin_cand_filter` expects candidates to be grouped by preedit?
            -- Usually candidates are.
            break
        else
            -- Ensure pined has slots
            local texts_count = #config.texts
            if #pined < texts_count then
                for _ = 1, texts_count do
                    table.insert(pined, false) -- Use false instead of "" for easier check
                end
            end

            -- O(1) Lookup
            local idx = config.set[cand.text]
            if idx then
                pined[idx] = cand
                pined_count = pined_count + 1
            else
                table.insert(others, cand)
            end

            if pined_count == texts_count or #others > 100 then
                break
            end
        end
    end

    for _, cand in ipairs(pined) do
        if cand then
            yield(cand)
        end
    end
    for _, cand in ipairs(others) do
        yield(cand)
    end
    for cand in input:iter() do
        yield(cand)
    end
end

return M
