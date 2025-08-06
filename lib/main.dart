import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() => runApp(BoutiqueApp());

class BoutiqueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ma Boutique',
      theme: ThemeData(primarySwatch: Colors.green),
      home: RegisterPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// === Page d'inscription ===
class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  Future<void> _register() async {
    final response = await http.post(
      Uri.parse('https://paris-4nys.onrender.com/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nom': _nameCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text.trim()) ?? 0,
      }),
    );

    final data = jsonDecode(response.body);
    final msg = data['message'] ?? data['error'] ?? 'Erreur';
    if (response.statusCode == 200 || response.statusCode == 201) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BoutiquePage(user: _nameCtrl.text.trim())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Inscription')),
    body: Padding(
      padding: EdgeInsets.all(16),
      child: Column(children: [
        TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'Nom')),
        TextField(
            controller: _ageCtrl,
            decoration: InputDecoration(labelText: 'Âge'),
            keyboardType: TextInputType.number),
        SizedBox(height: 20),
        ElevatedButton(onPressed: _register, child: Text('S’inscrire')),
      ]),
    ),
  );
}

// === Page Boutique ===
class BoutiquePage extends StatefulWidget {
  final String user;
  BoutiquePage({required this.user});
  @override
  _BoutiquePageState createState() => _BoutiquePageState();
}

class _BoutiquePageState extends State<BoutiquePage> {
  List<dynamic> arts = [];
  late IO.Socket socket;

  Future<void> _fetch() async {
    final res = await http.get(Uri.parse('https://paris-4nys.onrender.com/get_articles'));
    if (res.statusCode == 200 && mounted) {
      setState(() => arts = jsonDecode(res.body));
    }
  }

