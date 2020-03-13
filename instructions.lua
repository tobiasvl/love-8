local bit = bit or require 'bit32'

local instructions = {}

instructions[0x0000] = function(cpu, opcode)
    -- 0NNN: call machine language at 0NNN
    -- We only implement the ones defined by the CHIP-8 specification
    -- as well as the display related ones
    if bit.band(opcode, 0x0FF) == 0x04B then
        -- 004B: turn on display
        cpu.display = true
    elseif bit.band(opcode, 0x00FF) == 0x00E0 then
        -- 00E0: clear screen
        for x=0,63 do
            for y=0,31 do
                cpu.screen[x][y] = 0
            end
        end
        cpu.drawflag = true
    elseif bit.band(opcode, 0x00FF) == 0x00EE then
        -- 00EE: return
        cpu.pc = cpu.stack:pop()
    elseif bit.band(opcode, 0x00FF) == 0x00FC then
        -- 00FC: turn off display
        cpu.display = false
        print("Warning: Display turned off by opcode 00FC")
    else
        print("undefined opcode 0000 at " .. cpu.pc)
    end
end
instructions[0x1000] = function(cpu, opcode)
    -- 1NNN: jump
    local nnn = bit.band(opcode, 0x0FFF)
    cpu.pc = nnn
end
instructions[0x2000] = function(cpu, opcode)
    -- 2NNN: call
    local nnn = bit.band(opcode, 0x0FFF)
    cpu.stack:push(cpu.pc)
    cpu.pc = nnn
end
instructions[0x3000] = function(cpu, opcode)
    -- 3XNN: skip if VX == NN
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local nn = bit.band(opcode, 0x00FF)
    if cpu.v[x] == nn then
        cpu.pc = cpu.pc + 2
    end
end
instructions[0x4000] = function(cpu, opcode)
    -- 4XNN: skip if VX != NN
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local nn = bit.band(opcode, 0x00FF)
    if cpu.v[x] ~= nn then
        cpu.pc = cpu.pc + 2
    end
end
instructions[0x5000] = function(cpu, opcode)
    -- 5XY0: skip if VX == VY
    if bit.band(opcode, 0x000F) ~= 0 then
        print("undefined opcode 5XYN")
        return
    end
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local y = bit.rshift(bit.band(opcode, 0x00F0), 4)
    if cpu.v[x] == cpu.v[y] then
        cpu.pc = cpu.pc + 2
    end
end
instructions[0x6000] = function(cpu, opcode)
    -- 6XNN: VX = NN
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local nn = bit.band(opcode, 0x00FF)
    cpu.v[x] = nn
end
instructions[0x7000] = function(cpu, opcode)
    -- 7XNN: VX += NN
    -- Note: Does not affect VF
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local nn = bit.band(opcode, 0x00FF)
    cpu.v[x] = cpu.v[x] + nn
    cpu.v[x] = cpu.v[x] % 256
end
instructions[0x8000] = function(cpu, opcode)
    -- 8XYN: dispatch to RCA subroutine N
    -- VF should be changed by some or all of these, but I'm not sure how.
    local rca = bit.band(opcode, 0x000F)
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local y = bit.rshift(bit.band(opcode, 0x00F0), 4)

    if rca == 0 then
        -- 8XY0: VX = VY
        cpu.v[x] = cpu.v[y]
    elseif rca == 1 then
        -- 8XY1: VX |= VY
        -- TODO: should change VF, but how?
        cpu.v[x] = bit.bor(cpu.v[x], cpu.v[y])
    elseif rca == 2 then
        -- 8XY2: VX &= VY
        -- TODO: should change VF, but how?
        cpu.v[x] = bit.band(cpu.v[x], cpu.v[y])
    elseif rca == 3 then
        -- 8XY3: VX ^= VY
        cpu.v[x] = bit.bxor(cpu.v[x], cpu.v[y])
    elseif rca == 4 then
        -- 8XY4: VX += VY
        cpu.v[x] = cpu.v[x] + cpu.v[y]
        if cpu.v[x] >= 256 then
            cpu.v[0xF] = 1
            cpu.v[x] = cpu.v[x] % 256
        else
            cpu.v[0xF] = 0
        end
    elseif rca == 5 then
        -- 8XY5: VX -= VY
        cpu.v[0xF] = cpu.v[x] >= cpu.v[y] and 1 or 0
        cpu.v[x] = cpu.v[x] - cpu.v[y]
        cpu.v[x] = cpu.v[x] % 256
    elseif rca == 6 then
        -- 8XY6: VX >>= VY
        cpu.v[0xF] = bit.band(cpu.v[x], 1)
        cpu.v[x] = bit.rshift(cpu.v[x], 1)
    elseif rca == 7 then
        -- 8XY7: VX = VY - VX
        cpu.v[0xF] = cpu.v[y] > cpu.v[x] and 1 or 0
        cpu.v[x] = cpu.v[y] - cpu.v[x]
        cpu.v[x] = cpu.v[x] % 256
    elseif rca == 0xE then
        -- 8XYE: VX <<= VY
        cpu.v[0xF] = bit.band(cpu.v[x], 0x80)
        cpu.v[0xF] = bit.rshift(cpu.v[0xF], 7)
        cpu.v[x] = bit.lshift(cpu.v[x], 1)
        cpu.v[x] = cpu.v[x] % 256
    else
        print("undefined opcode 8000")
    end
