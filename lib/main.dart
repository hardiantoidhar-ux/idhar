
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'blockchain_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => BlockchainService(),
      child: const ChainTodoApp(),
    ),
  );
}

class ChainTodoApp extends StatelessWidget {
  const ChainTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChainTodo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const TodoHomePage(),
    );
  }
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final TextEditingController judulController =
      TextEditingController();

  @override
  void dispose() {
    judulController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BlockchainService>(
      builder: (context, service, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'ChainTodo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: service.muatDaftarTugas,
                icon: const Icon(Icons.refresh),
                tooltip: 'Muat ulang',
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet,
                          size: 35,
                          color: Colors.indigo,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Wallet MetaMask',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (service.account == null)
                          ElevatedButton.icon(
                            onPressed: service.hubungkanWallet,
                            icon: const Icon(Icons.link),
                            label: const Text('Hubungkan Wallet'),
                          )
                        else ...[
                          Text(
                            '${service.account!.substring(0, 8)}...'
                            '${service.account!.substring(service.account!.length - 6)}',
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Jaringan Sepolia',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: judulController,
                  decoration: InputDecoration(
                    labelText: 'Judul tugas',
                    hintText: 'Masukkan tugas baru',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: service.isLoading
                          ? null
                          : () async {
                              final judul =
                                  judulController.text.trim();

                              if (judul.isEmpty) return;

                              await service.tambahTugas(judul);

                              if (service.errorMessage == null) {
                                judulController.clear();
                              }
                            },
                    ),
                  ),
                  onSubmitted: (value) async {
                    if (value.trim().isEmpty) return;

                    await service.tambahTugas(value);

                    if (service.errorMessage == null) {
                      judulController.clear();
                    }
                  },
                ),

                const SizedBox(height: 12),

                if (service.isLoading)
                  const LinearProgressIndicator(),

                if (service.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      service.errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daftar Tugas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('${service.daftarTugas.length} tugas'),
                  ],
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: service.daftarTugas.isEmpty
                      ? const Center(
                          child: Text('Belum ada tugas.'),
                        )
                      : ListView.builder(
                          itemCount: service.daftarTugas.length,
                          itemBuilder: (context, index) {
                            final tugas =
                                service.daftarTugas[index];

                            final bool selesai =
                                tugas['selesai'] as bool;

                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    '${tugas['id']}',
                                  ),
                                ),
                                title: Text(
                                  tugas['judul'],
                                  style: TextStyle(
                                    decoration: selesai
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  selesai
                                      ? 'Sudah selesai'
                                      : 'Belum selesai',
                                ),
                                trailing: selesai
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                        ),
                                        onPressed:
                                            service.isLoading ||
                                                    service.account == null
                                                ? null
                                                : () {
                                                    service.tandaiSelesai(
                                                      tugas['id'] as int,
                                                    );
                                                  },
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
