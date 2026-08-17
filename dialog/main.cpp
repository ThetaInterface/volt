#include <FL/Fl.H>
#include <FL/Fl_Box.H>
#include <FL/Fl_Button.H>
#include <FL/Fl_Multiline_Input.H>
#include <FL/Fl_Window.H>

#include <clocale>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#ifdef _WIN32
#include <shellapi.h>
#include <windows.h>
#elif defined(__APPLE__)
#include <limits.h>
#include <mach-o/dyld.h>
#include <unistd.h>
#else
#include <limits.h>
#include <unistd.h>
#endif

struct Options {
    std::string title = u8"Enter text";
    std::string saveButton = u8"Save";
    std::string cancelButton = u8"Cancel";
    std::string placeholder = u8"Type here...";
};

static std::filesystem::path outputPath;
static Fl_Window *window = nullptr;
static bool isSaved = false;

static const Fl_Color windowColor = fl_rgb_color(32, 32, 35);
static const Fl_Color inputColor = fl_rgb_color(24, 24, 27);
static const Fl_Color buttonColor = fl_rgb_color(48, 48, 54);
static const Fl_Color textColor = fl_rgb_color(235, 235, 235);
static const Fl_Color selectionColor = fl_rgb_color(82, 109, 165);
static const size_t maxPastedLineLength = 80;

static bool isUtf8Continuation(unsigned char value) {
    return (value & 0xC0) == 0x80;
}

static void appendWrappedCharacter(std::string &result, const std::string &text,
                                   size_t &index, size_t &lineLength) {
    if (lineLength >= maxPastedLineLength) {
        result.push_back('\n');
        lineLength = 0;
    }

    result.push_back(text[index++]);

    while (index < text.size() && isUtf8Continuation(
                                      static_cast<unsigned char>(text[index]))) {
        result.push_back(text[index++]);
    }

    ++lineLength;
}

class TextInput : public Fl_Multiline_Input {
  public:
    TextInput(int x, int y, int width, int height)
        : Fl_Multiline_Input(x, y, width, height) {}

    int handle(int event) override {
        if (event == FL_PASTE) {
            std::string text(Fl::event_text(),
                             static_cast<size_t>(Fl::event_length()));
            std::string normalized;
            normalized.reserve(text.size());
            size_t lineLength = 0;

            for (size_t i = 0; i < text.size(); ++i) {
                if (text[i] == '\r') {
                    if (i + 1 < text.size() && text[i + 1] == '\n') {
                        ++i;
                    }

                    normalized.push_back('\n');
                    lineLength = 0;
                } else if (text[i] == '\n') {
                    normalized.push_back('\n');
                    lineLength = 0;
                } else {
                    appendWrappedCharacter(normalized, text, i, lineLength);
                    --i;
                }
            }

            replace(position(), mark(), normalized.c_str(),
                    static_cast<int>(normalized.size()));
            return 1;
        }

        if (event == FL_KEYDOWN) {
            const int key = Fl::event_key();
            const int state = Fl::event_state();
            const bool modifier = (state & FL_CTRL) || (state & FL_COMMAND);

            if (modifier && (key == 'c' || key == 'C')) {
                copy(1);
                return 1;
            }

            if (modifier && (key == 'x' || key == 'X')) {
                copy(1);
                cut();
                return 1;
            }

            if (modifier && (key == 'v' || key == 'V')) {
                Fl::paste(*this, 1);
                return 1;
            }

            if (modifier && (key == 'a' || key == 'A')) {
                position(size(), 0);
                return 1;
            }
        }

        return Fl_Multiline_Input::handle(event);
    }
};

static TextInput *input = nullptr;

#ifdef _WIN32
static std::string utf16ToUtf8(const wchar_t *value) {
    if (!value) {
        return {};
    }

    int size =
        WideCharToMultiByte(CP_UTF8, 0, value, -1, nullptr, 0, nullptr, nullptr);
    if (size <= 1) {
        return {};
    }

    std::string result(static_cast<size_t>(size - 1), '\0');
    WideCharToMultiByte(CP_UTF8, 0, value, -1, result.data(), size, nullptr,
                        nullptr);
    return result;
}

static std::filesystem::path utf16Path(const wchar_t *value) {
    return std::filesystem::path(value);
}
#endif

static std::vector<std::string> getArgs(int argc, char **argv) {
#ifdef _WIN32
    int wideArgc = 0;
    LPWSTR *wideArgv = CommandLineToArgvW(GetCommandLineW(), &wideArgc);
    std::vector<std::string> args;

    if (wideArgv) {
        args.reserve(static_cast<size_t>(wideArgc));

        for (int i = 0; i < wideArgc; ++i) {
            args.push_back(utf16ToUtf8(wideArgv[i]));
        }

        LocalFree(wideArgv);
    }

    return args;
#else
    std::vector<std::string> args;
    args.reserve(static_cast<size_t>(argc));

    for (int i = 0; i < argc; ++i) {
        args.emplace_back(argv[i]);
    }
    return args;
#endif
}

