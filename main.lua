bit = bit or bit32

key_mapping = {
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

key_status = {}

instructions = {}

instructions[0x0000] = function(opcode)
    -- 0NNN: call machine language at 0NNN
    -- We only implement the ones defined by the CHIP-8 specification
    -- as well as the display related ones
    if bit.band(opcode, 0x0FF) == 0x04B then
        -- 004B: turn on display
        display = true
    elseif bit.band(opcode, 0x00FF) == 0x00E0 then
        -- 00E0: clear screen
        for x=0,63 do
            for y=0,31 do
                screen[x][y] = 0
            end
        end
    elseif bit.band(opcode, 0x00FF) == 0x00EE then
        -- 00EE: return
        pc = stack:pop()
    elseif bit.band(opcode, 0x00FF) == 0x00FC then
        -- 00FV: turn off display
        display = false
        print("Warning: Display turned off by opcode 00FC")
    else
        print("undefined opcode 0000 at " .. pc)
    end
end
instructions[0x1000] = function(opcode)
    -- 1NNN: jump
    local nnn = bit.band(opcode, 0x0FFF)
    pc = nnn
end
instructions[0x2000] = function(opcode)
    -- 2NNN: call
    local nnn = bit.band(opcode, 0x0FFF)
    stack:push(pc)
    pc = nnn
end
instructions[0x3000] = function(opcode)
    -- 3XNN: skip if VX == NN
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local nn = bit.band(opcode, 0x00FF)
    if v[x] == nn then
        pc = pc + 2
    end
end
instructions[0x4000] = function(opcode)
    -- 4XNN: skip if VX != NN
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local nn = bit.band(opcode, 0x00FF)
    if v[x] ~= nn then
        pc = pc + 2
    end
end
instructions[0x5000] = function(opcode)
    -- 5XY0: skip if VX == VY
    if bit.band(opcode, 0x000F) ~= 0 then
        print("undefined opcode 5XYN")
        return
    end
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local y = bit.rshift(bit.band(opcode, 0x00F0), 4)
    if v[x] == v[y] then
        pc = pc + 2
    end
end
instructions[0x6000] = function(opcode)
    -- 6XNN: VX = NN
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local nn = bit.band(opcode, 0x00FF)
    v[x] = nn
end
instructions[0x7000] = function(opcode)
    -- 7XNN: VX += NN
    -- Note: Does not affect VF
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local nn = bit.band(opcode, 0x00FF)
    v[x] = v[x] + nn
    v[x] = v[x] % 256
end
instructions[0x8000] = function(opcode)
    -- 8XYN: dispatch to RCA subroutine N
    -- VF should be changed by some or all of these, but I'm not sure how.
    local rca = bit.band(opcode, 0x000F)
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local y = bit.rshift(bit.band(opcode, 0x00F0), 4)

    if rca == 0 then
        -- 8XY0: VX = VY
        v[x] = v[y]
    elseif rca == 1 then
        -- 8XY1: VX |= VY
        -- TODO: should change VF, but how?
        v[x] = bit.bor(v[x], v[y])
    elseif rca == 2 then
        -- 8XY2: VX &= VY
        -- TODO: should change VF, but how?
        v[x] = bit.band(v[x], v[y])
    elseif rca == 3 then
        -- 8XY3: VX ^= VY
        v[x] = bit.bxor(v[x], v[y])
    elseif rca == 4 then
        -- 8XY4: VX += VY
        v[x] = v[x] + v[y]
        if v[x] >= 256 then
            v[0xF] = 1
            v[x] = v[x] % 256
        else
            v[0xF] = 0
        end
    elseif rca == 5 then
        -- 8XY5: VX -= VY
        v[0xF] = v[x] >= v[y] and 1 or 0
        v[x] = v[x] - v[y]
        v[x] = v[x] % 256
    elseif rca == 6 then
        -- 8XY6: VX >>= VY
        v[0xF] = bit.band(v[x], 1)
        v[x] = bit.rshift(v[x], 1)
    elseif rca == 7 then
        -- 8XY7: VX = VY - VX
        v[0xF] = v[y] > v[x] and 1 or 0
        v[x] = v[y] - v[x]
        v[x] = v[x] % 256
    elseif rca == 0xE then
        -- 8XYE: VX <<= VY
        v[0xF] = bit.band(v[x], 0x80)
        v[0xF] = bit.rshift(v[0xF], 7)
        v[x] = bit.lshift(v[x], 1)
        v[x] = v[x] % 256
    else
        print("undefined opcode 8000")
    end
end
instructions[0x9000] = function(opcode)
    -- 9XY0: skip if VX != VY
    if bit.band(opcode, 0x000F) ~= 0 then
        print("undefined opcode 9XYN")
        return
    end
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local y = bit.rshift(bit.band(opcode, 0x00F0), 4)
    if v[x] ~= v[y] then
        pc = pc + 2
    end
end
instructions[0xA000] = function(opcode)
    -- ANNN: I = NNN
    local nnn = bit.band(opcode, 0x0FFF)
    i = nnn
end
instructions[0xB000] = function(opcode)
    -- BNNN: jump to V0 + NNN
    local nnn = bit.band(opcode, 0x0FFF)
    pc = nnn + v[0]
end
instructions[0xC000] = function(opcode)
    -- CXNN: VX = random() & NN
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local nn = bit.band(opcode, 0x00FF)
    local random = love.math.random(0, 255)
    v[x] = bit.band(random, nn)
    -- TODO or just love.math.random(0, nn) ?
end
instructions[0xD000] = function(opcode)
    -- DXYN: draw N-pixel tall sprite at VX,VY
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local y = bit.rshift(bit.band(opcode, 0x00F0), 4)
    x = v[x]
    y = v[y]
    local n = bit.band(opcode, 0x000F)
    if n == 0 then
        print("undefined opcode DXY0")
        return
    end
    v[0xF] = 0
    for m=0,n-1 do
        local byte = rom[i+m]
        for x2 = x+7, x, -1 do
            xx = x2 % 64
            local yy = (y+m) % 32
            local pixel = screen[xx][yy]
            local pixel2 = bit.band(byte, 1)
            if bit.band(pixel, pixel2) == 1 then
                v[0xF] = 1
            end
            screen[xx][yy] = bit.bxor(pixel, pixel2)
            byte = bit.rshift(byte, 1)
        end
    end
end
instructions[0xE000] = function(opcode)
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    if bit.band(opcode, 0x00FF) == 0x009E then
        -- EX9E: skip if key VX is pressed
        -- TODO what if v[x] > 0xf?
        if key_status[v[x]] then
            pc = pc + 2
        end
    elseif bit.band(opcode, 0x00FF) == 0x00A1 then
        -- EX9E: skip if key VX is not pressed
        -- TODO what if v[x] > 0xf?
        if not key_status[v[x]] then
            pc = pc + 2
        end
    else
        print("undefined opcode E000 at " .. (pc - 1))
    end
end
instructions[0xF000] = function(opcode)
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local instruction = bit.band(opcode, 0x00FF)

    if instruction == 0x07 then
        -- FX07: VX = delay timer
        v[x] = delay
    elseif instruction == 0x0A then
        -- FX0A: block for VX = keypress
        for i=0,0xF do
            if key_status[i] then
                v[x] = i
                return
            end
        end
        pc = pc - 2
    elseif instruction == 0x15 then
        -- FX15: delay timer = VX
        delay = v[x]
    elseif instruction == 0x18 then
        -- FX18: sound timer = VX
        sound = v[x]
    elseif instruction == 0x1E then
        -- FX1E: I += VX
        i = i + v[x]
    elseif instruction == 0x29 then
        -- FX29: I = address of character in VX
        i = 0x050 + (v[x] * 5) -- TODO: hva med sifre over F?
    elseif instruction == 0x33 then
        -- FX33: put BCD representation of VX in three bytes pointed at by I
        local bcd = v[x]
        rom[i + 2] = bcd % 10
        bcd = math.floor(bcd / 10)
        rom[i + 1] = bcd % 10
        bcd = math.floor(bcd / 10)
        rom[i] = bcd
    elseif instruction == 0x55 then
        -- FX55: store V0 through VX to addresses pointed at by I
        for j=0,x do
            rom[i+j] = v[j]
        end
        --i = i + x + 1
    elseif instruction == 0x65 then
        -- FX65: load bytes from addresses pointed at by I into V0 through VX
        for j=0,x do
           v[j] = rom[i+j]
        end
        --i = i + x + 1
    else
        print("undefined opcode " .. opcode)
    end
end

function decode(opcode)
    local opcode2 = bit.band(opcode, 0xF000)
    instructions[opcode2](opcode)
end

function read_rom(file)
    -- The font, originally located at memory page 81
    -- with a jump table at location 00 and numbers at (in ascending order)
    -- 30, 39, 22, 2A, 3E, 20, 24, 34, 26, 28, 2E, 18, 14, 1C, 10, 12
    -- We just store them consecutively here for convenience
    local fontset = {
        0xF0, 0x90, 0x90, 0x90, 0xF0, -- 0
        0x20, 0x60, 0x20, 0x20, 0x70, -- 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, -- 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, -- 3
        0x90, 0x90, 0xF0, 0x10, 0x10, -- 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, -- 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, -- 6
        0xF0, 0x10, 0x20, 0x40, 0x40, -- 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, -- 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, -- 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, -- A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, -- B
        0xF0, 0x80, 0x80, 0x80, 0xF0, -- C
        0xE0, 0x90, 0x90, 0x90, 0xE0, -- D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, -- E
        0xF0, 0x80, 0xF0, 0x80, 0x80  -- F
    }

    -- The CHIP-8 program actually starts at 01FC, by first clearing
    -- the screen, and then turning on the display. In case any ROMs
    -- actually do this during execution, we make sure to adhere to this.
    rom[0x1FD] = 0xE0
    rom[0x1FF] = 0x4B

    for i, byte in ipairs(fontset) do
        rom[0x050+(i-1)] = byte
    end

    local address = 0x200
    while (not file:isEOF()) do 
        -- TODO: should be 0x69F with 2K RAM
        if address > 0xE8F then
            print("Warning: ROM spills into VIP memory reserved for variables and display refresh")
        end

        local byte, len = file:read(1)
        -- Dropped files don't seem to report EOF
        if len ~= 1 or not string.byte(byte) then
            break
        end
        rom[address] = string.byte(byte)
        address = address + 1
    end
end

function cpu_init()
    rom = {}
    for i=0,0xFFF do
        rom[i] = 0
    end

    for i=0x0,0xF do
        key_status[i] = false
    end

    v = {}
    for x=0,0xF do
        v[x] = 0
    end
    i = 0
    delay = 0
    sound = 0

    stack = {}
    function stack:pop()
        if #self == 0 then
            print("Attempted to pop empty stack!")
        end
        return table.remove(self)
    end
    function stack:push(element)
        table.insert(self, element)
        if #self > 12 then
            print("Warning: VIP stack limit reached")
        end
    end

    screen = {}
    for x=0,63 do
        screen[x] = {}
    end

    pc = 0x1FC
end

function cycle()
    local byte1 = rom[pc]
    local byte2 = rom[pc+1]

    local opcode = bit.bor(bit.lshift(byte1, 8), byte2)

    pc = pc + 2

    return opcode
end

function love.load(arg)
    rom_loaded = false

    cpu_init()

    local romfile = arg[1] or "mini-lights-out.ch8"
    local file = love.filesystem.newFile("ROM/" .. romfile)
    local ok, err = file:open("r")
    if ok then
        rom_loaded = true
        read_rom(file)
    else
        print(err)
        rom_loaded = false
    end
    file:close()
end

function love.filedropped(file)
    cpu_init()

    local ok, err = file:open("r")
    if ok then
        read_rom(file)
        rom_loaded = true
    else
        print(err)
        rom_loaded = false
    end
    file:close()
end

function love.update(dt)
    if rom_loaded and not pause then
        if delay > 0 then delay = delay - 1 end
        if sound > 0 then sound = sound - 1 end

        local opcode = cycle()

        decode(opcode)
    end
end

function love.draw()
    if display then
        love.graphics.setColor(1,1,1)
        for x=0,63 do
            for y=0,31 do
                if screen[x][y]==1 then
                    love.graphics.rectangle("fill", x*8, y*8, 8, 8)
                end
            end
        end
    end

    local y=0
    for i=pc-16,pc+16,2 do
        if i == pc then
            love.graphics.print(">", 590, y)
        end
        love.graphics.print(string.format("%03x", i) .. ": " .. string.format("%02x%02x", rom[i], rom[i+1]), 600, y)
        y = y+10
    end
    y=0
    for i=0,#v do
        love.graphics.print("V" .. string.format("%x", i) .. ": " .. v[i], 670, y)
        y = y+10
    end
    love.graphics.print("I: " .. string.format("%03x", i), 740, 0)
    love.graphics.print("D: " .. delay, 740, 10)
    love.graphics.print("T: " .. sound, 740, 20)
    y=25
    for i=#stack,1,-1 do
        love.graphics.print(string.format("%03x", stack[i]), 740, 10+y)
        y = y + 10
    end
    local x=600
    y=200
    local k=0
    for y=200,230,10 do
        for x=600,630,10 do
            if key_status[k] then love.graphics.setColor(1,0,0) end
            love.graphics.print(string.format("%x", k),x,y)
            k = k + 1
            love.graphics.setColor(1,1,1)
        end
    end
end

function love.keypressed(key)
    if key_mapping[key] then
        key_status[key_mapping[key]] = true
    end

    if key == "space" then pause = not pause end
    if pause and key == "right" then
        if delay > 0 then delay = delay - 1 end
        if sound > 0 then sound = sound - 1 end
        decode(cycle())
    end
end

function love.keyreleased(key)
    if key_mapping[key] then
        key_status[key_mapping[key]] = false
    end
end
