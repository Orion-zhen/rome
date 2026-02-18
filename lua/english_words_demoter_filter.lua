-- 降低部分英语单词在候选项的位置
-- https://dvel.me/posts/make-rime-en-better/#短单词置顶的问题
-- 感谢大佬 @[Shewer Lu](https://github.com/shewer) 指点
-- YummyCocoa修改:
--   1. 在不设置 mode 情况下，调整为默认全降模式（原本为 none 模式）；
--   2. all 会合并默认全降内容和自定义内容。

local M = {}

function M.init(env)
    local config = env.engine.schema.config
    env.name_space = env.name_space:gsub("^*", "")

    -- 要降低到的位置
    M.idx = config:get_int(env.name_space .. "/idx")

    -- 所有 3~4 位长度、前 2~3 位是完整拼音、最后一位是声母的单词
    local all_list = require("data.english_words")

    M.all = {}
    for _, v in ipairs(all_list) do
        M.all[v] = true
    end

    -- 自定义
    M.words = {}
    local list = config:get_list(env.name_space .. "/words")

    -- 当 words 没有定义，赋值长度为0
    local listSize = list and list.size or 0

    for i = 0, listSize - 1 do
        local word = list:get_value_at(i).value
        M.words[word] = true
    end

    -- 模式(YummyCocoa: all 会合并默认全降内容)
    local mode = config:get_string(env.name_space .. "/mode")
    if mode == "all" then
        -- 合并 all 和 words
        local mergedTable = {}
        for key in pairs(M.all) do
            mergedTable[key] = true
        end
        for key in pairs(M.words) do
            mergedTable[key] = true
        end
        M.map = mergedTable
    elseif mode == "custom" then
        M.map = M.words
    elseif mode == "none" then
        M.map = {}
    else
        M.map = M.all
    end
end

function M.func(input, env)
    -- filter start
    local code = env.engine.context.input
    if M.map[code] then
        local pending_cands = {}
        local index = 0
        for cand in input:iter() do
            index = index + 1
            -- 找到要降低的英文词，加入 pending_cands
            if cand.preedit:find(" ") or not cand.text:match("[a-zA-Z]") then
                yield(cand)
            else
                table.insert(pending_cands, cand)
            end
            if index >= M.idx + #pending_cands - 1 then
                for _, cand in ipairs(pending_cands) do
                    yield(cand)
                end
                break
            end
        end
    end

    -- yield other
    for cand in input:iter() do
        yield(cand)
    end
end

return M
