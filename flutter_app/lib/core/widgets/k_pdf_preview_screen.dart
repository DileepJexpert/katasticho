import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../api/api_client.dart';

class KPdfPreviewScreen extends ConsumerStatefulWidget {
  final String title;
  final String pdfEndpoint;
  final String fileName;

  const KPdfPreviewScreen({
    super.key,
    required this.title,
    required this.pdfEndpoint,
    required this.fileName,
  });

  @override
  ConsumerState<KPdfPreviewScreen> createState() => _KPdfPreviewScreenState();
}

class _KPdfPreviewScreenState extends ConsumerState<KPdfPreviewScreen> {
  Future<Uint8List>? _pdfFuture;

  @override
  void initState() {
    super.initState();
    _pdfFuture = _fetchPdf();
  }

  Future<Uint8List> _fetchPdf() async {
    final api = ref.read(apiClientProvider);
    final response = await api.dio.get<List<int>>(
      widget.pdfEndpoint,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<Uint8List>(
        future: _pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating PDF...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Failed to load PDF: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() => _pdfFuture = _fetchPdf()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final pdfBytes = snapshot.data!;
          return PdfPreview(
            build: (_) async => pdfBytes,
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            pdfFileName: widget.fileName,
          );
        },
      ),
    );
  }
}
