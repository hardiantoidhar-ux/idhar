
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Penghubung langsung ke fungsi request milik MetaMask.
extension type EthereumProvider._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> request(JSAny? options);
}

class BlockchainService extends ChangeNotifier {
  final String rpcUrl =
      'https://ethereum-sepolia-rpc.publicnode.com';

  final String contractAddress =
      '0xfE5440706E7ae57441f28677D790e74e529F3796';

  String? account;
  bool isLoading = false;
  List<Map<String, dynamic>> daftarTugas = [];
  String? errorMessage;

  BlockchainService() {
    muatDaftarTugas();
  }

  static const String _jumlahSelector = '1dc35da6';
  static const String _ambilSelector = '31aaffe8';
  static const String _tambahSelector = '4a67f68f';
  static const String _selesaiSelector = '63032087';

  // Koneksi MetaMask
  Future<Object?> _walletRequest(
    Map<String, dynamic> request,
  ) async {
    final provider = globalContext['ethereum'];

    if (provider == null || provider.isUndefinedOrNull) {
      throw Exception(
        'MetaMask belum terpasang di browser.',
      );
    }

    final ethereum =
        EthereumProvider._(provider as JSObject);

    final promise = ethereum.request(request.jsify());
    final result = await promise.toDart;

    return result.dartify();
  }

  // Koneksi RPC Sepolia
  Future<dynamic> _rpc(
    String method,
    List<dynamic> params,
  ) async {
    final response = await http.post(
      Uri.parse(rpcUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'jsonrpc': '2.0',
        'method': method,
        'params': params,
        'id': 1,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'RPC gagal: HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    if (data['error'] != null) {
      throw Exception(data['error']['message']);
    }

    return data['result'];
  }

  String _word(int value) =>
      value.toRadixString(16).padLeft(64, '0');

  String _encodeString(String value) {
    final bytes = utf8.encode(value);

    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final padding = (64 - (hex.length % 64)) % 64;

    return _word(32) +
        _word(bytes.length) +
        hex +
        ('0' * padding);
  }

  String _decodeString(String hex) {
    final clean = hex.replaceFirst('0x', '');

    final offset =
        int.parse(clean.substring(0, 64), radix: 16) * 2;

    final length = int.parse(
      clean.substring(offset, offset + 64),
      radix: 16,
    );

    final start = offset + 64;

    final value = clean.substring(
      start,
      start + length * 2,
    );

    final bytes = <int>[];

    for (int i = 0; i < value.length; i += 2) {
      bytes.add(
        int.parse(
          value.substring(i, i + 2),
          radix: 16,
        ),
      );
    }

    return utf8.decode(bytes);
  }

  // Menghubungkan wallet
  Future<void> hubungkanWallet() async {
    try {
      final result = await _walletRequest({
        'method': 'eth_requestAccounts',
      });

      final accounts = result as List<dynamic>?;

      if (accounts == null || accounts.isEmpty) {
        throw Exception('Wallet belum terhubung.');
      }

      account = accounts[0].toString();

      final chainResult = await _walletRequest({
        'method': 'eth_chainId',
      });

      final chainId = chainResult.toString().toLowerCase();

      if (chainId != '0xaa36a7') {
        account = null;

        throw Exception(
          'Silakan pilih jaringan Sepolia di MetaMask.',
        );
      }

      errorMessage = null;
      await muatDaftarTugas();
    } catch (e) {
      errorMessage = 'Gagal menghubungkan wallet: $e';
      notifyListeners();
    }
  }

  // Memuat daftar tugas dari blockchain
  Future<void> muatDaftarTugas() async {
    isLoading = true;
    notifyListeners();

    try {
      final jumlahData = await _rpc(
        'eth_call',
        [
          {
            'to': contractAddress,
            'data': '0x$_jumlahSelector',
          },
          'latest',
        ],
      );

      final total = int.parse(
        jumlahData.toString().replaceFirst('0x', ''),
        radix: 16,
      );

      final List<Map<String, dynamic>> hasil = [];

      for (int i = 0; i < total; i++) {
        final data = await _rpc(
          'eth_call',
          [
            {
              'to': contractAddress,
              'data': '0x$_ambilSelector${_word(i)}',
            },
            'latest',
          ],
        );

        final clean =
            data.toString().replaceFirst('0x', '');

        final judul = _decodeString(clean);

        final selesai = int.parse(
              clean.substring(64, 128),
              radix: 16,
            ) ==
            1;

        final dibuat = int.parse(
          clean.substring(128, 192),
          radix: 16,
        );

        final pembuat =
            '0x${clean.substring(216, 256)}';

        hasil.add({
          'id': i,
          'judul': judul,
          'selesai': selesai,
          'dibuat': dibuat,
          'pembuat': pembuat,
        });
      }

      daftarTugas = hasil.reversed.toList();
      errorMessage = null;
    } catch (e) {
      errorMessage = 'Gagal memuat tugas: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  // Mengirim transaksi ke MetaMask
  Future<void> _kirimTransaksi(String data) async {
    if (account == null) {
      throw Exception(
        'Hubungkan MetaMask terlebih dahulu.',
      );
    }

    await _walletRequest({
      'method': 'eth_sendTransaction',
      'params': [
        {
          'from': account,
          'to': contractAddress,
          'data': data,
        }
      ],
    });

    await Future.delayed(
      const Duration(seconds: 5),
    );

    await muatDaftarTugas();
  }

  // Menambahkan tugas
  Future<void> tambahTugas(String judul) async {
    if (judul.trim().isEmpty) return;

    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final data =
          '0x$_tambahSelector${_encodeString(judul.trim())}';

      await _kirimTransaksi(data);
    } catch (e) {
      errorMessage = 'Gagal menambah tugas: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  // Menandai tugas selesai
  Future<void> tandaiSelesai(int id) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final data = '0x$_selesaiSelector${_word(id)}';

      await _kirimTransaksi(data);
    } catch (e) {
      errorMessage = 'Gagal menyelesaikan tugas: $e';
    }

    isLoading = false;
    notifyListeners();
  }
}
