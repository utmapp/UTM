/* GL 4.1 core feature probe for Intel Mac guests (UTM Intel guest kit, research).
 * Draws one full-viewport primitive per test into a 16x16 FBO and checks the
 * centre pixel. Each test exercises one feature a modern GL game depends on
 * (SuperTuxKart 1.5's SP pipeline): UBOs, instanced attributes, half-float and
 * 2_10_10_10 attributes, integer attributes, base-vertex draws, depth FBOs,
 * MRT, mapped buffers, samplers, texture buffers.
 * Build: clang -arch x86_64 -mmacosx-version-min=10.14 gl41-features.c -framework OpenGL */
#define GL_SILENCE_DEPRECATION 1
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl3.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>

static GLuint fbo, color0, color1, depth;
static int failures;

static GLuint shader(GLenum type, const char *src)
{
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[1024] = "";
        glGetShaderInfoLog(s, sizeof(log), NULL, log);
        printf("  compile error: %s\n", log);
    }
    return s;
}

static GLuint program(const char *vs, const char *fs)
{
    GLuint p = glCreateProgram();
    glAttachShader(p, shader(GL_VERTEX_SHADER, vs));
    glAttachShader(p, shader(GL_FRAGMENT_SHADER, fs));
    glBindFragDataLocation(p, 0, "o0");
    glLinkProgram(p);
    GLint ok = 0;
    glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) {
        char log[1024] = "";
        glGetProgramInfoLog(p, sizeof(log), NULL, log);
        printf("  link error: %s\n", log);
    }
    glUseProgram(p);
    return p;
}

