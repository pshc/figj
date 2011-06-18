log = (msgs...) -> console.log.apply console, msgs

screenW = screenH = 0
levelW = levelH = 0
tileW = tileH = 32
prog = null
tileBuffer = mapBuffer = null

draw = ->
    gl.clearColor 0, 0, 0, 1
    gl.clear gl.COLOR_BUFFER_BIT

    gl.drawArrays gl.TRIANGLE_STRIP, 0, levelW * 2 + 2

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

setup = ->
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
    prog.pos = gl.getAttribLocation prog, 'pos'
    if prog.pos < 0
        throw "Couldn't get attrib"
    gl.enableVertexAttribArray prog.pos

    prog.col = gl.getAttribLocation prog, 'col'
    if prog.col < 0
        throw "Couldn't get attrib"
    gl.enableVertexAttribArray prog.col

    prog.proj = gl.getUniformLocation prog, 'proj'
    ortho = new Float32Array [
        2/screenW, 0, 0, 0,
        0, 2/screenH, 0, 0,
        0, 0, -1, 0,
        -1, -1, 0, 1
    ]
    gl.uniformMatrix4fv prog.proj, false, ortho

    # gen row of tiles
    tris = [0, 0, 0, tileH]
    for i in [1..levelW]
        tris.push(
            i*tileW, 0,
            i*tileW, tileH,
        )

    tileBuffer = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, tileBuffer
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(tris), gl.STATIC_DRAW
    gl.vertexAttribPointer prog.pos, 2, gl.FLOAT, false, 0, 0

    map = []
    for i in [0..levelW]
        map.push(i/levelW, i/levelW)
    mapBuffer = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, mapBuffer
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(map), gl.DYNAMIC_DRAW
    gl.vertexAttribPointer prog.col, 1, gl.FLOAT, false, 0, 0

    log 'OK!'
    draw()

setup()
