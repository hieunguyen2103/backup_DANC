import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StreamVideoScreen extends StatefulWidget {
  @override
  State<StreamVideoScreen> createState() => _StreamVideoScreenState();
}

class _StreamVideoScreenState extends State<StreamVideoScreen> {
  late final WebViewController _webViewController;
  bool _isError = false;
  bool _isLoading = true;


   @override
  void initState() {
    super.initState();
    _loadUserAndStream();
  }

  Future<void> _loadUserAndStream() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final data = userDoc.data();
        if (data != null && data.containsKey('level_id')) {
          final levelId = int.parse(data['level_id'].toString()).toString();
          final streamUrl = 'http://103.69.97.153:8888/pi_tang_$levelId.html';

          _webViewController = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setNavigationDelegate(
              NavigationDelegate(
                onPageStarted: (_) {
                  setState(() => _isError = false);
                },
                onWebResourceError: (error) {
                  setState(() => _isError = true);
                },
              ),
            )
            ..loadRequest(Uri.parse(streamUrl));
        } else {
          _isError = true;
        }
      } catch (e) {
        print('Lỗi khi lấy level_id: $e');
        _isError = true;
      }
    } else {
      _isError = true;
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _reloadPage() {
    _webViewController.reload();
  }

  // void initState() {
  //   super.initState();

  //   _webViewController = WebViewController()
  //     ..setJavaScriptMode(JavaScriptMode.unrestricted)
  //     ..setNavigationDelegate(
  //       NavigationDelegate(
  //         onPageStarted: (_) {
  //           setState(() => _isError = false);
  //         },
  //         onWebResourceError: (error) {
  //           setState(() => _isError = true);
  //         },
  //       ),
  //     )
  //     ..loadRequest(Uri.parse('http://103.69.97.153:8888/pi_tang_1.html'));
  // }

  // void _reloadPage() {
  //   _webViewController.reload();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera Live Stream'),
        actions: [
          IconButton(onPressed: _reloadPage, icon: Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _isError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off, size: 60, color: Colors.grey),
                      SizedBox(height: 10),
                      Text('Không thể tải stream'),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _reloadPage,
                        child: Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : WebViewWidget(controller: _webViewController),
    );
  }
}
