log = (msgs...) -> console.log.apply console, msgs

screenW = screenH = 0
levelW = levelH = 0
tileW = tileH = 16
playerX = playerY = 20
velX = velY = 0

prog = null
vertBuffer = coordBuffer = tileIndexBuffer = mapBuffer = null
tileTex = null

map = []
water = {}
waterBodies = {}
bodyCtr = 0

keys = up:0, down:0, left:0, right:0
canvas = timer = null
spriteCount = 1
noclip = false
msgbox = document.getElementById('info')

terminal = 5
waterFriction = 0.9
groundFriction = 0.9

SPACE = 1
WATER = 2
GROUND = 3

getPos = -> [Math.round(playerX/tileW), Math.round(playerY/tileH)]

addWater = (pos) ->
    if water[pos]
        return
    bodies = {}
    withAdjacent pos, (i, j) ->
        id = water[[i,j]]
        if id and id not of bodies
            bodies[id] = 1
    bodies = (parseInt(id) for id of bodies)
    body = null
    if bodies.length == 1
        body = waterBodies[bodies[0]]
    else if bodies.length > 1
        log 'merge bodies ' + bodies
        body = waterBodies[bodies.shift()]
        # naive scan for now
        for pos in Object.keys water
            id = water[pos]
            if id in bodies
                water[pos] = body.id
                body.size += 1
        for dead in bodies
            delete waterBodies[dead]
    else
        bodyCtr += 1
        body = {id: bodyCtr, size: 0, asleep: false}
        waterBodies[body.id] = body
        log 'created body ', body.id
    water[pos] = body.id
    body.size += 1
    body.asleep = false
    log 'new body size', body.size

removeWater = (pos) ->
    id = water[pos]
    if id
        body = waterBodies[id]
        delete water[pos]
        body.size -= 1
        if body.size == 0
            log 'delete water body', id
            delete waterBodies[id]

disrupt = (pos) ->
    withAdjacent pos, (i, j) ->
        id = water[[i,j]]
        if id
            waterBodies[id].asleep = false

flowWater = ->
    awake = []
    for id, body of waterBodies
        if not body.asleep
            awake.push body.id
            body.asleep = true
    reflow = {}
    needsLoad = false
    for pos, id of water
        if id in awake
            [x, y] = JSON.parse("[#{pos}]")
            if y > 0 and peekMap(x, y-1) == SPACE
                log 'suspended water at', x, y
                pokeMap x, y, SPACE
                pokeMap x, y-1, WATER
                addWater [x, y-1]
                removeWater [x, y]
                needsLoad = true
                reflow[id] = true
    for id of reflow
        body = waterBodies[id]
        if body
            body.asleep = false
    if needsLoad
        loadMap()

window.onkeydown = (event) ->
    key = event.which
    if key >= 48 and key < 58
        # modify tile
        col = key - 48
        pos = getPos()
        [x, y] = pos
        pokeMap x, y, col
        if col == WATER
            addWater pos
        else
            removeWater pos
        disrupt pos
        loadMap()
    else switch key
        when 37 then keys.left = 1
        when 38 then keys.up = 1
        when 39 then keys.right = 1
        when 40 then keys.down = 1
        when 78
            noclip = not noclip
            msgbox.textContent = if noclip then 'noclip' else 'clip'
            velX = velY = 0
        when 27
            clearInterval timer
            gl.clear gl.COLOR_BUFFER_BIT
        when 88
            window.localStorage.level = JSON.stringify exportMap()
            log 'exported.'
        else
            log event.which, 'up'
            return
    event.preventDefault()

window.onkeyup = (event) ->
    key = event.which
    if key >= 48 and key < 58
        # pass
    else switch key
        when 37 then keys.left = 0
        when 38 then keys.up = 0
        when 39 then keys.right = 0
        when 40 then keys.down = 0
        else
            return
    event.preventDefault()

clamp = (min, val, max) -> Math.min(max, Math.max(min, val))

