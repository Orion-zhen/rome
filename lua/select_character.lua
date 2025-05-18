-- 以词定字
-- 来源：
-- https://github.com/BlindingDark/rime-lua-select-character/blob/master/lua/select_character.lua
-- http://lua-users.org/lists/lua-l/2014-04/msg00590.html

-- 定义一个本地函数 utf8_sub，用于截取 UTF-8 编码的字符串的子串
local function utf8_sub(s, i, j)
    i = i or 1  -- 如果参数 i 未提供，则默认为 1 (字符串的起始位置)
    j = j or -1 -- 如果参数 j 未提供，则默认为 -1 (字符串的末尾位置)

    -- 处理索引为负数或小于1的情况，将其转换为相对于字符串长度的正向索引
    if i < 1 or j < 1 then
        local n = utf8.len(s)                           -- 获取 UTF-8 字符串的字符长度
        if not n then return nil end                    -- 如果字符串长度无效 (例如 nil)，则返回 nil
        if i < 0 then i = n + 1 + i end                 -- 如果 i 是负数，则从字符串末尾开始计算位置
        if j < 0 then j = n + 1 + j end                 -- 如果 j 是负数，则从字符串末尾开始计算位置
        if i < 0 then i = 1 elseif i > n then i = n end -- 确保 i 在有效范围内 [1, n]
        if j < 0 then j = 1 elseif j > n then j = n end -- 确保 j 在有效范围内 [1, n]
    end

    if j < i then return "" end -- 如果结束索引小于起始索引，则返回空字符串

    i = utf8.offset(s, i)       -- 获取 UTF-8 字符串中第 i 个字符的字节偏移量
    j = utf8.offset(s, j + 1)   -- 获取 UTF-8 字符串中第 j+1 个字符的字节偏移量 (用于 sub 函数的开闭区间)

    if i and j then             -- 如果起始和结束字节偏移量都有效
        return s:sub(i, j - 1)  -- 使用 Lua 的 string.sub 截取子串 (字节级别)，j-1 是因为 sub 是闭区间
    elseif i then               -- 如果只有起始字节偏移量有效 (表示截取到字符串末尾)
        return s:sub(i)         -- 使用 Lua 的 string.sub 从起始偏移量截取到末尾
    else                        -- 如果起始字节偏移量无效
        return ""               -- 返回空字符串
    end
end

-- 定义一个本地函数 first_character，用于获取字符串的第一个字符
local function first_character(s)
    return utf8_sub(s, 1, 1) -- 调用 utf8_sub 获取第一个字符
end

-- 定义一个本地函数 last_character，用于获取字符串的最后一个字符
local function last_character(s)
    return utf8_sub(s, -1, -1) -- 调用 utf8_sub 获取最后一个字符
end

-- 定义一个本地函数 get_commit_text，用于获取并构造最终要上屏的文本
local function get_commit_text(context, fun)
    local candidate_text = context:get_selected_candidate().text -- 获取当前选中候选词的文本
    local selected_character = fun(candidate_text)               -- 调用传入的函数 (first_character 或 last_character) 来获取候选词的特定字符

    context:clear_previous_segment()                             -- 清除前一个输入段 (如果有)
    local commit_text = context:get_commit_text()                -- 获取当前已经上屏的文本 (编码缓存中的文本)

    context:clear()                                              -- 清空当前的输入上下文 (包括候选词等)

    return commit_text .. selected_character                     -- 将已上屏的文本和新选中的字符拼接起来返回
end

-- 定义核心的本地函数 select_character，这是 Rime 输入法将会调用的 Lua 处理器函数
local function select_character(key, env)
    local engine = env.engine           -- 获取输入法引擎对象
    local context = engine.context      -- 获取输入法引擎的上下文对象
    local config = engine.schema.config -- 获取当前输入方案的配置对象

    -- 从配置中读取选择第一个字符的快捷键，默认为 'bracketleft' ([)
    local first_key = config:get_string('key_binder/select_first_character') or 'bracketleft'
    -- 从配置中读取选择最后一个字符的快捷键，默认为 'bracketright' (])
    local last_key = config:get_string('key_binder/select_last_character') or 'bracketright'

    local commit_text = context:get_commit_text() -- 获取当前已经上屏的文本

    -- 如果按下的键是选择第一个字符的快捷键，并且当前已有上屏文本 (避免在无输入时触发)
    if (key:repr() == first_key and commit_text ~= "") then
        engine:commit_text(get_commit_text(context, first_character)) -- 调用 get_commit_text 获取第一个字符并上屏

        return 1                                                      -- 返回 1 (kAccepted)，表示按键已被处理
    end

    -- 如果按下的键是选择最后一个字符的快捷键，并且当前已有上屏文本
    if (key:repr() == last_key and commit_text ~= "") then
        engine:commit_text(get_commit_text(context, last_character)) -- 调用 get_commit_text 获取最后一个字符并上屏

        return 1                                                     -- 返回 1 (kAccepted)，表示按键已被处理
    end

    return 2 -- 返回 2 (kNoop)，表示按键未被此 Lua 处理器处理，交由 Rime 后续处理
end

return select_character -- 返回 select_character 函数，使其可以被 Rime 输入法引擎调用
