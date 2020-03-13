local CPU = require 'cpu'

local key_mapping = {
    ["1"] = 0x1,
    ["2"] = 0x2,
    ["3"] = 0x3,
    ["4"] = 0xC,
    ["q"] = 0x4,
    ["w"] = 0x5,
    ["e"] = 0x6,
    ["r"] = 0xD,
    ["a"] = 0x7,
    ["s"] = 0x8,
    ["d"] = 0x9,
    ["f"] = 0xE,
    ["z"] = 0xA,
    ["x"] = 0x0,
    ["c"] = 0xB,
    ["v"] = 0xF
}

function love.load(arg)
    --min_dt = 1/60--60 --fps
    --next_time = love.timer.getTime()
    --debug.debug()
    canvas = love.graphics.newCanvas(64*8, 32*8)

    CPU:init()

    local romfile = arg[1] or "mini-lights-out.ch8"
    local file = love.filesystem.newFile("ROM/" .. romfile)
    local ok, err = file:open("r")
    if ok then
        CPU.rom_loaded = true
        CPU:read_rom(file)
    else
        print(err)
        CPU.rom_loaded = false
    end
    file:close()

    moonshine = require 'moonshine'
    effect = moonshine(64*8, 32*8, moonshine.effects.scanlines)
        .chain(moonshine.effects.glow)
        .chain(moonshine.effects.chromasep)
        .chain(moonshine.effects.crt)
    effect.chromasep.angle = 0.15
    effect.chromasep.radius = 2
    effect.scanlines.width = 1
    effect.crt.distortionFactor = {1.02, 1.065}
    effect.glow.strength = 3
    effect.glow.min_luma = 0.9
end

function love.filedropped(file)
    CPU:init()

    local ok, err = file:open("r")
    if ok then
        CPU:read_rom(file)
        CPU.rom_loaded = true
    else
        print(err)
        CPU.rom_loaded = false
    end
    file:close()
end

function love.update(dt)
    if CPU.rom_loaded and not pause then
        if CPU.delay > 0 then CPU.delay = CPU.delay - 1 end
        if CPU.sound > 0 then CPU.sound = CPU.sound - 1 end
        --next_time = next_time + min_dt

        for i=1,30 do
            local opcode = CPU:cycle()
            CPU:decode(opcode)
        end
    end
end

function love.draw()
    if CPU.display then
        if CPU.drawflag then
            love.graphics.setCanvas(canvas)
            love.graphics.clear()
            --love.graphics.setColor(1,1,1)
            for x=0,63 do
                for y=0,31 do
                    if CPU.screen[x][y]==1 then
                        love.graphics.rectangle("fill", x*8, y*8, 8, 8)
                    end
                end
            end
            love.graphics.setCanvas()
            CPU.drawflag = false
        end

        effect(function() love.graphics.draw(canvas) end)
    end

    local y = 0
    for i= CPU.pc -16, CPU.pc + 16, 2 do
        if i == CPU.pc then
            love.graphics.print(">", 590, y)
        end
        love.graphics.print(string.format("%03x", i) .. ": " .. string.format("%02x%02x", CPU.rom[i], CPU.rom[i+1]), 600, y)
        y = y + 12
    end
    y = 0
    for i = 0, #CPU.v do
        love.graphics.print("V" .. string.format("%x", i) .. ": " .. CPU.v[i], 670, y)
        y = y + 12
    end
    love.graphics.print("I: " .. string.format("%03x", CPU.i), 740, 0)
    love.graphics.print("D: " .. CPU.delay, 740, 10)
    love.graphics.print("T: " .. CPU.sound, 740, 20)
    y = 25
    for i = #CPU.stack, 1, -1 do
        love.graphics.print(string.format("%03x", CPU.stack[i]), 740, 10 + y)
        y = y + 12
    end
    local x = 600
    y = 200
    local k = 0
    for y = 200, 238, 12 do
        for x = 600, 630, 10 do
            if CPU.key_status[k] then love.graphics.setColor(1, 0, 0) end
            love.graphics.print(string.format("%x", k), x, y)
            k = k + 1
            love.graphics.setColor(1, 1, 1)
        end
    end


    --[[if not pause then
        local cur_time = love.timer.getTime()
        if next_time <= cur_time then
            next_time = cur_time
            return
        end
        love.timer.sleep(next_time - cur_time)
    end]]
end

function love.keypressed(key)
    -- TODO: VIP used the sound timer for this, so a sound should be emitted while a key is held down
    if key_mapping[key] then
        CPU.key_status[key_mapping[key]] = true
    end

    if key == "space" then pause = not pause end
    if pause and key == "right" then
        if CPU.delay > 0 then CPU.delay = CPU.delay - 1 end
        if CPU.sound > 0 then CPU.sound = CPU.sound - 1 end
        --next_time = next_time + min_dt
        CPU:decode(CPU:cycle())
    end
end

function love.keyreleased(key)
    -- TODO: VIP used the sound timer for this, so a sound should be emitted while a key is held down
    if key_mapping[key] then
        CPU.key_status[key_mapping[key]] = false
    end
end