static Options parseOptions(const std::vector<std::string> &args) {
    Options options;

    for (size_t i = 1; i < args.size(); ++i) {
        const std::string &arg = args[i];
        size_t equals = arg.find('=');
        std::string key = equals == std::string::npos ? arg : arg.substr(0, equals);
        std::string value;

        if (equals == std::string::npos) {
            if (i + 1 >= args.size()) {
                continue;
            }

            value = args[++i];
        } else {
            value = arg.substr(equals + 1);
        }

        if (key == "--title" || key == "-title") {
            options.title = value;
        } else if (key == "--save-btn" || key == "-save-btn") {
            options.saveButton = value;
        } else if (key == "--cancel-btn" || key == "-cancel-btn") {
            options.cancelButton = value;
        } else if (key == "--placeholder" || key == "-placeholder") {
            options.placeholder = value;
        }
    }

    return options;
}

static std::filesystem::path executablePath(char *argv0) {
#ifdef _WIN32
    std::wstring buffer(MAX_PATH, L'\0');
    DWORD size = GetModuleFileNameW(nullptr, buffer.data(),
                                    static_cast<DWORD>(buffer.size()));

    while (size == buffer.size()) {
        buffer.resize(buffer.size() * 2);
        size = GetModuleFileNameW(nullptr, buffer.data(),
                                  static_cast<DWORD>(buffer.size()));
    }

    buffer.resize(size);
    return utf16Path(buffer.c_str());
#elif defined(__APPLE__)
    uint32_t size = 0;
    _NSGetExecutablePath(nullptr, &size);
    std::string buffer(size, '\0');

    if (_NSGetExecutablePath(buffer.data(), &size) == 0) {
        char resolved[PATH_MAX];
        if (realpath(buffer.c_str(), resolved)) {
            return std::filesystem::path(resolved);
        }

        return std::filesystem::path(buffer.c_str());
    }

    return std::filesystem::absolute(argv0);
#else
    std::string buffer(PATH_MAX, '\0');
    ssize_t size = readlink("/proc/self/exe", buffer.data(), buffer.size() - 1);

    if (size > 0) {
      buffer.resize(static_cast<size_t>(size));
      return std::filesystem::path(buffer);
    }

    return std::filesystem::absolute(argv0);
#endif
}

static void writeOutput(const std::string &text) {
    std::ofstream file(outputPath, std::ios::binary | std::ios::trunc);
    file.write(text.data(), static_cast<std::streamsize>(text.size()));
}

static void saveCallback(Fl_Widget *, void *) {
    writeOutput(input->value() ? input->value() : "");
    isSaved = true;
    window->hide();
}

static void cancelCallback(Fl_Widget *, void *) {
    writeOutput("");
    isSaved = true;
    window->hide();
}

static void closeCallback(Fl_Widget *, void *) {
    if (!isSaved) {
        writeOutput("");
    }
    window->hide();
}

static void applyDarkTheme(Fl_Window &mainWindow, Fl_Box &label,
                           TextInput &textInput,
                           Fl_Button &cancelButton, Fl_Button &saveButton) {
    Fl::background(32, 32, 35);
    Fl::background2(24, 24, 27);
    Fl::foreground(235, 235, 235);
    Fl::set_color(FL_SELECTION_COLOR, selectionColor);

    mainWindow.color(windowColor);
    label.labelcolor(textColor);

    textInput.color(inputColor);
    textInput.textcolor(textColor);
    textInput.selection_color(selectionColor);
    textInput.labelcolor(textColor);

    cancelButton.color(buttonColor);
    cancelButton.labelcolor(textColor);
    cancelButton.selection_color(selectionColor);

    saveButton.color(buttonColor);
    saveButton.labelcolor(textColor);
    saveButton.selection_color(selectionColor);
}

int main(int argc, char **argv) {
    std::setlocale(LC_ALL, "");

    std::vector<std::string> args = getArgs(argc, argv);
    Options options = parseOptions(args);
    outputPath = executablePath(argv[0]).parent_path() / "_dialog_output.txt";

    Fl::scheme("gtk+");
    Fl::visible_focus(1);

    Fl_Window mainWindow(500, 350, options.title.c_str());
    window = &mainWindow;

    Fl_Box label(20, 15, 460, 25, u8"Введите текст ниже:");
    TextInput textInput(20, 50, 460, 240);
    textInput.wrap(1);
    textInput.tooltip(options.placeholder.c_str());
    input = &textInput;

    Fl_Button cancelButton(280, 305, 95, 30, options.cancelButton.c_str());
    Fl_Button saveButton(385, 305, 95, 30, options.saveButton.c_str());

    applyDarkTheme(mainWindow, label, textInput, cancelButton, saveButton);

    cancelButton.callback(cancelCallback);
    saveButton.callback(saveCallback);
    mainWindow.callback(closeCallback);

    mainWindow.end();
    mainWindow.resizable(textInput);
    mainWindow.show();
    Fl::focus(&textInput);

    return Fl::run();
}