  void _initSocket() {
    socket = IO.io('https://paris-4nys.onrender.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) => _fetch());
    socket.on('shop_update', (_) => _fetch());
    socket.onDisconnect((_) {});
  }

  void _acheter(Map a) async {
    String? dev = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Choisir une devise'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'usd'), child: Text('${a['prix_usd']} USD')),
          TextButton(onPressed: () => Navigator.pop(context, 'fc'), child: Text('${a['prix_fc']} FC')),
        ],
      ),
    );

    if (dev != null) {
      // Sans localisation, adresse vide ou par défaut
      final adresse = {
        'commune': '',
        'quartier': '',
        'avenue': '',
        'latitude': '',
        'longitude': '',
      };

      final res = await http.post(
        Uri.parse('https://paris-4nys.onrender.com/acheter'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user': widget.user,
          'article_id': a['id'],
          'devise': dev,
          'adresse': adresse,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(d['message'] ?? 'Achat effectué')),
        );
      } else {
        String msg;
        try {
          final err = jsonDecode(res.body);
          msg = err['error'] ?? 'Erreur inconnue';
        } catch (_) {
          msg = 'Erreur réseau ou réponse invalide';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $msg')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
    _initSocket();
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  void _openPage(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(
      title: Text('Boutique - ${widget.user}'),
      actions: [
        IconButton(icon: Icon(Icons.account_balance_wallet), onPressed: () => _openPage(SoldePage(user: widget.user))),
        IconButton(icon: Icon(Icons.receipt), onPressed: () => _openPage(RecusPage(user: widget.user))),
        IconButton(icon: Icon(Icons.attach_money), onPressed: () => _openPage(DepotPage(user: widget.user))),
      ],
    ),
    body: ListView.builder(
      itemCount: arts.length,
      itemBuilder: (_, i) {
        final a = arts[i];
        return Card(
          margin: EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (a['image'] != null)
              Image.network(a['image'], height: 180, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(children: [
                Text(a['description'] ?? 'Sans description', style: TextStyle(fontSize: 18)),
                Text('USD: ${a['prix_usd']}   FC: ${a['prix_fc']}', style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
            Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(onPressed: () => _acheter(a), child: Text('Acheter'))),
          ]),
        );
      },
    ),
  );
}

// === Page Solde ===
class SoldePage extends StatefulWidget {
  final String user;
  SoldePage({required this.user});
  @override
  _SoldePageState createState() => _SoldePageState();
}

class _SoldePageState extends State<SoldePage> {
  int fc = 0, usd = 0;
  void _fetch() async {
    final res = await http.get(Uri.parse('https://paris-4nys.onrender.com/balance/${widget.user}'));
    if (res.statusCode == 200 && mounted) {
      final d = jsonDecode(res.body);
      setState(() {
        fc = d['fc'] is int ? d['fc'] : int.tryParse(d['fc'].toString()) ?? 0;
        usd = d['usd'] is int ? d['usd'] : int.tryParse(d['usd'].toString()) ?? 0;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Mon compte')),
    body: Center(
        child: Text('FC: $fc\nUSD: $usd',
            style: TextStyle(fontSize: 22), textAlign: TextAlign.center)),
  );
}

// === Page Dépôt ===
class DepotPage extends StatefulWidget {
  final String user;
  DepotPage({required this.user});
  @override
  _DepotPageState createState() => _DepotPageState();
}

class _DepotPageState extends State<DepotPage> {
  final _fcCtrl = TextEditingController(text: '0');
  final _usdCtrl = TextEditingController(text: '0');
  String msg = '';

  Future<void> _envoyer() async {
    final fc = int.tryParse(_fcCtrl.text.trim()) ?? 0;
    final usd = int.tryParse(_usdCtrl.text.trim()) ?? 0;
    final res = await http.post(
      Uri.parse('https://paris-4nys.onrender.com/deposit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nom': widget.user, 'fc': fc, 'usd': usd}),
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      setState(() {
        msg = '✅ Dépôt effectué';
        _fcCtrl.text = _usdCtrl.text = '0';
      });
    } else {
      setState(() => msg = 'Erreur dépôt');
    }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Faire un dépôt')),
    body: Padding(
      padding: EdgeInsets.all(16),
      child: Column(children: [
        TextField(
            controller: _fcCtrl,
            decoration: InputDecoration(labelText: 'Montant FC'),
            keyboardType: TextInputType.number),
        TextField(
            controller: _usdCtrl,
            decoration: InputDecoration(labelText: 'Montant USD'),
            keyboardType: TextInputType.number),
        SizedBox(height: 20),
        ElevatedButton(onPressed: _envoyer, child: Text('Envoyer dépôt')),
        if (msg.isNotEmpty) SizedBox(height: 10),
        if (msg.isNotEmpty)
          Text(msg, style: TextStyle(color: msg.contains('✅') ? Colors.green : Colors.red)),
      ]),
    ),
  );
}

// === Page Reçus ===
class RecusPage extends StatefulWidget {
  final String user;
  RecusPage({required this.user});
  @override
  _RecusPageState createState() => _RecusPageState();
}

class _RecusPageState extends State<RecusPage> {
  List<dynamic> rcs = [];

  Future<void> _fetch() async {
    final r = await http.get(Uri.parse('https://paris-4nys.onrender.com/get_recus/${widget.user}'));
    if (r.statusCode == 200 && mounted) {
      setState(() => rcs = jsonDecode(r.body));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Mes Reçus')),
    body: ListView.builder(
      itemCount: rcs.length,
      itemBuilder: (_, i) {
        final r = rcs[i];
        final article = r['article'];
        String imageUrl = '';
        String description = '';
        String nomArticle = '';
        if (article is Map) {
          imageUrl = article['image']?.toString() ?? '';
          description = article['description']?.toString() ?? '';
          nomArticle = article['nom']?.toString() ?? '';
        }
        final prix = r['montant']?.toString() ?? '';
        final devise = r['devise']?.toString().toUpperCase() ?? '';
        String dateStr;
        try {
          final ts = r['timestamp'];
          final tsInt = ts is int ? ts : int.tryParse(ts.toString()) ?? 0;
          dateStr = DateTime.fromMillisecondsSinceEpoch(tsInt * 1000).toLocal().toString();
        } catch (_) {
          dateStr = 'Date invalide';
        }

        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageUrl, width: 70, height: 70, fit: BoxFit.cover),
                  ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomArticle.isNotEmpty ? nomArticle : description,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text('Montant payé : $prix $devise', style: TextStyle(color: Colors.black87)),
                      SizedBox(height: 4),
                      Text('Date : $dateStr', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
