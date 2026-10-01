
#include "include/flutter_qjs/flutter_qjs_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/plugin_registrar_windows.h>

namespace
{

  class FlutterQjsPlugin : public flutter::Plugin
  {
  public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

    FlutterQjsPlugin();

    virtual ~FlutterQjsPlugin();
  };

  // static
  void FlutterQjsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar) {}

  FlutterQjsPlugin::FlutterQjsPlugin() {}

  FlutterQjsPlugin::~FlutterQjsPlugin() {}
} // namespace

void FlutterQjsPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
  FlutterQjsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
