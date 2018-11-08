package au.com.xyris.cropsquareimage;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/** CropSquareImagePlugin */
public class CropSquareImagePlugin implements MethodCallHandler {
  /** Plugin registration. */
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "crop_square_image");
    channel.setMethodCallHandler(new CropSquareImagePlugin());
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    if (call.method.equals("getPlatformVersion")) {
      result.success("Hello world " + android.os.Build.VERSION.RELEASE);
      //result.success("Android " + android.os.Build.VERSION.RELEASE);
    } else if (call.method.equals("getCurrentTemperature")) {
      result.success("16.9 degrees");
    } else {
      result.notImplemented();
    }
  }
}
