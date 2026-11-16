#include <algorithm>
#include <array>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <numeric>
#include <stdexcept>
#include <string>
#include <vector>

#ifdef __APPLE__
#define GL_SILENCE_DEPRECATION
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl3.h>
#endif

struct Outcome {
    std::string name;
    int payout{};
    int weight{};
};

struct Matchday {
    int safeCash{};
    int cupValue{};
    std::array<Outcome, 3> shots;
};

Matchday readMatchday(std::istream& input) {
    Matchday rules;
    if (!(input >> rules.safeCash >> rules.cupValue) || rules.safeCash <= 0 || rules.cupValue <= 0) {
        throw std::runtime_error("Invalid safe cash or cup value");
    }
    for (auto& shot : rules.shots) {
        if (!(input >> shot.name >> shot.payout >> shot.weight) || shot.weight < 1 || shot.weight > 9) {
            throw std::runtime_error("Invalid shot outcome");
        }
    }
    for (const auto* expected : {"goal", "save", "offside"}) {
        const auto count = std::count_if(rules.shots.begin(), rules.shots.end(),
            [expected](const Outcome& shot) { return shot.name == expected; });
        if (count != 1) throw std::runtime_error("Every shot outcome must occur once");
    }
    std::string extra;
    if (input >> extra) throw std::runtime_error("Unexpected extra data");
    return rules;
}

int totalWeight(const Matchday& rules) {
    return std::accumulate(rules.shots.begin(), rules.shots.end(), 0,
        [](int sum, const Outcome& shot) { return sum + shot.weight; });
}

#ifdef __APPLE__
struct Vertex {
    float x, y, r, g, b;
};

void rectangle(std::vector<Vertex>& vertices, float x, float y, float w, float h,
               std::array<float, 3> color) {
    const auto [r, g, b] = color;
    const Vertex a{x, y, r, g, b}, c{x + w, y + h, r, g, b};
    const Vertex btm{x + w, y, r, g, b}, top{x, y + h, r, g, b};
    vertices.insert(vertices.end(), {a, btm, c, a, c, top});
}

class Context {
public:
    Context() {
        const auto profile = static_cast<CGLPixelFormatAttribute>(kCGLOGLPVersion_3_2_Core);
        const CGLPixelFormatAttribute attrs[] = {
            kCGLPFAOpenGLProfile, profile, kCGLPFAAllowOfflineRenderers, static_cast<CGLPixelFormatAttribute>(0)
        };
        GLint count = 0;
        CGLPixelFormatObj format = nullptr;
        if (CGLChoosePixelFormat(attrs, &format, &count) != kCGLNoError || format == nullptr) {
            throw std::runtime_error("No OpenGL Core pixel format");
        }
        const auto error = CGLCreateContext(format, nullptr, &context_);
        CGLReleasePixelFormat(format);
        if (error != kCGLNoError || CGLSetCurrentContext(context_) != kCGLNoError) {
            if (context_) CGLReleaseContext(context_);
            throw std::runtime_error("Could not activate an offscreen OpenGL Core context");
        }
    }
    Context(const Context&) = delete;
    Context& operator=(const Context&) = delete;
    ~Context() {
        CGLSetCurrentContext(nullptr);
        CGLReleaseContext(context_);
    }
private:
    CGLContextObj context_{};
};

GLuint compile(GLenum kind, const char* source) {
    const GLuint shader = glCreateShader(kind);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);
    GLint ok = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (ok != GL_TRUE) {
        std::array<char, 512> log{};
        glGetShaderInfoLog(shader, static_cast<GLsizei>(log.size()), nullptr, log.data());
        throw std::runtime_error(log.data());
    }
    return shader;
}