end
instructions[0x9000] = function(cpu, opcode)
    -- 9XY0: skip if VX != VY
    if bit.band(opcode, 0x000F) ~= 0 then
        print("undefined opcode 9XYN")
        return
    end
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local y = bit.rshift(bit.band(opcode, 0x00F0), 4)
    if cpu.v[x] ~= cpu.v[y] then
        cpu.pc = cpu.pc + 2
    end
end
instructions[0xA000] = function(cpu, opcode)
    -- ANNN: I = NNN
    local nnn = bit.band(opcode, 0x0FFF)
    cpu.i = nnn
end
instructions[0xB000] = function(cpu, opcode)
    -- BNNN: jump to V0 + NNN
    local nnn = bit.band(opcode, 0x0FFF)
    cpu.pc = nnn + cpu.v[0]
end
instructions[0xC000] = function(cpu, opcode)
    -- CXNN: VX = random() & NN
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local nn = bit.band(opcode, 0x00FF)
    local random = love.math.random(0, 255)
    cpu.v[x] = bit.band(random, nn)
    -- TODO or just love.math.random(0, nn) ?
end
instructions[0xD000] = function(cpu, opcode)
    -- DXYN: draw N-pixel tall sprite at VX,VY
    -- TODO: Does VIP change I? Manual says no. Who said yes? What about VX and VY?
    -- TODO: VIP does not wrap half-drawn sprites, but it DOES wrap full sprites
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local y = bit.rshift(bit.band(opcode, 0x00F0), 4)
    x = cpu.v[x] % 64
    y = cpu.v[y] % 32
    local n = bit.band(opcode, 0x000F)
    if n == 0 then
        print("undefined opcode DXY0")
        return
    end
    
    cpu.drawflag = true
    cpu.v[0xF] = 0

    for m = 0, n - 1 do
        local byte = cpu.rom[cpu.i + m]
        for x2 = 0, 7 do
            -- TODO: wrap screen in SCHIP mode
            --local xx = x2 % 64
            --local yy = (y+m) % 32
            local xx = x + x2
            if xx > 63 then break end
            local yy = y + m
            if yy > 31 then return end
            local pixel = cpu.screen[xx][yy]
            local pixel2 = bit.band(bit.rshift(byte, 7 - x2), 1)
            if bit.band(pixel, pixel2) == 1 then
                cpu.v[0xF] = 1
            end
            cpu.screen[xx][yy] = bit.bxor(pixel, pixel2)
        end
    end
end
instructions[0xE000] = function(cpu, opcode)
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    if bit.band(opcode, 0x00FF) == 0x009E then
        -- EX9E: skip if key VX is pressed
        -- TODO what if v[x] > 0xf?
        -- TODO: VIP used the sound timer for this, so a sound should be emitted while a key is held down
        if cpu.key_status[cpu.v[x]] then
            cpu.pc = cpu.pc + 2
        end
    elseif bit.band(opcode, 0x00FF) == 0x00A1 then
        -- EX9E: skip if key VX is not pressed
        -- TODO what if v[x] > 0xf?
        if not cpu.key_status[cpu.v[x]] then
            cpu.pc = cpu.pc + 2
        end
    else
        print("undefined opcode E000 at " .. (cpu.pc - 1))
    end
end
instructions[0xF000] = function(cpu, opcode)
    local x = bit.rshift(bit.band(opcode, 0x0F00), 8)
    local instruction = bit.band(opcode, 0x00FF)

    if instruction == 0x07 then
        -- FX07: VX = delay timer
        cpu.v[x] = cpu.delay
    elseif instruction == 0x0A then
        -- FX0A: block for VX = keypress
        -- TODO: VIP used the sound timer for this, so a sound should be emitted while a key is held down
        for i=0,0xF do
            if cpu.key_status[i] then
                cpu.v[x] = i
                return
            end
        end
        cpu.pc = cpu.pc - 2
    elseif instruction == 0x15 then
        -- FX15: delay timer = VX
        cpu.delay = cpu.v[x]
    elseif instruction == 0x18 then
        -- FX18: sound timer = VX
        cpu.sound = cpu.v[x]
    elseif instruction == 0x1E then
        -- FX1E: I += VX
        cpu.i = cpu.i + cpu.v[x]
    elseif instruction == 0x29 then
        -- FX29: I = address of character in VX
        cpu.i = 0x050 + (cpu.v[x] * 5) -- TODO: hva med sifre over F?
    elseif instruction == 0x33 then
        -- FX33: put BCD representation of VX in three bytes pointed at by I
        local bcd = cpu.v[x]
        cpu.rom[cpu.i + 2] = bcd % 10
        bcd = math.floor(bcd / 10)
        cpu.rom[cpu.i + 1] = bcd % 10
        bcd = math.floor(bcd / 10)
        cpu.rom[cpu.i] = bcd
    elseif instruction == 0x55 then
        -- FX55: store V0 through VX to addresses pointed at by I
        for j=0,x do
            cpu.rom[cpu.i+j] = cpu.v[j]
        end
        --i = i + x + 1
    elseif instruction == 0x65 then
        -- FX65: load bytes from addresses pointed at by I into V0 through VX
        for j=0,x do
            cpu.v[j] = cpu.rom[cpu.i+j]
        end
        --i = i + x + 1
    else
        print("undefined opcode " .. opcode)
    end
end

return instructions