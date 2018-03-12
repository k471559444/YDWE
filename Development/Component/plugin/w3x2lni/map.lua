require 'filesystem'
require 'utility'
local lni = require 'lni'
local uni = require 'ffi.unicode'
local core = require 'tool.sandbox_core'
local builder = require 'map-builder'
local triggerdata = require 'tool.triggerdata'
local w2l = core()

local std_print = print
function print(...)
    local tbl = {...}
    local count = select('#', ...)
    for i = 1, count do
        tbl[i] = tostring(tbl[i]):gsub('[\r\n]', ' ')
    end
    std_print(table.concat(tbl, ' '))
end
w2l:set_messager(print)

local root = fs.current_path():remove_filename()

local function unpack_config()
    local config = lni(io.load(root / 'config.ini'))
    for _, command in ipairs(arg) do
        if command:sub(1, 1) == '-' then
            if command == '-slk' then
                config.mode = 'slk'
            elseif command == '-lni' then
                config.mode = 'lni'
            elseif command == '-obj' then
                config.mode = 'obj'
            end
        else
            if not config.input then
                config.input = fs.path(command)
            else
                config.output = fs.path(command)
            end
        end
    end
    for k, v in pairs(config[config.mode]) do
        config[k] = v
    end
    return config
end

local function default_output(input)
    if w2l.config.target_storage == 'dir' then
        if fs.is_directory(input) then
            return input:parent_path() / (input:filename():string() .. '_' .. w2l.config.mode)
        else
            return input:parent_path() / input:stem():string()
        end
    elseif w2l.config.target_storage == 'mpq' then
        if fs.is_directory(input) then
            return input:parent_path() / (input:filename():string() .. '.w3x')
        else
            return input:parent_path() / (input:stem():string() .. '_' .. w2l.config.mode .. '.w3x')
        end
    end
end

local config = unpack_config()
w2l:set_config(config)

local input = config.input
print('正在打开地图...')
local slk = {}
local input_ar = builder.load(input)
if not input_ar then
    return
end

local output = config.output or default_output(config.input)
if w2l.config.target_storage == 'dir' then
    fs.create_directories(output)
end
local output_ar = builder.load(output, 'w')
if not output_ar then
    return
end

function w2l:map_load(filename)
    return input_ar:get(filename)
end

function w2l:map_save(filename, buf)
    return input_ar:set(filename, buf)
end

function w2l:map_remove(filename)
    return input_ar:remove(filename)
end

function w2l:mpq_load(filename)
    return w2l.mpq_path:each_path(function(path)
        return io.load(root / 'data' / 'mpq' / path / filename)
    end)
end

function w2l:prebuilt_load(filename)
    return w2l.mpq_path:each_path(function(path)
        return io.load(root / 'data' / 'prebuilt' / path / filename)
    end)
end

function w2l:trigger_data()
    return triggerdata()
end

print('正在读取物编...')
w2l.progress:start(0.4)
w2l:frontend(slk)
w2l.progress:finish()

print('正在转换...')
w2l.progress:start(0.8)
w2l:backend(slk)
w2l.progress:finish()

print('正在生成文件...')
w2l.progress:start(1)
builder.save(w2l, output_ar, slk.w3i, input_ar)
w2l.progress:finish()
output_ar:close()
input_ar:close()
print('转换完毕,用时 ' .. os.clock() .. ' 秒') 