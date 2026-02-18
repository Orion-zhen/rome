-- 以词定字 (Select Character from Candidate)
-- 
-- 逻辑重构说明：
-- 1. 修复了上下文丢失问题：原逻辑在“以词定字”时会丢弃除当前选中词外的其他已确认片段。
--    现在通过计算 `commit_text` 偏移量，确保保留之前已确定的分段。
-- 2. 优化了 UTF-8 处理：移除了冗余的 `utf8_sub`（800+行逻辑其实只是为了取值），
--    改用更精简的位移查找。
-- 3. 增强了健壮性：增加了对 `utf8` 库的兼容性检查和 `nil` 防御。

-- 兼容性处理：尝试获取 utf8 库，适配不同的 Rime Lua 环境
local utf8 = utf8 or (type(unicode) == "table" and unicode.utf8)

-- 高效获取 UTF-8 字符串的第 n 个字符
local function utf8_at(s, n)
    if not s or s == "" or not n then return "" end
    if not utf8 then
        -- 如果环境实在没有 utf8 库（极罕见），回退到字节处理（对中文不友好但不会崩）
        return s:sub(n, n) 
    end
    
    local offset = utf8.offset(s, n)
    if not offset then return "" end
    
    local next_offset = utf8.offset(s, n + 1)
    if next_offset then
        return s:sub(offset, next_offset - 1)
    else
        return s:sub(offset)
    end
end

-- 核心处理器
local function select_character_processor(key, env)
    local context = env.engine.context
    -- 仅在正在输入（有组合码）时处理
    if not context:is_composing() then
        return 2 -- kNoop
    end

    local config = env.engine.schema.config
    -- 读取快捷键配置，默认 [ 为首字，] 为尾字
    local first_key = config:get_string('key_binder/select_first_character') or 'bracketleft'
    local last_key = config:get_string('key_binder/select_last_character') or 'bracketright'

    local repr = key:repr()
    local is_first = (repr == first_key)
    local is_last = (repr == last_key)

    -- 如果不是目标按键，直接跳过
    if not (is_first or is_last) then
        return 2 -- kNoop
    end

    -- 获取当前高亮的候选词
    local cand = context:get_selected_candidate()
    if not cand then
        return 2 -- kNoop
    end

    local text = cand.text
    if not text or text == "" then
        return 2 -- kNoop
    end

    -- 计算字符长度
    local len = utf8 and utf8.len(text) or #text
    if len == 0 then return 2 end

    -- 提取目标字
    local target_char
    if is_first then
        target_char = utf8_at(text, 1)
    else
        target_char = utf8_at(text, len)
    end

    if not target_char or target_char == "" then
        return 2 -- kNoop
    end

    -- 【关键修复】获取完整的提交文本并保留前置分段
    -- commit_text 包含：已确定的段落 + 当前选中的候选词
    local full_commit = context:get_commit_text()
    
    -- 计算前置片段：从 full_commit 中截掉当前候选词占用的字节长度
    -- 比如 "我[喜欢]"，full_commit 是 "我喜欢"，text 是 "喜欢"
    -- 截取后得到 "我"
    local confirmed_part = full_commit:sub(1, #full_commit - #text)
    
    -- 提交：前置片段 + 选定的单字
    env.engine:commit_text(confirmed_part .. target_char)
    
    -- 清除当前的输入组合
    context:clear()

    return 1 -- kAccepted
end

return select_character_processor
