import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'api_error_parser.dart';

mixin FormErrorHandler<T extends StatefulWidget> on State<T> {
  Map<String, String> serverErrors = {};

  String? fieldError(String field, String? clientError) {
    if (clientError != null) return clientError;
    return serverErrors[field];
  }

  void handleSaveError(Object e, GlobalKey<FormState> formKey) {
    if (e is DioException) {
      final fieldErrs = ApiErrorParser.fieldErrors(e);
      if (fieldErrs.isNotEmpty) {
        setState(() => serverErrors = fieldErrs);
        formKey.currentState!.validate();
        _showSnack('Please fix the errors below');
      } else {
        _showSnack(ApiErrorParser.message(e));
      }
    } else {
      _showSnack('Save failed. Please try again.');
    }
  }

  void clearServerErrors() {
    if (serverErrors.isNotEmpty) {
      setState(() => serverErrors = {});
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
