import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'package:intl/intl.dart';

import 'package:http/http.dart' as http;

import 'package:logger/logger.dart';
import 'package:path/path.dart';

import 'package:http_parser/http_parser.dart';

extension SplitByLength on String {
  List<String> splitByLength1(int length, {bool ignoreEmpty = false}) {
    List<String> pieces = [];

    for (int i = 0; i < this.length; i += length) {
      int offset = i + length;
      var piece = substring(i, offset >= this.length ? this.length : offset);

      if (ignoreEmpty) {
        piece = piece.replaceAll(RegExp(r'\s+'), '');
      }

      pieces.add(piece);
    }
    return pieces;
  }

  bool get canSendToSearch {
    if (isEmpty) false;

    return split(' ').last.length > 2;
  }

  String get removeSpace => replaceAll(' ', '');

  int get numberOnly {
    try {
      return int.parse(this);
    } on Exception {
      return 0;
    }
  }

  double get getCost {
    RegExp regExp = RegExp(r"(\d+\.\d+)");
    String? match = regExp.stringMatch(this);
    double number = double.parse(match ?? '0');
    return number;
  }

  String get removeDuplicates {
    List<String> words = split(' ');
    Set<String> uniqueWords = Set<String>.from(words);
    List<String> uniqueList = uniqueWords.toList();
    String output = uniqueList.join(' ');
    return output;
  }
}

extension DateUtcHelper on DateTime {
  int get hashDate => (day * 61) + (month * 83) + (year * 23);

  DateTime get getUtc => DateTime.utc(year, month, day);

  DateTime addFromNow({int? year, int? month, int? day}) {
    return DateTime(
        this.year + (year ?? 0), this.month + (month ?? 0), this.day + (day ?? 0));
  }
}

var loggerObject = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    // number of method calls to be displayed
    errorMethodCount: 0,
    // number of method calls if stacktrace is provided
    lineLength: 300,
    // width of the output
    colors: true,
    // Colorful log messages
    printEmojis: false,
    // Print an emoji for each log message
    printTime: false,
  ),
);

DateTime? _serverDate;

DateTime get getServerDate => _serverDate ?? DateTime.now();

DateTime getDateTimeFromHeaders(http.Response response) {
  final headers = response.headers;

  if (headers.containsKey('date')) {
    final dateString = headers['date']!;

    final dateTime = parseGMTDate(dateString);
    return dateTime.addFromNow();
  } else {
    return DateTime.now();
  }
}

DateTime parseGMTDate(String dateString) {
  final formatter = DateFormat('EEE, dd MMM yyyy HH:mm:ss \'GMT\'');
  return formatter.parseUTC(dateString);
}

class APIService {
  static APIService _singleton = APIService._internal();

  void initHeader({Map<String, String> header = const {}}) {
    innerHeader.addAll(header);
  }

  void initBaseUrl({required String baseUrl}) {
    this.baseUrl = baseUrl;
  }

  factory APIService() => _singleton;

  factory APIService.reInitial() {
    _singleton = APIService._internal();
    return _singleton;
  }

  final innerHeader = {
    'Content-Type': 'application/json',
  };
  var baseUrl = '';

  APIService._internal();

  Future<DateTime> getServerTime() async {
    if (_serverDate != null) return _serverDate!;
    var uri = Uri.https(baseUrl);

    final response = await http.get(uri, headers: innerHeader).timeout(
          const Duration(seconds: 40),
          onTimeout: () => http.Response('connectionTimeOut', 481),
        );

    _serverDate = getDateTimeFromHeaders(response);

    return _serverDate!;
  }

  Future<http.Response> getApi({
    required String url,
    Map<String, dynamic>? query,
    Map<String, String>? header,
    String? path,
    String? hostName,
  }) async {
    if (query != null) query.removeWhere((key, value) => value == null);

    innerHeader.addAll(header ?? {});

    if (path != null) url = '$url/$path';

    if (query != null) {
      query.removeWhere((key, value) => value == null);
      query.forEach((key, value) => query[key] = value.toString());
    }

    logRequest('${hostName ?? ''}$url', query);

    final uri = Uri.https(hostName ?? baseUrl, url, query);

    final response = await http.get(uri, headers: innerHeader).timeout(
          const Duration(seconds: 400),
          onTimeout: () => http.Response('connectionTimeOut', 481),
        );

    logResponse(url, response);
    return response;
  }