update_state = ->
    flowWater()

    aX = aY = 0
    if keys.left then aX = -1
    if keys.right then aX = 1
    if keys.up then aY = 1
    if keys.down then aY = -1
    if noclip
        playerX += aX
        playerY += aY
        return
    [x, y] = getPos()
    col = peekMap x, y
    if col == SPACE
        # fl- fling yourself through space
        aY = -1
        aX *= 0.5

    velX = clamp(-terminal, velX + aX * 0.2, terminal)
    velY = clamp(-terminal, velY + aY * 0.2, terminal)

    # friction
    if col == SPACE and peekMap(x, y-1) == GROUND
        velX = clamp(-1, velX * groundFriction, 1)
    else if col == WATER
        # only apply water friction if not trying to move in that dir
        if aX * velX <= 0 then velX *= waterFriction
        if aY * velY <= 0 then velY *= waterFriction

    if velX != 0 and hit_test playerX+velX, playerY then velX = 0
    if velY != 0 and hit_test playerX+velX, playerY+velY then velY = 0
    playerX += velX
    playerY += velY

hit_test = (x, y) ->
    x1 = Math.floor((x+2) / tileW)
    x2 = Math.floor((x+14) / tileW)
    y1 = Math.floor((y+2) / tileH)
    y2 = Math.floor((y+14) / tileH)
    ok = (col) -> col == GROUND
    (ok peekMap x1, y1) or (ok peekMap x2, y1) or (
        ok peekMap x1, y2) or (ok peekMap x2, y2)

draw = ->
    update_state()

    gl.clearColor 0, 0, 0, 1
    gl.clear gl.COLOR_BUFFER_BIT

    gl.activeTexture gl.TEXTURE0
    gl.bindTexture gl.TEXTURE_2D, tileTex
    gl.uniform1i prog.sampler, 0

    # map
    gl.uniform2f prog.offset, 0, 0
    gl.drawElements gl.TRIANGLES, (levelW * levelH + spriteCount) * 6, gl.UNSIGNED_SHORT, 0

    # sprite
    gl.uniform2f prog.offset, Math.round(playerX), Math.round(playerY)
    gl.drawElements gl.TRIANGLES, 6, gl.UNSIGNED_SHORT, 0

getShader = (id) ->
    script = document.getElementById id
    shader = null
    if script.type == 'x-shader/x-fragment'
        shader = gl.createShader gl.FRAGMENT_SHADER
    else if script.type == 'x-shader/x-vertex'
        shader = gl.createShader gl.VERTEX_SHADER
    else
        throw "No shader."
    src = ''
    c = script.firstChild
    while c
        if c.nodeType == 3
            src += c.textContent
        c = c.nextSibling
    gl.shaderSource shader, src
    gl.compileShader shader
    if not gl.getShaderParameter shader, gl.COMPILE_STATUS
        log gl.getShaderInfoLog shader
        gl.deleteShader shader
        throw "Shader error."
    shader