static void begin(void)
{
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glViewport(0, 0, 16, 16);
    glClearColor(0, 0, 0, 1);
    glClearDepth(1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

static void check(const char *name, GLenum attachment)
{
    unsigned char px[4] = {0};
    glReadBuffer(attachment);
    glReadPixels(8, 8, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
    GLenum err = glGetError();
    int ok = px[0] > 200 && px[1] < 60 && px[2] < 60 && !err;
    printf("%-28s %s  pixel=%3u,%3u,%3u gl_error=0x%x\n", name, ok ? "PASS" : "FAIL",
           px[0], px[1], px[2], err);
    failures += !ok;
    glReadBuffer(GL_COLOR_ATTACHMENT0);
}

static const char *FS_RED = "#version 410\nout vec4 o0; void main(){ o0 = vec4(1,0,0,1); }\n";
static const char *FS_COLOR = "#version 410\nin vec4 c; out vec4 o0; void main(){ o0 = c; }\n";

/* A triangle that covers the whole viewport. */
static const float TRI[] = { -1, -1, 0,   3, -1, 0,   -1, 3, 0 };

static GLuint vbo(const void *data, GLsizeiptr size, GLenum target)
{
    GLuint b;
    glGenBuffers(1, &b);
    glBindBuffer(target, b);
    glBufferData(target, size, data, GL_STATIC_DRAW);
    return b;
}

static GLuint vao(void)
{
    GLuint a;
    glGenVertexArrays(1, &a);
    glBindVertexArray(a);
    return a;
}

static uint16_t half(float f)
{
    union { float f; uint32_t u; } v = { f };
    uint32_t s = (v.u >> 16) & 0x8000, e = (v.u >> 23) & 0xff, m = v.u & 0x7fffff;
    if (e == 0) return (uint16_t)s;
    int ne = (int)e - 127 + 15;
    return (uint16_t)(s | (ne << 10) | (m >> 13));
}

int main(void)
{
    CGLPixelFormatAttribute attrs[] = {
        kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_GL4_Core,
        kCGLPFAAccelerated, kCGLPFAColorSize, 24, kCGLPFADepthSize, 24, 0
    };
    CGLPixelFormatObj pf;
    GLint n;
    CGLContextObj ctx;
    if (CGLChoosePixelFormat(attrs, &pf, &n) || !pf || CGLCreateContext(pf, NULL, &ctx)) {
        printf("no GL 4 core context\n");
        return 2;
    }
    CGLSetCurrentContext(ctx);
    printf("renderer: %s\nversion:  %s\nglsl:     %s\n\n", glGetString(GL_RENDERER),
           glGetString(GL_VERSION), glGetString(GL_SHADING_LANGUAGE_VERSION));

    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    GLuint tex[3];
    glGenTextures(3, tex);
    color0 = tex[0]; color1 = tex[1]; depth = tex[2];
    for (int i = 0; i < 2; i++) {
        glBindTexture(GL_TEXTURE_2D, tex[i]);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 16, 16, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + i, GL_TEXTURE_2D, tex[i], 0);
    }
    glBindTexture(GL_TEXTURE_2D, depth);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT24, 16, 16, 0, GL_DEPTH_COMPONENT, GL_UNSIGNED_INT, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depth, 0);
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    printf("FBO (2 colour + depth texture) status=0x%x %s\n\n", status,
           status == GL_FRAMEBUFFER_COMPLETE ? "complete" : "INCOMPLETE");
    GLenum one[] = { GL_COLOR_ATTACHMENT0 };
    glDrawBuffers(1, one);

    /* 1. VAO + VBO + glDrawArrays */
    begin(); vao(); vbo(TRI, sizeof(TRI), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    program("#version 410\nlayout(location=0) in vec3 p; void main(){ gl_Position = vec4(p,1); }\n", FS_RED);
    glDrawArrays(GL_TRIANGLES, 0, 3); check("1 vao+vbo drawArrays", GL_COLOR_ATTACHMENT0);

    /* 2. plain uniform mat4 */
    begin(); vao(); vbo(TRI, sizeof(TRI), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    GLuint p = program("#version 410\nlayout(location=0) in vec3 p; uniform mat4 m; void main(){ gl_Position = m*vec4(p,1); }\n", FS_RED);
    float ident[16] = { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 };
    glUniformMatrix4fv(glGetUniformLocation(p, "m"), 1, GL_FALSE, ident);
    glDrawArrays(GL_TRIANGLES, 0, 3); check("2 uniform mat4", GL_COLOR_ATTACHMENT0);

    /* 3. std140 UBO (bindBufferBase) */
    begin(); vao(); vbo(TRI, sizeof(TRI), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    p = program("#version 410\nlayout(location=0) in vec3 p; layout(std140) uniform Matrices { mat4 a; mat4 b; }; void main(){ gl_Position = b*vec4(p,1); }\n", FS_RED);
    float two[32]; memset(two, 0, sizeof(two)); memcpy(two + 16, ident, sizeof(ident));
    GLuint ubo = vbo(two, sizeof(two), GL_UNIFORM_BUFFER);
    glUniformBlockBinding(p, glGetUniformBlockIndex(p, "Matrices"), 0);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, ubo);
    glDrawArrays(GL_TRIANGLES, 0, 3); check("3 UBO bindBufferBase", GL_COLOR_ATTACHMENT0);

    /* 4. UBO via bindBufferRange at an offset */
    begin();
    float big[64]; memset(big, 0, sizeof(big)); memcpy(big + 32, two, sizeof(two));
    GLuint ubo2 = vbo(big, sizeof(big), GL_UNIFORM_BUFFER);
    glBindBufferRange(GL_UNIFORM_BUFFER, 0, ubo2, 128, 128);
    glDrawArrays(GL_TRIANGLES, 0, 3); check("4 UBO bindBufferRange", GL_COLOR_ATTACHMENT0);

    /* 5. instanced attribute with divisor 1 */
    begin(); vao(); vbo(TRI, sizeof(TRI), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    float inst[] = { 1, 0, 0, 1 };
    vbo(inst, sizeof(inst), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(8); glVertexAttribPointer(8, 4, GL_FLOAT, GL_FALSE, 0, 0);
    glVertexAttribDivisor(8, 1);
    program("#version 410\nlayout(location=0) in vec3 p; layout(location=8) in vec4 ic; out vec4 c; void main(){ c = ic; gl_Position = vec4(p,1); }\n", FS_COLOR);
    glDrawArraysInstanced(GL_TRIANGLES, 0, 3, 1); check("5 instanced divisor", GL_COLOR_ATTACHMENT0);

    /* 6. half-float attribute */
    begin(); vao(); vbo(TRI, sizeof(TRI), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    uint16_t h[12]; for (int i = 0; i < 3; i++) { h[i*4] = half(1); h[i*4+1] = half(0); h[i*4+2] = half(0); h[i*4+3] = half(1); }
    vbo(h, sizeof(h), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(9); glVertexAttribPointer(9, 4, GL_HALF_FLOAT, GL_FALSE, 0, 0);
    program("#version 410\nlayout(location=0) in vec3 p; layout(location=9) in vec4 hc; out vec4 c; void main(){ c = hc; gl_Position = vec4(p,1); }\n", FS_COLOR);
    glDrawArrays(GL_TRIANGLES, 0, 3); check("6 half-float attribute", GL_COLOR_ATTACHMENT0);

    /* 7. INT_2_10_10_10_REV normalized attribute */
    begin(); vao(); vbo(TRI, sizeof(TRI), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    uint32_t pk = 511u | (0u << 10) | (0u << 20) | (1u << 30);
    uint32_t pks[3] = { pk, pk, pk };
    vbo(pks, sizeof(pks), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(1); glVertexAttribPointer(1, 4, GL_INT_2_10_10_10_REV, GL_TRUE, 0, 0);
    program("#version 410\nlayout(location=0) in vec3 p; layout(location=1) in vec4 n; out vec4 c; void main(){ c = vec4(n.x, n.y, n.z, 1); gl_Position = vec4(p,1); }\n", FS_COLOR);
    glDrawArrays(GL_TRIANGLES, 0, 3); check("7 INT_2_10_10_10_REV", GL_COLOR_ATTACHMENT0);

    /* 8. integer attribute (VertexAttribIPointer, ivec2 short) */
    begin(); vao(); vbo(TRI, sizeof(TRI), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    int16_t iv[6] = { 7, 100, 7, 100, 7, 100 };
    vbo(iv, sizeof(iv), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(12); glVertexAttribIPointer(12, 2, GL_SHORT, 0, 0);
    program("#version 410\nlayout(location=0) in vec3 p; layout(location=12) in ivec2 m; out vec4 c; void main(){ c = (m.x==7 && m.y==100) ? vec4(1,0,0,1) : vec4(0,0,1,1); gl_Position = vec4(p,1); }\n", FS_COLOR);
    glDrawArrays(GL_TRIANGLES, 0, 3); check("8 integer attribute", GL_COLOR_ATTACHMENT0);

    /* 9. drawElementsInstancedBaseVertex */
    begin(); vao();
    float tri2[18]; memset(tri2, 0, sizeof(tri2)); memcpy(tri2 + 9, TRI, sizeof(TRI));
    vbo(tri2, sizeof(tri2), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    uint16_t idx[3] = { 0, 1, 2 };
    vbo(idx, sizeof(idx), GL_ELEMENT_ARRAY_BUFFER);
    program("#version 410\nlayout(location=0) in vec3 p; void main(){ gl_Position = vec4(p,1); }\n", FS_RED);
    glDrawElementsInstancedBaseVertex(GL_TRIANGLES, 3, GL_UNSIGNED_SHORT, 0, 1, 3);
    check("9 elements instanced basevtx", GL_COLOR_ATTACHMENT0);

    /* 10. depth test into depth texture */
    begin(); glEnable(GL_DEPTH_TEST); glDepthFunc(GL_LEQUAL); vao(); vbo(TRI, sizeof(TRI), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    program("#version 410\nlayout(location=0) in vec3 p; void main(){ gl_Position = vec4(p.xy,0.5,1); }\n", FS_RED);
    glDrawArrays(GL_TRIANGLES, 0, 3); check("10 depth test", GL_COLOR_ATTACHMENT0);
    glDisable(GL_DEPTH_TEST);

    /* 11. MRT: second attachment */
    begin(); GLenum both[] = { GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1 }; glDrawBuffers(2, both);
    glClear(GL_COLOR_BUFFER_BIT);
    vao(); vbo(TRI, sizeof(TRI), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    program("#version 410\nlayout(location=0) in vec3 p; void main(){ gl_Position = vec4(p,1); }\n",
            "#version 410\nlayout(location=0) out vec4 o0; layout(location=1) out vec4 o1; void main(){ o0 = vec4(0,0,1,1); o1 = vec4(1,0,0,1); }\n");
    glDrawArrays(GL_TRIANGLES, 0, 3); check("11 MRT attachment 1", GL_COLOR_ATTACHMENT1);
    glDrawBuffers(1, one);

    /* 12. glMapBufferRange-written vertices */
    begin(); vao(); GLuint mb = vbo(NULL, sizeof(TRI), GL_ARRAY_BUFFER);
    void *ptr = glMapBufferRange(GL_ARRAY_BUFFER, 0, sizeof(TRI), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
    if (ptr) memcpy(ptr, TRI, sizeof(TRI));
    glUnmapBuffer(GL_ARRAY_BUFFER); (void)mb;
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    program("#version 410\nlayout(location=0) in vec3 p; void main(){ gl_Position = vec4(p,1); }\n", FS_RED);
    glDrawArrays(GL_TRIANGLES, 0, 3); check("12 mapBufferRange vertices", GL_COLOR_ATTACHMENT0);

    /* 13. glBufferSubData update after draw (stream) */
    begin(); vao(); GLuint sb = vbo(NULL, sizeof(TRI), GL_ARRAY_BUFFER);
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(TRI), TRI); (void)sb;
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_TRIANGLES, 0, 3); check("13 bufferSubData vertices", GL_COLOR_ATTACHMENT0);

    /* 14. sampler object + texture */
    begin(); vao(); vbo(TRI, sizeof(TRI), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    unsigned char red[16]; for (int i = 0; i < 4; i++) { red[i*4] = 255; red[i*4+1] = 0; red[i*4+2] = 0; red[i*4+3] = 255; }
    GLuint t; glGenTextures(1, &t); glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, t);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 2, 2, 0, GL_RGBA, GL_UNSIGNED_BYTE, red);
    GLuint s; glGenSamplers(1, &s); glSamplerParameteri(s, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glBindSampler(0, s);
    p = program("#version 410\nlayout(location=0) in vec3 p; void main(){ gl_Position = vec4(p,1); }\n",
                "#version 410\nuniform sampler2D tx; out vec4 o0; void main(){ o0 = texture(tx, vec2(0.5)); }\n");
    glUniform1i(glGetUniformLocation(p, "tx"), 0);
    glDrawArrays(GL_TRIANGLES, 0, 3); check("14 sampler object", GL_COLOR_ATTACHMENT0);
    glBindSampler(0, 0);

    /* 15. texture buffer (texelFetch) */
    begin(); vao(); vbo(TRI, sizeof(TRI), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    float tb[4] = { 1, 0, 0, 1 };
    GLuint tbo = vbo(tb, sizeof(tb), GL_TEXTURE_BUFFER);
    GLuint tt; glGenTextures(1, &tt); glActiveTexture(GL_TEXTURE1); glBindTexture(GL_TEXTURE_BUFFER, tt);
    glTexBuffer(GL_TEXTURE_BUFFER, GL_RGBA32F, tbo);
    p = program("#version 410\nlayout(location=0) in vec3 p; void main(){ gl_Position = vec4(p,1); }\n",
                "#version 410\nuniform samplerBuffer b; out vec4 o0; void main(){ o0 = texelFetch(b, 0); }\n");
    glUniform1i(glGetUniformLocation(p, "b"), 1);
    glDrawArrays(GL_TRIANGLES, 0, 3); check("15 texture buffer", GL_COLOR_ATTACHMENT0);
    glActiveTexture(GL_TEXTURE0);

    /* 16. STK-like: UBO + instanced (divisor) attributes + base vertex together */
    begin(); vao();
    vbo(tri2, sizeof(tri2), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    vbo(idx, sizeof(idx), GL_ELEMENT_ARRAY_BUFFER);
    float origin[4] = { 0, 0, 0, 1 };
    vbo(origin, sizeof(origin), GL_ARRAY_BUFFER);
    glEnableVertexAttribArray(8); glVertexAttribPointer(8, 3, GL_FLOAT, GL_FALSE, 16, 0); glVertexAttribDivisor(8, 1);
    p = program("#version 410\nlayout(location=0) in vec3 p; layout(location=8) in vec3 o; layout(std140) uniform Matrices { mat4 a; mat4 b; }; void main(){ gl_Position = b*vec4(p+o,1); }\n", FS_RED);
    glUniformBlockBinding(p, glGetUniformBlockIndex(p, "Matrices"), 0);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, ubo);
    glDrawElementsInstancedBaseVertex(GL_TRIANGLES, 3, GL_UNSIGNED_SHORT, 0, 1, 3);
    check("16 STK-like combined", GL_COLOR_ATTACHMENT0);

    printf("\n%d failure(s)\n", failures);
    return failures ? 1 : 0;
}
