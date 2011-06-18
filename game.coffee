log = (msgs...) -> console.log.apply console, msgs

screenW = screenH = 0
levelW = levelH = 0
tileW = tileH = 16
prog = null
vertBuffer = coordBuffer = tileIndexBuffer = mapBuffer = null
tileTex = null

draw = ->
    gl.clearColor 0, 0, 0, 1
    gl.clear gl.COLOR_BUFFER_BIT

    gl.activeTexture gl.TEXTURE0
    gl.bindTexture gl.TEXTURE_2D, tileTex
    gl.uniform1i prog.sampler, 0

    gl.drawElements gl.TRIANGLES, levelW * levelH * 6, gl.UNSIGNED_SHORT, 0

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

    verts = []
    coords = []
    indices = []
    map = []
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
            x = (j * levelW + i) * 4
            indices.push(
                x, x+1, x+2,
                x+1, x+2, x+3,
            )
            col = (j * levelW + i) % 5
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
    gl.bindBuffer gl.ARRAY_BUFFER, mapBuffer
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(map), gl.DYNAMIC_DRAW
    gl.vertexAttribPointer prog.col, 1, gl.FLOAT, false, 0, 0

    tileImage = new Image()
    tileImage.onload = ->
        tileTex = gl.createTexture()
        gl.bindTexture gl.TEXTURE_2D, tileTex
        #gl.pixelStorei gl.UNPACK_FLIP_Y_WEBGL, true
        gl.texImage2D gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, this
        gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST
        gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST

        log 'OK!'
        setTimeout(callback, 0)
    tileImage.src = 'tiles.png'


setup(draw)