  Uri getUri({
    required String url,
    Map<String, dynamic>? query,
    Map<String, String>? header,
    String? path,
    String? hostName,
  }) {
    if (query != null) query.removeWhere((key, value) => value == null);

    innerHeader.addAll(header ?? {});

    if (path != null) url = '$url/$path';

    if (query != null) {
      query.removeWhere((key, value) => value == null);
      query.forEach((key, value) => query[key] = value.toString());
    }

    logRequest('${hostName ?? ''}$url', query);

    final uri = Uri.https(hostName ?? baseUrl, url, query);

    return uri;
  }

  Future<http.Response> postApi({
    required String url,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, String>? header,
    String? hostName,
  }) async {
    if (body != null) body.removeWhere((key, value) => value == null);

    if (query != null) {
      query.removeWhere((key, value) => value == null);
      query.forEach((key, value) => query[key] = value.toString());
    }

    innerHeader.addAll(header ?? {});

    final uri = Uri.https(hostName ?? baseUrl, url, query);

    logRequest(url, (body ?? {})..addAll(query ?? {}));

    final response =
        await http.post(uri, body: jsonEncode(body), headers: innerHeader).timeout(
              const Duration(seconds: 400),
              onTimeout: () => http.Response('connectionTimeOut', 481),
            );

    logResponse(url, response);

    return response;
  }

  Future<http.Response> puttApi({
    required String url,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, String>? header,
  }) async {
    if (body != null) body.removeWhere((key, value) => value == null);
    if (query != null) query.removeWhere((key, value) => value == null);

    innerHeader.addAll(header ?? {});

    if (query != null) {
      query.removeWhere((key, value) => value == null);
      query.forEach((key, value) => query[key] = value.toString());
    }

    final uri = Uri.https(baseUrl, url, query);

    logRequest(url, body);

    final response =
        await http.put(uri, body: jsonEncode(body), headers: innerHeader).timeout(
              const Duration(seconds: 400),
              onTimeout: () => http.Response('connectionTimeOut', 481),
            );

    logResponse(url, response);

    return response;
  }

  Future<http.Response> deleteApi({
    required String url,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, String>? header,
  }) async {
    if (body != null) body.removeWhere((key, value) => value == null);

    if (query != null) {
      query.removeWhere((key, value) => value == null);
      query.forEach((key, value) => query[key] = value.toString());
    }

    innerHeader.addAll(header ?? {});

    final uri = Uri.https(baseUrl, url, query);

    logRequest(url, body);

    final response =
        await http.delete(uri, body: jsonEncode(body), headers: innerHeader).timeout(
              const Duration(seconds: 400),
              onTimeout: () => http.Response('connectionTimeOut', 481),
            );

    logResponse(url, response);

    return response;
  }

  Future<http.Response> uploadMultiPart({
    required String url,
    String? path,
    String type = 'POST',
    String nameFile = 'File',
    List<File?>? files,
    Map<String, dynamic>? fields,
    Map<String, String>? header,
  }) async {
    Map<String, String> f = {};
    (fields ?? {}).forEach((key, value) => f[key] = value.toString());

    innerHeader.addAll(header ?? {});
    final uri = Uri.https(baseUrl, '$url/${path ?? ''}');

    var request = http.MultipartRequest(type, uri);

    ///log
    logRequest(url, fields, additional: files?.firstOrNull?.length.toString());

    for (var file in (files ?? <File?>[])) {
      if (file == null) continue;

      final multipartFile = http.MultipartFile.fromBytes(
        nameFile,
        file.readAsBytesSync(),
        filename: basename(file.path),
        contentType: MediaType('image', 'jpeg'),
      );

      request.files.add(multipartFile);
    }

    request.headers.addAll(innerHeader);

    request.fields.addAll(f);

    final stream = await request.send();

    final response = await http.Response.fromStream(stream);

    ///log
    logResponse(url, response);

    return response;
  }
}

void logRequest(String url, Map<String, dynamic>? q, {String? additional}) {
  if (url.contains('api.php')) return;
  loggerObject.i('$url \n ${jsonEncode(q)}${additional == null ? '' : '\n$additional'}');
}

void logResponse(String url, http.Response response) {
  if (url.contains('api.php')) return;
  var r = [];
  var res = '';
  if (response.body.length > 800) {
    r = response.body.splitByLength1(800);
    for (var e in r) {
      res += '$e\n';
    }
  } else {
    res = response.body;
  }

  loggerObject.v('${response.statusCode} \n $res');
}

// extension on String {
//   List<String> splitByLength(int length) => [substring(0, length), substring(length)];
// }
