#include "flutter_window.h"

#include <optional>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  keystroke_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "com.locknkey.app/keystroke",
      &flutter::StandardMethodCodec::GetInstance());

  keystroke_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "typeText") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto text_it = arguments->find(flutter::EncodableValue("text"));
            if (text_it != arguments->end() && std::holds_alternative<std::string>(text_it->second)) {
              std::string text = std::get<std::string>(text_it->second);

              // Hide window to restore focus to previous app
              ::ShowWindow(GetHandle(), SW_HIDE);
              ::Sleep(200); // Wait for focus switch

              // Convert to wstring for SendInput
              int len = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, NULL, 0);
              if (len > 0) {
                 std::vector<wchar_t> wtext(len);
                 MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, &wtext[0], len);

                 std::vector<INPUT> inputs;
                 inputs.reserve(wtext.size() * 2);

                 for (wchar_t ch : wtext) {
                   if (ch == 0) continue;

                   INPUT input = {0};
                   input.type = INPUT_KEYBOARD;
                   input.ki.wScan = ch;
                   input.ki.time = 0;
                   input.ki.dwExtraInfo = 0;
                   input.ki.dwFlags = KEYEVENTF_UNICODE;
                   inputs.push_back(input);

                   input.ki.dwFlags = KEYEVENTF_KEYUP | KEYEVENTF_UNICODE;
                   inputs.push_back(input);
                 }

                 if (!inputs.empty()) {
                    SendInput(static_cast<UINT>(inputs.size()), inputs.data(), sizeof(INPUT));
                 }
              }
               // Secure cleanup
               std::fill(text.begin(), text.end(), '\0');
               result->Success();
               return;
            }
          }
          result->Error("INVALID_ARGUMENT", "Text argument missing or invalid");
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
