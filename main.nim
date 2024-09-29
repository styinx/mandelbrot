import strformat
import sdl2

discard sdl2.init(INIT_EVERYTHING)

const
  c_x_min: float = -2.5
  c_x_max: float = 2.5
  c_y_min: float = -2.5
  c_y_max: float = 2.5
  escape_radius: float = 2.0
  escape_radius_squared: float = escape_radius * escape_radius

const
  frames: uint32 = 60
  frametarget: uint32 = 1000 div frames
  width: uint32 = 800
  height: uint32 = 800
  pixel_width: float = (c_x_max - c_x_min) / width.float
  pixel_height: float = (c_y_max - c_y_min) / height.float

type FrameBuffer = array[width * height, uint32]
type FrameBufferPtr = ptr FrameBuffer

var
  evt = sdl2.defaultEvent
  window: WindowPtr = createWindow("Mandelbrot", 200, 200, cint(width), cint(height), SDL_WINDOW_SHOWN)
  renderer: RendererPtr = createRenderer(window, -1,  Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)
  texture: TexturePtr = createTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, cint(width), cint(height))

var
  max_iterations : uint8 = 30
  zoom: float = 1.0
  off_x: float = 0.0
  off_y: float = 0.0

var
  c_x : float = 0.0
  c_y : float = 0.0
  z_x : float = 0.0
  z_y : float = 0.0
  z_x_2 : float = 0.0
  z_y_2 : float = 0.0

proc draw(frame: FrameBufferPtr) =
  var
    iteration: uint8
    color: uint32

  for y in 0 ..< height:
    c_y = c_y_min + y.float * pixel_height * zoom + off_y

    if abs(c_y) < pixel_height / 2:
      c_y = 0.0

    for x in 0 ..< width:
      c_x = c_x_min + x.float * pixel_width * zoom + off_x

      z_x = 0.0
      z_y = 0.0
      z_x_2 = z_x * z_x
      z_y_2 = z_y * z_y

      iteration = 0
      while (z_x_2 + z_y_2) < (escape_radius_squared) and iteration < max_iterations:
        z_y = 2 * z_x * z_y + c_y
        z_x = z_x_2 - z_y_2 + c_x
        z_x_2 = z_x * z_x
        z_y_2 = z_y * z_y
        iteration += 1

      if iteration == max_iterations:
         color = 0xffffffff'u32
      else:
         color = 0

#[
      c = 0x0000ff00'u32
      c += uint32(x / width * 255)
      c = c shl 8
      c += uint32(y / height * 255)
      c = c shl 8
      ]#
      frame[y * width + x] = color


proc render(renderer: RendererPtr) =
  var
    pixels: pointer
    pitch: cint

  renderer.clear()

  lockTexture(texture, nil, pixels.addr, pitch.addr)
  draw(cast[FrameBufferPtr](pixels))
  unlockTexture(texture)

  renderer.copy(texture, nil, nil);

  renderer.present()

proc main() =

  var
    running: bool = true
    redraw: bool = false
    now: uint32 = 0
    frametime: uint32 = 0

  echo "Config:"
  echo fmt"- {frames} fps ({frametarget} ms)"
  echo fmt"- {width} x {height}"

  renderer.setDrawColor(0,0,0,255)

  render(renderer)

  while running:
    redraw = false

    while pollEvent(evt):

      if evt.kind == QuitEvent:
        running = false
        break

      if evt.kind == MouseWheel:
        zoom -= float(evt.wheel.y) / 10
        echo fmt"zoom: {zoom}"
        redraw = true

      elif evt.kind == KEYUP:
        redraw = true

        if evt.key.keysym.scancode == SDL_SCANCODE_UP:
          off_y -= 1.0 * zoom
          echo fmt"off_y: {off_y}"
        elif evt.key.keysym.scancode == SDL_SCANCODE_DOWN:
          off_y += 1.0 * zoom
          echo fmt"off_y: {off_y}"
        elif evt.key.keysym.scancode == SDL_SCANCODE_LEFT:
          off_x -= 1.0 * zoom
          echo fmt"off_x: {off_x}"
        elif evt.key.keysym.scancode == SDL_SCANCODE_RIGHT:
          off_x += 1.0 * zoom
          echo fmt"off_x: {off_x}"

        elif evt.key.keysym.scancode == SDL_SCANCODE_KP_PLUS:
          max_iterations += (if max_iterations < 246: 10 else: 0)
          echo fmt"max_iterations: {max_iterations}"
        elif evt.key.keysym.scancode == SDL_SCANCODE_KP_MINUS:
          max_iterations -= (if max_iterations > 10: 10 else: 0)
          echo fmt"max_iterations: {max_iterations}"

        elif evt.key.keysym.scancode == SDL_SCANCODE_R:
          max_iterations = 30
          zoom = 1.0
          off_x = 0.0
          off_y = 0.0
          echo fmt"reset"

        else:
          redraw = false

    if redraw:
      now = getTicks()

      render(renderer)

      frametime = getTicks() - now

      if frametime < frametarget:
        delay(frametarget - frametime)

  destroy renderer
  destroy window

main()

