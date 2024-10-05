import strformat
import opengl
import opengl/glu
import sdl2

discard sdl2.init(INIT_EVERYTHING)

const
  frames: uint32 = 60
  frametarget: uint32 = 1000 div frames
  width: uint32 = 1000
  height: uint32 = 800

const
  zoom_factor: float = 2.0
  scroll_factor: float = 0.5
  iteration_factor: float = 1.5

const
  zoom_max: float = 2.0
  scroll_x_min: float = -2.0
  scroll_x_max: float = 1.0
  scroll_y_min: float = -1.5
  scroll_y_max: float = 1.0
  iterations_min: float = 10.0
  iterations_max: float = 1000.0

var
  evt = sdl2.defaultEvent
  window: WindowPtr = createWindow("Mandelbrot", 200, 200, width.cint, height.cint, SDL_WINDOW_OPENGL)
  context: GlContextPtr = glCreateContext(window)

var
  max_iterations : float = 100.0
  zoom: float = 2.0
  scroll_x: float = -1.5
  scroll_y: float = -1.0

var program : uint32 = 0

var vertices = @[
  -1.0f, -1.0f, -0.0f,
   1.0f,  1.0f, -0.0f,
  -1.0f,  1.0f, -0.0f,
   1.0f, -1.0f, -0.0]

var indices = @[
  0'u32, 1'u32, 2'u32,
  0'u32, 3'u32, 1'u32]


proc initShader(program: uint32, shader: uint32, shader_source: cStringArray) =
  var
    success: int32 = 0
    logSize: int32 = 0

  # Load and compile shader
  glShaderSource(shader, 1, shader_source, nil)
  glCompileShader(shader)

  # Check status and exit if not successful
  glGetShaderiv(shader, GL_COMPILE_STATUS, success.addr)
  if success == 0:
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, logSize.addr)

    var logStr = cast[ptr GLchar](alloc(logSize))
    glGetShaderInfoLog(shader, logSize, nil, logStr)

    echo "Error compiling shader: ", logStr

    dealloc(logStr)
    quit(-1)

  glAttachShader(program, shader)


proc initProgram(program: uint32) =
  var
    success: int32 = 0
    logSize: int32 = 0

  glLinkProgram(program)

  # Check status and exit if not successful
  glGetProgramiv(program, GL_LINK_STATUS, success.addr)
  if success == 0:
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, logSize.addr)

    var logStr = cast[ptr GLchar](alloc(logSize))
    glGetProgramInfoLog(program, logSize, nil, logStr)

    echo "Error linking program: ", logStr

    dealloc(logStr)
    quit(-1)

  glUseProgram(program)


