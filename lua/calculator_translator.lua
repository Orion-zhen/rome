-- 簡易計算器（執行任何Lua表達式）
-- 来源: https://github.com/baopaau/rime-lua-collection/blob/master/calculator_translator.lua

-- Mintimate 修改:
--   1. 解决了 鼠须管输入法 调用可能存在的问题。
--   2. 优化了代码结构。
--   3. 动态获取触发前缀。

-- Refactored by Agent:
--   1. 消除全局变量污染
--   2. 使用沙盒环境 (Sandbox) 执行代码，提升安全性
--   3. 优化代码逻辑和安全性检查

-- Create the restricted environment for calculator execution
local function create_env()
    local math = math
    local table = table
    local string = string
    
    local E = {}

    -- Proxy standard math functions
    E.abs = math.abs
    E.acos = math.acos
    E.asin = math.asin
    E.atan = math.atan
    E.ceil = math.ceil
    E.cos = math.cos
    E.deg = math.deg
    E.exp = math.exp
    E.floor = math.floor
    E.fmod = math.fmod
    E.huge = math.huge -- inf
    E.log = math.log -- Will be overwritten by custom log
    E.maxinteger = math.maxinteger -- MAX_INT
    E.mininteger = math.mininteger -- MIN_INT
    E.modf = math.modf
    E.pi = math.pi
    E.rad = math.rad
    E.random = math.random
    E.randomseed = math.randomseed
    E.sin = math.sin
    E.sqrt = math.sqrt
    E.tan = math.tan
    E.tointeger = math.tointeger
    E.type = type
    -- E.ult = math.ult -- Lua 5.3+

    -- Aliases and Constants
    E.inf = math.huge
    E.MAX_INT = math.maxinteger
    E.MIN_INT = math.mininteger
    E.e = math.exp(1)
    E.ln = math.log
    
    -- Fixed random value (preserved from original behavior, though arguable)
    E.rdm = math.random()

    -- Custom Math Functions
    E.mod = math.fmod
    
    E.trunc = function(x, dc)
        if dc == nil then
            return math.modf(x)
        end
        return x - E.mod(x, dc)
    end

    E.round = function(x, dc)
        dc = dc or 1
        local dif = E.mod(x, dc)
        if E.abs(dif) > dc / 2 then
            return x < 0 and x - dif - dc or x - dif + dc
        end
        return x - dif
    end

    -- Custom log with base support
    E.log = function(x, base)
        base = base or 10
        return math.log(x) / math.log(base)
    end

    -- Custom Array/List Functions
    -- Min/Max for arrays
    E.min = function(arr)
        local m = E.inf
        for k, x in ipairs(arr) do
            m = x < m and x or m
        end
        return m
    end

    E.max = function(arr)
        local m = -E.inf
        for k, x in ipairs(arr) do
            m = x > m and x or m
        end
        return m
    end

    E.sum = function(t)
        local acc = 0
        for k, v in ipairs(t) do
            acc = acc + v
        end
        return acc
    end

    E.avg = function(t)
        return E.sum(t) / #t
    end

    E.isinteger = function(x)
        return math.fmod(x, 1) == 0
    end

    -- Iterators & Generators
    -- array(...) creates an array from an iterator
    E.array = function(...)
        local arr = {}
        for v in ... do
            arr[#arr + 1] = v
        end
        return arr
    end

    E.irange = function(from, to, step)
        if to == nil then
            to = from
            from = 0
        end
        step = step or 1
        local i = from - step
        to = to - step
        return function()
            if i < to then
                i = i + step
                return i
            end
        end
    end

    E.range = function(from, to, step)
        return E.array(E.irange(from, to, step))
    end

    E.irev = function(arr)
        local i = #arr + 1
        return function()
            if i > 1 then
                i = i - 1
                return arr[i]
            end
        end
    end

    E.arev = function(arr)
        return E.array(E.irev(arr))
    end

    -- Functional Programming Helpers
    E.test = function(f, t)
        for k, v in ipairs(t) do
            if not f(v) then
                return false
            end
        end
        return true
    end

    E.map = function(t, ...)
        local ta = {}
        local funcs = {...}
        for k, v in pairs(t) do
            local tmp = v
            for _, f in ipairs(funcs) do
                tmp = f(tmp)
            end
            ta[k] = tmp
        end
        return ta
    end

    E.filter = function(t, ...)
        local ta = {}
        local i = 1
        local funcs = {...}
        for k, v in pairs(t) do
            local erase = false
            for _, f in ipairs(funcs) do
                if not f(v) then
                    erase = true
                    break
                end
            end
            if not erase then
                ta[i] = v
                i = i + 1
            end
        end
        return ta
    end

    E.foldr = function(t, f, acc)
        for k, v in pairs(t) do
            acc = f(acc, v)
        end
        return acc
    end

    E.foldl = function(t, f, acc)
        for v in E.irev(t) do
            acc = f(acc, v)
        end
        return acc
    end

    E.chain = function(t)
        local ta = t
        local function cf(f, ...)
            if f ~= nil then
                ta = f(ta, ...)
                return cf
            else
                return ta
            end
        end
        return cf
    end

    -- Statistics & Math Utils
    E.fac = function(n)
        local acc = 1
        for i = 2, n do
            acc = acc * i
        end
        return acc
    end
    -- Alias for factorial used in expressions like 5!
    E.factorial = E.fac

    E.nPr = function(n, r)
        return E.fac(n) / E.fac(n - r)
    end

    E.nCr = function(n, r)
        return E.nPr(n, r) / E.fac(r)
    end

    E.MSE = function(t)
        local ss = 0
        local s = 0
        local n = #t
        for k, v in ipairs(t) do
            ss = ss + v * v
            s = s + v
        end
        return E.sqrt((n * ss - s * s) / (n * n))
    end

    -- Calculus
    E.lapproxd = function(f, delta)
        local delta = delta or 1e-8
        return function(x)
            return (f(x + delta) - f(x)) / delta
        end
    end

    E.sapproxd = function(f, delta)
        local delta = delta or 1e-8
        return function(x)
            return (f(x + delta) - f(x - delta)) / delta / 2
        end
    end

    E.deriv = function(f, delta, dc)
        dc = dc or 1e-4
        local fd = E.sapproxd(f, delta)
        return function(x)
            return E.round(fd(x), dc)
        end
    end

    E.trapzo = function(f, a, b, n)
        local dif = b - a
        local acc = 0
        for i = 1, n - 1 do
            acc = acc + f(a + dif * (i / n))
        end
        acc = acc * 2 + f(a) + f(b)
        acc = acc * dif / n / 2
        return acc
    end

    E.integ = function(f, delta, dc)
        delta = delta or 1e-4
        dc = dc or 1e-4
        return function(a, b)
            if b == nil then
                b = a
                a = 0
            end
            local n = E.round(E.abs(b - a) / delta)
            return E.round(E.trapzo(f, a, b, n), dc)
        end
    end

    E.rk4 = function(f, timestep)
        local timestep = timestep or 0.01
        return function(start_x, start_y, time)
            local x = start_x
            local y = start_y
            local t = time
            for i = 0, t, timestep do
                local k1 = f(x, y)
                local k2 = f(x + (timestep / 2), y + (timestep / 2) * k1)
                local k3 = f(x + (timestep / 2), y + (timestep / 2) * k2)
                local k4 = f(x + timestep, y + timestep * k3)
                y = y + (timestep / 6) * (k1 + 2 * k2 + 2 * k3 + k4)
                x = x + timestep
            end
            return y
        end
    end

    -- System / Metadata (Preserved from original)
    E.date = os.date
    E.time = os.time
    
    -- Safe path function
    E.path = function()
        -- Attempt to get source path safely
        local info = debug.getinfo(1)
        if info and info.source then
            return info.source:match("@?(.*/)")
        end
        return ""
    end

    return E
end

-- Initialize the environment table once
-- This table mimics the environment the scripts expect
local Env = create_env()

-- Helper function to replace 3! with factorial(3)
-- This is a syntax transformation, not an Env function
local function replaceToFactorial(str)
    return str:gsub("([0-9]+)!", "factorial(%1)")
end

local function serialize(obj)
    local type_name = type(obj)
    if type_name == "number" then
        return Env.isinteger(obj) and Env.floor(obj) or obj
    elseif type_name == "boolean" then
        return tostring(obj)
    elseif type_name == "string" then
        return '"' .. obj .. '"'
    elseif type_name == "table" then
        local str = "{"
        local i = 1
        for k, v in pairs(obj) do
            if i ~= k then
                str = str .. "[" .. serialize(k) .. "]="
            end
            str = str .. serialize(v) .. ", "
            i = i + 1
        end
        str = str:len() > 3 and str:sub(0, -3) or str
        return str .. "}"
    elseif type_name == "function" then
        return "callable"
    end
    return tostring(obj)
end

-- 是否随时计算
local ImmediateCalculation = true

local function calculator_translator(input, seg, env)
    -- 获取 recognizer/patterns/expression 的第 2 个字符作为触发前缀（也就是获取等于号 = 或其他自定义字符）
    local expression_keyword = env.engine.schema.config:get_string('recognizer/patterns/expression'):sub(2, 2)

    -- 如果当前输入的是触发前缀，则尝试解析输入的 Lua 表达式，其中 seg:has_tag 判断是否是候选词；否则返回
    if not (seg:has_tag("expression") and expression_keyword ~= '' and input:sub(1, 1) == expression_keyword) then
        return
    end

    -- 解决 鼠须管 单个 input 字直接上屏问题
    if string.len(input) < 2 then
        return
    end

    -- 匹配结束标记字符
    local expfin = ImmediateCalculation or input:sub(-1, -1) == ";"
    if not expfin then
        return
    end

    local exp = (ImmediateCalculation or not expfin) and input:sub(2, -1) or input:sub(2, -2)

    -- 空格输入可能
    exp = exp:gsub("#", " ")

    local expe = exp
    -- 链式调用语法糖: $ -> chain
    expe = expe:gsub("%$", " chain ")
    
    -- lambda語法糖: \x.x+1| -> (function (x) return x+1 end)
    do
        local count
        repeat
            expe, count = expe:gsub("\\%s*([%a%d%s,_]-)%s*%.(.-)|", " (function (%1) return %2 end) ")
        until count == 0
    end

    -- 仅作为调试输出，正式使用时可注释
    -- yield(Candidate("number", seg.start, seg._end, expe, "展开"))

    -- 在计算前先处理阶乘表达式
    local processed_exp = replaceToFactorial(expe)

    -- 安全执行环境加载
    -- 使用 load 而不是 loadstring 以支持环境表 (Lua 5.2+)
    -- 第三个参数 't' 表示只加载文本块，防止二进制代码攻击
    -- 第四个参数 Env 为受限环境
    local chunk, err = load("return " .. processed_exp, "calculator", "t", Env)

    if not chunk then
        -- 编译错误（语法错误等）
        -- yield(Candidate("error", seg.start, seg._end, "Syntax Error", ""))
        return
    end

    -- 使用 pcall 捕获运行时错误
    local status, result = pcall(chunk)

    if not status then
        -- 运行时错误
        return
    end
    
    if result == nil then
        return
    end

    local formatted_result = serialize(result)
    yield(Candidate("number", seg.start, seg._end, formatted_result, "答案"))
    yield(Candidate("number", seg.start, seg._end, exp .. " = " .. formatted_result, "等式"))
end

return calculator_translator
