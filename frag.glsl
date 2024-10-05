#version 410 core
in vec4 gl_FragCoord;
in vec2 coord;

out vec4 color;

uniform float scroll_x;
uniform float scroll_y;
uniform float zoom;
uniform float max_iterations;

#define W 1000.0f
#define H 800.0f


void main()
{
    double r = (gl_FragCoord.x / W) * zoom + scroll_x;
    double i = (gl_FragCoord.y / H) * zoom + scroll_y;
    double r_c = r;
    double i_c = i;

    float iterations = 0.0;
    while(iterations < max_iterations)
    {
        double r_t = r;
        r = (r * r - i * i) + r_c;
        i = (2.0 * r_t * i) + i_c;

        double escape = r * r + i * i;

        if (escape > 4.0)
            break;

        iterations += 1.0;
    }

    if(iterations >= max_iterations)
        color = vec4(0.0, 0.0, 0.0, 1.0);
    else
    {
        float factor = iterations/max_iterations;
        color = vec4(factor, factor, factor + 0.25, factor + 0.25);
    }
}
