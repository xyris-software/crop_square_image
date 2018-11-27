package au.com.xyris.cropsquareimage;

import android.app.Activity;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.media.ExifInterface;
import android.os.Build;
import android.graphics.Matrix;
import android.util.Log;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import static android.Manifest.permission.READ_EXTERNAL_STORAGE;
import static android.Manifest.permission.WRITE_EXTERNAL_STORAGE;

/** CropSquareImagePlugin */
public class CropSquareImagePlugin implements MethodCallHandler, PluginRegistry.RequestPermissionsResultListener {
    private static final int PERMISSION_REQUEST_CODE = 13094;

    private final Activity activity;
    private Result permissionRequestResult;
    private ExecutorService executor;

    private CropSquareImagePlugin(Activity activity) {
        this.activity = activity;
        this.executor = Executors.newCachedThreadPool();
    }

    /** Plugin registration. */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "crop_square_image");
        CropSquareImagePlugin instance = new CropSquareImagePlugin(registrar.activity());
        channel.setMethodCallHandler(instance);
        registrar.addRequestPermissionsResultListener(instance);
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        if (call.method.equals("getPlatformVersion")) {
            result.success("Hello world " + android.os.Build.VERSION.RELEASE);
            //result.success("Android " + android.os.Build.VERSION.RELEASE);
        } else if (call.method.equals("getCurrentTemperature")) {
            result.success("16.9 degrees");
        } else if ("cropImage".equals(call.method)) {
            String path = call.argument("path");
            double scale = call.argument("scale");
            double left = call.argument("left");
            double top = call.argument("top");
            double right = call.argument("right");
            double bottom = call.argument("bottom");
            RectF area = new RectF((float) left, (float) top, (float) right, (float) bottom);
            cropImage(path, area, (float) scale, result);
        } else if ("cropImage2".equals(call.method)) {
            String fileName = call.argument("file");
            int originX = call.argument("originX");
            int originY = call.argument("originY");
            int width = call.argument("width");
            int height = call.argument("height");
            cropImage2(fileName, originX, originY, width, height, result);
        } else if ("scaleImage2".equals(call.method)) {
            String fileName = call.argument("file");
            int resizePercentage = call.argument("percentage");
            int targetWidth = call.argument("targetWidth") == null ? 0 : (int) call.argument("targetWidth");
            int targetHeight = call.argument("targetHeight") == null ? 0 : (int) call.argument("targetHeight");
            int quality = call.argument("quality");
            scaleImage2(fileName, resizePercentage, targetWidth, targetHeight, quality, result);
        } else if ("getImageDimensions".equals(call.method)) {
            String path = call.argument("path");
            getImageDimensions(path, result);
        } else if ("requestPermissions".equals(call.method)) {
            requestPermissions(result);
        } else {
            result.notImplemented();
        }
    }

    private void scaleImage2(final String fileName, final int resizePercentage, final int targetWidth, final int targetHeight, final int quality, Result result) {
        File file = new File(fileName);

        if(!file.exists()) {
            result.error("file does not exist", fileName, null);
            return;
        }

        Bitmap bmp = BitmapFactory.decodeFile(fileName);
        ByteArrayOutputStream bos = new ByteArrayOutputStream();

        int newWidth = targetWidth == 0 ? (bmp.getWidth() / 100 * resizePercentage) : targetWidth;
        int newHeight = targetHeight == 0 ? (bmp.getHeight() / 100 * resizePercentage) : targetHeight;

        bmp = Bitmap.createScaledBitmap(
                bmp, newWidth, newHeight, false);

        bmp.compress(Bitmap.CompressFormat.JPEG, quality, bos);

        try {
            String outputFileName = File.createTempFile(
                    getFilenameWithoutExtension(file).concat("_compressed"),
                    ".jpg",
                    activity.getExternalCacheDir()
            ).getPath();

            OutputStream outputStream = new FileOutputStream(outputFileName);
            bos.writeTo(outputStream);

            copyExif(fileName, outputFileName, newWidth, newHeight);

            result.success(outputFileName);
        } catch (FileNotFoundException e) {
            e.printStackTrace();
            result.error("file does not exist", fileName, null);
        } catch (IOException e) {
            e.printStackTrace();
            result.error("something went wrong", fileName, null);
        }
    }

    private void cropImage2(final String fileName, final int originX, final int originY, final int width, final int height, Result result) {
        File file = new File(fileName);

        if(!file.exists()) {
            result.error("file does not exist", fileName, null);
            return;
        }

        Bitmap bmp = BitmapFactory.decodeFile(fileName);
        ByteArrayOutputStream bos = new ByteArrayOutputStream();

        try {
            bmp = Bitmap.createBitmap(bmp, originX, originY, width, height);
        } catch(IllegalArgumentException e) {
            e.printStackTrace();
            result.error("bounds are outside of the dimensions of the source image", fileName, null);
        }

        bmp.compress(Bitmap.CompressFormat.JPEG, 100, bos);

        try {
            String outputFileName = File.createTempFile(
                    getFilenameWithoutExtension(file).concat("_cropped"),
                    ".jpg",
                    activity.getExternalCacheDir()
            ).getPath();

            OutputStream outputStream = new FileOutputStream(outputFileName);
            bos.writeTo(outputStream);

            copyExif(fileName, outputFileName, width, height);

            result.success(outputFileName);
        } catch (FileNotFoundException e) {
            e.printStackTrace();
            result.error("file does not exist", fileName, null);
        } catch (IOException e) {
            e.printStackTrace();
            result.error("something went wrong", fileName, null);
        }
    }

    private void cropImage(final String path, final RectF area, final float scale, final Result result) {
        executor.execute(new Runnable() {
            @Override
            public void run() {
                File srcFile = new File(path);
                if (!srcFile.exists()) {
                    result.error("INVALID", "Image source cannot be opened", null);
                    return;
                }

                Bitmap srcBitmap = BitmapFactory.decodeFile(path, null);
                if (srcBitmap == null) {
                    result.error("INVALID", "Image source cannot be decoded", null);
                    return;
                }

                int width = (int) (srcBitmap.getWidth() * area.width() * scale);
                int height = (int) (srcBitmap.getHeight() * area.height() * scale);

                Bitmap dstBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
                Canvas canvas = new Canvas(dstBitmap);

                Paint paint = new Paint();
                paint.setAntiAlias(true);
                paint.setFilterBitmap(true);
                paint.setDither(true);

                Rect srcRect = new Rect((int) (srcBitmap.getWidth() * area.left), (int) (srcBitmap.getHeight() * area.top),
                        (int) (srcBitmap.getWidth() * area.right), (int) (srcBitmap.getHeight() * area.bottom));
                Rect dstRect = new Rect(0, 0, width, height);

                canvas.drawBitmap(srcBitmap, srcRect, dstRect, paint);

                // Kludge - rotate image 90 degrees clockwise
                Matrix matrix = new Matrix();
                matrix.postRotate(90);
                Bitmap rotatedBitmap = Bitmap.createBitmap(dstBitmap, 0, 0, dstBitmap.getWidth(), dstBitmap.getHeight(), matrix, true);
                try {
                    File dstFile = createTemporaryImageFile();
                    compressBitmap(rotatedBitmap, dstFile);
                    result.success(dstFile.getAbsolutePath());
                } catch (IOException e) {
                    result.error("INVALID", "Image could not be saved", e);
                } finally {
                    canvas.setBitmap(null);
                    dstBitmap.recycle();
                    srcBitmap.recycle();
                    rotatedBitmap.recycle();
                }
            }
        });
    }

    @SuppressWarnings("TryFinallyCanBeTryWithResources")
    private void compressBitmap(Bitmap bitmap, File file) throws IOException {
        OutputStream outputStream = new FileOutputStream(file);
        try {
            boolean compressed = bitmap.compress(Bitmap.CompressFormat.JPEG, 25, outputStream);
            if (!compressed) {
                throw new IOException("Failed to compress bitmap into JPEG");
            }
        } finally {
            try {
                outputStream.close();
            } catch (IOException ignore) {
            }
        }
    }

    private void getImageDimensions(final String path, final Result result) {
        executor.execute(new Runnable() {
            @Override
            public void run() {
                File file = new File(path);
                if (!file.exists()) {
                    result.error("INVALID", "Image source cannot be opened", null);
                    return;
                }

                BitmapFactory.Options options = new BitmapFactory.Options();
                options.inJustDecodeBounds = true;
                BitmapFactory.decodeFile(path, options);

                Map<String, Object> properties = new HashMap<>();
                properties.put("width", options.outWidth);
                properties.put("height", options.outHeight);

                result.success(properties);
            }
        });
    }

    private void requestPermissions(Result result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (activity.checkSelfPermission(READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED &&
                    activity.checkSelfPermission(WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED) {
                result.success(true);
            } else {
                permissionRequestResult = result;
                activity.requestPermissions(new String[]{READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE}, PERMISSION_REQUEST_CODE);
            }
        } else {
            result.success(true);
        }
    }

    @Override
    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == PERMISSION_REQUEST_CODE && permissionRequestResult != null) {
            int readExternalStorage = getPermissionGrantResult(READ_EXTERNAL_STORAGE, permissions, grantResults);
            int writeExternalStorage = getPermissionGrantResult(WRITE_EXTERNAL_STORAGE, permissions, grantResults);
            permissionRequestResult.success(readExternalStorage == PackageManager.PERMISSION_GRANTED &&
                    writeExternalStorage == PackageManager.PERMISSION_GRANTED);
            permissionRequestResult = null;
        }
        return false;
    }

    private int getPermissionGrantResult(String permission, String[] permissions, int[] grantResults) {
        for (int i = 0; i < permission.length(); i++) {
            if (permission.equals(permissions[i])) {
                return grantResults[i];
            }
        }
        return PackageManager.PERMISSION_DENIED;
    }

    private File createTemporaryImageFile() throws IOException {
        File directory = activity.getCacheDir();
        String name = "crop_square_image_" + UUID.randomUUID().toString();
        return File.createTempFile(name, ".jpg", directory);
    }

    private static String getFilenameWithoutExtension(File file) {
        String fileName = file.getName();

        if (fileName.indexOf(".") > 0) {
            return fileName.substring(0, fileName.lastIndexOf("."));
        } else {
            return fileName;
        }
    }

    private void copyExif(String filePathOri, String filePathDest, int width, int height) {
        try {
            ExifInterface oldExif = new ExifInterface(filePathOri);
            ExifInterface newExif = new ExifInterface(filePathDest);

            List<String> attributes =
                    Arrays.asList(
                            "FNumber",
                            "ExposureTime",
                            "ISOSpeedRatings",
                            "GPSAltitude",
                            "GPSAltitudeRef",
                            "FocalLength",
                            "GPSDateStamp",
                            "WhiteBalance",
                            "GPSProcessingMethod",
                            "GPSTimeStamp",
                            "DateTime",
                            "Flash",
                            "GPSLatitude",
                            "GPSLatitudeRef",
                            "GPSLongitude",
                            "GPSLongitudeRef",
                            "Make",
                            "Model",
                            "Orientation"
                            );
            for (String attribute : attributes) {
                setIfNotNull(oldExif, newExif, attribute);
            }
            newExif.setAttribute("PixelXDimension", String.valueOf(width));
            newExif.setAttribute("PixelYDimension", String.valueOf(height));

            newExif.saveAttributes();

        } catch (Exception ex) {
            Log.e("CropSquareImagePlugin", "Error preserving Exif data on selected image: " + ex);
        }
    }

    private void setIfNotNull(ExifInterface oldExif, ExifInterface newExif, String property) {
        if (oldExif.getAttribute(property) != null) {
            newExif.setAttribute(property, oldExif.getAttribute(property));
        }
    }
}
