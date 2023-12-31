import 'dart:async';
import 'dart:io';

import 'cancel_token.dart';

class DioPlus {
  Future<int> download(
    String url,
    String savePath, {
    Function(int total, int received, int chunkSize)? onReceiveProgress,
    CustomCancelToken? cancelToken,
    bool deleteIfExist = false,
    Map<String, dynamic>? headers,
    int? startByte,
  }) async {
    if (deleteIfExist) {
      File file = File(savePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }

    Completer<int> completer = Completer<int>();
    Uri uri = Uri.parse(url);
    HttpClient httpClient = HttpClient();
    HttpClientRequest request = await httpClient.getUrl(uri);
    headers?.forEach((key, value) {
      request.headers.add(key, value);
    });
    HttpClientResponse response = await request.close();
    int received = 0;
    int length =
        int.parse(response.headers.value(HttpHeaders.contentLengthHeader)!);
    var raf = await File(savePath).open(mode: FileMode.append);
    if (received == length) {
      raf.closeSync();
      completer.complete(received);
    }
    late StreamSubscription responseSubscription;
    responseSubscription = response.listen((chunk) {
      if (cancelToken != null) {
        if (cancelToken.isCancelled) {
          raf.closeSync();
          responseSubscription.cancel();
          completer.complete(received);
          // throw Exception('Cancelled');
          return;
        }
      }
      received += chunk.length;
      raf.writeFromSync(chunk);
      if (onReceiveProgress != null) {
        onReceiveProgress(received, length, chunk.length);
      }

      if (received == length) {
        raf.closeSync();
        completer.complete(received);
        responseSubscription.cancel();
      }
    });

    return completer.future;
  }
}