proc init() =
  var
    mesh: tuple[vao,vbo,ebo: uint32]
    vertex_shader = glCreateShader(GL_VERTEX_SHADER)
    fragment_shader = glCreateShader(GL_FRAGMENT_SHADER)
    fragment_program = allocCStringArray([readFile("frag.glsl")])
    vertex_program = allocCStringArray([readFile("vert.glsl")])

  program = glCreateProgram()
  initShader(program, fragment_shader, fragment_program)
  initShader(program, vertex_shader, vertex_program)
  initProgram(program)

  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

  glUniform1f(glGetUniformLocation(program, "max_iterations"), max_iterations);
  glUniform1f(glGetUniformLocation(program, "zoom"), zoom);
  glUniform1f(glGetUniformLocation(program, "scroll_x"), scroll_x);
  glUniform1f(glGetUniformLocation(program, "scroll_y"), scroll_y);

  glGenVertexArrays(1, mesh.vao.addr)
  glGenBuffers(1, mesh.vbo.addr)
  glGenBuffers(1, mesh.ebo.addr)
  glBindVertexArray(mesh.vao)

  glBindBuffer(GL_ARRAY_BUFFER, mesh.vbo)
  glBufferData(GL_ARRAY_BUFFER, cint(cfloat.sizeof*vertices.len), vertices[0].addr, GL_STATIC_DRAW)

  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.ebo)
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, cint(cuint.sizeof*indices.len), indices[0].addr, GL_STATIC_DRAW)

  glVertexAttribPointer(0'u32, 3, cGL_FLOAT.GLenum, false, 3 * cfloat.sizeof, nil)
  glEnableVertexAttribArray(0)
  glBindBuffer(GL_ARRAY_BUFFER, 0)
  glBindVertexArray(mesh.vao)

  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
  glBindVertexArray(mesh.vao)


proc render() =
  glDrawElements(GL_TRIANGLES, indices.len.cint, GL_UNSIGNED_INT, nil)
  window.glSwapWindow()


proc main() =
  var
    running: bool = true
    redraw: bool = false
    now: uint32 = 0
    frametime: uint32 = 0
    mouse_capture: bool = false
    mouse_scroll: tuple[x: cint,y :cint] = (0, 0)

  echo "Config:"
  echo fmt"- {frames} fps ({frametarget} ms)"
  echo fmt"- {width} x {height}"

  loadExtensions()

  init()

  glViewport(0, 0, width.cint, height.cint)
  glMatrixMode(GL_PROJECTION)
  glLoadIdentity()
  gluPerspective(45.0, width.cint / height.cint, 0.1, 100.0)

  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
  glMatrixMode(GL_MODELVIEW)
  glLoadIdentity()
  glTranslatef(1.5, 0.0, -7.0)

  render()

  while running:
    redraw = false

    while pollEvent(evt):
      if evt.kind == QuitEvent:
        running = false
        break

      if evt.kind == MOUSEWHEEL:
        if evt.wheel.y > 0:
          zoom /= zoom_factor
        else:
          zoom = min(zoom * zoom_factor, zoom_max)
        glUniform1f(glGetUniformLocation(program, "zoom"), zoom);
        echo fmt"zoom: {zoom}"
        redraw = true

      elif evt.kind == MOUSEMOTION:
        if mouse_capture and getTicks() - now > 60:
          let diff_x: float = (mouse_scroll.x.float - evt.motion.x.float) * scroll_factor / 60
          let diff_y: float = (mouse_scroll.y.float - evt.motion.y.float) * scroll_factor / 60

          scroll_x = (scroll_x + diff_x * zoom).clamp(scroll_x_min, scroll_x_max)
          glUniform1f(glGetUniformLocation(program, "scroll_x"), scroll_x);
          echo fmt"scroll_x: {scroll_x}"

          scroll_y = (scroll_y - diff_y * zoom).clamp(scroll_y_min, scroll_y_max)
          glUniform1f(glGetUniformLocation(program, "scroll_y"), scroll_y);
          echo fmt"scroll_y: {scroll_y}"

          mouse_scroll = (evt.motion.x, evt.motion.y)
          redraw = true

      elif evt.kind == MOUSEBUTTONDOWN:
        mouse_capture = true
        mouse_scroll = (evt.button.x, evt.button.y)

      elif evt.kind == MOUSEBUTTONUP:
        mouse_capture = false

      elif evt.kind == KEYUP:
        redraw = true

        if evt.key.keysym.scancode == SDL_SCANCODE_UP:
          scroll_y = min(scroll_y + scroll_factor * zoom, scroll_y_max)
          glUniform1f(glGetUniformLocation(program, "scroll_y"), scroll_y);
          echo fmt"scroll_y: {scroll_y}"

        elif evt.key.keysym.scancode == SDL_SCANCODE_DOWN:
          scroll_y = max(scroll_y - scroll_factor * zoom, scroll_y_min)
          glUniform1f(glGetUniformLocation(program, "scroll_y"), scroll_y);
          echo fmt"scroll_y: {scroll_y}"

        elif evt.key.keysym.scancode == SDL_SCANCODE_LEFT:
          scroll_x = max(scroll_x - scroll_factor * zoom, scroll_x_min)
          glUniform1f(glGetUniformLocation(program, "scroll_x"), scroll_x);
          echo fmt"scroll_x: {scroll_x}"

        elif evt.key.keysym.scancode == SDL_SCANCODE_RIGHT:
          scroll_x = min(scroll_x + scroll_factor * zoom, scroll_x_max)
          glUniform1f(glGetUniformLocation(program, "scroll_x"), scroll_x);
          echo fmt"scroll_x: {scroll_x}"

        elif evt.key.keysym.scancode == SDL_SCANCODE_KP_PLUS:
          max_iterations = min(max_iterations * iteration_factor, iterations_max)
          glUniform1f(glGetUniformLocation(program, "max_iterations"), max_iterations);
          echo fmt"max_iterations: {max_iterations}"

        elif evt.key.keysym.scancode == SDL_SCANCODE_KP_MINUS:
          max_iterations = max(max_iterations / iteration_factor, iterations_min)
          glUniform1f(glGetUniformLocation(program, "max_iterations"), max_iterations);
          echo fmt"max_iterations: {max_iterations}"

        elif evt.key.keysym.scancode == SDL_SCANCODE_R:
          max_iterations = 100.0
          zoom = 2.0
          scroll_x = -1.5
          scroll_y = -1.0
          glUniform1f(glGetUniformLocation(program, "max_iterations"), max_iterations);
          glUniform1f(glGetUniformLocation(program, "zoom"), zoom);
          glUniform1f(glGetUniformLocation(program, "scroll_x"), scroll_x);
          glUniform1f(glGetUniformLocation(program, "scroll_y"), scroll_y);
          echo fmt"reset"

      else:
        redraw = false

    if redraw:
      now = getTicks()

      render()

      frametime = getTicks() - now

      if frametime < frametarget:
        delay(frametarget - frametime)

  destroy window

main()