setup = (callback) ->
    canvas = document.getElementsByTagName('canvas')[0]
    try
        window.gl = canvas.getContext 'experimental-webgl'
    catch e
        throw "No WebGL."

    screenW = canvas.width
    screenH = canvas.height
    levelW = screenW / tileW
    levelH = screenH / tileH
    gl.viewport 0, 0, screenW, screenH

    frag = getShader 'frag'
    vert = getShader 'vert'
    prog = gl.createProgram()
    gl.attachShader prog, vert
    gl.attachShader prog, frag
    gl.linkProgram prog
    if not gl.getProgramParameter prog, gl.LINK_STATUS
        log gl.getProgramInfoLog prog
        gl.deleteProgram prog
        throw "Couldn't link."

    gl.useProgram prog

    gl.enable gl.BLEND
    gl.blendFunc gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA

    # attributes
    prog.pos = gl.getAttribLocation prog, 'pos'
    if prog.pos < 0
        throw "Couldn't get attrib"
    gl.enableVertexAttribArray prog.pos

    prog.coord = gl.getAttribLocation prog, 'coord'
    if prog.pos < 0
        throw "Couldn't get attrib"
    gl.enableVertexAttribArray prog.coord

    prog.col = gl.getAttribLocation prog, 'col'
    if prog.col < 0
        throw "Couldn't get attrib"
    gl.enableVertexAttribArray prog.col

    # uniforms
    prog.proj = gl.getUniformLocation prog, 'proj'
    ortho = new Float32Array [
        2/screenW, 0, 0, 0,
        0, 2/screenH, 0, 0,
        0, 0, -1, 0,
        -1, -1, 0, 1
    ]
    gl.uniformMatrix4fv prog.proj, false, ortho

    prog.sampler = gl.getUniformLocation prog, 'sampler'
    prog.offset = gl.getUniformLocation prog, 'offset'

    verts = []
    coords = []
    indices = []
    curIndex = 0
    for i in [0...spriteCount]
        verts.push 0, 0, 0, 1, 1, 0, 1, 1
        coords.push 0, 0.25, 0, 0, 0.25, 0.25, 0.25, 0
        x = curIndex
        curIndex += 4
        indices.push x, x+1, x+2, x+1, x+2, x+3
        map.push 0, 0, 0, 0
    for j in [0...levelH]
        for i in [0...levelW]
            verts.push(
                i, j,
                i, j+1,
                i+1, j,
                i+1, j+1,
            )
            coords.push(
                0, 0.25,
                0, 0,
                0.25, 0.25,
                0.25, 0,
            )
            x = curIndex
            curIndex += 4
            indices.push(
                x, x+1, x+2,
                x+1, x+2, x+3,
            )
            col = if j < levelH/2 then 3 else 1
            map.push(col, col, col, col)

    vertBuffer = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, vertBuffer
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(verts), gl.STATIC_DRAW
    gl.vertexAttribPointer prog.pos, 2, gl.FLOAT, false, 0, 0

    coordBuffer = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, coordBuffer
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(coords), gl.STATIC_DRAW
    gl.vertexAttribPointer prog.coord, 2, gl.FLOAT, false, 0, 0

    tileIndexBuffer = gl.createBuffer()
    gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, tileIndexBuffer
    gl.bufferData gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(indices), gl.STATIC_DRAW

    mapBuffer = gl.createBuffer()
    pokeMap(0, 0, 0)
    if window.localStorage.level
        importMap JSON.parse window.localStorage.level
    loadMap()

    tileImage = new Image()
    tileImage.onload = ->
        tileTex = gl.createTexture()
        gl.bindTexture gl.TEXTURE_2D, tileTex
        gl.texImage2D gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, this
        gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST
        gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST

        log 'OK!'
        setTimeout(callback, 0)
    tileImage.src = 'tiles.png'

pokeMap = (x, y, col) ->
    i = (spriteCount + y * levelW + x) * 4
    map[j] = col for j in [i...i+4]

peekMap = (x, y) -> map[(spriteCount + y * levelW + x) * 4]

loadMap = ->
    gl.bindBuffer gl.ARRAY_BUFFER, mapBuffer
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(map), gl.DYNAMIC_DRAW
    gl.vertexAttribPointer prog.col, 1, gl.FLOAT, false, 0, 0

withAdjacent = (pos, func) ->
    [x, y] = pos
    if x > 0 then func x-1, y
    if x < levelW - 1 then func x+1, y
    if y > 0 then func x, y-1
    if y < levelH - 1 then func x, y+1

fillWater = (body, x, y) ->
    pos = [x, y]
    if pos of water
        return
    if peekMap(x, y) != WATER
        return
    water[pos] = body.id
    body.size += 1
    withAdjacent pos, fillWater.bind null, body

loadBodies = ->
    water = {}
    waterBodies = {}
    for j in [0...levelH]
        for i in [0...levelW]
            col = peekMap i, j
            if col == WATER
                pos = [i, j]
                if not (pos of water)
                    bodyCtr += 1
                    body = {size: 0, id: bodyCtr, asleep: false}
                    fillWater body, i, j
                    waterBodies[body.id] = body
                    log 'found body of size', body.size

importMap = (data) ->
    for i in [0...levelW*levelH]
        x = (spriteCount + i) * 4
        map[x] = map[x+1] = map[x+2] = map[x+3] = data[i]
    loadBodies()

exportMap = ->
    map[i] for i in [spriteCount*4...(spriteCount+levelW*levelH)*4] by 4

setup () ->
    timer = setInterval draw, 1000/60
