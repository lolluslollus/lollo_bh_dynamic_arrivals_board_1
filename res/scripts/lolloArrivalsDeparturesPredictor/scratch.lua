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


local dummy = 123