void preview(const Matchday& rules, const char* path) {
    const Context context;
    constexpr GLsizei width = 960, height = 540;
    const GLuint vs = compile(GL_VERTEX_SHADER, R"(#version 150 core
        in vec2 position; in vec3 rgb; out vec3 color;
        void main() { color=rgb; gl_Position=vec4(position,0,1); })");
    const GLuint fs = compile(GL_FRAGMENT_SHADER, R"(#version 150 core
        in vec3 color; out vec4 pixel; void main() { pixel=vec4(color,1); })");
    GLuint program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glBindAttribLocation(program, 0, "position");
    glBindAttribLocation(program, 1, "rgb");
    glLinkProgram(program);
    GLint linked = GL_FALSE;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (linked != GL_TRUE) throw std::runtime_error("Could not link preview shader");

    GLuint fbo{}, texture{}, vao{}, buffer{};
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        throw std::runtime_error("Offscreen framebuffer is incomplete");
    }

    const std::array<float, 3> chalk{.49F, .69F, .61F}, grass{.10F, .24F, .22F};
    const std::array<float, 3> green{.73F, .97F, .51F}, blue{.36F, .67F, .91F}, pink{.98F, .54F, .60F};
    std::vector<Vertex> vertices;
    rectangle(vertices, -.89F, -.76F, 1.78F, 1.52F, grass);
    for (float x : {-.89F, 0.0F, .88F}) rectangle(vertices, x, -.76F, .009F, 1.52F, chalk);
    for (float y : {-.76F, .752F}) rectangle(vertices, -.89F, y, 1.78F, .008F, chalk);
    rectangle(vertices, -.75F, .54F, 1.50F, .035F, chalk);
    float offset = -.75F;
    const auto total = static_cast<float>(totalWeight(rules));
    for (const auto& shot : rules.shots) {
        const float w = 1.5F * static_cast<float>(shot.weight) / total;
        const auto& swatch = shot.name == "goal" ? green : (shot.name == "save" ? blue : pink);
        rectangle(vertices, offset, .30F, w - .012F, .18F, swatch);
        offset += w;
    }
    const auto safe = static_cast<float>(rules.safeCash) / 200;
    rectangle(vertices, -.75F, -.12F, 1.5F, .095F, { .15F, .33F, .30F });
    rectangle(vertices, -.75F, -.12F, 1.5F * safe, .095F, blue);
    float y = -.44F;
    for (const auto& shot : rules.shots) {
        const float payout = std::clamp(static_cast<float>(shot.payout) / 200, -1.0F, 1.0F) * .73F;
        rectangle(vertices, std::min(0.0F, payout), y, std::abs(payout), .055F,
                  shot.name == "goal" ? green : (shot.name == "save" ? blue : pink));
        y -= .1F;
    }
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, static_cast<GLsizeiptr>(vertices.size() * sizeof(Vertex)), vertices.data(), GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), nullptr);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), reinterpret_cast<void*>(2 * sizeof(float)));
    glViewport(0, 0, width, height);
    glClearColor(.035F, .062F, .092F, 1.F);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(program);
    glDrawArrays(GL_TRIANGLES, 0, static_cast<GLsizei>(vertices.size()));
    std::vector<char> pixels(static_cast<std::size_t>(width) * height * 3);
    glReadPixels(0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, pixels.data());
    if (glGetError() != GL_NO_ERROR) throw std::runtime_error("OpenGL render or readback failed");
    std::ofstream out(path, std::ios::binary);
    out << "P6\n" << width << ' ' << height << "\n255\n";
    for (int row = height - 1; row >= 0; --row) out.write(pixels.data() + row * width * 3, width * 3);
    if (!out) throw std::runtime_error("Could not write the preview");
    std::cout << "Renderer: " << glGetString(GL_RENDERER) << '\n';
    glDeleteBuffers(1, &buffer);
    glDeleteVertexArrays(1, &vao);
    glDeleteTextures(1, &texture);
    glDeleteFramebuffers(1, &fbo);
    glDeleteProgram(program);
    glDeleteShader(vs);
    glDeleteShader(fs);
}
#endif

int main(int argc, char** argv) try {
    const auto rules = readMatchday(std::cin);
    const auto weight = static_cast<double>(totalWeight(rules));
    double cash = 0, value = 0, goal = 0;
    for (const auto& shot : rules.shots) {
        const double probability = shot.weight / weight;
        cash += probability * shot.payout;
        value += probability * shot.payout;
        if (shot.name == "goal") {
            goal = probability;
            value += probability * rules.cupValue;
        }
    }
    std::cout << std::fixed << std::setprecision(3)
              << "goal_probability=" << goal << " expected_cash=" << cash << " expected_value=" << value
              << " safe_cash=" << rules.safeCash << '\n';
    if (argc == 1) return 0;
    if (argc != 3 || std::string(argv[1]) != "--preview") throw std::runtime_error("Usage: cup_preview [--preview picture.ppm]");
#ifdef __APPLE__
    preview(rules, argv[2]);
#else
    throw std::runtime_error("Offscreen preview uses macOS CGL; the balance check is portable");
#endif
    return 0;
} catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
}
