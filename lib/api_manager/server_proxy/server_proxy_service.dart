import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:saed_http/api_manager/server_proxy/server_proxy_request.dart';

import '../../pair_class.dart';
import '../api_service.dart';


extension MapResponse on Response {
  dynamic get json => jsonDecode(body);
}

Future<Pair<dynamic, Response?>> getServerProxyApi(
    {required ApiServerRequest request}) async {
  final response = await APIService().postApi(
      url: 'api/services/app/HttpRequestService/ExecuteRequest', body: request.toJson());

  if (response.statusCode == 200) {
    return Pair(response.json['result'], null);
  } else {
    return Pair(null, response);
  }
}
