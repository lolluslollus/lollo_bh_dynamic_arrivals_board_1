package.path = package.path .. ';res/scripts/?.lua'

local aaa = { 1, 2, 3, 4}
table.remove(aaa, 2)

local function getBracketsContent(str1)
-- local str1 = 'aaaa(b12 _?) ajs'
-- local str2 = string.gsub(str1, '[^()]*%(', '')
local str2 = string.gsub(str1, '[^(]*%(', '')
-- local str3 = string.gsub(str2, '%)[^()]*', '')
local str3 = string.gsub(str2, '%)[^)]*', '')
return str3
end

local a = getBracketsContent('aaaa(b12 _?) ajs')
local b = getBracketsContent('(aaaab12 _?) ajs')
local c = getBracketsContent('(aaaab12 _?)')
local d = getBracketsContent('(aaaa(b12 _?) ajs')
local e = getBracketsContent('aaaab12 _? ajs')

local deltaI = 0
local _fetchNextDelta = function()
    -- + 1, -1, +2, -2, +3. -3 and so on
    if deltaI > 0 then deltaI = -deltaI else deltaI = -deltaI + 1 end
end

local aa = {}
for i = 1, 25, 1 do
    aa[i] = deltaI
    _fetchNextDelta()
end


local dummy = 123
