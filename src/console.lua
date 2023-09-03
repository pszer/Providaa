-- console
--
--

local utf8 = require("utf8")

Console = {
	text = "",
	text_draw = nil,

	open_flag = false
}
Console.__index = self

function Console.open()
	love.keyboard.setKeyRepeat(true)
	Console.text_draw = love.graphics.newText(love.graphics.getFont(), Console.text)
	Console.open_flag = true
end

function Console.keypressed(key)
	if key == "backspace" then
		-- get the byte offset to the last UTF-8 character in the string.
		local byteoffset = utf8.offset(Console.text, -1)
		if byteoffset then
		-- remove the last UTF-8 character.
		-- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
		Console.text = string.sub(Console.text, 1, byteoffset - 1)
        end
	elseif key == "return" then
		local code = "do "..Console.text.." end"
		print("CONSOLE:", code)
		local ok, func = pcall(loadstring,code)
		if ok then
			func()
		end

		Console.text = ""
	elseif key == "escape" or key == "f8" then
		Console.open_flag = false
    end
end

function Console.textinput(t)
	Console.text = Console.text .. t
end

function Console.draw()
	love.graphics.push("all")
	love.graphics.reset()
	love.graphics.setColor(0,0,0,1)
	local w,h = Console.text_draw:getWidth(), Console.text_draw:getHeight()
	love.graphics.rectangle("fill",0,0,1500,64)
	love.graphics.setColor(1,1,1,1)
	Console.text_draw:set(Console.text)
	love.graphics.draw(Console.text_draw, 16,16)
	love.graphics.pop()
end

function Console.isOpen()
	return Console.open_flag
end
