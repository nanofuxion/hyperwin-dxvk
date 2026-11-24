#if defined(DXVK_WSI_ANDROID)

#include "../wsi_platform.h"
#include "../wsi_monitor.h"
#include "../wsi_window.h"
#include "../../util/util_error.h"
#include "../../util/util_string.h"
#include "../../util/util_env.h"

#include <android/native_window.h>
#include <vulkan/vulkan_android.h>
#include <cstdio>

namespace dxvk::wsi {

  class AndroidWsiDriver : public WsiDriver {
  public:
    std::vector<const char *> getInstanceExtensions() override {
      return { VK_KHR_SURFACE_EXTENSION_NAME, VK_KHR_ANDROID_SURFACE_EXTENSION_NAME };
    }

    HMONITOR getDefaultMonitor() override { return monitor(); }
    HMONITOR enumMonitors(uint32_t index) override { return index ? nullptr : monitor(); }

    bool getDisplayName(HMONITOR, WCHAR (&Name)[32]) override {
      const WCHAR name[] = L"\\\\.\\DISPLAY1";
      for (size_t i = 0; i < 32; i++) Name[i] = i < sizeof(name) / sizeof(WCHAR) ? name[i] : 0;
      return true;
    }

    bool getDesktopCoordinates(HMONITOR, RECT* pRect) override {
      WsiMode m;
      getCurrentDisplayMode(nullptr, &m);
      *pRect = { 0, 0, LONG(m.width), LONG(m.height) };
      return true;
    }

    bool getDisplayMode(HMONITOR h, uint32_t modeNumber, WsiMode* pMode) override {
      return modeNumber == 0 && getCurrentDisplayMode(h, pMode);
    }

    bool getCurrentDisplayMode(HMONITOR, WsiMode* pMode) override {
      uint32_t w = 1920, h = 1080, hz = 60;
      std::string s = env::getEnvVar("HWGPU_SCREEN");
      if (!s.empty()) std::sscanf(s.c_str(), "%u %u %u", &w, &h, &hz);
      *pMode = { w, h, { hz, 1 }, 32, false };
      return true;
    }

    void getWindowSize(HWND hWindow, uint32_t* pWidth, uint32_t* pHeight) override {
      auto* w = reinterpret_cast<ANativeWindow*>(hWindow);
      if (pWidth) *pWidth = w ? uint32_t(ANativeWindow_getWidth(w)) : 0;
      if (pHeight) *pHeight = w ? uint32_t(ANativeWindow_getHeight(w)) : 0;
    }

    void resizeWindow(HWND, DxvkWindowState*, uint32_t, uint32_t) override { }
    void saveWindowState(HWND, DxvkWindowState*, bool) override { }
    void restoreWindowState(HWND, DxvkWindowState*, bool) override { }
    bool setWindowMode(HMONITOR, HWND, DxvkWindowState*, const WsiMode&) override { return true; }
    bool enterFullscreenMode(HMONITOR, HWND, DxvkWindowState*, bool) override { return true; }
    bool leaveFullscreenMode(HWND, DxvkWindowState*) override { return true; }
    bool restoreDisplayMode() override { return true; }
    HMONITOR getWindowMonitor(HWND) override { return monitor(); }
    bool isWindow(HWND hWindow) override { return hWindow != nullptr; }
    bool isMinimized(HWND) override { return false; }
    bool isOccluded(HWND) override { return false; }
    void updateFullscreenWindow(HMONITOR, HWND, bool) override { }

    VkResult createSurface(HWND hWindow, PFN_vkGetInstanceProcAddr gipa, VkInstance instance,
                           VkSurfaceKHR* pSurface) override {
      auto create = reinterpret_cast<PFN_vkCreateAndroidSurfaceKHR>(gipa(instance, "vkCreateAndroidSurfaceKHR"));
      if (!create || !hWindow) return VK_ERROR_INITIALIZATION_FAILED;
      VkAndroidSurfaceCreateInfoKHR info = { VK_STRUCTURE_TYPE_ANDROID_SURFACE_CREATE_INFO_KHR };
      info.window = reinterpret_cast<ANativeWindow*>(hWindow);
      return create(instance, &info, nullptr, pSurface);
    }

  private:
    static HMONITOR monitor() { return reinterpret_cast<HMONITOR>(uintptr_t(1)); }
  };

  static bool createAndroidWsiDriver(WsiDriver **driver) {
    *driver = new AndroidWsiDriver();
    return true;
  }

  WsiBootstrap AndroidWSI = {
    "Android",
    createAndroidWsiDriver
  };

}

#endif
