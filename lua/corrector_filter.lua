--[[
    错音错字提示。
    示例：「给予」的正确读音是 ji yu，当用户输入 gei yu 时，在候选项的 comment 显示正确读音
    示例：「按耐」的正确写法是「按捺」，当用户输入「按耐」时，在候选项的 comment 显示正确写法
    为了让这个 Lua 同时适配全拼与双拼，使用 `spelling_hints` 生成的 comment（全拼拼音）作为通用的判断条件。
    感谢大佬@[Shewer Lu](https://github.com/shewer)提供的思路。

    容错词在 dicts/rime_ice.others.dict.yaml 中，定期同步 雾凇拼音 ，有新增建议可以在 雾凇拼音 地址提个 issue（嘿嘿）
--]]
local Corrector = {} -- 定义一个名为 Corrector 的本地表，用于组织脚本的功能和数据。

local DefaultTable = require("data.corrector")

function Corrector.init(env)                                                                  -- 定义 Corrector 表的初始化函数，接收一个 env 参数（通常是 Rime 引擎环境）。
    local config = env.engine.schema.config                                                   -- 从 Rime 环境中获取配置对象。
    local delimiter = config:get_string('speller/delimiter')                                  -- 从配置中读取 'speller/delimiter'（拼写分隔符）的字符串值。
    env.name_space = env.name_space:gsub('^*', '')                                            -- 移除 env.name_space 字符串可能存在的前导星号 '*'。
    -- 是否保持原有注释
    Corrector.keep_source_comment = config:get_bool(env.name_space .. "/keep_source_comment") -- 从配置中读取布尔值，决定是否保留原始注释。配置键由 env.name_space(此处为corrector_filter, 配置字段名) 和 "/keep_source_comment" 拼接而成。
    if delimiter and #delimiter > 0 and delimiter:sub(1, 1) ~= ' ' then                       -- 如果分隔符存在、长度大于0，并且第一个字符不是空格，则进行处理。
        env.delimiter = delimiter:sub(1, 1)                                                   -- 将 env.delimiter 设置为获取到的分隔符的第一个字符。
    end
    env.name_space = env.name_space:gsub('^*', '')                                            -- 再次移除 env.name_space 字符串可能存在的前导星号 '*'。
    Corrector.style = config:get_string(env.name_space .. "/style") or
        '{comment}'                                                                           -- 从配置中读取注释的显示样式，配置键为 env.name_space/style 的值。如果未找到，则默认为 '{comment}'。
    Corrector.corrections = DefaultTable
end

function Corrector.func(input, env) -- 定义 Corrector 表的核心处理函数 func，接收输入候选项列表 input 和 Rime 环境 env。
    for cand in input:iter() do -- 遍历输入候选项列表中的每一个候选项 (cand)。
        -- cand.comment 是目前输入的词汇的完整拼音
        local pinyin = cand.comment:match("^［(.-)］$") -- 从候选项的注释 (cand.comment) 中提取拼音。
        if pinyin and #pinyin > 0 then -- 如果成功提取到拼音且拼音字符串不为空，则继续处理。
            if env.delimiter then -- 如果在环境中设置了自定义分隔符 (env.delimiter)。
                pinyin = pinyin:gsub(env.delimiter, ' ') -- 将拼音字符串中的自定义分隔符替换为空格，以便与 corrections 表中的键格式一致。
            end
            local c = Corrector.corrections[pinyin] -- 根据处理后的拼音在 corrections 表中查找对应的校正项。
            if c and cand.text == c.text then -- 如果找到了校正项 (c)，并且当前候选项的文本 (cand.text) 与校正项中的文本 (c.text) 相同。
                cand:get_genuine().comment = string.gsub(Corrector.style, "{comment}", c.comment) -- 更新候选项的实际注释。使用 Corrector.style 指定的格式，并将 "{comment}" 替换为校正项中的正确注释 (c.comment)。
            else -- 如果没有找到匹配的校正项，或者候选项文本与校正项文本不符。
                if Corrector.keep_source_comment then -- 检查是否设置了 Corrector.keep_source_comment (在 init 函数中初始化)。
                    cand:get_genuine().comment = string.gsub(Corrector.style, "{comment}", pinyin) -- 如果需要保留原始注释，则使用 Corrector.style 指定的格式，并将 "{comment}" 替换为从候选项提取的原始拼音。
                else -- 如果不需要保留原始注释。
                    cand:get_genuine().comment = "" -- 将候选项的实际注释设置为空字符串。
                end
            end
        end
        yield(cand) -- 将处理后（可能已修改注释）的候选项传递给下一个处理器。
    end
end

return Corrector
